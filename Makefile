EXTENSION = ddl_original
DATA = ddl_original--1.0.0.sql ddl_original--unpackaged--1.0.0.sql

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
