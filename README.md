# serverTest-do

Infrastructure-as-code for a DigitalOcean lab environment, provisioning the four-machine cluster required by [Kubernetes the Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way) (KtHW).

Terraform manages the VPC and droplets. Ansible runs a production-grade server baseline and automates KtHW docs 01–03. GitHub Actions orchestrates the pipeline on push to `main`.

---

## KtHW Tutorial Coverage

This repo automates the first three sections of Kubernetes the Hard Way:

| KtHW Doc | Section | Automation Status |
|----------|---------|-------------------|
| [01 - Prerequisites](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-prerequisites.md) | Provision 4 Debian 12 machines | ✅ Terraform (`infra/`) |
| [02 - Jumpbox Setup](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-jumpbox.md) | Clone repo, download binaries, install kubectl | ✅ Ansible (`playbooks/jumpbox.yml`) |
| [03 - Compute Resources](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/03-compute-resources.md) | SSH keys, hostnames, /etc/hosts, machines.txt | ✅ Ansible (`playbooks/network.yml`) |
| 04+ | Certificate authority onwards | ❌ Manual — start here after deploy |

After the CI pipeline completes, the jumpbox is fully configured. SSH in and begin the tutorial at **doc 04 (Certificate Authority)**.

---

## Repository Structure

```
.
├── .github/
│   └── workflows/
│       └── provision.yml   # CI pipeline — provisions infra and runs Ansible
├── infra/
│   ├── backend.tf          # DO Spaces remote state backend
│   ├── main.tf             # Provider, VPC, and droplet resources
│   ├── variables.tf        # All input variables with defaults
│   └── outputs.tf          # IPs, /etc/hosts block, SSH config
└── playbooks/
    ├── site.yml            # Master playbook — orchestrates execution order
    ├── setup.yml           # Server hardening baseline (all nodes)
    ├── jumpbox.yml         # KtHW tooling and SSH keypair (jumpbox only)
    └── network.yml         # Hostnames, /etc/hosts, machines.txt, SSH config
```

---

## Playbook Execution Flow

The CI pipeline runs `site.yml`, which imports playbooks in this order:

```
1. setup.yml    → All nodes    → Hardening baseline, deploy user, UFW, fail2ban
2. jumpbox.yml  → Jumpbox only → KtHW repo, binaries (~500MB), kubectl, SSH keypair
3. network.yml  → All nodes    → Hostnames, /etc/hosts, machines.txt, connectivity check
```

**Key automation decisions:**

- **Jumpbox SSH keypair**: A fresh ed25519 keypair is generated each CI run. The public key is pushed to all nodes during `setup.yml`, and the private key is placed on the jumpbox during `jumpbox.yml`. This lets the jumpbox reach all cluster nodes from the moment root SSH is locked out.

- **machines.txt**: Auto-generated from Terraform outputs. Located at `/home/deploy/kubernetes-the-hard-way/machines.txt` on the jumpbox.

- **Binary downloads**: The ~500MB of Kubernetes binaries are downloaded once to the jumpbox. The `creates:` guard makes this idempotent — re-runs skip the download if `downloads/` exists.

---

## Infrastructure

### Network

A dedicated VPC (`kthw-vpc`) is created in `nyc3` with a `10.10.0.0/24` private CIDR. All droplets live inside it. Only the jumpbox has a meaningful public IP — `server`, `node-0`, and `node-1` are accessed via ProxyJump through it.

### Machines

Matches the [KtHW prerequisites](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/01-prerequisites.md) exactly. All machines run Debian 12 (bookworm).

| Name      | Role            | CPU | RAM    | Disk  | DO Slug               | $/mo |
|-----------|-----------------|-----|--------|-------|-----------------------|------|
| `jumpbox` | Admin / bastion | 1   | 512 MB | 10 GB | `s-1vcpu-512mb-10gb`  | $4   |
| `server`  | Control plane   | 1   | 2 GB   | 50 GB | `s-1vcpu-2gb`         | $12  |
| `node-0`  | Worker          | 1   | 2 GB   | 50 GB | `s-1vcpu-2gb`         | $12  |
| `node-1`  | Worker          | 1   | 2 GB   | 50 GB | `s-1vcpu-2gb`         | $12  |

**Total: ~$40/mo while running.** Destroy when not in use — `terraform destroy` via the workflow dispatch takes everything down cleanly.

### Remote State

Terraform state is stored in a DigitalOcean Space (`lazy1-tfstate`, region `nyc3`) using the S3-compatible backend. The CI pipeline checks whether the bucket exists before `terraform init` runs and creates it if not — no manual bootstrapping required.

State locking is not supported by DO Spaces (there is no DynamoDB equivalent). This is fine for a solo setup — avoid running concurrent pipeline executions.

To reuse this backend in another DO module, copy `backend.tf` and change the `key` value, for example:

