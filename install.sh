#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_CATALOG=0
INSTALL_TEMPLATE1=0
INSTALL_ALL=0
DATABASES=()
PSQL_CMD=(psql)
SYSTEM_DB_USER=postgres
PG_CONFIG_CMD=${PG_CONFIG:-pg_config}

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [options]

Defaults:
  Installs or updates ddl_original in database "postgres".
  If the current Linux user cannot connect to PostgreSQL, the installer falls
  back to "sudo -u postgres psql".

Options:
  --db NAME          Install in one database. Can be repeated.
  --all             Install in all connectable non-template databases.
  --template1       Also install the extension in template1 for future databases.
  --system-db-user USER
                     Linux user used for peer-auth psql fallback.
                     Default: postgres.
  --patch           Re-run the standalone pg_catalog repair script after install.
                     CREATE EXTENSION already applies this patch by default.
  --no-patch        Do not run the standalone repair script. This is the default.
  --help            Show this help.

Examples:
  ./install.sh
  ./install.sh --db visao --db vianopolis
  ./install.sh --all
  ./install.sh --all --template1
  ./install.sh --db postgres --no-patch
  ./install.sh --system-db-user postgres --all
  PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config ./install.sh
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)
      if [[ $# -lt 2 ]]; then
        echo "Missing database name after --db" >&2
        exit 2
      fi
      DATABASES+=("$2")
      shift 2
      ;;
    --all)
      INSTALL_ALL=1
      shift
      ;;
    --template1)
      INSTALL_TEMPLATE1=1
      shift
      ;;
    --system-db-user)
      if [[ $# -lt 2 ]]; then
        echo "Missing Linux user after --system-db-user" >&2
        exit 2
      fi
      SYSTEM_DB_USER="$2"
      shift 2
      ;;
    --patch)
      PATCH_CATALOG=1
      shift
      ;;
    --no-patch)
      PATCH_CATALOG=0
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

detect_psql_command() {
  if psql -d postgres -Atqc "select 1" >/dev/null 2>&1; then
    PSQL_CMD=(psql)
    echo "Using psql as current user"
    return
  fi

  if command -v sudo >/dev/null 2>&1 && sudo -u "$SYSTEM_DB_USER" psql -d postgres -Atqc "select 1" >/dev/null; then
    PSQL_CMD=(sudo -u "$SYSTEM_DB_USER" psql)
    echo "Using sudo -u ${SYSTEM_DB_USER} psql"
    return
  fi

  if command -v runuser >/dev/null 2>&1 && runuser -u "$SYSTEM_DB_USER" -- psql -d postgres -Atqc "select 1" >/dev/null; then
    PSQL_CMD=(runuser -u "$SYSTEM_DB_USER" -- psql)
    echo "Using runuser -u ${SYSTEM_DB_USER} -- psql"
    return
  fi

  cat >&2 <<'ERROR'
Could not connect to PostgreSQL.

Tried:
  psql -d postgres
  sudo -u <system-db-user> psql -d postgres
  runuser -u <system-db-user> -- psql -d postgres

Run this installer as a Linux user with permission to install PostgreSQL
extension files and to execute psql as the PostgreSQL system user.
ERROR
  exit 1
}

run_psql() {
  local db="$1"
  shift
  "${PSQL_CMD[@]}" -d "$db" "$@"
}

run_psql_file() {
  local db="$1"
  local file="$2"
  "${PSQL_CMD[@]}" -d "$db" -v ON_ERROR_STOP=1 < "$file"
}

detect_pg_config_command() {
  local server_version_num
  local server_major
  local candidate

  server_version_num="$(psql_scalar postgres "select current_setting('server_version_num')")"
  server_major="$((server_version_num / 10000))"
  candidate="/usr/lib/postgresql/${server_major}/bin/pg_config"

  if [[ -n "${PG_CONFIG:-}" ]]; then
    PG_CONFIG_CMD="$PG_CONFIG"
  elif [[ -x "$candidate" ]]; then
    PG_CONFIG_CMD="$candidate"
  else
    PG_CONFIG_CMD="pg_config"
  fi

  if ! command -v "$PG_CONFIG_CMD" >/dev/null 2>&1; then
    echo "Could not find pg_config: ${PG_CONFIG_CMD}" >&2
    echo "Install postgresql-server-dev-${server_major} or pass PG_CONFIG=/path/to/pg_config." >&2
    exit 1
  fi

  echo "Using PG_CONFIG=${PG_CONFIG_CMD}"
  echo "Target PostgreSQL server major version: ${server_major}"
}

psql_scalar() {
  local db="$1"
  local sql="$2"
  run_psql "$db" -Atqc "$sql"
}

install_extension_files() {
  local sharedir
  local extdir

  sharedir="$("$PG_CONFIG_CMD" --sharedir)"
  extdir="${sharedir}/extension"

  echo "Installing extension files in ${extdir}"

  if [[ -w "${extdir}" ]]; then
    make -C "$SCRIPT_DIR" PG_CONFIG="$PG_CONFIG_CMD" install
  else
    sudo make -C "$SCRIPT_DIR" PG_CONFIG="$PG_CONFIG_CMD" install
  fi
}

load_database_list() {
  if [[ "$INSTALL_ALL" -eq 1 ]]; then
    mapfile -t DATABASES < <(
      run_psql postgres -Atqc \
        "select datname from pg_database where datallowconn and not datistemplate order by datname"
    )
  fi

  if [[ "${#DATABASES[@]}" -eq 0 ]]; then
    DATABASES=("postgres")
  fi

  if [[ "$INSTALL_TEMPLATE1" -eq 1 ]]; then
    DATABASES+=("template1")
  fi
}

install_in_database() {
  local db="$1"
  local ext_installed
  local manual_objects

  echo "Installing ddl_original in database ${db}"

  ext_installed="$(psql_scalar "$db" "select exists (select 1 from pg_extension where extname = 'ddl_original')")"

  if [[ "$ext_installed" == "t" ]]; then
    echo "  Extension already installed"
    run_psql "$db" -v ON_ERROR_STOP=1 -c "ALTER EXTENSION ddl_original UPDATE;"
  else
    manual_objects="$(psql_scalar "$db" "
      select exists (
        select 1 from pg_namespace where nspname = 'ddl_original'
      ) or exists (
        select 1 from pg_event_trigger where evtname like 'ddl_original_%'
      )
    ")"

    if [[ "$manual_objects" == "t" ]]; then
      echo "  Existing manual install found; adopting with FROM unpackaged"
      run_psql "$db" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION ddl_original FROM unpackaged;"
    else
      run_psql "$db" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION ddl_original;"
    fi
  fi

  if [[ "$PATCH_CATALOG" -eq 1 ]]; then
    echo "  Re-running pg_catalog repair script"
    run_psql_file "$db" "${SCRIPT_DIR}/scripts/install_pg_catalog_patch.sql"
  else
    echo "  pg_catalog patch is managed by the extension"
  fi
}

main() {
  require_command psql
  require_command make

  detect_psql_command
  detect_pg_config_command
  install_extension_files
  load_database_list

  for db in "${DATABASES[@]}"; do
    install_in_database "$db"
  done

  echo "ddl_original installation finished"
}

main "$@"
