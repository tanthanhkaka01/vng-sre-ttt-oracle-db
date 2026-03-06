# 06 - Data Guard Configuration

## Overview

This section describes the configuration of Oracle Data Guard 21c between the primary Oracle RAC database and the standby Oracle RAC database in the DR datacenter.

Oracle Data Guard provides:

- Disaster recovery across datacenters
- Data protection through continuous redo transport
- Role transition using switchover and failover
- Centralized management with Data Guard Broker

In this design:

- Primary RAC runs in the primary datacenter
- Standby RAC runs in the DR datacenter
- Replication mode is SYNC to target near-zero or zero data loss

---

## Data Guard Architecture

```text
Primary Site (DC1)                          DR Site (DC2)
------------------                          -------------
RAC: rac01, rac02                           RAC: rac03, rac04
DB_UNIQUE_NAME: pridb                       DB_UNIQUE_NAME: drdb
Role: PRIMARY                               Role: PHYSICAL STANDBY
             \                              /
              \------ Data Guard SYNC -----/
```

---

## Environment

| Component | Primary | Standby |
|----------|---------|---------|
| Database Name (`DB_NAME`) | pridb | pridb |
| Unique Name (`DB_UNIQUE_NAME`) | pridb | drdb |
| Database Role | PRIMARY | PHYSICAL STANDBY |
| Protection Mode | Maximum Availability | Maximum Availability |
| Transport Mode | SYNC | SYNC |
| Storage | ASM (+DATA, +FRA) | ASM (+DATA, +FRA) |

---

## Prerequisites

Before configuring Data Guard, verify:

- Oracle RAC is installed and running on both sites
- Primary database is in ARCHIVELOG mode
- FORCE LOGGING is enabled on primary
- Standby redo logs (SRL) exist on both primary and standby
- Network connectivity is open between all RAC nodes
- Oracle Net services (SCAN/listener/tnsnames) are configured
- Time synchronization (NTP/chrony) is enabled on all nodes

---

## Step 1. Configure Primary Database

Run as `sysdba` on primary.

```bash
sqlplus / as sysdba
```

Check current status:

```sql
SELECT name, open_mode, database_role, log_mode, force_logging FROM v$database;
```

Enable ARCHIVELOG mode (if not enabled):

```sql
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
ALTER DATABASE ARCHIVELOG;
ALTER DATABASE OPEN;
```

Enable FORCE LOGGING:

```sql
ALTER DATABASE FORCE LOGGING;
```

Set Data Guard related parameters:

```sql
ALTER SYSTEM SET log_archive_config='DG_CONFIG=(pridb,drdb)' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=pridb' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_2='SERVICE=drdb_sync SYNC AFFIRM VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=drdb' SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_state_1=ENABLE SCOPE=BOTH SID='*';
ALTER SYSTEM SET log_archive_dest_state_2=ENABLE SCOPE=BOTH SID='*';
ALTER SYSTEM SET fal_server='drdb_sync' SCOPE=BOTH SID='*';
ALTER SYSTEM SET standby_file_management='AUTO' SCOPE=BOTH SID='*';
```

Create standby redo logs on primary.

> Number of SRL groups should be at least online redo log groups + 1 for each thread.

Example:

```sql
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 11 ('+FRA') SIZE 1024M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 12 ('+FRA') SIZE 1024M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 1 GROUP 13 ('+FRA') SIZE 1024M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 21 ('+FRA') SIZE 1024M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 22 ('+FRA') SIZE 1024M;
ALTER DATABASE ADD STANDBY LOGFILE THREAD 2 GROUP 23 ('+FRA') SIZE 1024M;
```

---

## Step 2. Prepare Standby Parameter File

Create standby SPFILE/PFILE from primary settings with standby-specific values.

Key parameters on standby:

```text
DB_NAME=pridb
DB_UNIQUE_NAME=drdb
LOG_ARCHIVE_CONFIG='DG_CONFIG=(pridb,drdb)'
LOG_ARCHIVE_DEST_1='LOCATION=USE_DB_RECOVERY_FILE_DEST VALID_FOR=(ALL_LOGFILES,ALL_ROLES) DB_UNIQUE_NAME=drdb'
LOG_ARCHIVE_DEST_2='SERVICE=pridb_sync SYNC AFFIRM VALID_FOR=(ONLINE_LOGFILES,PRIMARY_ROLE) DB_UNIQUE_NAME=pridb'
FAL_SERVER=pridb_sync
STANDBY_FILE_MANAGEMENT=AUTO
```

Ensure password files are synchronized between primary and standby.

---

## Step 3. Configure Oracle Net Services

On both sites, configure `tnsnames.ora` entries:

