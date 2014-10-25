-- encrypt
os.execute('rm sec_ret.so test/sec_ret.c')
os.execute('lua luacryptor.lua enc-func-src ' ..
    'test/sec_ret.lua 123')
os.execute('gcc test/sec_ret.c -o sec_ret.so ' ..
    '-shared -fpic -I /usr/include/lua5.1/ -llua5.1')

-- load
debug.getregistry().__luacryptor_pwd = '123'
local sec_ret = require('sec_ret').f()
assert(sec_ret == 'secret')

