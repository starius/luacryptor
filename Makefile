all: test/ctr.exe luacryptorext.so

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

twofish_and_sha256.c: twofish_lib.c sha256_lib.c
	cat $^ | sed -e 's/^u/static u/' \
		-e 's/^void/static void/' \
		-e 's/^inline/static/' > $@

luacryptorbase.c: twofish_and_sha256.c lua_bindings.c
	cat $^ > $@

luacryptorext.c: luacryptorbase.c luaopen.c
	cat $< > $@
	echo 'const char luacryptorbase[] = {' >> $@
	./luacryptor.lua dump $< >> $@
	echo '};' >> $@
	cat luaopen.c >> $@

luacryptorext.so: luacryptorext.c
	./luacryptor.lua buildso $^

test/ctr.exe: test/ctr.c luacryptorbase.c
	./luacryptor.lua buildexe $<

.PHONY: test
test: test/ctr.exe
	./test/ctr.exe
	lua test/test_sec_ret.lua
	lua test/test_sec_ret_enc_func.lua

.PHONY: all

