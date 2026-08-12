# ddl_original

`ddl_original` preserves the original SQL used to create PostgreSQL functions and procedures. This keeps typmods such as `varchar(25)` and `numeric(10,2)` available for tools that inspect routine definitions.

The extension has two layers:

- `CREATE EXTENSION ddl_original`: installs the capture table, event triggers, and helper functions.
- `scripts/install_pg_catalog_patch.sql`: optional patch that makes `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)` read the preserved source first. This is the layer pgAdmin and DBeaver normally notice automatically.

## One-Step Install

Default: install in `postgres` and apply the pgAdmin/DBeaver patch.

```bash
git clone https://github.com/AtlasGold/pg-precise-ddl.git
cd pg-precise-ddl
./install.sh
```

Run the installer as a normal Linux user with `sudo` access. Do not run it after `sudo su - postgres`: the PostgreSQL system user usually cannot run `sudo make install`.

If your normal Linux user does not have a matching PostgreSQL role, the installer automatically falls back to:

```bash
sudo -u postgres psql
```

The installer still works when your home directory is private, such as `/home/user` with `750` permissions. It streams bundled SQL files into `psql` instead of making the PostgreSQL system user read files from your home directory.

If your PostgreSQL system user is not named `postgres`, pass it explicitly:

```bash
./install.sh --system-db-user pgsql
```

Specific database:

```bash
./install.sh --db test
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
cd pg-precise-ddl
sudo make install
```

### Install In One Database

```sql
CREATE EXTENSION ddl_original;
```

Optional pgAdmin/DBeaver integration:

```bash
sudo -u postgres psql -d my_database -f scripts/install_pg_catalog_patch.sql
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
