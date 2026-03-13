# 10-05 - OS Baseline and Oracle Prerequisite Automation

## Overview

This section describes how to automate the post-installation operating system baseline and Oracle prerequisite configuration required before Grid Infrastructure and RAC installation.

The objective is to eliminate manual host preparation drift across primary and DR environments.

Automation scope includes:

- Required package installation
- User and group creation
- Kernel parameter configuration
- Limits and sysctl settings
- Time sync and service baseline
- Oracle software staging prerequisites

---

## Baseline Areas

| Area | Examples |
|------|------|
| OS packages | `oracle-database-preinstall`, `chrony`, `unzip`, `kmod` |
| Users and groups | `oracle`, `grid`, `oinstall`, `asmadmin`, `dba` |
| Kernel tuning | shared memory, semaphores, file handles |
| Limits | `nofile`, `nproc`, stack size |
| Services | time sync, firewall policy, tuned profile |
| Storage prep | multipath packages, ASM library prerequisites |

---

## Automation Method

Recommended tool:

- Ansible roles executed after successful host provisioning and network validation

Suggested role order:

1. `os_bootstrap`
2. `os_packages`
3. `os_users_groups`
4. `os_kernel_limits`
5. `storage_prereq`
6. `oracle_prereq`
7. `validation`

This sequence helps isolate failures early.

---

## Package and Repository Automation

Automate:

- Registration to approved repositories
- Installation of baseline packages
- Version pinning for critical packages
- Validation that required dependencies are present

Package automation should support offline or mirrored repositories if production hosts do not have internet access.

---

## User and Permission Baseline

Automation must create and verify:

- `grid` user for Grid Infrastructure
- `oracle` user for database software
- Required Unix groups and GIDs
- Ownership and permission of Oracle base directories

Example managed paths:

```text
/u01/app
/u01/app/grid
/u01/app/oracle
/u01/stage
```

---

## Kernel and Limits Configuration

Automate standardized settings for:

- `fs.file-max`
- `kernel.sem`
- `kernel.shmall`
- `kernel.shmmax`
- `net.ipv4.ip_local_port_range`
- User shell limits

Changes should be applied through managed files or templates, not by ad-hoc line edits.

---

## Validation Checklist

Each node should pass the following checks before Oracle installation:

- Required packages installed
- Required users and groups present
- Oracle directories created with correct ownership
- Kernel parameters match baseline
- Time synchronization healthy
- Reboot performed if required by kernel or package changes

Example result:

```text
Node: rac-node1
Packages: OK
Users/Groups: OK
Kernel Params: OK
Storage Prereq: OK
Ready for Grid Install: YES
```

---

## Compliance and Drift Control

Scheduled baseline validation should detect:

- Unauthorized package removal
- Changed kernel parameters
- Incorrect directory ownership
- Disabled time synchronization

Low-risk drift can be auto-remediated in non-production.
Production remediation should remain approval-based.

---

## Handoff to Oracle Installation

When all prerequisite automation checks are complete, the environment is ready for:

- Oracle Grid Infrastructure installation
- ASM disk discovery validation
- Oracle RAC database software deployment

This forms the final host-preparation gate before the database layer is automated further.
