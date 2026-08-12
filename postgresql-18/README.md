# PostgreSQL 18

```bash
make
sudo make install
```

Then in PostgreSQL:

```sql
CREATE EXTENSION ddl_original;
```

Rollback:

```bash
sudo -u postgres psql -d my_database -f scripts/rollback.sql
```

Warning: this extension patches `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)`. Use at your own risk.
