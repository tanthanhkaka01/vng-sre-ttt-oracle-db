# 10-04 - DNS and Service Endpoint Automation

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

---

## Next Steps

After DNS and service endpoint automation is in place, the next step is to automate OS baseline settings and Oracle prerequisite configuration.

See:
[10-05-os-baseline-and-oracle-prerequisite-automation.md](./10-05-os-baseline-and-oracle-prerequisite-automation.md)
