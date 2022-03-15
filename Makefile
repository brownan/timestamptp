EXTENSION = timestamptp
DATA = timestamptp--1.0.sql
REGRESS = timestamptp_test
MODULES = timestamptp
PG_CFLAGS = -Wno-declaration-after-statement

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

