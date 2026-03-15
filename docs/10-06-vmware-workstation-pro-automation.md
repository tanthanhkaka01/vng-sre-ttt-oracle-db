# 10-06 - VMware Workstation Pro 17 Automation

## Overview

This section describes how to automate Oracle RAC lab node provisioning on VMware Workstation Pro 17.

This platform is intended for:

- Local lab environments
- Fresher onboarding
- Automation dry runs before vSphere deployment

It is not the recommended target for production datacenter deployment.

Automation scope includes:

- Clone VM from a local template
- Update CPU, memory, and VM identity
- Start and stop VM with `vmrun`
- Prepare the guest for Ansible bootstrap

---

## Platform Positioning

| Platform | Primary Use |
|------|------|
| VMware vSphere / ESXi | Production and datacenter deployment |
| OpenStack | Production private cloud deployment |
| VMware Workstation Pro 17 | Local lab, test, and onboarding |

---

## Prerequisites

Before running automation, confirm:

1. VMware Workstation Pro 17 is installed on the Windows host
2. `vmrun.exe` is available
3. A powered-off template VM already exists
4. The template VM contains Oracle Linux and VMware Tools
5. The destination datastore path on the local disk has enough free space
6. WinRM or SSH access to the guest will be configured after first boot

Typical `vmrun` path:

```text
C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe
```

---

## Recommended Folder Structure

```text
automation/
  workstation-pro/
    configs/
      lab-rac-nodes.example.json
    scripts/
      create-vm.ps1
      start-vm.ps1
      stop-vm.ps1
      invoke-lab-build.ps1
    templates/
      README.md
```

---

## Step-by-Step Flow for Freshers

Use this order:

1. Create or verify the base template VM
2. Copy the example JSON config
3. Fill in the VM name, target path, CPU, RAM, and destination folder
4. Run `create-vm.ps1`
5. Run `start-vm.ps1`
6. Wait for the guest OS to boot
7. Verify network and SSH access
8. Run Ansible baseline playbooks

This gives you a repeatable local lab build without touching the existing vSphere or OpenStack paths.

---

## Template Requirements

The template VM should:

- Be powered off before cloning
- Use Oracle Linux 8 or 9
- Have VMware Tools installed
- Have unique machine identity reset if cloning manually
- Include a known local admin or bootstrap account

Recommended template contents:

- `openssh-server`
- `python3`
- `chrony`
- Cleaned `/etc/machine-id`

---

## Example JSON Configuration

Example `automation/workstation-pro/configs/lab-rac-nodes.example.json`:

```json
{
  "templatePath": "D:\VM\Templates\ol8-rac-template",
  "vmrunPath": "C:\Program Files (x86)\VMware\VMware Workstation\vmrun.exe",
  "vms": [
    {
      "name": "rac-lab-node1",
      "destinationPath": "D:\VM\OracleLab\rac-lab-node1",
      "vmxName": "rac-lab-node1.vmx",
      "memoryMb": 16384,
      "numVcpus": 4
    },
    {
      "name": "rac-lab-node2",
      "destinationPath": "D:\VM\OracleLab\rac-lab-node2",
      "vmxName": "rac-lab-node2.vmx",
      "memoryMb": 16384,
      "numVcpus": 4
    }
  ]
}
```

---

## Practical Automation Notes

Unlike vSphere, VMware Workstation Pro does not provide the same datacenter-grade API model.

The simplest reliable approach is:

- Copy the template directory
- Rename `.vmx` and `.vmdk` references as needed
- Update CPU and memory in the `.vmx`
- Start the VM with `vmrun`

After that, reuse the same Ansible playbooks already stored in `automation/ansible`.

---

## Execution Commands

Create a VM:

```powershell
.\automation\workstation-pro\scripts\create-vm.ps1 `
  -ConfigPath .\automation\workstation-pro\configs\lab-rac-nodes.json `
  -VmName rac-lab-node1
```

Start a VM:

```powershell
.\automation\workstation-pro\scripts\start-vm.ps1 `
  -ConfigPath .\automation\workstation-pro\configs\lab-rac-nodes.json `
  -VmName rac-lab-node1
```

Stop a VM:

```powershell
.\automation\workstation-pro\scripts\stop-vm.ps1 `
  -ConfigPath .\automation\workstation-pro\configs\lab-rac-nodes.json `
  -VmName rac-lab-node1
```

Build the whole lab:

```powershell
.\automation\workstation-pro\scripts\invoke-lab-build.ps1 `
  -ConfigPath .\automation\workstation-pro\configs\lab-rac-nodes.json
```

---

## Validation Checklist

After build, verify:

- The VM folder exists
- The `.vmx` file contains the expected CPU and memory
- The VM starts successfully
- The guest gets the expected IP address
- SSH is reachable from the automation host

Validation command example:

```powershell
Get-Content "D:\VM\OracleLab\rac-lab-node1\rac-lab-node1.vmx" | Select-String "memsize|numvcpus|displayName"
```

---

## Limitations

Known limitations of this platform:

- No enterprise scheduler or vCenter governance
- No shared SAN model by default
- Less suitable for full Oracle RAC storage simulation
- Best for lab and learning, not production

---

## Next Steps

After the lab VMs are created, continue with:

- [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
- [10-04-os-baseline-and-oracle-prerequisite-automation.md](./10-04-os-baseline-and-oracle-prerequisite-automation.md)
- [10-05-dns-and-service-endpoint-automation.md](./10-05-dns-and-service-endpoint-automation.md) if the lab uses a dedicated resolver instead of temporary host file mapping
