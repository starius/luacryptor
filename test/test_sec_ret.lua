-- encrypt
os.execute('rm sec_ret.so test/sec_ret.c')
os.execute('./luacryptor embed test/sec_ret.lua 123')
os.execute('./luacryptor buildso ' ..
    'test/sec_ret.c sec_ret.so')

-- load
debug.getregistry().__luacryptor_pwd = '123'
local _1, sec_ret, _2 = require('sec_ret').f('a', 'b')
assert(sec_ret == 'secret')

