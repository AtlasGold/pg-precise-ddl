EXTENSION = ddl_original
DATA = ddl_original--1.0.0.sql ddl_original--1.0.1.sql ddl_original--1.0.0--1.0.1.sql ddl_original--unpackaged--1.0.0.sql ddl_original--unpackaged--1.0.1.sql
REGRESS = ddl_original

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
