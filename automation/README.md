# Automation Starter Kit

This folder contains a production-oriented starter kit for automating Oracle RAC and Data Guard infrastructure tasks.

Included areas:

- `terraform/` for VMware, OpenStack, DNS, and network resource provisioning
- `workstation-pro/` for local VMware Workstation Pro 17 lab provisioning
- `ansible/` for OS bootstrap, network baseline, DNS validation, and Oracle prerequisites
- `pipelines/` for validation and deployment jobs
- `docs/runbooks/` for execution guidance
- `docs/rollback/` for rollback notes

Recommended usage order:

1. Update Terraform environment variables in `terraform/environments/<env>/terraform.tfvars`
2. Update Ansible inventory in `ansible/inventories/<env>/`
3. Run Terraform plan and apply for vSphere or OpenStack, or run PowerShell scripts for Workstation Pro
4. Run Ansible validation and baseline playbooks
5. Save outputs in the change record
