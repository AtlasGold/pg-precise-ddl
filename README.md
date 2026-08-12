# pg-precise-ddl

Install in any PostgreSQL database as a superuser:

```bash
sudo -u postgres psql -d my_database -f install.sql
```

Rollback:

```bash
sudo -u postgres psql -d my_database -f rollback.sql
```

Warning: `install.sql` patches `pg_catalog.pg_get_functiondef(oid)` and `pg_catalog.pg_get_function_arguments(oid)`. Use at your own risk.
