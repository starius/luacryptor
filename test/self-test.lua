-- encrypt
os.execute('rm luacryptor.c test/luacryptor.so')
os.execute('./luacryptor encfunc luacryptor.lua 123')
os.execute('./luacryptor buildso ' ..
    'luacryptor.c test/luacryptor.so')

package.path = ''
package.cpath = './test/luacryptor.so;./luacryptorext.so'

-- load
debug.getregistry().__luacryptor_pwd = '123'
local lc = require('luacryptor')
assert(lc.undump(lc.dump('test')) == 'test')

