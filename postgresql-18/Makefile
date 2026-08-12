EXTENSION = ddl_original
PG_MAJOR = 18
EXTENSION_DIR = $(DESTDIR)/usr/share/postgresql/$(PG_MAJOR)/extension
DATA = ddl_original--1.0.0.sql \
       ddl_original--1.0.1.sql \
       ddl_original--1.0.0--1.0.1.sql \
       ddl_original--unpackaged--1.0.0.sql \
       ddl_original--unpackaged--1.0.1.sql

.PHONY: all install uninstall

all:
	@echo "Nothing to build for $(EXTENSION) on PostgreSQL $(PG_MAJOR). Run: sudo make install"

install:
	install -d "$(EXTENSION_DIR)"
	install -m 644 "$(EXTENSION).control" "$(EXTENSION_DIR)/"
	install -m 644 $(DATA) "$(EXTENSION_DIR)/"

uninstall:
	rm -f "$(EXTENSION_DIR)/$(EXTENSION).control"
	rm -f $(addprefix $(EXTENSION_DIR)/,$(DATA))
