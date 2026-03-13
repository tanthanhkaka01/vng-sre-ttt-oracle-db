# 10-03 - Network Configuration Automation

## Overview

This section describes how to automate operating system network configuration for Oracle RAC nodes after the VM or instance has been provisioned.

The objective is to ensure that every node receives a consistent, validated, and repeatable network baseline without manual editing of interface files.

Automation scope includes:

- Interface naming and mapping
- IP address assignment
- VLAN and bond configuration
- Route configuration
- MTU and network tuning
- Post-change connectivity validation

---

## Network Roles

| Network Role | Purpose |
|------|------|
| Client access | Application connectivity and Data Guard transport |
| Private interconnect | RAC heartbeat and cache fusion |
| Management | Administration, backup, and monitoring access |

Each role should be managed as a separate automation object so changes remain easy to review.

---

## Source of Truth

Network variables should be defined in structured inventory data.

Example model:

```yaml
network_interfaces:
  public:
    device: ens192
    ip: 192.168.10.11
    prefix: 24
    gateway: 192.168.10.1
  interconnect:
    device: ens224
    ip: 192.168.20.11
    prefix: 24
  management:
    device: ens256
    ip: 192.168.30.11
    prefix: 24
    gateway: 192.168.30.1
```

This inventory should drive all network playbooks.

---

## Automation Method

Recommended tool:

- Ansible using `nmcli`, NetworkManager roles, or platform-standard network modules

Automated tasks:

- Map discovered NIC MAC addresses to expected roles
- Configure static IP addressing
- Apply DNS resolver settings if managed locally
- Configure default routes and route metrics
- Restart or reload network services in a controlled order

---

## VLAN and Bonding Automation

If the platform requires NIC redundancy or segmented traffic, automation should support:

- Bond interface creation
- Active-backup or LACP configuration
- VLAN sub-interface creation
- MTU enforcement per network

Example design:

```text
bond0.10 -> client access
bond0.20 -> private interconnect
bond1.30 -> management
```

These settings should be parameterized so VMware and OpenStack sites can share the same role logic with different variables.

---

## Oracle RAC Network Requirements

Automation must validate the following Oracle-specific requirements:

- Public hostname resolves correctly
- Private interconnect is isolated from client traffic
- Reverse path and routing rules do not break cluster communication
- Interconnect latency stays within acceptable range

Do not proceed to Grid installation until these checks pass.

---

## Validation Workflow

```text
Apply network config -> Verify interface status -> Ping default gateway -> Verify node-to-node interconnect -> Verify DNS reachability -> Mark host ready
```

Recommended checks:

- `ip addr`
- `ip route`
- Ping between RAC nodes on interconnect network
- Access from automation control node to management IP
- Resolver test for required FQDNs

---

## Drift Detection

Scheduled automation should detect:

- IP mismatch from source of truth
- Missing routes
- Unexpected interface renaming
- MTU mismatch across RAC nodes

Drift findings should create alerts but should not auto-remediate production network settings without approval.

---

## Failure and Rollback

Before applying changes:

- Save active network configuration
- Record current routes and interface status
- Ensure out-of-band or console access exists

Rollback actions:

- Re-apply last known-good profile
- Restore previous route configuration
- Re-run connectivity validation

---

## Next Steps

After the guest operating system network is configured, the next step is to automate DNS records and service endpoints for Oracle RAC and Data Guard.

See:
[10-04-dns-and-service-endpoint-automation.md](./10-04-dns-and-service-endpoint-automation.md)
