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

## Prerequisites

Before baseline automation starts, confirm:

1. OS provisioning is complete
2. Network connectivity is stable
3. Package repositories or internal mirrors are reachable
4. ASM and multipath requirements are confirmed with the storage team
5. Oracle software users and group IDs are approved

This prevents rework during Grid installation.

---

## Step-by-Step Host Preparation for Freshers

Use this exact order:

1. Verify SSH access as the automation user
2. Collect OS facts
3. Enable approved repositories
4. Install required packages
5. Create users and groups
6. Create Oracle directories
7. Apply kernel and limits configuration
8. Enable time synchronization
9. Reboot if required
10. Run validation tasks

Quick pre-check:

```bash
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m setup -a "filter=ansible_distribution*"
```

---

## Package and Repository Automation

Automate:

- Registration to approved repositories
- Installation of baseline packages
- Version pinning for critical packages
- Validation that required dependencies are present

Package automation should support offline or mirrored repositories if production hosts do not have internet access.

Example Ansible task:

```yaml
- name: Install baseline packages
  ansible.builtin.package:
    name:
      - chrony
      - unzip
      - kmod
      - libaio
      - python3
    state: present
```

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

Example task:

```yaml
- name: Create Oracle groups
  ansible.builtin.group:
    name: "{{ item.name }}"
    gid: "{{ item.gid }}"
    state: present
  loop:
    - { name: "oinstall", gid: 1001 }
    - { name: "dba", gid: 1002 }
    - { name: "asmadmin", gid: 1003 }

- name: Create Oracle users
  ansible.builtin.user:
    name: "{{ item.name }}"
    uid: "{{ item.uid }}"
    group: oinstall
    groups: "{{ item.groups }}"
    append: true
    shell: /bin/bash
  loop:
    - { name: "grid", uid: 1101, groups: "asmadmin,dba" }
    - { name: "oracle", uid: 1102, groups: "dba" }
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

Example sysctl template content:

```text
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
net.ipv4.ip_local_port_range = 9000 65500
```

Example Ansible task:

```yaml
- name: Deploy Oracle sysctl baseline
  ansible.builtin.copy:
    dest: /etc/sysctl.d/99-oracle.conf
    content: |
      fs.file-max = 6815744
      kernel.sem = 250 32000 100 128
      kernel.shmall = 1073741824
      kernel.shmmax = 4398046511104
      net.ipv4.ip_local_port_range = 9000 65500
    owner: root
    group: root
    mode: "0644"

- name: Apply sysctl settings
  ansible.builtin.command: sysctl --system
  changed_when: true
```

---

## Example Playbook

Example `automation/ansible/playbooks/os-baseline.yml`:

```yaml
- name: Apply OS baseline for Oracle RAC
  hosts: rac_primary:rac_dr
  become: true
  roles:
    - os_packages
    - os_users_groups
    - os_kernel_limits
    - storage_prereq
    - oracle_prereq
    - validation
```

Run:

```bash
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/os-baseline.yml
```

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

Example validation commands:

```bash
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "id grid; id oracle"
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "sysctl -a | egrep 'fs.file-max|kernel.sem|kernel.shmmax'"
ansible -i automation/ansible/inventories/prod/hosts.yml rac_primary -m shell -a "systemctl is-active chronyd"
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

Example scheduled validation:

```bash
ansible-playbook -i automation/ansible/inventories/prod/hosts.yml automation/ansible/playbooks/os-baseline.yml --tags validation
```

---

## Handoff to Oracle Installation

When all prerequisite automation checks are complete, the environment is ready for:

- Oracle Grid Infrastructure installation
- ASM disk discovery validation
- Oracle RAC database software deployment

This forms the final host-preparation gate before the database layer is automated further.

Practical handoff criteria:

1. All baseline tasks completed with no failed hosts
2. Reboot, if required, has already been performed
3. Storage devices are visible to the OS
4. `grid` and `oracle` users can access their directories
5. Validation output is attached to the change record
