# 05 - Oracle RAC Database Installation

## Overview

This section describes the installation of Oracle Database 21c software and the creation of an Oracle RAC database using DBCA.

After completing the previous step (Oracle Grid Infrastructure installation), the cluster environment already provides:

- Oracle Clusterware
- Oracle ASM
- SCAN listener
- Shared ASM storage

In this step we will:

- Install Oracle Database software on all RAC nodes
- Configure Oracle environment variables
- Create a RAC database using DBCA
- Configure client connectivity using SCAN

---

## RAC Environment

| Component        | Value        |
| ---------------- | ------------ |
| Database Version | Oracle 21c   |
| Architecture     | Oracle RAC   |
| Nodes            | rac01, rac02 |
| Storage          | ASM          |
| DATA Disk Group  | +DATA        |
| FRA Disk Group   | +FRA         |

---

## Oracle Database Installation

### 1. Extract Oracle Database Software

Login as oracle user on rac01.

```bash
su - oracle
```

Extract the Oracle database installation package to the Oracle home directory.

```bash
unzip /u01/app/oracle_install/LINUX.X64_213000_db_home.zip -d /u01/app/product/db21c
```

### 2. Configure Oracle Environment

Create environment configuration file.

```bash
nano /home/oracle/setEnv.sh
```

Example configuration.

> ORACLE_SID must match the instance name of the node.

#### rac01

```text
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/product/db21c
export ORAINVENTORY=/u01/app/oraInventory
export ORACLE_SID=pridb1
export GRID_HOME=/u01/app/21c/grid
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export PATH=$GRID_HOME/bin:$ORACLE_HOME/bin:$PATH
```

#### rac02

```text
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/product/db21c
export ORAINVENTORY=/u01/app/oraInventory
export ORACLE_SID=pridb2
export GRID_HOME=/u01/app/21c/grid
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:/lib:/usr/lib
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8
export PATH=$GRID_HOME/bin:$ORACLE_HOME/bin:$PATH
```

Add the environment file to .bash_profile.

```bash
echo ". /home/oracle/setEnv.sh" >> /home/oracle/.bash_profile
source /home/oracle/.bash_profile
```

### 3. Start Oracle Database Installer

Run the Oracle installer only on rac01.

Start VNC session:

```bash
vncserver :2 -geometry 1024x768 -depth 24
```

Set display.

```bash
export DISPLAY=:2
```

Start installer.

```bash
nohup /u01/app/product/db21c/runInstaller > /tmp/oracle_setup.log 2>&1 &
```

### 4. Oracle Software Installation Configuration

Follow the GUI steps below.

#### Step 1. Configuration Option

Set Up Software Only

#### Step 2. Database Installation Option

Oracle Real Application Clusters database installation

#### Step 3. Nodes Selection

Select both cluster nodes.

```text
rac01
rac02
```

#### Step 4. Database Edition

```text
Enterprise Edition
```

#### Step 5. Installation Location

```text
Oracle Base: /u01/app/oracle
Oracle Home: /u01/app/product/db21c
```

#### Step 6. Operating System Groups

| Role        | Group    |
| ----------- | -------- |
| OSDBA       | dba      |
| OSOPER      | dba      |
| OSBACKUPDBA | dba      |
| OSDGDBA     | dba      |
| OSKMDBA     | dba      |
| OSRACDBA    | dba      |

#### Step 7. Root Script Execution

Enable automatic root script execution.

Automatically run configuration scripts

Root credential:

```text
User: root
Password: <password root user>
```

#### Step 8. Prerequisite Checks

If all prerequisite checks pass, continue to the next step.

#### Step 9. Summary

Review the configuration and click:

```text
Install
```

#### Step 10. Install Product

The installer copies Oracle Database software to both RAC nodes.

#### Step 11. Finish

Click:

```text
Close
```

### 5. Run Root Scripts (If Required)

If the installer does not run them automatically, execute the following commands on both nodes.

Login as root:

```bash
su - root
```

Run scripts.

```bash
/u01/app/oraInventory/orainstRoot.sh
/u01/app/product/db21c/root.sh
```

### 6. Network Configuration

