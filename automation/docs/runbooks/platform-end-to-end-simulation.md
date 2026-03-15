# Platform End-to-End Simulation Runbook

## Purpose

This runbook simulates the automation journey across three target platforms:

- VMware vSphere / ESXi
- OpenStack
- VMware Workstation Pro 17 lab

The goal is to help junior engineers understand:

- the expected step-by-step delivery flow
- which steps are already runnable from this repository
- which steps are only documented today
- which gaps should be fixed before calling the platform path "fully automated"

This is a simulation and readiness guide, not a claim that the full Oracle RAC + Data Guard lifecycle is already automated end-to-end in this repository.

---

## Status Legend

| Status | Meaning |
|------|------|
| Runnable now | The repository already contains executable automation for this step |
| Partial | Some automation exists, but wiring, provider setup, or platform integration is incomplete |
| Manual only | The repository currently provides documentation or examples, not executable automation |

---

## Common End-to-End Goal

For all three platforms, the intended final target is:

1. Create primary site VMs
2. Create DR site VMs
3. Configure guest networking
4. Apply OS baseline and Oracle prerequisites
5. Prepare shared storage / ASM visibility
6. Install Oracle Grid Infrastructure
7. Create Oracle RAC database
8. Build and validate Data Guard standby
9. Validate backup, monitoring, and failover readiness

Current repository reality:

- Steps 1 to 4 are automated or partially automated depending on platform
- Steps 6 to 8 now have executable silent-install scaffolding in Ansible, but still depend on Oracle media, storage, and platform prerequisites
- Step 5 remains largely platform-specific and still needs storage integration work
- Step 9 has a small but useful set of operational scripts today

---

## Path 1: VMware vSphere / ESXi

### Intended junior-friendly execution flow

1. Read [README.md](../../../README.md) for the target architecture.
2. Read [docs/01-infrastructure-preparation.md](../../../docs/01-infrastructure-preparation.md) to understand the 4-node target layout.
3. Read [docs/10-01-automation-platform-and-delivery-model.md](../../../docs/10-01-automation-platform-and-delivery-model.md).
4. Prepare `automation/terraform/environments/prod/terraform.tfvars`.
5. Prepare provider credentials for vCenter.
6. Run Terraform plan and apply for the primary site.
7. Update the Ansible inventory for primary.
8. Run `bootstrap-validate.yml`.
9. Run `network.yml`.
10. Run `os-baseline.yml`.
11. Validate DNS resolution with `dns-validate.yml`.
12. Prepare shared storage and ASM devices.
13. Install Grid Infrastructure.
14. Create RAC database.
15. Repeat equivalent provisioning and baseline flow for DR.
16. Configure Data Guard.
17. Run post-build health checks and DR validation.

### What is runnable now

| Step | Repository asset | Status | Notes |
|------|------------------|--------|-------|
| Prepare prod Terraform vars | `automation/terraform/environments/prod/terraform.tfvars.example` | Runnable now | Good starting template for network and DNS values |
| Terraform syntax structure | `automation/terraform/environments/prod/*.tf` | Partial | Environment exists, but VM module is not wired in |
| Network baseline | `automation/ansible/playbooks/network.yml` | Runnable now | Assumes hosts already exist and Ansible can reach them |
| OS baseline | `automation/ansible/playbooks/os-baseline.yml` | Runnable now | Covers only a light prerequisite baseline |
| DNS validation | `automation/ansible/playbooks/dns-validate.yml` | Runnable now | Validates resolution, does not create DNS records |
| Full site baseline | `automation/ansible/playbooks/site.yml` | Runnable now | Still limited to baseline roles, not Grid/DB install |

### What is not yet fully automated

| Step | Status | Why it is blocked today |
|------|--------|--------------------------|
| Create vSphere VMs | Partial | `prod/main.tf` has commented VM module wiring |
| Use real vSphere provider | Partial | `providers.tf` is still placeholder-only |
| Create real DNS records | Partial | `dns_records` module is a `null_resource` placeholder |
| Shared storage presentation | Manual only | No vSphere or storage automation for RAC shared disks |
| ASM disk preparation | Manual only | No automation for multipath, udev, or ASM device naming |
| Grid install | Partial | Silent Ansible role now exists, but still assumes staged Oracle media and valid response inputs |
| RAC DB creation | Partial | Silent DBCA automation now exists, but still assumes successful Grid and DB software installation |
| Data Guard build | Partial | Ansible automation now renders SQL, RMAN, and DGMGRL scripts, but still assumes working connectivity, media, and storage |

