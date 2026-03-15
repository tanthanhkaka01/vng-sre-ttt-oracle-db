# 10 - Automation Strategy

## Overview

This section defines the automation strategy for operating Oracle RAC + Data Guard at production scale.

The objective is to reduce manual operations, improve consistency, and shorten incident recovery time while maintaining strong change control.

Automation scope includes:

- Infrastructure provisioning
- OS and database configuration management
- Backup and recovery operations
- Monitoring and alert automation
- Failover orchestration and DR drills
- Compliance, audit, and governance workflows

This document is the summary layer for the automation design.

Detailed implementation guidance is split into the following companion documents in execution order for the production path:

- [10-01-automation-platform-and-delivery-model.md](./10-01-automation-platform-and-delivery-model.md)  
  Defines the automation platform, repository layout, CI/CD pipeline, approval model, execution flow, and rollback controls.
- [10-02-01-vm-and-os-provisioning-automation.md](./10-02-01-vm-and-os-provisioning-automation.md)  
  Describes automated VM provisioning and OS installation for VMware vSphere and OpenStack, including templates, Kickstart, cloud-init, and validation flow.
- [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)  
  Covers guest OS network automation for interface mapping, static IP configuration, VLAN, bonding, routing, MTU, and post-change validation.
- [10-04-os-baseline-and-oracle-prerequisite-automation.md](./10-04-os-baseline-and-oracle-prerequisite-automation.md)  
  Defines automated OS baseline hardening and Oracle prerequisite setup, including packages, users, kernel parameters, limits, and readiness checks.
- [10-05-dns-and-service-endpoint-automation.md](./10-05-dns-and-service-endpoint-automation.md)  
  Details automation for host records, VIP, SCAN, logical database endpoints, TTL policy, and DR DNS cutover workflow.
- [10-02-02-vmware-workstation-pro-automation.md](./10-02-02-vmware-workstation-pro-automation.md)  
  Describes the separate VMware Workstation Pro 17 automation path for local lab environments, including template clone, VMX update, `vmrun` execution, and handoff to Ansible.

## Recommended Execution Routes

### Production build path

