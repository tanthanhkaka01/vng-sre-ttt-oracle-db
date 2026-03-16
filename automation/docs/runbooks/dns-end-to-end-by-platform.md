# DNS End-to-End Runbook by Platform

## Purpose

This runbook defines the step-by-step DNS operating flow for:

- VMware vSphere
- OpenStack
- VMware Workstation Pro 17 lab

Shared DNS assumptions for all three platforms:

- DNS zone: `company.local`
- Primary DNS: `192.168.10.53`
- Secondary DNS: `192.168.10.54`
- Logical DB endpoint: `db.company.local`
- Primary SCAN: `scan-db.company.local`
- Standby SCAN: `scan-standby.company.local`

---

## Shared DNS Objects

Manage these records through the central DNS workflow:

| Record Type | Example | Target |
|------|------|------|
| Host A | `rac-node1.company.local` | `192.168.10.11` |
| Host A | `rac-node2.company.local` | `192.168.10.12` |
| Host A | `rac-node3.company.local` | `192.168.110.11` |
| Host A | `rac-node4.company.local` | `192.168.110.12` |
| VIP A | `rac-node1-vip.company.local` | Reserved VIP address |
| VIP A | `rac-node2-vip.company.local` | Reserved VIP address |
| SCAN A | `scan-db.company.local` | `192.168.10.101-103` |
| SCAN A | `scan-standby.company.local` | `192.168.110.101-103` |
| Service CNAME | `db.company.local` | `scan-db.company.local` or `scan-standby.company.local` |

Recommended TTL:

- Host and VIP records: `300`
- SCAN records: `60`
- `db.company.local`: `30`

---

## Preconditions

Complete these checks before using any platform-specific procedure:

1. Confirm the `company.local` zone already exists.
2. Confirm the automation account is restricted to the required zone.
3. Confirm the IP plan and hostname plan are approved.
4. Confirm SCAN IPs are reserved and not in use.
5. Confirm the rollback target for `db.company.local` is recorded.
6. Confirm the target nodes are reachable through management access.
7. Confirm the target SCAN listener state before switching `db.company.local`.

---

## Standard Validation Commands

Run these commands after resolver configuration and after every DNS change:

```bash
getent hosts scan-db.company.local
getent hosts scan-standby.company.local
getent hosts db.company.local
```

Additional checks:

```bash
dig +short scan-db.company.local
dig +short scan-standby.company.local
dig +short db.company.local
```

Expected results:

- `scan-db.company.local` returns exactly 3 IPs
- `scan-standby.company.local` returns exactly 3 IPs
- `db.company.local` resolves to the active site target

---

## VMware vSphere Procedure

### Files Used

- `automation/terraform/environments/prod/main.tf`
- `automation/terraform/environments/prod/terraform.tfvars.example`
- `automation/terraform/modules/vmware_vm/main.tf`
- `automation/ansible/playbooks/dns-validate.yml`

### Step-by-Step

1. Copy and prepare `automation/terraform/environments/prod/terraform.tfvars`.
2. For each production VM, set `dns_servers = ["192.168.10.53", "192.168.10.54"]`.
3. Define `host_records` for production nodes.
4. Define `scan_name = "scan-db.company.local"`.
5. Define `scan_ips = ["192.168.10.101", "192.168.10.102", "192.168.10.103"]`.
6. Define `service_name = "db.company.local"`.
7. Define `service_target = "scan-db.company.local"`.
8. Run Terraform plan.
9. Review the plan output.
10. Run Terraform apply.
11. Log in to the provisioned guest OS.
12. Confirm the guest resolver points to `192.168.10.53` and `192.168.10.54`.
13. Submit or execute the central DNS record workflow for host, VIP, SCAN, and service records.
14. Run DNS validation from the production RAC nodes.
15. Record command output and final DNS targets in the change record.

### Example Inputs

```hcl
host_records = [
  { name = "rac-node1.company.local", value = "192.168.10.11" },
  { name = "rac-node2.company.local", value = "192.168.10.12" }
]

scan_name      = "scan-db.company.local"
scan_ips       = ["192.168.10.101", "192.168.10.102", "192.168.10.103"]
service_name   = "db.company.local"
service_target = "scan-db.company.local"
```

```bash
terraform -chdir=automation/terraform/environments/prod plan
terraform -chdir=automation/terraform/environments/prod apply
```

```bash
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/dns-validate.yml
```

---

## OpenStack Procedure

### Files Used

- `automation/terraform/environments/dr/main.tf`
- `automation/terraform/environments/dr/terraform.tfvars.example`
- `automation/terraform/modules/openstack_instance/main.tf`
- `automation/ansible/playbooks/dns-validate.yml`

