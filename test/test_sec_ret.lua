-- encrypt
os.execute('rm sec_ret.so test/sec_ret.c')
os.execute('lua luacryptor.lua embed test/sec_ret.lua 123')
os.execute('gcc test/sec_ret.c -o sec_ret.so ' ..
    '-shared -fpic -I /usr/include/lua5.1/ -llua5.1')

-- load
debug.getregistry().__luacryptor_pwd = '123'
local _1, sec_ret, _2 = require('sec_ret').f('a', 'b')
assert(sec_ret == 'secret')