```hcl
key = "my-other-project/terraform.tfstate"
```

---

## Server Baseline (Ansible)

After Terraform provisions the machines, Ansible runs `playbooks/setup.yml` against all four droplets. It applies a production-grade hardening baseline:

- **System update** — full package upgrade before anything else
- **Non-root deploy user** — `deploy` user created with your SSH key and passwordless sudo; root SSH login disabled
- **SSH hardening** — written as a drop-in to `sshd_config.d/` so it survives package updates. Key settings: keys only (no passwords), `MaxAuthTries 5`, `AllowUsers deploy`, idle session timeout
- **UFW firewall** — default-deny inbound; allows SSH (22), HTTP (80), HTTPS (443)
- **Fail2ban** — bans IPs after 5 failed SSH attempts within 10 minutes; uses `ufw` as the ban backend and `systemd` as the log backend (required on Debian 12)
- **Sysctl hardening** — SYN cookie protection, disable ICMP redirects, disable source routing, log martian packets
- **Unattended upgrades** — security patches applied automatically

### The `deploy` User Adaptation

The original KtHW tutorial assumes root SSH access. This setup uses a hardened `deploy` user instead. Translation rules for the rest of the tutorial:

| Original KtHW | This Setup |
|---------------|------------|
| `ssh root@<host>` | `ssh deploy@<host>` or `ssh <host>` (using config) |
| `scp file root@<host>:~/` | `scp file deploy@<host>:~/` |
| `ssh root@<host> "<cmd>"` | `ssh <host> "sudo <cmd>"` |
| Commands as root on a node | Prefix with `sudo` or `sudo -i` |
| Writing to `/etc/`, `/opt/` | Pipe through `sudo tee` or `scp` then `sudo mv` |

Example — writing a file to a system path:
```bash
# Instead of: ssh root@server "cat > /etc/somefile" < localfile
scp localfile deploy@server:~/somefile
ssh server "sudo mv ~/somefile /etc/somefile"

# Or inline with tee:
ssh server "sudo tee /etc/somefile > /dev/null" < localfile
```

---

## CI Pipeline

The workflow at `.github/workflows/provision.yml` has two jobs:

**`terraform`** — runs on every push to `main` or manually via workflow dispatch:
1. Fetches secrets from Bitwarden Secrets Manager
2. Checks the DO Spaces bucket exists (creates it if not)
3. Runs `terraform init` and `terraform apply`
4. Prints public IPs, a ready-to-paste `/etc/hosts` block, and an `~/.ssh/config` block to the Actions log

**`ansible`** — runs after `terraform` completes on an apply:
1. Derives the SSH public key from the private key (`ssh-keygen -y`)
2. Builds an inventory from the Terraform IP output
3. Runs `playbooks/setup.yml` against all four machines

To destroy all infrastructure, trigger the workflow manually and select `destroy`.

---

## Secrets

Secrets are stored in Bitwarden Secrets Manager and fetched at runtime using the `bitwarden/sm-action`. One repository-level secret is required in GitHub:

| GitHub Secret     | Description                              |
|-------------------|------------------------------------------|
| `BW_ACCESS_TOKEN` | Bitwarden Secrets Manager access token  |

The following secrets must exist in Bitwarden (UUIDs are referenced in the workflow):

| Secret                  | Description                                         |
|-------------------------|-----------------------------------------------------|
| `DO_TOKEN`              | DigitalOcean API token                              |
| `DO_SSH_KEY_FINGERPRINT`| Fingerprint of SSH key registered in DO             |
| `DO_SPACES_ACCESS_KEY`  | Spaces access key (for Terraform state backend)     |
| `DO_SPACES_SECRET_KEY`  | Spaces secret key (for Terraform state backend)     |
| `SSH_PRIVATE_KEY`       | Private key used by Ansible to connect to droplets  |

---

## Accessing the Machines

After the workflow runs, the Terraform job prints a ready-made SSH config block to the Actions log. Go to **Actions → latest run → `terraform` job → "Show VM IPs"** step and you'll see something like:

```
=== ~/.ssh/config block ===
# KtHW — direct jumpbox access
Host jumpbox
  HostName 104.131.174.26
  User root
  IdentityFile ~/.ssh/id_rsa

Host server
  HostName 10.10.0.3
  User root
  IdentityFile ~/.ssh/id_rsa
  ProxyJump jumpbox

Host node-0
  HostName 10.10.0.4
  User root
  IdentityFile ~/.ssh/id_rsa
  ProxyJump jumpbox

Host node-1
  HostName 10.10.0.5
  User root
  IdentityFile ~/.ssh/id_rsa
  ProxyJump jumpbox
```

Append that block to `~/.ssh/config` on your local machine, then connect by name:

```bash
ssh jumpbox   # direct public IP
ssh server    # tunnels through jumpbox automatically
ssh node-0
ssh node-1
```

