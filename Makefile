twofish-cpy/tables.h: twofish-cpy/makeCtables.py
	python $< > $@

twofish-cpy/twofish_lib.c: twofish-cpy/opt2.c
	cat $< | sed -e '/TESTING FUNCTIONS/,$$d' > $@
	echo '*/' >> $@

