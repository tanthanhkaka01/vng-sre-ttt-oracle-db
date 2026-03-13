# 10-01 - Automation Platform and Delivery Model

## Overview

This section expands the automation strategy into an executable delivery model for Oracle RAC + Data Guard.

The goal is to define how automation assets are organized, how jobs are executed, and how production changes are governed across infrastructure, operating system, network, DNS, and Oracle layers.

The automation platform covers:

- Source control and branching model
- Terraform and Ansible responsibility split
- CI/CD pipeline stages
- Environment promotion flow
- Approval, audit, and rollback controls

---

## Automation Stack

| Layer | Primary Tool | Purpose |
|------|------|------|
| Infrastructure provisioning | Terraform | VM, network, DNS, storage objects |
| Guest OS bootstrap | cloud-init, Kickstart, templates | Initial OS installation and bootstrap |
| Configuration management | Ansible | OS baseline, network, Oracle prerequisites |
| Secret management | Vault or enterprise secret manager | Credentials, SSH keys, API tokens |
| Pipeline orchestration | GitLab CI, GitHub Actions, Jenkins | Validation, approval, deployment |
| Evidence and logging | CI artifacts, log store, ticket system | Audit trail and troubleshooting |

---

## Execution Model

```text
Engineer Change -> Pull Request -> Pipeline Validation -> Approval Gate -> Controlled Execution -> Evidence Archive
```

Execution domains:

- Terraform runner for virtualization, network, DNS, and shared infrastructure objects
- Ansible control node for OS and Oracle configuration
- Restricted production runners for high-risk actions

Key rules:

- All changes originate from Git
- No direct production shell changes without emergency process
- Every run must produce logs and a change reference

---

## Repository Structure

Recommended structure:

```text
automation/
  terraform/
    modules/
      vmware_vm/
      openstack_instance/
      dns_records/
      network_segments/
    environments/
      prod/
      dr/
  ansible/
    inventories/
      prod/
      dr/
    group_vars/
    roles/
      os_bootstrap/
      network_baseline/
      dns_validation/
      oracle_prereq/
      grid_prep/
  pipelines/
    validate.yml
    deploy.yml
  docs/
    runbooks/
    rollback/
```

---

## Pipeline Stages

Standard pipeline stages:

1. Validate syntax and formatting
2. Run policy checks and naming validation
3. Execute `terraform plan`
4. Execute `ansible-lint` and dry run where supported
5. Require approval for production
6. Apply changes in controlled sequence
7. Publish logs, diffs, and test evidence

Recommended separation:

- One pipeline for infrastructure changes
- One pipeline for guest OS and Oracle configuration
- One scheduled pipeline for drift detection and periodic validation

---

## Prerequisites for Freshers

Before running any automation, prepare the following:

1. Access to Git repository with read and write permission
2. Access to CI/CD platform with permission to run pipelines
3. Service account for vCenter or OpenStack API
4. Service account for DNS automation
5. SSH private key for Ansible control node
6. Secret manager path for storing API and SSH credentials

Minimum workstation tools:

```bash
git --version
terraform version
ansible --version
python3 --version
```

If any command is missing, install it before continuing.

---

## Step-by-Step Delivery Flow

Use this sequence for every production change:

1. Create a feature branch from `main`
2. Update variables or modules in the relevant automation folder
3. Run validation locally
4. Commit code with a change reference
5. Open a pull request
6. Wait for review and pipeline validation
7. Approve and execute the production pipeline
8. Archive output logs and screenshots

Example:

```bash
git checkout -b feature/prod-rac-node-build
terraform -chdir=automation/terraform/environments/prod fmt -recursive
terraform -chdir=automation/terraform/environments/prod validate
ansible-lint automation/ansible
git add .
git commit -m "CHG-20260313 add prod RAC node build automation"
git push origin feature/prod-rac-node-build
```

---

## Recommended Repository Layout with Real Files

```text
automation/
  terraform/
    modules/
      vmware_vm/
        main.tf
        variables.tf
        outputs.tf
      openstack_instance/
        main.tf
        variables.tf
        outputs.tf
      dns_records/
        main.tf
        variables.tf
    environments/
      prod/
        main.tf
        providers.tf
        variables.tf
        terraform.tfvars
      dr/
        main.tf
        providers.tf
        variables.tf
        terraform.tfvars
  ansible/
    inventories/
      prod/
        hosts.yml
        group_vars/
          all.yml
      dr/
        hosts.yml
        group_vars/
          all.yml
    roles/
      network_baseline/
      dns_validation/
      oracle_prereq/
    playbooks/
      site.yml
      network.yml
      os-baseline.yml
      dns-validate.yml
```

