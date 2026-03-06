#!/usr/bin/env bash
set -euo pipefail

# Checks Data Guard health from a DB host.
#
# Required env:
#   ORACLE_HOME, ORACLE_SID
# Optional env:
#   DG_CONNECT (default: sys@pridb_sync)
#   WARN_LAG_SECONDS (default: 60)
#   CRIT_LAG_SECONDS (default: 300)

DG_CONNECT="${DG_CONNECT:-sys@pridb_sync}"
WARN_LAG_SECONDS="${WARN_LAG_SECONDS:-60}"
CRIT_LAG_SECONDS="${CRIT_LAG_SECONDS:-300}"
export PATH="${ORACLE_HOME}/bin:${PATH}"

to_seconds() {
  # Input format expected: +DD HH:MI:SS
  local in="$1"
  if [[ -z "${in}" ]] || [[ "${in^^}" == "UNKNOWN" ]]; then
    echo 999999
    return
  fi

  local d h m s
  d="$(echo "${in}" | awk '{print $1}' | sed 's/+//')"
  h="$(echo "${in}" | awk '{print $2}' | cut -d: -f1)"
  m="$(echo "${in}" | awk '{print $2}' | cut -d: -f2)"
  s="$(echo "${in}" | awk '{print $2}' | cut -d: -f3)"
  echo $((10#${d} * 86400 + 10#${h} * 3600 + 10#${m} * 60 + 10#${s}))
}

DB_INFO="$(
sqlplus -s / as sysdba <<'SQL'
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT database_role || '|' || open_mode FROM v$database;
EXIT;
SQL
)"

ROLE="$(echo "${DB_INFO}" | cut -d'|' -f1 | xargs)"
OPEN_MODE="$(echo "${DB_INFO}" | cut -d'|' -f2 | xargs)"

DG_STATS="$(
sqlplus -s / as sysdba <<'SQL'
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT
  MAX(CASE WHEN name='transport lag' THEN value END) || '|' ||
  MAX(CASE WHEN name='apply lag' THEN value END)
FROM v$dataguard_stats;
EXIT;
SQL
)"

TRANSPORT_LAG_RAW="$(echo "${DG_STATS}" | cut -d'|' -f1 | xargs)"
APPLY_LAG_RAW="$(echo "${DG_STATS}" | cut -d'|' -f2 | xargs)"
TRANSPORT_LAG_SEC="$(to_seconds "${TRANSPORT_LAG_RAW}")"
APPLY_LAG_SEC="$(to_seconds "${APPLY_LAG_RAW}")"

BROKER_STATUS="$(dgmgrl -silent "${DG_CONNECT}" "show configuration" | tr -d '\r')"

STATUS="OK"
EXIT_CODE=0
REASON="Healthy"

if echo "${BROKER_STATUS}" | grep -Eq "ORA-|ERROR|WARNING"; then
  STATUS="CRITICAL"
  EXIT_CODE=2
  REASON="Broker reports error/warning"
elif [[ "${APPLY_LAG_SEC}" -ge "${CRIT_LAG_SECONDS}" ]] || [[ "${TRANSPORT_LAG_SEC}" -ge "${CRIT_LAG_SECONDS}" ]]; then
  STATUS="CRITICAL"
  EXIT_CODE=2
  REASON="Lag exceeds critical threshold"
elif [[ "${APPLY_LAG_SEC}" -ge "${WARN_LAG_SECONDS}" ]] || [[ "${TRANSPORT_LAG_SEC}" -ge "${WARN_LAG_SECONDS}" ]]; then
  STATUS="WARNING"
  EXIT_CODE=1
  REASON="Lag exceeds warning threshold"
fi

echo "status=${STATUS}"
echo "reason=${REASON}"
echo "database_role=${ROLE}"
echo "open_mode=${OPEN_MODE}"
echo "transport_lag_raw=${TRANSPORT_LAG_RAW}"
echo "apply_lag_raw=${APPLY_LAG_RAW}"
echo "transport_lag_seconds=${TRANSPORT_LAG_SEC}"
echo "apply_lag_seconds=${APPLY_LAG_SEC}"

exit "${EXIT_CODE}"
