# pg-precise-ddl

`pg-precise-ddl` packages the PostgreSQL extension `ddl_original`. It preserves the original SQL used to create PostgreSQL functions and procedures, keeping typmods such as `varchar(25)` and `numeric(10,2)` available for inspection tools.

## Standard Install

This is the normal PostgreSQL extension flow:

```bash
git clone https://github.com/AtlasGold/pg-precise-ddl.git
cd pg-precise-ddl
make
sudo make install
```

If your `psql` client and PostgreSQL server are different major versions, install with the `pg_config` from the server version. Example: client 18 connected to server 16 must install into PostgreSQL 16:

```bash
make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
sudo make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config install
```

Then, inside PostgreSQL:

```sql
CREATE EXTENSION ddl_original;
```

Example from the shell:

```bash
sudo -u postgres psql -d postgres -c "CREATE EXTENSION ddl_original;"
```

## Important Safety Notice

`CREATE EXTENSION ddl_original` intentionally patches `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)` so pgAdmin, DBeaver, and similar tools see the preserved routine source automatically.

This is not a normal low-risk extension behavior. It renames the native PostgreSQL functions to:

- `pg_catalog.pg_get_functiondef_native(oid)`
- `pg_catalog.pg_get_function_arguments_native(oid)`

Then it creates wrappers with the original names. Install and use this at your own risk, especially on production servers and before PostgreSQL major-version upgrades.

## Update Existing Install

```bash
git pull
make
sudo make install
sudo -u postgres psql -d postgres -c "ALTER EXTENSION ddl_original UPDATE;"
```

## Test

After `sudo make install`, run the regression test:

```bash
make installcheck
```

## One-Step Installer

For convenience, this repository also includes an installer that performs `make install` and runs `CREATE EXTENSION` or `ALTER EXTENSION UPDATE`.

Default: install in `postgres`. The installer detects the connected server major version and uses the matching `pg_config` when it exists, such as `/usr/lib/postgresql/16/bin/pg_config`.

```bash
./install.sh
```

You can force a specific PostgreSQL installation path:

```bash
PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config ./install.sh
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

The `--no-patch` flag only skips the standalone repair script. Current versions patch `pg_catalog` inside `CREATE EXTENSION`, so `--no-patch` does not disable that behavior.

Without running the standalone repair script:

```bash
./install.sh --db visao --no-patch
```

The installer detects an existing manual `ddl_original` setup and automatically runs `CREATE EXTENSION ddl_original FROM unpackaged`.

## Manual Install

The standard install above is preferred. These lower-level commands are useful when you want to control each step.

### Install Extension Files

```bash
cd pg-precise-ddl
sudo make install
```

For a specific PostgreSQL server version:

```bash
sudo make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config install
```

### Install In One Database

```sql
CREATE EXTENSION ddl_original;
```

Re-run the pgAdmin/DBeaver catalog repair script manually:

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

The extension patches `pg_catalog` in each database where it is created.

## Remove

```bash
sudo -u postgres psql -d my_database -f scripts/uninstall_pg_catalog_patch.sql
```

Then:

```sql
DROP EXTENSION ddl_original;
```

If you already ran `DROP EXTENSION ddl_original` first and `pg_get_functiondef` is missing, run the same `scripts/uninstall_pg_catalog_patch.sql` afterward to restore the native PostgreSQL function names.

## Compatibility Notes

The extension itself is pure SQL/PLpgSQL and targets PostgreSQL 14 or newer. The underlying event trigger APIs are stable across current PostgreSQL releases, but the `pg_catalog` patch intentionally checks for the native internal functions before renaming them.

The capture uses `current_query()`. For best results, execute one `CREATE FUNCTION` or `CREATE PROCEDURE` statement at a time. If a client sends several statements in one protocol query, PostgreSQL exposes the whole batch as `current_query()`, and that whole text can be captured.
