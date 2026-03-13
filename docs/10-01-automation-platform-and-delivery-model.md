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
