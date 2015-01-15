
TMP_FILE=tmp-install.sql

all:
	@echo "Available targets"
	@echo ""
	@echo "install, remove"

install:	check
	cat src/start.sql src/install/schema.sql src/install/tables.sql src/install/functions.sql src/install/test_tables.sql src/install/test_functions.sql src/end.sql > $TMP_FILE
	psql -f $TMP_FILE
	rm -f $TMP_FILE


remove:	check
	cat src/start.sql src/remove/schema.sql src/end.sql > $TMP_FILE
	psql -f $TMP_FILE
	rm -f $TMP_FILE


clean:	remove-tmp


check:
	@if [ -z $$PGDATABASE ]; then echo "please set PGDATABASE!"; exit 1; fi



remove-tmp:
	rm -f $TMP_FILE

.PHONY:	remove-tmp all install remove clean

