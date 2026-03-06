# 08 - Monitoring and Observability

## Overview

This section defines the monitoring and observability strategy for the Oracle RAC + Data Guard platform.

The goals are:

- Detect failures early across database, cluster, storage, and replication layers
- Reduce incident response time with actionable alerts
- Track service health against SLO targets
- Provide operational visibility for capacity and performance planning

Observability in this architecture combines:

- Infrastructure monitoring
- Database monitoring
- Data Guard and backup monitoring
- Centralized logging and alerting

---

## Monitoring Scope

The platform must monitor the following layers:

| Layer | Scope |
|------|-------|
| Host/OS | CPU, memory, disk, network, process health |
| Oracle RAC / Clusterware | Node membership, VIP/SCAN listener, CRS resources |
| ASM Storage | Disk group usage, rebalance status, disk failures |
| Oracle Database | Availability, sessions, wait events, performance metrics |
| Data Guard | Transport lag, apply lag, role status, broker health |
| Backup/Recovery | RMAN job success, FRA usage, backup age |
| Application Connectivity | DB endpoint reachability and latency |

---

## Observability Architecture

```text
RAC/DB Nodes + DR Nodes
       |
   Exporters / Agents
       |
Metrics Collector (Prometheus / OEM / Zabbix)
       |
Alert Engine (Alertmanager / OEM Rules)
       |
Notification Channels (Email, Slack, PagerDuty)
       |
Ops/SRE On-call
```

For logs:

```text
DB Alert Logs / Listener Logs / OS Logs
       |
 Log Shipper (Fluent Bit / Filebeat)
       |
 Central Log Store (ELK / OpenSearch / Splunk)
       |
 Dashboards + Search + Incident Investigation
```

---

## Service Level Indicators (SLIs)

Track core SLIs for database service quality:

| SLI | Description |
|----|-------------|
| Availability | Percentage of successful DB connection attempts |
| Connection Latency | Time to establish DB session |
| Query Latency p95/p99 | Response time for critical queries |
| Error Rate | Failed DB operations over total operations |
| Replication Health | Data Guard transport/apply lag |

Suggested SLO targets:

- Availability: 99.99%
- Connection latency p95: < 500 ms
- Query latency p95: based on application workload baseline
- Data Guard apply lag: < 60 seconds (steady state)

---

## Key Metrics by Component

### 1. Host and OS Metrics

- CPU utilization (`user`, `system`, `iowait`)
- Memory utilization and swap usage
- Disk I/O latency and throughput
- Network packet drops and interface saturation
- Filesystem capacity and inode usage

### 2. Oracle RAC / Clusterware Metrics

- CRS resource state (`ONLINE/OFFLINE`)
- Node eviction events
- VIP failover events
- SCAN listener status
- Interconnect health and latency

Useful command checks:

```bash
crsctl check cluster -all
crsctl stat res -t
srvctl status scan_listener
srvctl status database -d pridb
```

### 3. ASM Metrics

- Disk group free/used percentage (`+DATA`, `+FRA`, `+OCR`)
- ASM disk offline status
- Rebalance operations and duration
- I/O performance per disk group

SQL checks:

```sql
SELECT name, total_mb, free_mb, ROUND((1 - free_mb/total_mb)*100,2) AS used_pct
FROM v$asm_diskgroup;
```

### 4. Oracle Database Metrics

- Instance up/down status
- Active sessions and blocked sessions
- Top wait events
- Redo generation rate
- Tablespace usage
- FRA utilization
- Long-running queries

SQL checks:

```sql
SELECT instance_name, status FROM v$instance;
SELECT tablespace_name, used_percent FROM dba_tablespace_usage_metrics;
SELECT name, space_limit, space_used FROM v$recovery_file_dest;
```

### 5. Data Guard Metrics

- Primary/standby role state
- Transport lag
- Apply lag
- Standby apply rate
- Broker health status

SQL checks:

```sql
SELECT name, value, unit FROM v$dataguard_stats;
SELECT database_role, open_mode, switchover_status FROM v$database;
```

Broker check:

```bash
dgmgrl sys@pridb_sync "show configuration"
```

### 6. Backup Metrics

- Last successful backup time
- Backup duration and throughput
- Backup failure count
- Archivelog backup lag
- Number of days since successful restore test

---

## Alerting Strategy

Alerts should be severity-based:

| Severity | Purpose | Example |
|---------|---------|---------|
| Critical | Immediate outage or high risk | Database down, Data Guard broken |
| Warning | Degradation or capacity risk | FRA > 80%, apply lag increasing |
| Info | Operational awareness | Backup completed, switchover success |

Recommended critical alerts:

- Any RAC instance down
- CRS resource OFFLINE unexpectedly
- Data Guard apply stopped
- Data Guard lag exceeds threshold (for example > 300s)
- Backup job failed
- FRA usage > 90%
- ASM disk group free space < 15%

Recommended warning alerts:

- CPU sustained > 85% for 15 minutes
- Tablespace usage > 85%
- Listener registration issues
- Repeated ORA- errors in alert log

---

## Logging and Event Correlation

Collect and centralize:

- Oracle alert logs
- Listener logs
- CRS/Clusterware logs
- ASM logs
- RMAN logs
- OS system logs

Retention recommendation:

- Hot searchable logs: 30-90 days
- Archive logs for audit/forensics: 6-12 months

Use correlation by:

- Hostname
- DB name / DB unique name
- Instance name
- Timestamp (UTC recommended)
- Incident ID / change window

---

## Dashboards

Minimum dashboard set:

1. Executive Service Health
2. RAC Cluster Health
3. Database Performance
4. Data Guard Replication Status
5. Backup and Recovery Health
6. Capacity and Growth Trends

Each dashboard should show:

- Current status
- Historical trend (24h / 7d / 30d)
- Alert summary
- Drill-down links to logs

---

## Incident Response Integration

Monitoring should integrate with incident workflows:

- Auto-create incidents for critical alerts
- Route by service ownership (DBA/SRE/Infra)
- Attach runbook links directly in alert payload
- Track MTTA and MTTR per incident class

Runbooks to link:

- RAC node/instance recovery
- Listener and SCAN troubleshooting
- Data Guard lag/apply failure handling
- FRA cleanup and archivelog pressure
- RMAN backup failure remediation

---

## Capacity and Trend Monitoring

Track monthly growth trends for:

- Database size growth
- FRA consumption
- ASM disk group utilization
- Redo generation volume
- Backup storage growth

Capacity policy:

- Alert at 70% (planning threshold)
- Escalate at 85% (action threshold)
- Expand capacity before 90%

---

## Security and Compliance Observability

Monitor and audit:

- Failed login attempts
- Privileged account usage
- Changes to Data Guard and RMAN configuration
- Listener and network access anomalies
- Audit trail growth and retention

Protect monitoring data:

- Role-based access to dashboards and logs
- Encrypted transport for telemetry and alerts
- Immutable backup of critical audit logs

---

## Operational Best Practices

- Keep metric and alert definitions in version control
- Review alert thresholds quarterly
- Remove noisy alerts and tune false positives
- Test alert delivery channels during DR drills
- Validate dashboard accuracy after major DB changes

---

## Summary

This observability design provides end-to-end visibility across Oracle RAC, ASM, Data Guard, and backup workflows.

Key outcomes:

- Early detection of availability and replication risks
- Faster incident triage through centralized telemetry
- SLO-driven monitoring for production reliability
- Capacity visibility for proactive planning

This monitoring foundation supports stable operations and predictable disaster recovery readiness.

---

## Next Steps

See:

```text
09-failover-and-disaster-recovery.md
```
