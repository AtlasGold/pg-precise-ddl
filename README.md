# pg-precise-ddl

PostgreSQL extension that preserves original `CREATE FUNCTION` and `CREATE PROCEDURE` SQL so tools can show typmods such as `varchar(25)` and `numeric(10,2)`.

This repository contains separate install directories by PostgreSQL major version:

- `postgresql-18/`
- `postgresql-16/`

Use the directory that matches the PostgreSQL server version, not necessarily the `psql` client version.

The version directories are SQL-only packages. They install directly into PostgreSQL's extension directory and do not require `pg_config` or `postgresql-server-dev-*`.

## PostgreSQL 18

```bash
git clone https://github.com/AtlasGold/pg-precise-ddl.git
cd pg-precise-ddl/postgresql-18
make
sudo make install
```

Then in PostgreSQL:

```sql
CREATE EXTENSION ddl_original;
```

## PostgreSQL 16

```bash
git clone https://github.com/AtlasGold/pg-precise-ddl.git
cd pg-precise-ddl/postgresql-16
make
sudo make install
```

Then in PostgreSQL:

```sql
CREATE EXTENSION ddl_original;
```

## Important

`CREATE EXTENSION ddl_original` intentionally patches `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)` so pgAdmin, DBeaver, and similar tools see preserved routine source automatically.

This is not normal low-risk extension behavior. It renames the native PostgreSQL functions to:

- `pg_catalog.pg_get_functiondef_native(oid)`
- `pg_catalog.pg_get_function_arguments_native(oid)`

Then it creates wrappers with the original names. Install and use this at your own risk, especially on production servers and before PostgreSQL major-version upgrades.

## Remove

Inside the version directory you installed from:

```bash
sudo -u postgres psql -d my_database -f scripts/uninstall_pg_catalog_patch.sql
```

Then:

```sql
DROP EXTENSION ddl_original;
```