```text
pridb_sync =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = scan-db.company.local)(PORT = 1521))
    (CONNECT_DATA = (SERVICE_NAME = pridb_dg))
  )

drdb_sync =
  (DESCRIPTION =
    (ADDRESS = (PROTOCOL = TCP)(HOST = scan-standby.company.local)(PORT = 1521))
    (CONNECT_DATA = (SERVICE_NAME = drdb_dg))
  )
```

Validate connectivity:

```bash
tnsping pridb_sync
tnsping drdb_sync
```

---

## Step 4. Create Standby Database (RMAN Duplicate)

Start standby instance in `NOMOUNT`, then duplicate from active primary.

On standby host:

```bash
rman target sys@pridb_sync auxiliary sys@drdb_sync
```

Run duplicate:

```rman
DUPLICATE TARGET DATABASE FOR STANDBY FROM ACTIVE DATABASE
  DORECOVER
  SPFILE
  SET db_unique_name='drdb'
  SET control_files='+DATA','+FRA'
  NOFILENAMECHECK;
```

After duplicate, mount standby and start managed recovery:

```sql
ALTER DATABASE RECOVER MANAGED STANDBY DATABASE USING CURRENT LOGFILE DISCONNECT;
```

---

## Step 5. Configure Data Guard Broker

Enable broker on both primary and standby:

```sql
ALTER SYSTEM SET dg_broker_start=TRUE SCOPE=BOTH SID='*';
```

Use DGMGRL from primary:

```bash
dgmgrl sys@pridb_sync
```

Create and enable broker configuration:

```text
CREATE CONFIGURATION dg_config AS PRIMARY DATABASE IS pridb CONNECT IDENTIFIER IS pridb_sync;
ADD DATABASE drdb AS CONNECT IDENTIFIER IS drdb_sync MAINTAINED AS PHYSICAL;
ENABLE CONFIGURATION;
```

Verify:

```text
SHOW CONFIGURATION;
SHOW DATABASE VERBOSE pridb;
SHOW DATABASE VERBOSE drdb;
```

---

## Step 6. Validate Redo Transport and Apply

Run checks on primary:

```sql
SELECT dest_name, status, error, destination, target, archiver, transmit_mode
FROM v$archive_dest_status
WHERE dest_id <= 3;
```

Run checks on standby:

```sql
SELECT process, status, thread#, sequence# FROM v$managed_standby;
SELECT thread#, MAX(sequence#) AS last_applied FROM v$archived_log WHERE applied='YES' GROUP BY thread#;
```

Broker validation:

```bash
dgmgrl sys@pridb_sync "validate database verbose drdb"
```

---

## Step 7. Switchover Procedure (Planned Role Transition)

Check readiness:

```bash
dgmgrl sys@pridb_sync "show configuration"
```

Execute switchover:

```bash
dgmgrl sys@pridb_sync "switchover to drdb"
```

Verify new roles:

```bash
dgmgrl sys@drdb_sync "show configuration"
```

Switchover is used for:

- Planned maintenance on primary site
- DR drill and readiness testing

---

## Step 8. Failover Procedure (Unplanned Outage)

If primary is unavailable and cannot be recovered quickly:

```bash
dgmgrl sys@drdb_sync "failover to drdb"
```

After original primary is repaired, reinstate it:

```bash
dgmgrl sys@drdb_sync "reinstate database pridb"
```

If reinstate is not possible, rebuild old primary as a standby using RMAN duplicate.

---

## Operational Best Practices

- Use Data Guard Broker for all role transitions
- Keep protection mode as Maximum Availability for production
- Monitor apply lag and transport lag continuously
- Perform periodic switchover drills
- Keep standby open read-only (Active Data Guard) only if licensed and required
- Ensure SRL sizing matches online redo log sizing

---

## Troubleshooting Quick Checks

Common checks:

```sql
SELECT database_role, open_mode, switchover_status FROM v$database;
SELECT message, timestamp FROM v$dataguard_status ORDER BY timestamp DESC;
```

Common issues:

- `ORA-16724` / `ORA-16810`: broker configuration or health status issue
- `ORA-12514`: listener/service registration mismatch
- Apply lag increasing: network bottleneck or standby I/O pressure

---

## Summary

Oracle Data Guard extends Oracle RAC architecture with cross-datacenter disaster recovery and role transition capabilities.

Key outcomes of this configuration:

- Synchronous redo transport to DR site
- Physical standby RAC kept in continuous recovery
- Broker-managed switchover/failover
- Standardized validation and operational runbook

This design supports high availability in primary and resilient disaster recovery for production workloads.

---

## Next Steps

See:

```text
07-backup-and-recovery-strategy.md
```