Running NETCA is not required, because the SCAN listener and local listeners are already managed by Grid Infrastructure.

### 7. Create RAC Database Using DBCA

Run DBCA on rac01.

Start VNC.

```bash
vncserver :2 -geometry 1024x768 -depth 24
export DISPLAY=:2
```

Start DBCA.

```bash
nohup $ORACLE_HOME/bin/dbca > /tmp/dbca_setup.log 2>&1 &
```

#### Step 1. Database Operation

Create a Database

#### Step 2. Creation Mode

Advanced Configuration

#### Step 3. Deployment Type

```text
Database type: Oracle Real Application Clusters (RAC)
Database Management Policy: Automatic
Template: General Purpose or Transaction Processing
```

#### Step 4. Nodes Selection

Select both nodes.

```text
rac01
rac02
```

#### Step 5. Database Identification

```text
Global Database Name: pridb
SID Prefix: pridb
```

Container database configuration.

```text
Create as Container Database
Use Local Undo Tablespace for PDBs
```

Create PDB.

```text
Number of PDBs: 1
PDB Name: pridbpdb1
```

#### Step 6. Storage Option

```text
Storage Type: Automatic Storage Management (ASM)
Database Files Location: +DATA/{DB_UNIQUE_NAME}
Use Oracle Managed Files (OMF)
```

#### Step 7. Fast Recovery Area

Enable FRA.

```text
Recovery Storage Type: ASM
Fast Recovery Area: +FRA/{DB_UNIQUE_NAME}
FRA Size: 4194304 MB
```

#### Step 8. Data Vault

Leave all options unchecked.

#### Step 9. Configuration Options

> To set the Oracle SGA and PGA on a Linux server with 128GB of RAM, use Automatic Shared Memory Management (ASMM) and configure HugePages. A common starting point is to dedicate approximately 60% to 80% of total RAM to the Oracle instance (SGA + PGA), which is about 90GB in this case, leaving 30% for the OS and other processes.

Memory

```text
Memory Management: Automatic Shared Memory Management (ASMM)
SGA: 71680 MB
PGA: 20480 MB
```

Sizing

```text
Processes: 1280
```

Character Set

```text
Character Set: AL32UTF8
National Character Set: AL16UTF16
Language: American
Territory: United States
```

Connection Mode

```text
Dedicated Server Mode
```

#### Step 10. Management Options

Enable management features.

```text
Run Cluster Verification Utility (CVU) checks periodically
Configure Enterprise Manager Database Express
```

EM Express Port:

```text
5500
```

#### Step 11. User Credentials

Use the same password for administrative accounts.

```text
Password: <strong password>
Confirm Password: <strong password>
```

#### Step 12. Creation Option

Create Database

#### Step 13. Prerequisite Checks

If all checks pass, continue.

#### Step 14. Summary

Click:

```text
Finish
```

#### Step 15. Progress Page

DBCA will create the RAC database across both nodes.

#### Step 16. Finish

Click:

```text
Close
```

### 8. Configure Client Connectivity

Edit tnsnames.ora on both nodes.

```bash
nano $ORACLE_HOME/network/admin/tnsnames.ora
nano $ORACLE_BASE/homes/OraDB21Home1/network/admin/tnsnames.ora
```

Add the following configuration.

```text
pridb =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = scan-db.company.local)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pridb)
    )
  )

pridbpdb1 =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = scan-db.company.local)(PORT = 1521))
    (CONNECT_DATA =
      (SERVER = DEDICATED)
      (SERVICE_NAME = pridbpdb1)
    )
  )
```

Clients should connect to the database using the SCAN address.

Example:

```text
scan-db.company.local:1521
```

This allows Oracle RAC to automatically provide:

- Connection load balancing
- Instance failover
- Transparent connection routing

### 9. Verify RAC Database

Check instance status.

```sql
SELECT inst_id, instance_name, host_name, status FROM gv$instance;
```

Check services.

```sql
SELECT name FROM v$services;
```

Check PDB status.

```sql
SELECT name, open_mode FROM v$pdbs;
```
---

## Next Steps

See:
[06-data-guard-configuration.md](./06-data-guard-configuration.md)

