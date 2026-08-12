\set ON_ERROR_STOP on

\ir uninstall_pg_catalog_patch.sql

DROP EXTENSION IF EXISTS ddl_original;