### Step-by-Step

1. Copy and prepare `automation/terraform/environments/dr/terraform.tfvars`.
2. In the cloud-init section, set `manage_resolv_conf: true`.
3. In the cloud-init section, set nameservers to `192.168.10.53` and `192.168.10.54`.
4. In the cloud-init section, set the search domain to `company.local`.
5. Define `host_records` for DR nodes.
6. Define `scan_name = "scan-standby.company.local"`.
7. Define `scan_ips = ["192.168.110.101", "192.168.110.102", "192.168.110.103"]`.
8. Define `service_name = "db.company.local"`.
9. Define `service_target = "scan-standby.company.local"`.
10. Run Terraform plan.
11. Review the plan output.
12. Run Terraform apply.
13. Wait for cloud-init completion and SSH readiness.
14. Log in to the guest OS.
15. Confirm `/etc/resolv.conf` points to `192.168.10.53` and `192.168.10.54`.
16. Submit or execute the central DNS record workflow for DR host and SCAN records.
17. Run DNS validation from the DR RAC nodes.
18. Record command output and final DNS targets in the change record.

### Example Inputs

```hcl
host_records = [
  { name = "rac-node3.company.local", value = "192.168.110.11" },
  { name = "rac-node4.company.local", value = "192.168.110.12" }
]

scan_name      = "scan-standby.company.local"
scan_ips       = ["192.168.110.101", "192.168.110.102", "192.168.110.103"]
service_name   = "db.company.local"
service_target = "scan-standby.company.local"
```

Cloud-init pattern:

```yaml
manage_resolv_conf: true
resolv_conf:
  nameservers:
    - 192.168.10.53
    - 192.168.10.54
  searchdomains:
    - company.local
```

```bash
terraform -chdir=automation/terraform/environments/dr plan
terraform -chdir=automation/terraform/environments/dr apply
```

```bash
ansible-playbook -i automation/ansible/inventories/dr/hosts.yml automation/ansible/playbooks/dns-validate.yml
```

---

## VMware Workstation Pro 17 Procedure

### Files Used

- `automation/workstation-pro/scripts/create-vm.ps1`
- `automation/workstation-pro/scripts/start-vm.ps1`
- `automation/workstation-pro/scripts/invoke-lab-build.ps1`
- `automation/ansible/playbooks/network.yml`
- `automation/ansible/playbooks/dns-validate.yml`

### Step-by-Step

1. Prepare the Workstation Pro lab VM configuration JSON.
2. Clone or build the required lab VMs.
3. Start the lab VMs.
4. Wait for SSH access.
5. Apply the guest network baseline.
6. Confirm the guest resolver points to `192.168.10.53` and `192.168.10.54`.
7. Create or request the required central DNS host and SCAN records.
8. Confirm the guest resolves `scan-db.company.local`.
9. Confirm the guest resolves `scan-standby.company.local`.
10. Confirm the guest resolves `db.company.local`.
11. Run Ansible DNS validation from the lab inventory.
12. Record command output and final DNS targets in the change record.

### Example Commands

```powershell
powershell -ExecutionPolicy Bypass -File automation/workstation-pro/scripts/invoke-lab-build.ps1 -ConfigPath automation/workstation-pro/configs/lab-rac-nodes.example.json
```

```bash
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/network.yml
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/dns-validate.yml
```

---

## DR Cutover Procedure

Use this procedure for DNS endpoint switching because the DNS authority is shared across platforms.

### Primary to Standby

1. Confirm Data Guard role transition is complete.
2. Confirm standby SCAN listeners are healthy.
3. Capture the current value of `db.company.local`.
4. Update `db.company.local` from `scan-db.company.local` to `scan-standby.company.local`.
5. Validate `db.company.local` from at least two probe hosts or application subnets.
6. Record the old value, new value, TTL, timestamp, and command output.

### Example Command

```bash
./update-db-endpoint.sh scan-standby.company.local
```

### Rollback

1. Repoint `db.company.local` back to `scan-db.company.local`.
2. Re-run forward lookup validation.
3. Record rollback evidence in the incident or change ticket.

---

## Implementation Status

| Capability | VMware vSphere | OpenStack | Workstation Pro 17 |
|------|------|------|------|
| Guest DNS resolver setup | Partial to runnable | Partial to runnable | Runnable with guest baseline |
| DNS validation | Runnable now | Runnable now | Runnable now |
| Central DNS record creation | Placeholder only | Placeholder only | Manual or external |
| DR endpoint cutover logic | Documented | Documented | Documented |

Current limitation:

- Real authoritative DNS record creation still needs a provider-backed implementation or an approved script wrapper.
