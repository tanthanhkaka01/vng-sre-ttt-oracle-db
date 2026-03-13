# 10-02 - VM and OS Provisioning Automation

## Overview

This section describes how to automate virtual machine provisioning and operating system installation for Oracle RAC and Data Guard nodes.

The design supports both VMware vSphere and OpenStack so the same operating model can be reused across private cloud platforms.

Automation scope includes:

- VM creation
- Template or image selection
- CPU, memory, and disk assignment
- Initial OS installation
- Bootstrap of SSH, users, packages, and agent registration

---

## Supported Provisioning Patterns

| Platform | Provisioning Method | OS Installation Method |
|------|------|------|
| VMware vSphere | Terraform provider for vSphere | Golden template clone or Kickstart-based install |
| OpenStack | Terraform provider for OpenStack | Image boot with cloud-init |

Preferred pattern:

- Use pre-approved golden images for production speed and consistency
- Keep Kickstart or cloud-init as the rebuild mechanism for template refresh

---

## Provisioning Inputs

Required parameters for each node:

| Parameter | Example |
|------|------|
| Site | primary / dr |
| Platform | vmware / openstack |
| Hostname | rac-node1.company.local |
| vCPU | 32 |
| Memory | 128 GB |
| System disk | 1 TB |
| Data network IP | 192.168.10.11 |
| Management IP | 192.168.30.11 |
| Interconnect IP | 192.168.20.11 |
| OS image version | Oracle Linux 8 Update 8 |

All inputs should be stored as code in environment variable files.

---

## VMware Automation Flow

```text
Terraform -> vCenter -> Clone VM from approved template -> Attach NICs and disks -> Power on -> Guest customization -> Handoff to Ansible
```

Automated tasks:

- Select datacenter, cluster, datastore, and resource pool
- Clone from Oracle Linux template
- Attach required NICs for client, private interconnect, and management networks
- Apply hostname and guest customization
- Register the VM in inventory and monitoring

Recommended controls:

- Use a versioned VM template catalog
- Tag VMs with environment, service, site, and owner
- Block ad-hoc manual resizing outside Terraform

---

## OpenStack Automation Flow

```text
Terraform -> OpenStack API -> Create ports -> Create instance -> Inject cloud-init -> Attach volumes -> Handoff to Ansible
```

Automated tasks:

- Create Neutron ports for each network role
- Launch instance from approved image
- Assign security groups
- Inject cloud-init for hostname, SSH key, package baseline, and bootstrap agent
- Attach additional block volumes if required

Recommended controls:

- Keep image catalog controlled by version
- Use port pre-allocation for deterministic IP addresses
- Enforce metadata tags for CMDB and audit

---

## OS Installation Automation

### VMware Template Approach

Use when fast rebuilds and standardization are the priority.

Template contents:

- Oracle Linux base install
- Open VM Tools
- Time synchronization configuration
- Baseline partition layout
- Cloud-init or first-boot bootstrap script

### Kickstart Approach

Use when the template lifecycle must be fully reproducible.

Kickstart can automate:

- Disk partitioning
- Package selection
- Timezone and locale
- Root password policy
- Initial user creation
- Post-install bootstrap script

### OpenStack cloud-init Approach

Use cloud-init to automate:

- Hostname assignment
- Network bootstrap if image policy allows
- SSH key injection
- Registration to package repositories
- Initial package install
- Ansible pull or callback bootstrap

---

## Build Sequence

Recommended sequence per node:

1. Create VM or instance
2. Attach required NICs and system disk
3. Boot from approved image or template
4. Apply OS bootstrap configuration
5. Validate SSH reachability
6. Register host in Ansible inventory
7. Trigger baseline playbooks

This sequence prevents application-level configuration from starting before the host is stable.

---

## Validation Checks

Post-build validation must confirm:

- Correct hostname
- Correct CPU, RAM, and disk sizing
- All NICs present and mapped to expected networks
- Time sync enabled
- Required repositories reachable
- SSH and automation account working

Example validation outputs:

```text
Hostname: rac-node1.company.local
Platform: vmware
OS: Oracle Linux 8.8
NIC count: 3
Ansible access: OK
```

---

## Failure Handling

If provisioning fails:

- Destroy incomplete VM or instance if safe
- Keep logs and API responses as artifacts
- Mark hostname as failed to avoid duplicate builds
- Re-run only after root cause is recorded

Avoid manual repair of half-built systems unless it is part of an incident response process.

---

## Next Steps

After VM and OS provisioning is complete, the next step is to automate network configuration inside the guest operating system.

See:
[10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
