# 10-02 - VM and OS Provisioning Automation

## Overview

This section describes how to automate virtual machine provisioning and operating system installation for Oracle RAC and Data Guard nodes.

The design supports VMware vSphere, OpenStack, and VMware Workstation Pro 17 so the same operating model can be reused across production and lab platforms.

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
| VMware Workstation Pro 17 | PowerShell + `vmrun` + local template clone | Prebuilt VM template or unattended OS install |

Preferred pattern:

- Use pre-approved golden images for production speed and consistency
- Keep Kickstart or cloud-init as the rebuild mechanism for template refresh

---

## Provisioning Inputs

Required parameters for each node:

| Parameter | Example |
|------|------|
| Site | primary / dr |
| Platform | vmware / openstack / workstation_pro |
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

## Prerequisites

Before starting, prepare:

1. Approved Oracle Linux template or image
2. vCenter or OpenStack credentials, or local VMware Workstation access
3. IP plan for public, interconnect, and management networks
4. DNS names reserved for each node
5. SSH public key for automation account
6. Ansible control node reachable from target networks

Junior engineers should not start a build until all six items are confirmed.

---

## Step-by-Step Provisioning for Freshers

Use this exact sequence:

1. Confirm the node list and IP plan
2. Create or update the Terraform variable file
3. Run `terraform init`
4. Run `terraform plan` and check CPU, RAM, disk, and NIC count
5. Run `terraform apply`
6. Wait until the host is reachable by SSH
7. Run a bootstrap validation playbook
8. Record the output in the change ticket

Example checklist:

```text
[ ] Hostname confirmed
[ ] Public IP confirmed
[ ] Interconnect IP confirmed
[ ] Management IP confirmed
[ ] Template or image version confirmed
[ ] SSH key confirmed
```

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

## Example VMware Terraform Code

Example `automation/terraform/modules/vmware_vm/main.tf`:

```hcl
resource "vsphere_virtual_machine" "rac_vm" {
  name             = var.vm_name
  folder           = var.vm_folder
  num_cpus         = var.num_cpus
  memory           = var.memory_mb
  datastore_id     = var.datastore_id
  resource_pool_id = var.resource_pool_id
  guest_id         = var.guest_id

  network_interface {
    network_id   = var.public_network_id
    adapter_type = "vmxnet3"
  }

  network_interface {
    network_id   = var.private_network_id
    adapter_type = "vmxnet3"
  }

  network_interface {
    network_id   = var.management_network_id
    adapter_type = "vmxnet3"
  }

  disk {
    label            = "system-disk"
    size             = var.system_disk_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = var.template_uuid
    customize {
      linux_options {
        host_name = var.short_hostname
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.public_ip
        ipv4_netmask = var.public_netmask
      }

      ipv4_gateway = var.public_gateway
    }
  }
}
```

Example `terraform.tfvars`:

```hcl
vm_name               = "rac-node1.company.local"
short_hostname        = "rac-node1"
domain                = "company.local"
num_cpus              = 32
memory_mb             = 131072
system_disk_gb        = 1024
public_ip             = "192.168.10.11"
public_netmask        = 24
public_gateway        = "192.168.10.1"
```

Run:

```bash
terraform -chdir=automation/terraform/environments/prod init
terraform -chdir=automation/terraform/environments/prod plan -target=module.rac_node1
terraform -chdir=automation/terraform/environments/prod apply -target=module.rac_node1
```

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

## Example OpenStack Terraform Code

Example `automation/terraform/modules/openstack_instance/main.tf`:

```hcl
resource "openstack_networking_port_v2" "public" {
  name           = "${var.instance_name}-public"
  network_id     = var.public_network_id
  admin_state_up = true

  fixed_ip {
    subnet_id  = var.public_subnet_id
    ip_address = var.public_ip
  }
}

resource "openstack_compute_instance_v2" "rac_vm" {
  name            = var.instance_name
  image_name      = var.image_name
  flavor_name     = var.flavor_name
  key_pair        = var.keypair
  security_groups = var.security_groups
  user_data       = var.cloud_init

  network {
    port = openstack_networking_port_v2.public.id
  }
}
```

Example cloud-init:

```yaml
#cloud-config
hostname: rac-node3
fqdn: rac-node3.company.local
users:
  - name: ansible
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: wheel
    ssh_authorized_keys:
      - ssh-rsa AAAAB3Nza...
package_update: true
packages:
  - chrony
  - python3
runcmd:
  - hostnamectl set-hostname rac-node3.company.local
  - systemctl enable --now chronyd
```

Run:

```bash
terraform -chdir=automation/terraform/environments/dr init
terraform -chdir=automation/terraform/environments/dr plan
terraform -chdir=automation/terraform/environments/dr apply
```

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

### VMware Workstation Pro Approach

Use VMware Workstation Pro 17 for:

- Local lab setup
- Fresher onboarding
- Script validation before moving to vSphere

Recommended method:

- Keep a powered-off Oracle Linux template VM
- Clone the template directory
- Update `.vmx` values for CPU, memory, and VM name
- Start the VM using `vmrun`
- Hand off to Ansible after SSH is reachable

Detailed implementation:
[10-06-vmware-workstation-pro-automation.md](./10-06-vmware-workstation-pro-automation.md)

Example Kickstart snippet:

```text
lang en_US.UTF-8
keyboard us
timezone Asia/Ho_Chi_Minh --isUtc
rootpw --lock
reboot
network --bootproto=static --device=ens192 --ip=192.168.10.11 --netmask=255.255.255.0 --gateway=192.168.10.1 --nameserver=192.168.10.53 --hostname=rac-node1.company.local
firewall --disabled
selinux --enforcing
services --enabled="chronyd,sshd"
%packages
@^minimal-environment
chrony
python3
open-vm-tools
%end
```

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

Example bootstrap validation:

```bash
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m ping
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "hostnamectl; ip addr show"
```

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

Rollback example:

```bash
terraform -chdir=automation/terraform/environments/prod destroy -target=module.rac_node1
```

---

## Next Steps

After VM and OS provisioning is complete, the next step is to automate network configuration inside the guest operating system.

See:
[10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
