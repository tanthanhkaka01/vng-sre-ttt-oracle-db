# 00 - Technical Assignment Deliverables (A/B/C/D + Implementation + Post-mortem)

## Scope

Database engine selected: **Oracle Database 21c** with **Oracle RAC + Oracle Data Guard**.

Primary objective for production:

- Absolute data integrity
- High availability (HA)
- Clear and automatable operations

Architecture diagram: `images/architecture.png`

---

## A. High Availability & Fault-Tolerance

### A1. Architecture model and rationale

Model used:

- Intra-DC HA: Oracle RAC (active-active instances, shared storage ASM)
- Cross-DC DR: Oracle Data Guard Physical Standby (SYNC mode)

Why this model fits large production:

- RAC removes single-node failure risk and supports scale-out read/write capacity
- Data Guard provides site-level resilience and controlled role transition
- Proven Oracle-native stack with mature operational tooling (`srvctl`, `crsctl`, `dgmgrl`, RMAN)

### A2. Auto-failover, health-check, split-brain prevention

Failure detection:

- Cluster layer: Clusterware monitors node, VIP, listener, CRS resources
- Database layer: instance/session/redo and service health probes
- DR layer: broker checks transport lag, apply lag, and standby readiness

Automatic/semi-automatic failover flow:

1. Detect primary service outage from monitoring + broker signals
2. Confirm old primary isolation (no write capability)
3. Promote standby via Data Guard Broker failover
4. Expose writer service on new primary
5. Redirect application endpoint and validate transactions

Split-brain prevention:

- RAC voting disk + quorum-based node eviction
- Data Guard single-primary role control via broker
- Operational guardrail: failover only after confirming primary isolation

### A3. Service discovery for active writer

Client connectivity pattern:

- Applications connect via logical endpoint `db.company.local`
- DNS points to site SCAN listener (`scan-db.company.local` or DR SCAN)
- Keep DNS TTL at 30 seconds for quick reconnection

Writer identification after failover:

- Writer service is attached only to current primary role
- After role transition, service starts on new primary and old site service is disabled

---

## B. Backup & Disaster Recovery Strategy

### B1. Point-in-time recovery design

Backup design (RMAN):

- Weekly incremental Level 0
- Daily incremental Level 1
- Archivelog backup every 15-30 minutes
- Controlfile/SPFILE autobackup

PITR capability:

- Use RMAN `SET UNTIL TIME` + `RESTORE` + `RECOVER` + `OPEN RESETLOGS`
- Supports recovery to specific incident timestamp

### B2. Trade-off analysis

Physical vs Logical backup:

- Physical (RMAN): fastest full restore, block-level efficiency, best for large DB
- Logical (Data Pump/export): object-level recovery, portability, but slower for large full restore

Online vs Offline backup:

- Online: no business downtime, operationally preferred for production
- Offline: simpler consistency model but requires outage window

Design choice:

- Primary strategy: RMAN online physical backups + archived redo
- Complementary strategy: periodic logical exports for selected schemas/tables

### B3. Automated backup validation

Validation controls:

- Daily `CROSSCHECK` and expired cleanup
- Weekly `RESTORE DATABASE VALIDATE`
- Monthly full restore drill in non-production

Implementation artifact:

- `scripts/rman_backup_validate.sh`

---

## C. Monitoring & Observability

### C1. Critical metrics (minimum dashboard set)

At least 5 core metrics:

1. Database availability (instance/service up/down)
2. Connection latency p95
3. Query latency p95/p99 (critical workload)
4. Data Guard apply lag / transport lag
5. Backup freshness (time since last successful backup)
6. FRA and ASM diskgroup utilization
7. ORA error rate and blocked sessions

### C2. Alerting thresholds (Warning vs Critical)

Warning examples:

- CPU > 85% sustained 15 minutes
- Tablespace/FRA > 80-85%
- Data Guard lag > 60 seconds

Critical examples:

- Any required DB service down
- Broker/apply stopped or configuration error
- Data Guard lag > 300 seconds
- Backup failed or no successful backup in 24h
- FRA > 90% or ASM free < 15%

