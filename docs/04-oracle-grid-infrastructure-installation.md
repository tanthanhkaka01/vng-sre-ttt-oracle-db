# 04 - Oracle Grid Infrastructure Installation

## Overview

This section describes the installation and configuration of Oracle Grid Infrastructure 21c for an Oracle RAC environment.

Oracle Grid Infrastructure provides the core components required for Oracle RAC, including:

- Oracle Clusterware
- Oracle ASM (Automatic Storage Management)
- SCAN Listener
- Cluster resource management

This guide installs Grid Infrastructure on a 2-node Oracle RAC cluster:

```text
rac01
rac02
```

---

## Architecture Components

Oracle Grid Infrastructure includes the following major components:

| Component          | Description                                               |
| ------------------ | --------------------------------------------------------- |
| Oracle Clusterware | Manages cluster membership, node monitoring, and failover |
| Oracle ASM         | Manages shared storage for database files                 |
| SCAN Listener      | Provides load-balanced database connection endpoint       |
| ASM Disk Groups    | Logical storage groups used by Oracle Database            |

In this architecture:

```text
Application
     |
 Load Balancer / DNS
     |
     SCAN
     |
+------------+      +------------+
| RAC Node 1 | <--> | RAC Node 2 |
+------------+      +------------+
       \              /
        \            /
         \          /
        Shared ASM Storage
```

---

## Installation Prerequisites

Before installing Oracle Grid Infrastructure, ensure the following prerequisites are completed.

### OS Configuration

Each RAC node must be configured with:

- Oracle Linux / RedHat compatible OS
- Required kernel parameters
- Required OS packages

---

## Open Required Firewall Ports

```bash
sudo firewall-cmd --permanent --add-port=1521/tcp
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --permanent --add-port=2100/tcp
sudo firewall-cmd --permanent --add-port=3260/tcp
sudo firewall-cmd --permanent --add-port=6200/tcp
sudo firewall-cmd --permanent --add-port=2016/tcp
sudo firewall-cmd --permanent --add-port=1158/tcp
sudo firewall-cmd --permanent --add-port=9000-9100/tcp
sudo firewall-cmd --permanent --add-port=5556/tcp
sudo firewall-cmd --permanent --add-port=7070/tcp
sudo firewall-cmd --permanent --add-port=42424/tcp
sudo firewall-cmd --permanent --add-port=4888/tcp
```

Reload firewall rules:

```text
sudo firewall-cmd --reload
```

Check firewall configuration:

```text
sudo firewall-cmd --list-all
```

Disable firewall:
```text
systemctl stop firewalld
systemctl disable firewalld
```

---

## Create Required Users and Groups

Create Oracle required groups:

```bash
groupadd oinstall
groupadd dba
groupadd asmadmin
groupadd asmdba
groupadd asmoper
```

Group description:

| Group    | Purpose                            |
| -------- | ---------------------------------- |
| oinstall | Installation ownership             |
| dba      | Database administration privileges |
| asmadmin | ASM administration                 |
| asmdba   | ASM database access                |
| asmoper  | ASM operator privileges            |

Create grid User:

```bash
useradd -g oinstall -G asmadmin,asmdba,asmoper grid
passwd grid
```

Create oracle user:

```bash
useradd -g oinstall -G dba,asmdba oracle
passwd oracle
```

Add additional groups if needed:

```bash
sudo usermod -aG dba,asmdba oracle
```

Check user groups:

```bash
groups oracle
```

---

## Create Oracle Directory Structure

Create required directories:

```bash
mkdir -p /u01/app/grid
mkdir -p /u01/app/oracle
mkdir -p /u01/app/product/db21c
mkdir -p /u01/app/oraInventory
mkdir -p /u01/app/21c/grid
mkdir -p /u01/app/grid_install
mkdir -p /u01/app/oracle_install
```

Set ownership:

```bash
chown -R grid:oinstall /u01/app/grid
chown -R oracle:oinstall /u01/app/oracle
chown -R oracle:oinstall /u01/app/product/db21c
chown -R grid:oinstall /u01/app/oraInventory
chown -R grid:oinstall /u01/app/21c
chown -R grid:oinstall /u01/app/grid_install
chown -R oracle:oinstall /u01/app/oracle_install
```