### Junior-friendly simulation verdict

- You can use this repository to simulate the build up to "VM exists + network baseline + Oracle prerequisites".
- You cannot honestly call the vSphere path "fully automated to RAC + DR" yet.

### Fixes needed before this path becomes credible end-to-end

1. Wire `module.rac_node1`, `module.rac_node2`, `module.rac_node3`, and `module.rac_node4` into Terraform environments.
2. Replace placeholder providers with real vSphere provider configuration.
3. Replace `dns_records` placeholder with a real DNS provider or script-backed execution model.
4. Add storage preparation automation for shared disks and ASM labels.
5. Add Ansible or shell automation for silent Grid install.
6. Add Ansible or shell automation for silent DBCA RAC creation.
7. Add Data Guard build automation using RMAN and DGMGRL.

---

## Path 2: OpenStack

### Intended junior-friendly execution flow

1. Read [README.md](../../../README.md).
2. Read [docs/01-infrastructure-preparation.md](../../../docs/01-infrastructure-preparation.md), but treat the VMware-specific details as architecture intent, not exact OpenStack implementation.
3. Read [docs/10-01-automation-platform-and-delivery-model.md](../../../docs/10-01-automation-platform-and-delivery-model.md).
4. Prepare `automation/terraform/environments/dr/terraform.tfvars` or an OpenStack-specific environment file.
5. Prepare OpenStack credentials, networks, image, flavor, and security groups.
6. Run Terraform plan and apply for instances and ports.
7. Wait for SSH and cloud-init completion.
8. Update Ansible inventory.
9. Run `bootstrap-validate.yml`.
10. Run `network.yml`.
11. Run `os-baseline.yml`.
12. Validate DNS resolution.
13. Prepare storage for RAC-compatible shared access.
14. Install Grid Infrastructure.
15. Create RAC database.
16. Build Data Guard relationship against the other site.

### What is runnable now

| Step | Repository asset | Status | Notes |
|------|------------------|--------|-------|
| OpenStack instance module | `automation/terraform/modules/openstack_instance/main.tf` | Partial | Module exists and is usable as a pattern |
| Guest baseline via Ansible | `automation/ansible/playbooks/*.yml` | Runnable now | Works only after instances already exist and are reachable |
| Inventory examples | `automation/ansible/inventories/dr/*` | Runnable now | Useful for structure, but not a complete OpenStack source of truth |

### What is not yet fully automated

| Step | Status | Why it is blocked today |
|------|--------|--------------------------|
| Create OpenStack instances from env | Partial | Environment files do not wire the instance module |
| OpenStack provider setup | Partial | Provider scaffolding is not fully configured in env files |
| RAC shared storage model | Manual only | No automation for OpenStack shared block storage design suitable for RAC |
| DNS creation | Partial | Validation exists, creation does not |
| Grid install | Partial | Silent Ansible role now exists, but OpenStack platform prerequisites are still external to the repo |
| RAC DB creation | Partial | Silent DBCA automation now exists, but still depends on successful cluster build |
| Data Guard build | Partial | Data Guard automation now exists, but still requires valid network, storage, and duplicate prerequisites |

### Junior-friendly simulation verdict

- OpenStack is currently a design-supported path, not a ready-to-run end-to-end automation path.
- It is suitable for architecture discussion and module prototyping, but not for a junior engineer to execute without additional implementation.

### Fixes needed before this path becomes credible end-to-end

1. Create a dedicated OpenStack environment using the existing module.
2. Define floating IP, security group, image, flavor, and volume patterns clearly for RAC.
3. Document whether RAC shared storage will use Cinder multi-attach, external SAN, or another storage model.
4. Add real DNS creation automation.
5. Add Grid, DBCA, and Data Guard automation.

---

## Path 3: VMware Workstation Pro 17 Lab

