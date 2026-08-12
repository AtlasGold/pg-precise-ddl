# pg-precise-ddl for PostgreSQL 18

This directory installs the `ddl_original` extension into PostgreSQL 18.

```bash
cd postgresql-18
make
sudo make install
```

This is a SQL-only extension package. This directory installs directly into `/usr/share/postgresql/18/extension` and does not require `pg_config`.

Then, in each database where you want it:

```sql
CREATE EXTENSION ddl_original;
```

From the shell:

```bash
sudo -u postgres psql -d postgres -c "CREATE EXTENSION ddl_original;"
```

## Safety Notice

`CREATE EXTENSION ddl_original` patches `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)` so pgAdmin, DBeaver, and similar tools see preserved routine source automatically.

It renames the native functions to:

- `pg_catalog.pg_get_functiondef_native(oid)`
- `pg_catalog.pg_get_function_arguments_native(oid)`

Use this at your own risk, especially on production servers and before PostgreSQL major-version upgrades.

## Remove

Restore the native catalog function names first:

```bash
sudo -u postgres psql -d my_database -f scripts/uninstall_pg_catalog_patch.sql
```

Then drop the extension:

```sql
DROP EXTENSION ddl_original;
```
