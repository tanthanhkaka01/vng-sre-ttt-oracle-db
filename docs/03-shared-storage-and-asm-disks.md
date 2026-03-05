# 03 - Shared Storage and ASM Disk Configuration

## Overview

Oracle Real Application Clusters (RAC) requires shared storage so that all cluster nodes can access the same database files simultaneously.

In this architecture, shared storage is provided through enterprise storage (SAN / vSAN / iSCSI) and managed by **Oracle Automatic Storage Management (ASM)**.

ASM simplifies storage management by providing:

- Automatic file striping
- Load balancing across disks
- Simplified storage administration
- Integrated redundancy management

The environment uses **three ASM disk groups** to organize database storage.

---

## Storage Architecture

Each datacenter has its own independent storage system.

- **Primary Datacenter** uses its own SAN storage
- **Disaster Recovery Datacenter** uses a separate SAN storage system

This separation ensures that a storage failure in the primary datacenter does not affect the DR environment.

```text
                 Primary Datacenter
                 -------------------
                  SAN Storage
                       |
          --------------------------------
          |                              |
      RAC Node 1                     RAC Node 2


                 DR Datacenter
                 -------------------
                  SAN Storage
                       |
          --------------------------------
          |                              |
      RAC Node 3                     RAC Node 4
```

Database synchronization between the two datacenters is handled by Oracle Data Guard, not by shared storage replication.

---

## ASM Disk Groups Design

Three ASM disk groups are used in the system.

| Disk Group | Purpose                                        |
| ---------- | ---------------------------------------------- |
| +GRID      | Oracle Clusterware files (OCR and Voting Disk) |
| +DATA      | Database datafiles and tempfiles               |
| +RECO      | Redo logs, archive logs, and RMAN backups      |

Separating storage into these disk groups improves performance, manageability, and recovery operations.

---

## ASM Disk Layout

Example disk layout in ASM:

```text
+GRID
  OCR
  Voting Disk

+DATA
  Database Datafiles
  Tempfiles
  Controlfiles

+RECO
  Online Redo Logs
  Archive Logs
  RMAN Backups
  Flashback Logs
```

The +RECO disk group acts as the Flash Recovery Area (FRA).

---

## Shared Disk Provisioning

Shared disks are provisioned from the SAN storage as LUNs and presented to all RAC nodes within the same datacenter.

Example LUN allocation:

| LUN Name | Size   | Usage                |
| -------- | ------ | -------------------- |
| LUN_DATA | 10 TB  | ASM +DATA disk group |
| LUN_FRA  | 6 TB   | ASM +RECO disk group |
| LUN_OCR1 | 200 GB | ASM +GRID disk group |
| LUN_OCR2 | 200 GB | ASM +GRID disk group |
| LUN_OCR3 | 200 GB | ASM +GRID disk group |

Multiple disks are used in the +GRID disk group to ensure cluster metadata redundancy.

---

## ASM Redundancy

ASM redundancy mode depends on the storage system.

Recommended configuration for enterprise storage environments:

| Disk Group | Redundancy |
| ---------- | ---------- |
| +GRID      | External   |
| +DATA      | External   |
| +RECO      | External   |

External redundancy is used because redundancy is already provided by the SAN storage (RAID configuration).

---

## ASM Disk Discovery

ASM discovers shared disks using the following disk string configuration:

```text
ASM_DISKSTRING = '/dev/oracleasm/disks/*'
```

All RAC nodes must detect the same disks with identical names.

Example ASM disk labels:

```text
DATA01
DATA02
RECO01
RECO02
GRID01
GRID02
GRID03
```

Consistent disk labeling ensures that ASM can correctly identify shared storage across all nodes.

---

## Storage Performance Considerations

To ensure optimal performance in production environments, the storage system must provide:

- Low latency
- High IOPS
- High throughput
- Redundant storage paths

Best practices include:

- Use multiple disks in each ASM disk group
- Enable multipath I/O
- Separate data and recovery workloads
- Monitor disk performance regularly

## Summary

The shared storage architecture provides a scalable and resilient storage foundation for the Oracle RAC environment.

Key characteristics of the design:

- Shared storage provided through enterprise SAN
- Independent storage systems for Primary and DR datacenters
- Three ASM disk groups for organized storage management
- Integration with Oracle Data Guard for disaster recovery

This architecture ensures high availability, data protection, and efficient storage management for production workloads.

---

## Next Steps

See:

```text
04-oracle-grid-infrastructure-installation.md
```