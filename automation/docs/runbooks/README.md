# Runbooks

Important scope note:

- This repository now automates infrastructure baseline tasks and also includes silent-install scaffolding for Oracle Grid, RAC database creation, and Data Guard broker bootstrap.
- Use [platform-end-to-end-simulation.md](./platform-end-to-end-simulation.md) to see what is runnable now, what is partial, and what is still manual for VMware vSphere, OpenStack, and VMware Workstation Pro 17.

For end-to-end orchestration:

- Use `automation/ansible/playbooks/full-stack-prod.yml` with both inventories for primary and DR.
- Example: `ansible-playbook -i automation/ansible/inventories/prod/hosts.yml -i automation/ansible/inventories/dr/hosts.yml automation/ansible/playbooks/full-stack-prod.yml`
- Use `automation/ansible/playbooks/full-stack-lab.yml` for a lab-style build when you want Grid and RAC database automation without the Data Guard step.

Suggested execution order:

1. Copy `terraform.tfvars.example` to `terraform.tfvars`
2. Fill in real provider values and network information
3. Run Terraform plan in the target environment
4. Run Terraform apply after approval
5. Run `bootstrap-validate.yml`
6. Run `network.yml`
7. Run `os-baseline.yml`
8. Run `dns-validate.yml`
9. Run `site.yml` for the full baseline if needed

For VMware Workstation Pro 17 lab builds:

1. Copy `automation/workstation-pro/configs/lab-rac-nodes.example.json`
2. Update local template and destination paths
3. Run `invoke-lab-build.ps1`
4. Wait for guest boot and network readiness
5. Continue with the same Ansible playbooks

Example commands:

```bash
cp automation/terraform/environments/prod/terraform.tfvars.example automation/terraform/environments/prod/terraform.tfvars
terraform -chdir=automation/terraform/environments/prod init
terraform -chdir=automation/terraform/environments/prod plan
terraform -chdir=automation/terraform/environments/prod apply
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/bootstrap-validate.yml
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/network.yml
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/os-baseline.yml
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/dns-validate.yml
```

Workstation Pro example:

```powershell
Copy-Item automation\workstation-pro\configs\lab-rac-nodes.example.json automation\workstation-pro\configs\lab-rac-nodes.json
.\automation\workstation-pro\scripts\invoke-lab-build.ps1 -ConfigPath .\automation\workstation-pro\configs\lab-rac-nodes.json
```

