twofish-cpy/tables.h: twofish-cpy/makeCtables.py
	python $< > $@

twofish_lib.c: twofish-cpy/tables.h twofish-cpy/opt2.c
	cat twofish-cpy/tables.h > $@
	cat twofish-cpy/opt2.c | sed -e '/TESTING FUNCTIONS/,$$d' \
		>> $@
	echo '*/' >> $@

sha256_lib.c: sha256/sha256.h sha256/sha256.c
	cat sha256/sha256.h > $@
	cat sha256/sha256.c | sed -e '/ifdef TEST/,$$d' >> $@

common_lib.c: twofish_lib.c sha256_lib.c
	cat $^ | sed -e 's/^u/static u/' \
		-e 's/^void/static void/' \
		-e 's/^inline/static/' > $@

encrypt_lib.c: common_lib.c lua_bindings.c
	cat $^ > $@

encrypt_lib.so: encrypt_lib.c
	gcc -shared -fpic -I /usr/include/lua5.1/ \
		$^ -o $@ -llua5.1

