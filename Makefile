twofish-cpy/tables.h: twofish-cpy/makeCtables.py
	python $< > $@

twofish_lib.c: twofish-cpy/tables.h twofish-cpy/opt2.c
	cat twofish-cpy/tables.h > $@
	cat twofish-cpy/opt2.c | sed -e '/TESTING FUNCTIONS/,$$d' \
		>> $@
	echo '*/' >> $@

sha256_lib.c: sha256/sha256.h sha256/sha256.c
	cat $^ > $@

common_lib.c: twofish_lib.c sha256_lib.c
	cat $^ > $@

