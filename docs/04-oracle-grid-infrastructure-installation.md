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

## Lab Installation Steps (Detail)

> Run the steps on both nodes unless specified otherwise.

### 1. set hosts file (do on both node)

```bash
nano /etc/hosts
```

```text
192.168.10.101 rac01
192.168.10.102 rac02
```

### Open Required Firewall Ports

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

Set permissions:

```bash
chmod -R 775 /u01/app
```

---

## Configure Shared Storage

This lab uses Oracle VM VirtualBox shared disks.

Create the following disks:

Disk	Size	Purpose
OCR1	10 GB	Cluster registry
OCR2	10 GB	Cluster registry
OCR3	10 GB	Cluster registry
FRA	30 GB	Fast Recovery Area
DATA	50 GB	Database files

Attach the disks to both RAC nodes.

Verify disks:

lsblk
Prepare ASM Disks

Clear disks:

dd if=/dev/zero of=/dev/sdb bs=1M count=100
dd if=/dev/zero of=/dev/sdc bs=1M count=100
dd if=/dev/zero of=/dev/sdd bs=1M count=100
dd if=/dev/zero of=/dev/sde bs=1M count=100
dd if=/dev/zero of=/dev/sdf bs=1M count=100

Check disk serial numbers:

udevadm info --query=all --name=/dev/sdb | grep ID_SERIAL
Configure udev Rules for ASM

Create rule file:

nano /etc/udev/rules.d/99-oracle-asm.rules

Example configuration:

ENV{ID_SERIAL}=="VBOX_HARDDISK_VB7fd22947-1ee2be80", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="RAC_DATA_01"
ENV{ID_SERIAL}=="VBOX_HARDDISK_VBcea8deba-23e870e8", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="RAC_FRA_01"
ENV{ID_SERIAL}=="VBOX_HARDDISK_VBec27af00-c7ce861a", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="RAC_OCR_01"
ENV{ID_SERIAL}=="VBOX_HARDDISK_VB0a450419-7e5bd8c9", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="RAC_OCR_02"
ENV{ID_SERIAL}=="VBOX_HARDDISK_VB520ecf59-e376a5d1", OWNER="grid", GROUP="asmadmin", MODE="0660", SYMLINK+="RAC_OCR_03"

Reload rules:

udevadm control --reload-rules
udevadm trigger

Verify:

ls -l /dev/RAC_*

---

## Install GUI Environment

Install GUI:

```bash
yum -y groups install "Server with GUI"
```

Configure Xfce:

```bash
echo "exec /usr/bin/xfce4-session" >> ~/.xinitrc
startx
```

Install VNC server:

```bash
yum -y install tigervnc-server
```

Allow VNC firewall access:

```bash
firewall-cmd --add-service=vnc-server --permanent
firewall-cmd --reload
```

Start VNC:

```bash
vncserver :1 -geometry 1024x768 -depth 24
```

---

## Configure SSH Equivalency

Login as grid user:

```bash
su - grid
```

Generate key:

```bash
ssh-keygen -t rsa
```

Copy key:

```bash
ssh-copy-id grid@rac02
ssh-copy-id grid@rac01
```

Repeat the same process for oracle user.

Test SSH:

```bash
ssh rac02
```

---

## Configure /dev/shm

Set shared memory size equal to RAM.

```bash
umount /dev/shm
mount -t tmpfs tmpfs -o size=120G /dev/shm
```

Persist configuration:

```bash
nano /etc/fstab
```

```text
tmpfs   /dev/shm        tmpfs   defaults,size=120G        0       0
```

Reload systemd:

```bash
systemctl daemon-reload
```

---

## Configure Swap

Create swap file:

```bash
dd if=/dev/zero of=/swapfile bs=1G count=16
mkswap /swapfile
swapon /swapfile
```

verify:

```bash
free -h
```

Add to fstab:

```bash
/swapfile swap swap defaults 0 0
```

---

## Copy Oracle Installation Files

Copy the following zip files:

```text
Grid Infrastructure
Oracle Database
```

Destination:

```text
/u01/app/grid_install
/u01/app/oracle_install
```

---

## Install Oracle Grid Infrastructure

Login as grid user:

```bash
su - grid
```

Extract Grid software:

```bash
unzip /u01/app/grid_install/LINUX.X64_213000_grid_home.zip -d /u01/app/21c/grid
```

---

## Configure Grid Environment

Create environment file:

```bash
nano /home/grid/setEnv.sh
```

rac01:

```text
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/21c/grid
export GRID_HOME=/u01/app/21c/grid
export ORACLE_SID=+ASM1
export PATH=$ORACLE_HOME/bin:$PATH
```

rac02:

```text
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/21c/grid
export GRID_HOME=/u01/app/21c/grid
export ORACLE_SID=+ASM2
export PATH=$ORACLE_HOME/bin:$PATH
```

Add to profile:

```bash
echo ". /home/grid/setEnv.sh" >> ~/.bash_profile
source ~/.bash_profile
```

---

## Start Grid Installer

Start VNC:

```bash
vncserver :1 -geometry 1024x768 -depth 24
```

Set display:

```bash
export DISPLAY=:1
```

Run installer:

```bash
nohup /u01/app/21c/grid/gridSetup.sh > /u01/app/21c/grid/grid_setup.log 2>&1 &
```

---

## Grid Installation Configuration

### Cluster Configuration

```text
Cluster Name: rac
SCAN Name: rac-scan.private.db.com
SCAN Port: 1521
```

### Add Nodes

```text
rac01
rac02
```

### Network Interfaces

| Interface | Purpose       |
| --------- | ------------- |
| enp0s3    | Public        |
| enp0s8    | Private / ASM |

### ASM Disk Group

Disk group name:

```text
OCR
```

Discovery path:

```text
/dev/RAC*
```

Selected disks:

```text
RAC_OCR_01
RAC_OCR_02
RAC_OCR_03
```

ASM password:

```text
oracle
```

### Check CRS Services

Configure CRS environment for root:

```bash
nano /home/root/setEnv.sh
```

```text
export ORACLE_HOME=/u01/app/21c/grid
export GRID_HOME=/u01/app/21c/grid
export PATH=$ORACLE_HOME/bin:$PATH
```

Load environment:

```bash
source /root/.bash_profile
```

Check CRS:

```bash
crsctl check crs
```

Restart CRS:

```bash
crsctl stop crs
crsctl start crs
```

---

## Configure ASM Disk Groups

Run ASMCA:

```bash
su - grid
vncserver :1 -geometry 1024x768 -depth 24
export DISPLAY=:1
nohup /u01/app/21c/grid/bin/asmca > /tmp/asmca_setup.log 2>&1 &
```

Create disk groups.

### DATA

```text
Disk Group Name: DATA
Redundancy: External
Disk: /dev/RAC_DATA_01
```

### FRA

```text
Disk Group Name: FRA
Redundancy: External
Disk: /dev/RAC_FRA_01
```

## Installation Completed

After completing these steps:

- Oracle Clusterware is running
- ASM disk groups are configured
- RAC infrastructure is ready

---

## Next Steps

See:

```text
05-oracle-rac-database-installation.md
```