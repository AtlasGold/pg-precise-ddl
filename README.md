# pg-precise-ddl

Preserves original PostgreSQL function/procedure DDL, including typmods like `varchar(25)` and `numeric(10,2)`.

Choose the directory for your PostgreSQL server version:

```bash
cd postgresql-16
# or
cd postgresql-18
```

Install:

```bash
make
sudo make install
```

In each database:

```sql
CREATE EXTENSION ddl_original;
```

Warning: `CREATE EXTENSION ddl_original` patches `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)`. Use at your own risk.