This layout is simple enough for junior engineers and still production-safe.

---

## Example CI Pipeline

Example `pipelines/validate.yml`:

```yaml
stages:
  - validate
  - plan

terraform_validate:
  stage: validate
  script:
    - terraform -chdir=automation/terraform/environments/prod init -backend=false
    - terraform -chdir=automation/terraform/environments/prod fmt -check
    - terraform -chdir=automation/terraform/environments/prod validate

ansible_validate:
  stage: validate
  script:
    - ansible-lint automation/ansible

terraform_plan_prod:
  stage: plan
  script:
    - terraform -chdir=automation/terraform/environments/prod init
    - terraform -chdir=automation/terraform/environments/prod plan -out=tfplan
  artifacts:
    paths:
      - automation/terraform/environments/prod/tfplan
```

Example `pipelines/deploy.yml`:

```yaml
stages:
  - deploy

deploy_prod:
  stage: deploy
  when: manual
  script:
    - terraform -chdir=automation/terraform/environments/prod apply -auto-approve tfplan
    - ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/site.yml
```

---

## Local Runbook for Engineers

If the pipeline runner is not yet available, use this order on the automation control host:

1. Pull latest code
2. Export required credentials from secret manager
3. Run Terraform `init`
4. Run Terraform `plan`
5. Review the diff with a reviewer
6. Run Terraform `apply`
7. Run Ansible baseline playbooks
8. Save output under a dated change folder

Example:

```bash
export TF_VAR_vcenter_server="vcsa01.company.local"
export TF_VAR_vcenter_user="svc_terraform@vsphere.local"
export TF_VAR_vcenter_password="$(pass show infra/vcenter)"
export ANSIBLE_HOST_KEY_CHECKING=False

terraform -chdir=automation/terraform/environments/prod init
terraform -chdir=automation/terraform/environments/prod plan -out=tfplan
terraform -chdir=automation/terraform/environments/prod apply tfplan
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/site.yml
```

---

## Environment Promotion

Promotion order:

```text
Lab -> UAT -> Production Primary -> Production DR
```

Promotion requirements:

- Same module version across sites
- Variable-only differences between primary and DR
- Successful validation evidence before production release

This avoids separate logic branches for each datacenter.

---

## Change Control Model

| Change Type | Execution Mode | Approval Required |
|------|------|------|
| New VM build | Automated | Yes |
| Network baseline change | Automated | Yes |
| DNS record creation | Automated | Yes |
| Oracle prerequisite update | Automated | Yes |
| DR switchover drill | Semi-automated | Yes |
| Production failover | Semi-automated | Mandatory final approval |

Guardrails:

- Runner allow-list for production jobs
- Secret retrieval only at runtime
- Serialized execution for shared resources
- Automatic stop on failed validation

---

## Rollback Strategy

Rollback must be defined before go-live.

Examples:

- Terraform change rollback by reverting module version or variable set
- Ansible rollback by applying previous known-good baseline
- DNS rollback by restoring prior record target and TTL
- VM provisioning rollback by de-registering failed build and rebuilding from template

Each automation domain must have:

- Pre-change snapshot or export
- Clear owner for rollback decision
- Maximum rollback execution time target

Practical rollback for freshers:

1. Stop the active pipeline
2. Revert the last merged change in Git
3. Re-run validation
4. Re-apply the last known-good state
5. Confirm environment health before closing the ticket

Example:

```bash
git revert <commit_id>
git push origin main
terraform -chdir=automation/terraform/environments/prod plan
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/site.yml
```

---

## Operational Reporting

Track the following KPIs:

- Provisioning lead time
- Success and failure rate by pipeline
- Drift findings per week
- Mean time to recover after failed automation
- Number of manual changes outside pipeline

These KPIs help prove the automation program is improving reliability instead of only increasing tool complexity.

---

## Detailed Automation Documents

Continue with:

- [10-02-vm-and-os-provisioning-automation.md](./10-02-vm-and-os-provisioning-automation.md)
- [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
- [10-04-dns-and-service-endpoint-automation.md](./10-04-dns-and-service-endpoint-automation.md)
- [10-05-os-baseline-and-oracle-prerequisite-automation.md](./10-05-os-baseline-and-oracle-prerequisite-automation.md)
