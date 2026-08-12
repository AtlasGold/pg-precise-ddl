# ddl_original

`ddl_original` preserves the original SQL used to create PostgreSQL functions and procedures. This keeps typmods such as `varchar(25)` and `numeric(10,2)` available for tools that inspect routine definitions.

The extension has two layers:

- `CREATE EXTENSION ddl_original`: installs the capture table, event triggers, and helper functions.
- `scripts/install_pg_catalog_patch.sql`: optional patch that makes `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)` read the preserved source first. This is the layer pgAdmin and DBeaver normally notice automatically.

## One-Step Install

Default: install in `postgres` and apply the pgAdmin/DBeaver patch.

```bash
cd postgres_extensions/ddl_original
./install.sh
```

Specific database:

```bash
./install.sh --db visao
```

All databases:

```bash
./install.sh --all
```

All current databases and `template1` for future databases:

```bash
./install.sh --all --template1
```

Without the pgAdmin/DBeaver patch:

```bash
./install.sh --db visao --no-patch
```

The installer detects an existing manual `ddl_original` setup and automatically runs `CREATE EXTENSION ddl_original FROM unpackaged`.

## Manual Install

### Install Extension Files

```bash
cd postgres_extensions/ddl_original
sudo make install
```

### Install In One Database

```sql
CREATE EXTENSION ddl_original;
```

Optional pgAdmin/DBeaver integration:

```bash
psql -d my_database -f scripts/install_pg_catalog_patch.sql
```

### Adopt Existing Manual Install

If the database already has the manual `ddl_original` schema/event triggers, install the extension files and then run:

```sql
CREATE EXTENSION ddl_original FROM unpackaged;
```

That path keeps the existing captured rows and brings the objects under extension management.

### Install In All Databases

Core extension only:

```bash
./scripts/install_all_databases.sh
```

Core extension plus pgAdmin/DBeaver integration:

```bash
./scripts/install_all_databases.sh --patch-catalog
```

## New Databases

To make new databases inherit the extension:

```sql
\c template1
CREATE EXTENSION ddl_original;
```

Apply the `pg_catalog` patch separately in each real database where automatic tool integration is required.

## Remove pg_catalog Patch

```bash
psql -d my_database -f scripts/uninstall_pg_catalog_patch.sql
```

Then, if desired:

```sql
DROP EXTENSION ddl_original;
```

## Compatibility Notes

The extension itself is pure SQL/PLpgSQL and targets PostgreSQL 14 or newer. The underlying event trigger APIs are stable across current PostgreSQL releases, but the optional `pg_catalog` patch intentionally checks for the native internal functions before renaming them.

The capture uses `current_query()`. For best results, execute one `CREATE FUNCTION` or `CREATE PROCEDURE` statement at a time. If a client sends several statements in one protocol query, PostgreSQL exposes the whole batch as `current_query()`, and that whole text can be captured.