The `ProxyJump` directive means SSH transparently routes through the jumpbox to reach the private VPC IPs on the other three machines — no manual tunneling needed.

> **Note:** Once the Ansible playbook has completed, root login is disabled. Change the `User` lines in your SSH config from `root` to `deploy`.

---



### Spin up the cluster

Push to `main` or go to **Actions → Terraform Infra → Run workflow → apply**.

After the run, grab the SSH config from the Actions log and append it to `~/.ssh/config`:

```bash
# Then connect directly by name
ssh jumpbox
ssh server      # proxied through jumpbox automatically
ssh node-0
ssh node-1
```

### Tear it all down

Go to **Actions → Terraform Infra → Run workflow → destroy**.

This destroys all droplets and the VPC. The Spaces bucket and its state file are left intact so the next apply picks up cleanly.

### Change the machines

Edit the `vms` map in `infra/variables.tf` and push. Terraform will diff against the current state and only touch what changed. Removing an entry destroys that droplet; adding one creates it.

---

## Post-Deploy Workflow

After the CI pipeline completes successfully:

### 1. Update your local SSH config

Copy the SSH config block from the Actions log (**terraform job → "Show VM IPs"**) and paste it into `~/.ssh/config`. Change `User root` to `User deploy`:

```
Host jumpbox
  HostName <jumpbox-public-ip>
  User deploy
  IdentityFile ~/.ssh/id_rsa

Host server
  HostName <server-private-ip>
  User deploy
  IdentityFile ~/.ssh/id_rsa
  ProxyJump jumpbox

# ... node-0, node-1
```

### 2. Connect to the jumpbox

```bash
ssh jumpbox
```

### 3. Verify the KtHW setup

```bash
# Check kubectl works
kubectl version --client

# Check machines.txt
cat ~/kubernetes-the-hard-way/machines.txt

# Verify connectivity to cluster nodes
for host in server node-0 node-1; do
  ssh -n $host hostname
done
```

### 4. Continue the tutorial

The jumpbox is ready. Navigate to the KtHW directory and continue from doc 04:

```bash
cd ~/kubernetes-the-hard-way
# Start with: https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-certificate-authority.md
```

---

## Local Development

```bash
cd infra

export AWS_ACCESS_KEY_ID=<spaces-access-key>
export AWS_SECRET_ACCESS_KEY=<spaces-secret-key>
export TF_VAR_do_token=<do-token>
export TF_VAR_ssh_key_fingerprint=<key-fingerprint>

terraform init
terraform plan
terraform apply
```

---

## Troubleshooting

### "Connection refused" on SSH

If SSH connections are refused but the host pings:

1. **Check if you're banned by fail2ban** — Access the droplet via DigitalOcean Console (Dashboard → Droplets → Access → Launch Droplet Console):
   ```bash
   sudo fail2ban-client status sshd
   ```

2. **Unban your IP**:
   ```bash
   # Get your public IP (run locally)
   curl -s ifconfig.me

   # Unban it (in DO Console)
   sudo fail2ban-client set sshd unbanip YOUR_IP
   ```

3. **Check SSH service is running**:
   ```bash
   sudo systemctl status sshd
   ```

### "REMOTE HOST IDENTIFICATION HAS CHANGED"

After a redeploy, the droplets have new host keys but your `~/.ssh/known_hosts` has the old ones cached:

```bash
# Remove stale keys for all nodes
ssh-keygen -R <jumpbox-ip>
ssh-keygen -R 10.10.0.2   # jumpbox private
ssh-keygen -R 10.10.0.3   # varies by deploy
ssh-keygen -R 10.10.0.4
ssh-keygen -R 10.10.0.5
```

Or remove all keys for the VPC range at once:
```bash
sed -i '' '/^10\.10\.0\./d' ~/.ssh/known_hosts
```

### Stale SSH config after redeploy

If you redeployed and IPs changed, update your `~/.ssh/config` with the new IPs from the Actions log (**terraform job → "Show VM IPs"**).

### cloud-init overwrites /etc/hosts

DigitalOcean's cloud-init may rewrite `/etc/hosts` on reboot. The `network.yml` playbook disables this by setting `manage_etc_hosts: false` in `/etc/cloud/cloud.cfg`. If you still see issues:

```bash
ssh <host> "sudo sed -i 's/manage_etc_hosts: true/manage_etc_hosts: false/' /etc/cloud/cloud.cfg"
```

### SSH loop only processes first host

When iterating over hosts in a `while read` loop, SSH consumes stdin and exits early. Always use `-n`:

```bash
# Wrong — exits after first host
while read IP FQDN HOST SUBNET; do
  ssh deploy@${IP} hostname
done < machines.txt

# Correct — use -n to prevent stdin consumption
while read IP FQDN HOST SUBNET; do
  ssh -n deploy@${IP} hostname
done < machines.txt
```