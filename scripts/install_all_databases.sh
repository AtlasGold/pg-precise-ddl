#!/usr/bin/env bash
set -euo pipefail

PATCH_CATALOG=0

if [[ "${1:-}" == "--patch-catalog" ]]; then
  PATCH_CATALOG=1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mapfile -t DATABASES < <(
  psql -d postgres -Atqc \
    "select datname from pg_database where datallowconn and not datistemplate order by datname"
)

for db in "${DATABASES[@]}"; do
  echo "Installing ddl_original in ${db}"
  psql -d "${db}" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION IF NOT EXISTS ddl_original;"

  if [[ "${PATCH_CATALOG}" -eq 1 ]]; then
    echo "Applying pg_catalog patch in ${db}"
    psql -d "${db}" -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/install_pg_catalog_patch.sql"
  fi
done
