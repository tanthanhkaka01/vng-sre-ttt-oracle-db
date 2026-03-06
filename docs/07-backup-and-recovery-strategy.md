# 07 - Backup and Recovery Strategy

## Overview

This section defines the backup and recovery strategy for the Oracle RAC + Data Guard architecture.

The strategy is designed to:

- Protect data against logical and physical failures
- Meet business RPO and RTO targets
- Support fast recovery for common incidents
- Keep backup operations consistent across primary and DR environments

This design uses Oracle RMAN as the standard backup and recovery tool.

---

## Recovery Objectives

| Objective | Target |
|----------|--------|
| Recovery Point Objective (RPO) | 0 to 15 minutes (depends on failure scenario) |
| Recovery Time Objective (RTO) | 5 to 60 minutes (depends on failure scenario) |
| Backup Retention | 30 days |
| Archive Log Retention | Minimum 7 days (or until safely backed up and applied) |

---

## Backup Scope

Backups must include:

- Full database backup
- Incremental backup
- Archived redo logs
- Control file and SPFILE
- Backup metadata (RMAN repository / control file records)

For RAC:

- Backups run from one preferred node to avoid duplicate jobs
- ASM disk groups `+DATA` and `+FRA` are both considered in recovery planning

---

## Backup Architecture

```text
Primary RAC (pridb) ------------------------> Backup Storage (NFS/Object/Appliance)
      |                                                   ^
      |                                                   |
      +--> Data Guard Standby (drdb) ----(optional)------+
```

Recommended operating model:

- Primary site handles daily backups
- Standby site can be used for offloading backup workload if license/operations allow
- Backups are copied to an independent backup repository outside database servers

---

## RMAN Configuration Baseline

Run as `sysdba` on primary database:

```bash
rman target /
```

```rman
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/backup/rman/%F';
CONFIGURE DEVICE TYPE DISK PARALLELISM 4 BACKUP TYPE TO COMPRESSED BACKUPSET;
CONFIGURE CHANNEL DEVICE TYPE DISK FORMAT '/backup/rman/%d_%T_%U.bkp';
CONFIGURE ARCHIVELOG DELETION POLICY TO APPLIED ON ALL STANDBY BACKED UP 1 TIMES TO DISK;
```

Notes:

- Tune `PARALLELISM` based on storage throughput and CPU
- Keep backup destination outside ASM for isolation and easier restore in complete site failures

---

## Backup Schedule

| Frequency | Backup Type | Scope |
|----------|-------------|-------|
| Daily | Incremental Level 1 | Database + archivelogs |
| Weekly | Incremental Level 0 (Full baseline) | Database + archivelogs |
| Every 15-30 minutes | Archivelog backup | Archivelogs only |
| Every backup cycle | Controlfile/SPFILE autobackup | Metadata and recovery config |

Example schedule:

- Sunday 01:00: Level 0 backup
- Monday-Saturday 01:00: Level 1 backup
- Every 30 minutes: Archivelog backup and delete input

---

## RMAN Backup Scripts

### 1. Weekly Level 0 Backup

```rman
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP INCREMENTAL LEVEL 0 DATABASE TAG 'WEEKLY_L0';
  BACKUP ARCHIVELOG ALL TAG 'ARCH_L0' DELETE INPUT;
  DELETE NOPROMPT OBSOLETE;
}
```

### 2. Daily Level 1 Backup

```rman
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP INCREMENTAL LEVEL 1 DATABASE TAG 'DAILY_L1';
  BACKUP ARCHIVELOG ALL TAG 'ARCH_L1' DELETE INPUT;
}
```

### 3. Frequent Archivelog Backup

```rman
RUN {
  SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
  BACKUP ARCHIVELOG ALL TAG 'ARCH_FREQ' DELETE INPUT;
}
```

---

## Backup Validation and Integrity Checks

Run regularly:

```rman
CROSSCHECK BACKUP;
CROSSCHECK ARCHIVELOG ALL;
DELETE NOPROMPT EXPIRED BACKUP;
RESTORE DATABASE VALIDATE;
```

Database consistency checks:

```sql
SELECT * FROM v$database_block_corruption;
```

Validation policy:

