#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./rman_backup_validate.sh L0
#   ./rman_backup_validate.sh L1
#   ./rman_backup_validate.sh ARCH
#
# Required env:
#   ORACLE_HOME, ORACLE_SID
# Optional env:
#   BACKUP_DIR (default: /backup/rman)
#   LOG_DIR    (default: /u01/app/oracle/log)

BACKUP_TYPE="${1:-L1}"
BACKUP_DIR="${BACKUP_DIR:-/backup/rman}"
LOG_DIR="${LOG_DIR:-/u01/app/oracle/log}"
TIMESTAMP="$(date +%F_%H%M%S)"
LOG_FILE="${LOG_DIR}/rman_${BACKUP_TYPE,,}_${TIMESTAMP}.log"

mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"
export PATH="${ORACLE_HOME}/bin:${PATH}"

case "${BACKUP_TYPE}" in
  L0)
    RMAN_BLOCK="
      SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
      BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 0 DATABASE TAG 'WEEKLY_L0';
      BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL TAG 'ARCH_L0' DELETE INPUT;
    "
    ;;
  L1)
    RMAN_BLOCK="
      SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
      BACKUP AS COMPRESSED BACKUPSET INCREMENTAL LEVEL 1 DATABASE TAG 'DAILY_L1';
      BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL TAG 'ARCH_L1' DELETE INPUT;
    "
    ;;
  ARCH)
    RMAN_BLOCK="
      SQL 'ALTER SYSTEM ARCHIVE LOG CURRENT';
      BACKUP AS COMPRESSED BACKUPSET ARCHIVELOG ALL TAG 'ARCH_FREQ' DELETE INPUT;
    "
    ;;
  *)
    echo "Invalid backup type: ${BACKUP_TYPE}. Use L0 | L1 | ARCH." >&2
    exit 2
    ;;
esac

rman target / log="${LOG_FILE}" <<EOF
RUN {
  CROSSCHECK BACKUP;
  CROSSCHECK ARCHIVELOG ALL;
  DELETE NOPROMPT EXPIRED BACKUP;
  ${RMAN_BLOCK}
  BACKUP CURRENT CONTROLFILE TAG 'CTRLFILE';
  RESTORE DATABASE VALIDATE;
  DELETE NOPROMPT OBSOLETE;
}
EXIT;
EOF

echo "RMAN ${BACKUP_TYPE} completed. Log: ${LOG_FILE}"
