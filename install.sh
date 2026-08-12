#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_CATALOG=1
INSTALL_TEMPLATE1=0
INSTALL_ALL=0
DATABASES=()

usage() {
  cat <<'USAGE'
Usage:
  ./install.sh [options]

Defaults:
  Installs ddl_original in database "postgres" and applies the pg_catalog patch.

Options:
  --db NAME          Install in one database. Can be repeated.
  --all             Install in all connectable non-template databases.
  --template1       Also install the extension in template1 for future databases.
  --no-patch        Do not patch pg_catalog.pg_get_functiondef/arguments.
  --patch           Apply pg_catalog patch. This is the default.
  --help            Show this help.

Examples:
  ./install.sh
  ./install.sh --db visao --db vianopolis
  ./install.sh --all
  ./install.sh --all --template1
  ./install.sh --db postgres --no-patch
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

psql_scalar() {
  local db="$1"
  local sql="$2"
  psql -d "$db" -Atqc "$sql"
}

install_extension_files() {
  local sharedir
  local extdir

  sharedir="$(pg_config --sharedir)"
  extdir="${sharedir}/extension"

  if [[ -f "${extdir}/ddl_original.control" ]]; then
    echo "Extension files already installed in ${extdir}"
    return
  fi

  echo "Installing extension files in ${extdir}"

  if [[ -w "${extdir}" ]]; then
    make -C "$SCRIPT_DIR" install
  else
    sudo make -C "$SCRIPT_DIR" install
  fi
}

load_database_list() {
  if [[ "$INSTALL_ALL" -eq 1 ]]; then
    mapfile -t DATABASES < <(
      psql -d postgres -Atqc \
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
      psql -d "$db" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION ddl_original FROM unpackaged;"
    else
      psql -d "$db" -v ON_ERROR_STOP=1 -c "CREATE EXTENSION ddl_original;"
    fi
  fi

  if [[ "$PATCH_CATALOG" -eq 1 ]]; then
    echo "  Applying pg_catalog patch for pgAdmin/DBeaver"
    psql -d "$db" -v ON_ERROR_STOP=1 -f "${SCRIPT_DIR}/scripts/install_pg_catalog_patch.sql"
  else
    echo "  Skipping pg_catalog patch"
  fi
}

main() {
  require_command psql
  require_command pg_config
  require_command make

  install_extension_files
  load_database_list

  for db in "${DATABASES[@]}"; do
    install_in_database "$db"
  done

  echo "ddl_original installation finished"
}

main "$@"