### Intended junior-friendly execution flow

1. Read [README.md](../../../README.md).
2. Read [docs/10-02-02-vmware-workstation-pro-automation.md](../../../docs/10-02-02-vmware-workstation-pro-automation.md).
3. Copy `automation/workstation-pro/configs/lab-rac-nodes.example.json`.
4. Update template path, VM names, destination paths, CPU, and memory.
5. Run `create-vm.ps1` or `invoke-lab-build.ps1`.
6. Run `start-vm.ps1` if needed.
7. Wait for guest boot.
8. Verify SSH reachability from the automation host.
9. Update or confirm lab inventory.
10. Run `bootstrap-validate.yml`.
11. Run `network.yml`.
12. Run `os-baseline.yml`.
13. If the lab has proper DNS, run `dns-validate.yml`.
14. Manually complete storage, Grid, RAC, and Data Guard setup using the main docs.

### What is runnable now

| Step | Repository asset | Status | Notes |
|------|------------------|--------|-------|
| Clone lab VM | `automation/workstation-pro/scripts/create-vm.ps1` | Runnable now | Requires an existing powered-off template |
| Start lab VM | `automation/workstation-pro/scripts/start-vm.ps1` | Runnable now | Requires `vmrun.exe` and a valid VMX |
| Stop lab VM | `automation/workstation-pro/scripts/stop-vm.ps1` | Runnable now | Works for lifecycle control |
| Build multiple lab VMs | `automation/workstation-pro/scripts/invoke-lab-build.ps1` | Runnable now | Good junior-friendly entrypoint |
| Baseline after VM boot | Ansible playbooks | Runnable now | Same limitation as other paths: hosts must already be reachable |

### What is not yet fully automated

| Step | Status | Why it is blocked today |
|------|--------|--------------------------|
| Shared storage for RAC | Manual only | No lab storage automation or ASM-ready shared disk orchestration |
| RAC network extras | Partial | Basic NIC config exists, but SCAN/VIP host integration is not end-to-end |
| Grid install | Partial | Silent Ansible role now exists for lab use, but still assumes staged media and ASM-ready disks |
| RAC DB creation | Partial | Silent DBCA automation now exists, but still depends on a healthy cluster build |
| DR build | Partial | Data Guard automation now exists, but lab storage and multi-node standby assumptions still need validation |

### Junior-friendly simulation verdict

- This is the closest path to something a junior engineer can actually start running today.
- It is good for VM lifecycle practice and baseline automation practice.
- It is not yet a one-click RAC + DR lab builder.

### Fixes needed before this path becomes credible end-to-end

1. Define a lab storage design for ASM-compatible shared disks.
2. Add optional local DNS or host-file automation for lab SCAN and service names.
3. Add silent Grid and DBCA automation scripts.
4. Add a reduced-scope lab Data Guard bootstrap flow.

---

## Recommended Current Usage

If you want a realistic junior-friendly adoption order today:

1. Start with VMware Workstation Pro 17 to learn VM lifecycle and Ansible baseline flow.
2. Move to vSphere for production-style provisioning once the Terraform environment is fully wired.
3. Keep OpenStack as a secondary target after the storage and provider story is clarified.

---

## Honest Repository Readiness Summary

| Capability | vSphere / ESXi | OpenStack | Workstation Pro 17 |
|------|------|------|------|
| VM provisioning | Partial | Partial | Runnable now |
| Guest network baseline | Runnable now | Runnable now | Runnable now |
| OS prerequisite baseline | Runnable now | Runnable now | Runnable now |
| DNS validation | Runnable now | Runnable now | Runnable now if DNS exists |
| DNS creation | Partial | Partial | Manual only |
| Shared storage / ASM prep | Manual only | Manual only | Manual only |
| Grid install | Partial | Partial | Partial |
| RAC DB creation | Partial | Partial | Partial |
| Data Guard build | Partial | Partial | Partial |

Bottom line:

- The repository now includes executable automation for much more of the Oracle stack than before, especially Grid, RAC DB, and Data Guard bootstrap.
- It still depends on real Oracle media, storage presentation, and live provider integration, so end-to-end success is environment-dependent.

