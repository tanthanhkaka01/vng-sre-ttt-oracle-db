# Runbooks

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