1. [10-01-automation-platform-and-delivery-model.md](./10-01-automation-platform-and-delivery-model.md)
2. [10-02-01-vm-and-os-provisioning-automation.md](./10-02-01-vm-and-os-provisioning-automation.md)
3. [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
4. [10-04-os-baseline-and-oracle-prerequisite-automation.md](./10-04-os-baseline-and-oracle-prerequisite-automation.md)
5. [10-05-dns-and-service-endpoint-automation.md](./10-05-dns-and-service-endpoint-automation.md)

Use this route for vSphere or OpenStack based production and DR environments.

### Lab build path

1. [10-01-automation-platform-and-delivery-model.md](./10-01-automation-platform-and-delivery-model.md)
2. [10-02-02-vmware-workstation-pro-automation.md](./10-02-02-vmware-workstation-pro-automation.md)
3. [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
4. [10-04-os-baseline-and-oracle-prerequisite-automation.md](./10-04-os-baseline-and-oracle-prerequisite-automation.md)
5. [10-05-dns-and-service-endpoint-automation.md](./10-05-dns-and-service-endpoint-automation.md)

Use this route when building a local learning or test lab on VMware Workstation Pro. DNS automation in lab can be simplified if you are using a local resolver or `/etc/hosts` during early validation.

Practical execution note:

- The current repository now includes silent automation scaffolding for Oracle Grid installation, RAC database creation, and Data Guard broker bootstrap, but these flows still depend on staged Oracle media, shared storage, and real platform provider configuration.
- For a junior-friendly, platform-by-platform simulation of what can run now and what still needs implementation, see [../automation/docs/runbooks/platform-end-to-end-simulation.md](../automation/docs/runbooks/platform-end-to-end-simulation.md).

### Simulation Review for VM Automation (2026-03-15)

The repository was reviewed in a simulated environment for the three requested VM automation paths:

- VMware vSphere
- OpenStack
- VMware Workstation Pro 17

Scope of this review:

- Read the live Terraform, Ansible, and PowerShell assets in the repository
- Confirm that the environment Terraform files already call the vSphere and OpenStack modules
- Confirm that the VMware Workstation Pro scripts implement clone, start, and stop flows
- Record whether the code looks runnable with real infrastructure backing it

Important limitation of this review:

- This workstation does not currently have `terraform` or `ansible-playbook` installed, so the review is a code-path simulation and readiness check, not a real `plan/apply` or playbook execution.

### VM Automation Readiness Verdict

| Platform | Repository implementation status | Can code run on real environment? | Honest verdict |
|------|------|------|------|
| VMware vSphere | Terraform environment and module wiring exist | Yes, if real vCenter/template/network values are supplied | OK at VM provisioning layer, not yet full RAC end-to-end |
| OpenStack | Terraform environment and module wiring exist | Yes, if real OpenStack credentials, networks, image, and security groups are supplied | OK at instance provisioning layer, not yet full RAC end-to-end |
| VMware Workstation Pro 17 | PowerShell scripts exist for clone/start/stop/build | Yes, if `vmrun.exe`, template VM, and local paths are valid | Best current path for lab simulation and junior onboarding |

### Platform-by-Platform Notes

#### VMware vSphere

What is present in code now:

- `automation/terraform/environments/prod/main.tf` already loops through `var.vmware_nodes`
- `automation/terraform/modules/vmware_vm/main.tf` creates a `vsphere_virtual_machine`
- The module already sets CPU, memory, system disk, three NICs, clone source, guest hostname, gateway, and DNS list
- `automation/terraform/environments/prod/providers.tf` already contains a real `vsphere` provider block

What this means:

- The vSphere path is no longer only documentation; it is implementable code.
- If you provide a valid `terraform.tfvars`, real provider credentials, template UUID, datastore, resource pool, and network IDs, the VM creation layer is designed to run for real.

What still blocks full end-to-end automation:

- DNS creation is still placeholder-only through `null_resource`
- Shared storage and ASM disk preparation are not automated
- Grid, RAC DB, and Data Guard still depend on Oracle media and real storage/network prerequisites

#### OpenStack

What is present in code now:

- `automation/terraform/environments/dr/main.tf` already loops through `var.openstack_nodes`
- `automation/terraform/modules/openstack_instance/main.tf` creates three ports plus one compute instance
- `automation/terraform/environments/dr/providers.tf` already contains a real `openstack` provider block

What this means:

- The OpenStack path is also beyond documentation level.
- With valid auth, image, flavor, networks, subnets, and security groups, the instance provisioning layer is designed to run for real.

What still blocks full end-to-end automation:

- DNS creation is still placeholder-only
- RAC shared storage design is still outside the repository
- Oracle Grid, RAC DB, and Data Guard remain environment-dependent

#### VMware Workstation Pro 17

What is present in code now:

- `automation/workstation-pro/scripts/create-vm.ps1` clones a template directory, renames the VMX, and updates display name, memory, and vCPU
- `automation/workstation-pro/scripts/start-vm.ps1` and `stop-vm.ps1` call `vmrun`
- `automation/workstation-pro/scripts/invoke-lab-build.ps1` loops through the JSON config and builds multiple lab VMs

What this means:

- This is the closest path to something you can actually practice quickly in a local lab.
- If VMware Workstation Pro 17, `vmrun.exe`, a powered-off template, and valid JSON paths are present, the script path is designed to run for real.

Current caveats:

- The script assumes the cloned template remains valid after directory copy and VMX rename
- There is no automation yet for RAC shared disks, lab DNS, or full Oracle stack completion
- Successful Oracle RAC simulation still depends on extra manual lab preparation

### Final Simulation Conclusion

For the requested VM automation simulation, the answer is:

- The code base is OK for simulated review across all three platforms
- The code is plausibly runnable for real at the VM creation layer on all three platforms when connected to a real environment
- The repository is not yet a one-click full Oracle RAC + Data Guard automation solution

Recommended current usage order:

1. Use VMware Workstation Pro 17 first for lab practice
2. Use VMware vSphere next for production-style VM provisioning
3. Use OpenStack when the real storage and provider model is finalized

---

## Automation Principles

Automation in this architecture follows these principles:

- Everything as code (infrastructure, configuration, runbooks)
- Idempotent execution (safe reruns)
- Standardized environments across primary and DR sites
- Role-based and approval-based execution for high-risk actions
- Full auditability of every automated change

---

## Target Automation Domains

| Domain | Objective | Suggested Tools |
|-------|-----------|-----------------|
| Infrastructure Provisioning | Consistent host/network/storage build | Terraform, Ansible |
| OS Hardening & Baseline | Standard packages, kernel params, users/groups | Ansible |
| Oracle Configuration | Listener, tnsnames, RMAN, Data Guard params | Ansible, shell |
| Job Scheduling | Backup, health check, validation tasks | cron, enterprise scheduler |
| Monitoring Setup | Exporters, dashboards, alerts as code | Prometheus stack, Grafana |
| DR Orchestration | Switchover/failover workflow automation | Ansible, orchestrator pipeline |
| Compliance & Audit | Change records and execution logs | Git + CI/CD + ticketing |

---

## Automation Architecture

![Automation Architecture](../images/automation-architecture.svg)
*Figure: GitOps pipeline feeding Ansible/Terraform execution domains.*

```text
Git Repository (IaC + Runbooks + Scripts)
                |
           CI/CD Pipeline
                |
   +------------+-------------+
   |                          |
Ansible Control Node      Terraform Runner
   |                          |
Primary RAC + DR RAC      Infra Resources
   |
Execution Logs + Metrics + Alerts
```

Key concept:

- Git is the single source of truth
- Pipeline enforces validation before execution
- Production changes require approval gates

---

## Repository Structure (Recommended)

```text
automation/
  terraform/
    network/
    compute/
    storage/
  ansible/
    inventories/
      prod/
      dr/
    roles/
      os_baseline/
      oracle_prereq/
      grid_config/
      db_config/
      dataguard/
      monitoring_agent/
  scripts/
    rman/
    dataguard/
    healthchecks/
  pipelines/
    ci.yml
    cd.yml
  docs/
    runbooks/
```

---

## Infrastructure as Code Strategy

Automate provisioning of:

- VM or bare-metal profiles
- VLAN/subnet and routing definitions
- DNS records (`db.company.local`, SCAN aliases)
- Shared storage mappings
- Security groups/firewall baseline

IaC requirements:

- Use reusable modules for primary and DR
- Parameterize environment differences (IP ranges, hostnames)
- Enforce naming standards and tagging
- Keep state backend protected and access-controlled

---

## Configuration Management Strategy

Automate OS and Oracle prerequisites:

- Kernel parameters and limits
- Required packages and services
- User/group creation
- Oracle env files and profile settings
- Listener and `tnsnames.ora` templates
- RMAN policy deployment
- Data Guard Broker startup and validation scripts

Execution model:

- Apply baseline to all nodes
- Apply role-specific tasks (primary vs standby)
- Run post-check validation after each playbook

---

## Database Operational Automation

### 1. Backup Automation

- Schedule RMAN Level 0/1 and archivelog backups
- Auto-rotate logs
- Auto-validate backup success and age
- Auto-open ticket/alert on failure

### 2. Data Guard Health Automation

- Periodic broker status checks
- Transport/apply lag threshold checks
- Automatic evidence collection for incident triage

### 3. Capacity Automation

- Daily FRA and tablespace usage snapshots
- Growth trend reports
- Proactive capacity alert generation

---

## Failover Automation Strategy

Failover must be semi-automated with guardrails.

Automate:

- Pre-checks (broker status, standby health, lag, cluster state)
- Execution steps (`switchover`/`failover`) via controlled scripts
- DNS update workflow
- Post-check validation and report generation

Keep manual approval for:

- Final failover execution in production
- DNS cutover confirmation
- Failback decision

---

## Example DR Orchestration Flow

![DR Orchestration Flow](../images/dr-orchestration-flow.svg)
*Figure: Controlled role transition workflow for DR events and drills.*

```text
Trigger (Incident or Drill)
      |
Run Prechecks
      |
Approval Gate
      |
Execute Role Transition (DGMGRL)
      |
Update DNS Endpoint
      |
Run Smoke Tests
      |
Publish Outcome + Metrics
```

---

## CI/CD for Automation Assets

Pipeline stages:

1. Lint and syntax checks (`ansible-lint`, shellcheck, YAML validation)
2. Static policy checks (naming, required tags, risky commands)
3. Dry-run execution (`ansible --check` where possible)
4. Approval gate for production
5. Controlled deployment with logs/artifacts

Branch policy:

- Changes via pull request only
- Mandatory reviewer from DBA/SRE owners
- Version tags for release bundles

---

## Safety Controls and Guardrails

Mandatory safeguards:

- No destructive command execution without explicit approval
- Environment allow-list (prod vs non-prod)
- Concurrency control to avoid parallel conflicting jobs
- Automatic rollback path for configuration changes
- Secrets never stored in plain text

Use:

- Vault/secret manager for DB credentials
- Least privilege service accounts
- Signed change artifacts where possible

---

## Observability of Automation

Track automation KPIs:

- Job success rate
- Mean execution time
- Change failure rate
- Rollback frequency
- MTTR improvement after automation rollout

Log every run with:

- Who triggered the job
- What version was executed
- Which hosts were changed
- Result and evidence links

---

## Compliance and Audit

Automation must support audit requirements:

- Immutable logs for production changes
- Ticket/reference ID for each change execution
- Evidence retention for DR drill results
- Access review for automation accounts

Recommended retention:

- Automation execution logs: 12 months
- DR drill reports: 24 months

---

## Phased Implementation Plan

### Phase 1. Foundation

- Build Git repo and CI baseline
- Automate OS baseline and Oracle prerequisites
- Standardize inventory and variables

### Phase 2. Core Operations

- Automate RMAN jobs and health checks
- Automate monitoring agent/dashboards deployment
- Add alert integrations

### Phase 3. DR Automation

- Automate switchover drill flow
- Add controlled failover orchestration
- Generate DR drill reports automatically

### Phase 4. Optimization

- Tune thresholds and reduce noisy alerts
- Add self-healing actions for known low-risk issues
- Improve reporting and executive dashboards

---

## Risks and Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Incorrect automation logic | Service disruption | Peer review + staging tests |
| Credential leakage | Security incident | Vault + rotation + RBAC |
| Over-automation of critical actions | Uncontrolled failover | Approval gates + break-glass policy |
| Drift between code and environment | Inconsistent behavior | Scheduled drift detection |

---

## Summary

This automation strategy establishes a controlled, auditable, and scalable operating model for Oracle RAC + Data Guard.

Key outcomes:

- Reduced manual effort and configuration drift
- Faster and safer operational execution
- Repeatable DR operations with evidence
- Better reliability through policy-driven automation

This completes the end-to-end technical design from infrastructure setup to resilient operations.

For detailed implementation flows, use the route that matches your target environment:

Production path:
1. [10-01-automation-platform-and-delivery-model.md](./10-01-automation-platform-and-delivery-model.md)
2. [10-02-01-vm-and-os-provisioning-automation.md](./10-02-01-vm-and-os-provisioning-automation.md)
3. [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
4. [10-04-os-baseline-and-oracle-prerequisite-automation.md](./10-04-os-baseline-and-oracle-prerequisite-automation.md)
5. [10-05-dns-and-service-endpoint-automation.md](./10-05-dns-and-service-endpoint-automation.md)

Lab path:
1. [10-01-automation-platform-and-delivery-model.md](./10-01-automation-platform-and-delivery-model.md)
2. [10-02-02-vmware-workstation-pro-automation.md](./10-02-02-vmware-workstation-pro-automation.md)
3. [10-03-network-configuration-automation.md](./10-03-network-configuration-automation.md)
4. [10-04-os-baseline-and-oracle-prerequisite-automation.md](./10-04-os-baseline-and-oracle-prerequisite-automation.md)
5. [10-05-dns-and-service-endpoint-automation.md](./10-05-dns-and-service-endpoint-automation.md)

