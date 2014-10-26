-- encrypt
os.execute('rm sec_ret.so test/sec_ret.c')
os.execute('lua luacryptor.lua encfunc ' ..
    'test/sec_ret.lua 123')
os.execute('lua luacryptor.lua buildso ' ..
    'test/sec_ret.c sec_ret.so')

-- load
debug.getregistry().__luacryptor_pwd = '123'
local _1, sec_ret, _2 = require('sec_ret').f('a', 'b')
assert(sec_ret == 'secret')