- Daily: RMAN crosscheck
- Weekly: `RESTORE ... VALIDATE`
- Monthly: full recovery drill in non-production environment

---

## Recovery Scenarios

### Scenario 1. Accidental Datafile Loss

```rman
RUN {
  SQL 'ALTER DATABASE DATAFILE 7 OFFLINE';
  RESTORE DATAFILE 7;
  RECOVER DATAFILE 7;
  SQL 'ALTER DATABASE DATAFILE 7 ONLINE';
}
```

### Scenario 2. Complete Database Recovery on Same Site

```rman
SHUTDOWN IMMEDIATE;
STARTUP MOUNT;
RESTORE DATABASE;
RECOVER DATABASE;
ALTER DATABASE OPEN;
```

If incomplete recovery is required:

```rman
RUN {
  SET UNTIL TIME "TO_DATE('2026-03-06 10:30:00','YYYY-MM-DD HH24:MI:SS')";
  RESTORE DATABASE;
  RECOVER DATABASE;
}
ALTER DATABASE OPEN RESETLOGS;
```

### Scenario 3. Primary Site Failure

Primary recovery path:

- Perform Data Guard failover to standby
- Redirect application DNS to standby SCAN
- Rebuild failed site later as new standby

Broker command:

```bash
dgmgrl sys@drdb_sync "failover to drdb"
```

---

## Restore Priority and Decision Matrix

| Incident | Primary Method | Expected RTO |
|----------|----------------|--------------|
| Single datafile corruption/loss | RMAN restore datafile | 5-20 minutes |
| Lost redo/archivelog on primary | Recover from backup + standby shipping | 15-45 minutes |
| Full server/node failure | RAC service relocation + restore if needed | 5-30 minutes |
| Datacenter outage | Data Guard failover | 5-15 minutes |

---

## Operational Best Practices

- Keep RMAN scripts in version control
- Encrypt backups if offsite transfer is enabled
- Test restore on a separate recovery host regularly
- Monitor FRA usage to prevent archive log blockage
- Ensure backup windows do not overlap peak business load
- Keep at least one offline/offsite copy for ransomware resilience

---

## Monitoring and Alerting for Backup

Track these metrics:

- Last successful backup timestamp
- Backup job duration and throughput
- Archivelog generation rate
- FRA utilization percentage
- Apply lag on standby (for deletion policy safety)

Minimum alerts:

- No successful backup in last 24h
- FRA usage > 80%
- RMAN job failed
- Archivelog backup lag > 30 minutes

---

## Example Automation with Cron

```bash
# Weekly Level 0 - Sunday 01:00 (with deep restore validation)
0 1 * * 0 RUN_RESTORE_VALIDATE=true /u01/app/oracle/scripts/rman_backup_validate.sh L0 >> /u01/app/oracle/log/rman_l0.log 2>&1

# Daily Level 1 - Monday to Saturday 01:00
0 1 * * 1-6 RUN_RESTORE_VALIDATE=false /u01/app/oracle/scripts/rman_backup_validate.sh L1 >> /u01/app/oracle/log/rman_l1.log 2>&1

# Archivelog backup every 15 minutes
*/15 * * * * RUN_RESTORE_VALIDATE=false /u01/app/oracle/scripts/rman_backup_validate.sh ARCH >> /u01/app/oracle/log/rman_arch.log 2>&1
```

Recommended backup validation automation:

- Every 15 minutes: monitor backup freshness and alerting signals
- Daily: RMAN `CROSSCHECK` + expired cleanup (included in script)
- Weekly: `RESTORE DATABASE VALIDATE` (`RUN_RESTORE_VALIDATE=true`)
- Monthly: full restore drill in non-production

---

## Summary

This backup and recovery strategy combines RMAN backup discipline with Data Guard disaster recovery to provide resilient protection for Oracle production workloads.

Key characteristics:

- 30-day retention with compressed backupsets
- Daily incremental and frequent archivelog backups
- Broker-driven DR failover for site-level incidents
- Routine backup validation and recovery drills

This approach provides predictable recovery operations and supports production-grade availability targets.

---

## Next Steps

See:

```text
08-monitoring-and-observability.md
```