Implementation artifact:

- `scripts/dataguard_health_check.sh` (exit code: 0 OK, 1 WARNING, 2 CRITICAL)

### C3. Slow query and error logging strategy

Logging approach:

- Centralize alert log, listener log, CRS/ASM logs, RMAN logs, OS logs
- Parse and index ORA errors and long-running SQL events
- Keep 30-90 days hot searchable logs, 6-12 months archive retention

Operational use:

- Correlate logs with metrics by host, DB unique name, and timestamp
- Feed top SQL and repeated error patterns into performance tuning backlog

---

## D. Quality Commitments (SLO/SLA, RTO/RPO)

Service-level targets:

- Availability SLO: **99.99%**
- Connection latency p95: **< 500 ms** (in normal operating window)
- Query latency p95: baseline per critical transaction class

Recovery objectives by scenario:

| Scenario | RTO | RPO |
|---|---:|---:|
| Node/instance failure in RAC | 1-5 minutes | 0 |
| Primary site failure with SYNC standby healthy | 5-15 minutes | 0 |
| Logical corruption / operator error (PITR path) | 15-60 minutes | up to last good archivelog backup window |

Note:

- `RPO = 0` is achievable for site-failure path when SYNC transport is healthy.
- PITR scenarios have non-zero practical RPO depending on detection and restore point.

---

## Implementation Strategy (From Zero)

Step summary:

1. Prepare infrastructure baseline (compute/network/storage/DNS)
2. Install and configure Oracle Grid Infrastructure + ASM
3. Deploy RAC database at primary site
4. Build standby RAC and configure Data Guard broker
5. Configure RMAN policies and backup schedules
6. Configure observability stack (metrics, alerts, logs, dashboards)
7. Implement automation scripts/playbooks and approval gates
8. Execute switchover/failover drill and record measured RTO/RPO

Implementation artifacts in repository:

- RMAN backup/validate script: `scripts/rman_backup_validate.sh`
- Data Guard health-check script: `scripts/dataguard_health_check.sh`
- Ansible sample playbook: `scripts/ansible/dataguard_healthcheck.yml`

Detailed build documents:

- `docs/01` to `docs/10`

---

## Post-mortem Scenario (DB Outage)

### Incident summary

- Incident: primary datacenter DB service outage
- Impact: application write path unavailable
- Trigger: primary RAC cluster unavailable due to infrastructure failure

### SRE response steps

1. Declare incident and assign Incident Commander
2. Confirm blast radius and business impact
3. Validate old primary isolation to prevent split-brain
4. Check standby readiness (broker health, lag, cluster status)
5. Execute Data Guard failover to DR primary
6. Redirect `db.company.local` to DR SCAN endpoint
7. Run smoke tests for login, read/write, critical transactions
8. Monitor stabilization (error rate, latency, lag, backup jobs)
9. Publish recovery confirmation and timeline
10. Reinstate/rebuild old primary as standby after root cause fix

### Example timeline (UTC+7)

- 10:02: Alert fired (DB service down, RAC primary unreachable)
- 10:05: Incident declared (SEV-1)
- 10:08: Primary isolation confirmed
- 10:11: Failover executed on DR
- 10:13: DNS updated to DR SCAN
- 10:16: Application smoke tests passed
- 10:20: Service declared restored

Measured result:

- Actual RTO: 18 minutes
- Observed RPO: 0 (SYNC healthy before outage)

### Root cause and corrective actions template

Root cause categories to fill:

- Infra/network
- Cluster configuration
- Capacity/resource exhaustion
- Change-related regression

Corrective actions:

1. Add pre-failover automated isolation checks
2. Tighten alert correlation for earlier detection
3. Enforce quarterly DR drill with evidence
4. Review failover runbook and remove manual bottlenecks

---

## Cross-reference

- Data Guard: `docs/06-data-guard-configuration.md`
- Backup: `docs/07-backup-and-recovery-strategy.md`
- Observability: `docs/08-monitoring-and-observability.md`
- DR runbook: `docs/09-failover-and-disaster-recovery.md`
- Automation: `docs/10-automation-strategy.md`
