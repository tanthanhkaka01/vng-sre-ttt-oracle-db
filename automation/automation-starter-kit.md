# Automation Starter Kit

This folder contains a production-oriented starter kit for automating Oracle RAC and Data Guard infrastructure tasks.

Included areas:

- `terraform/` for VMware, OpenStack, DNS, and network resource provisioning
- `workstation-pro/` for local VMware Workstation Pro 17 lab provisioning
- `ansible/` for OS bootstrap, network baseline, DNS validation, and Oracle prerequisites
- `pipelines/` for validation and deployment jobs
- `docs/runbooks/` for execution guidance
- `docs/rollback/` for rollback notes

Automation platforms covered in this repository:

- VMware vSphere / ESXi for production VM provisioning
- OpenStack for private cloud provisioning
- VMware Workstation Pro 17 for local lab automation and onboarding

Core software used for automation:

- Terraform for infrastructure provisioning modules and environment definitions
- Ansible for OS bootstrap, network baseline, DNS validation, and Oracle prerequisite configuration
- PowerShell and `vmrun` for VMware Workstation Pro VM lifecycle automation on Windows hosts
- Bash / shell scripts for RMAN validation and Data Guard health checks
- Kickstart, cloud-init, and golden templates for Oracle Linux bootstrap
- CI/CD pipelines (`pipelines/validate.yml`, `pipelines/deploy.yml`) for validation, approval flow, and deployment execution

Recommended usage order:

1. Update Terraform environment variables in `terraform/environments/<env>/terraform.tfvars`
2. Update Ansible inventory in `ansible/inventories/<env>/`
3. Run Terraform plan and apply for vSphere or OpenStack, or run PowerShell scripts for Workstation Pro
4. Run Ansible validation and baseline playbooks
5. Save outputs in the change record


Important current limitation:

- This repository currently provides stronger automation for VM lifecycle, network baseline, OS prerequisite baseline, and validation than for Oracle Grid installation, RAC database creation, and Data Guard build.
- For an honest step-by-step readiness walkthrough across VMware vSphere / ESXi, OpenStack, and VMware Workstation Pro 17, see [automation/docs/runbooks/platform-end-to-end-simulation.md](./docs/runbooks/platform-end-to-end-simulation.md).

