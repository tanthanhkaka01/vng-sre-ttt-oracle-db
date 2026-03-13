# Rollback Notes

Use rollback only after approval.

Terraform rollback:

```bash
terraform -chdir=automation/terraform/environments/prod plan
terraform -chdir=automation/terraform/environments/prod apply
```

Ansible rollback approach:

1. Restore the last known-good variables or templates
2. Re-run the affected playbook
3. Validate host networking and DNS

Emergency network recovery on the host:

```bash
nmcli connection reload
nmcli connection up ens192
nmcli connection up ens224
nmcli connection up ens256
```
