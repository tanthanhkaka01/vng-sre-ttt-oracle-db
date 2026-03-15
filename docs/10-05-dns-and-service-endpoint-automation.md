# 10-05 - DNS and Service Endpoint Automation

## Overview

This section describes how to automate DNS record management for Oracle RAC and Data Guard.

DNS automation is critical because database connectivity, SCAN resolution, VIP assignment, and disaster recovery cutover all rely on accurate and timely name resolution.

Automation scope includes:

- Host A records
- VIP records
- SCAN records
- Database service endpoint records
- TTL policy
- DR failover DNS update workflow

---

## DNS Objects to Automate

| Record Type | Example | Purpose |
|------|------|------|
| Host A record | `rac-node1.company.local` | Node public hostname |
| VIP A record | `rac-node1-vip.company.local` | Oracle RAC fast client failover |
| SCAN A record | `scan-db.company.local` | Cluster client entry point |
| Service CNAME | `db.company.local` | Stable application endpoint |
| DR SCAN A record | `scan-standby.company.local` | DR cluster entry point |

---

## Automation Source of Truth

DNS definitions should come from code, not from manual tickets alone.

Example variable structure:

```yaml
dns_records:
  hosts:
    - name: rac-node1.company.local
      value: 192.168.10.11
    - name: rac-node2.company.local
      value: 192.168.10.12
  scan_primary:
    - 192.168.10.101
    - 192.168.10.102
    - 192.168.10.103
  service_endpoint:
    name: db.company.local
    target: scan-db.company.local
    ttl: 30
```

---

## Prerequisites

Before automating DNS, confirm:

1. The DNS zone already exists
2. The automation account has permission only for the required zone
3. Hostnames and IP addresses are approved
4. The SCAN addresses are reserved and not in use
5. A rollback target is documented for service endpoint records

These checks prevent accidental production outages caused by incorrect records.

---

## Automation Methods

Recommended options:

- Terraform provider for enterprise DNS platform
- Ansible modules for Infoblox, Windows DNS, or API-driven DNS services
- Controlled script wrapper if no native provider exists

The preferred model is:

- Provision records during infrastructure build
- Validate records before Oracle installation
- Update service endpoint records during DR workflow

---

## Step-by-Step DNS Build Flow

Use this order:

1. Create node A records
2. Create VIP A records
3. Create SCAN A records
4. Create logical database CNAME
5. Run lookup validation from all RAC nodes
6. Save results in the change ticket

Freshers should not update the logical DB endpoint first. Always build the lower-level records before the user-facing alias.

---

## Example Terraform for DNS

Example `automation/terraform/modules/dns_records/main.tf`:

```hcl
resource "infoblox_a_record" "node_records" {
  for_each = { for item in var.host_records : item.name => item }
  fqdn     = each.value.name
  ip_addr  = each.value.value
  ttl      = 300
}

resource "infoblox_a_record" "scan_records" {
  for_each = toset(var.scan_ips)
  fqdn     = var.scan_name
  ip_addr  = each.value
  ttl      = 60
}

resource "infoblox_cname_record" "service_endpoint" {
  alias = var.service_name
  canonical = var.service_target
  ttl = 30
}
```

Example variables:

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

Run:

```bash
terraform -chdir=automation/terraform/environments/prod plan -target=module.dns_primary
terraform -chdir=automation/terraform/environments/prod apply -target=module.dns_primary
```

---

## Example Script for Dynamic DNS Update

If the DNS platform does not have a Terraform provider, use a controlled script.

Example `update-db-endpoint.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ZONE="company.local"
RECORD="db.company.local"
TARGET="$1"
TTL="30"
DNS_SERVER="192.168.10.53"

cat <<EOF | nsupdate
server ${DNS_SERVER}
update delete ${RECORD} CNAME
update add ${RECORD} ${TTL} CNAME ${TARGET}
send
EOF

echo "Updated ${RECORD} -> ${TARGET}"
```

Run:

```bash
chmod +x update-db-endpoint.sh
./update-db-endpoint.sh scan-standby.company.local
```

This script should be executed only through an approved automation job.

---

## Standard DNS Flow

```text
Create node records -> Create VIP records -> Create SCAN records -> Create service endpoint -> Validate forward lookup -> Validate multi-record SCAN resolution
```

Validation requirements:

- All nodes resolve each other
- SCAN name resolves to exactly three IPs
- Service endpoint resolves to the correct SCAN target
- TTL matches DR design

---

## DR Failover DNS Automation

The logical database endpoint should be decoupled from the active site.

Example:

```text
db.company.local -> scan-db.company.local
```

During DR failover:

```text
db.company.local -> scan-standby.company.local
```

Failover workflow:

1. Confirm standby health and role transition status
2. Update logical database endpoint
3. Verify resolver propagation from approved probe nodes
4. Record completion evidence in the change record

Keep final approval for production endpoint switch.

Step-by-step DR cutover:

1. Confirm Data Guard role transition is complete
2. Confirm standby listeners are healthy
3. Capture current DNS target
4. Execute DNS update script or Terraform apply
5. Validate `db.company.local` from at least two application subnets
6. Attach command output to the incident record

Validation command:

```bash
for host in 192.168.10.21 192.168.110.21; do
  ssh ansible@"$host" "getent hosts db.company.local"
done
```

---

## TTL Policy

Recommended values:

| Record | TTL |
|------|------|
| Node records | 300 seconds |
| VIP records | 300 seconds |
| SCAN records | 60 seconds |
| Logical DB endpoint | 30 seconds |

Short TTL should be applied only where failover speed justifies it.

---

## Safety Controls

Mandatory safeguards:

- Restrict DNS write access to automation account scope
- Prevent deletion of unrelated records
- Validate zone and record ownership before apply
- Keep previous target value for rollback

For failover execution, the automation should show:

- Old record value
- New record value
- TTL
- Timestamp of change

---

## Validation Examples

Example checks after creation or update:

```bash
nslookup rac-node1.company.local
nslookup scan-db.company.local
nslookup db.company.local
```

Expected result for SCAN:

```text
Name: scan-db.company.local
Address: 192.168.10.101
Address: 192.168.10.102
Address: 192.168.10.103
```

Additional validation:

```bash
dig +short scan-db.company.local
dig +short db.company.local
```

---

## Next Steps

After DNS and service endpoint automation is in place, the environment is ready to continue with Oracle Grid Infrastructure installation and the higher database layers.

See:
[04-oracle-grid-infrastructure-installation.md](./04-oracle-grid-infrastructure-installation.md)

