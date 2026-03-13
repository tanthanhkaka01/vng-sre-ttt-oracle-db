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

## Prerequisites

Before applying guest OS network automation, confirm:

1. The VM has all required NICs attached
2. The MAC address of each NIC is known
3. The target IP address plan is approved
4. Out-of-band console access is available
5. DNS servers and gateways are reachable

If any item is missing, do not continue.

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

## Example Inventory for Production

Example `automation/ansible/inventories/prod/hosts.yml`:

```yaml
all:
  children:
    rac_primary:
      hosts:
        rac-node1.company.local:
          ansible_host: 192.168.30.11
          public_if: ens192
          private_if: ens224
          management_if: ens256
          public_ip: 192.168.10.11
          private_ip: 192.168.20.11
          management_ip: 192.168.30.11
          public_gw: 192.168.10.1
        rac-node2.company.local:
          ansible_host: 192.168.30.12
          public_if: ens192
          private_if: ens224
          management_if: ens256
          public_ip: 192.168.10.12
          private_ip: 192.168.20.12
          management_ip: 192.168.30.12
          public_gw: 192.168.10.1
```

---

## Step-by-Step Network Configuration

Follow this order for each node:

1. Log in through management access
2. Record current interface status
3. Map interface name to expected network
4. Apply public network settings
5. Apply private interconnect settings
6. Apply management network settings
7. Reload NetworkManager
8. Validate routing and connectivity

Useful pre-check command:

```bash
ip -br addr
ip route
nmcli device status
```

---

## Example Ansible Playbook

Example `automation/ansible/playbooks/network.yml`:

```yaml
- name: Configure RAC network
  hosts: rac_primary
  become: true
  tasks:
    - name: Configure public interface
      community.general.nmcli:
        conn_name: "{{ public_if }}"
        ifname: "{{ public_if }}"
        type: ethernet
        ip4: "{{ public_ip }}/24"
        gw4: "{{ public_gw }}"
        dns4:
          - 192.168.10.53
          - 192.168.10.54
        state: present

    - name: Configure private interconnect
      community.general.nmcli:
        conn_name: "{{ private_if }}"
        ifname: "{{ private_if }}"
        type: ethernet
        ip4: "{{ private_ip }}/24"
        state: present

    - name: Configure management interface
      community.general.nmcli:
        conn_name: "{{ management_if }}"
        ifname: "{{ management_if }}"
        type: ethernet
        ip4: "{{ management_ip }}/24"
        state: present
```

Run:

```bash
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/network.yml
```

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

Example bond configuration task:

```yaml
- name: Create bond0
  community.general.nmcli:
    conn_name: bond0
    ifname: bond0
    type: bond
    mode: active-backup
    state: present
```

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

Validation commands:

```bash
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "ip -br addr; ip route"
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "ping -c 2 192.168.20.12"
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "getent hosts rac-node1.company.local"
```

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

Emergency rollback example:

```bash
nmcli connection reload
nmcli connection up ens192
nmcli connection up ens224
nmcli connection up ens256
```

---

## Next Steps

After the guest operating system network is configured, the next step is to automate DNS records and service endpoints for Oracle RAC and Data Guard.

See:
[10-04-dns-and-service-endpoint-automation.md](./10-04-dns-and-service-endpoint-automation.md)
