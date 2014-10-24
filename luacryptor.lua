
local m = {}

function m.cleanSource(src)
    src = src:gsub("function ([%w_%.]+):([%w_]+)%(%)", "%1.%2 = function(self)")
    src = src:gsub("function ([%w_%.]+):([%w_]+)%(", "%1.%2 = function(self,")
    src = src:gsub("function ([%w_%.]+)%(", "%1 = function(")
    return src
end

do
    local numtab={}
    for i=0, 255 do
        numtab[string.char(i)] = ("%3d,"):format(i)
    end
    function m.dump(str)
        str = str
            :gsub(".", numtab)
            :gsub((".")
            :rep(80), "%0\n")
        return str
    end
end

function m.fileContent(fname)
    local f = assert(io.open(fname,"rb"))
    local content = f:read("*a")
    f:close()
    return content
end

function m.encryptFileContent(fname, password)
    local twofish = require 'twofish'
    local content = m.fileContent(fname)
    return twofish.encrypt(content, password)
end

function m.lua2c(fname_lua, password)
    local lua_enc = m.encryptFileContent(fname_lua, password)
    local lua_enc_dump = m.dump(lua_enc)
    local fname_c = fname_lua:gsub('.lua$', '.c')
    local basename = fname_lua:gsub('.lua$', '')
    local f_c = io.open(fname_c, 'w')
    local twofish_c = m.fileContent('twofish.c') -- TODO embed
    f_c:write(twofish_c)
    local ttt = [[
    LUALIB_API int luaopen_@basename@(lua_State *L) {
        lua_getfield(L, LUA_REGISTRYINDEX, "__luacryptor_pwd");
        const char* password = lua_tostring(L, -1);
        lua_pop(L, 1);
        if (!password) {
            printf("Set password in regiter property "
                "__luacryptor_pwd\n");
            return 0;
        }
        const char lua_enc_dump[] = { @lua_enc_dump@ };
        lua_pushlstring(L, lua_enc_dump, sizeof(lua_enc_dump));
        lua_pushstring(L, password);
        twofish_decrypt(L);
        int orig_size;
        const char* orig = lua_tolstring(L, -1, &orig_size);
        int status = luaL_loadbuffer(L, orig, orig_size,
            "@basename@");
        if (status) {
            printf("%s\n", lua_tostring(L, -1));
            lua_pop(L, 2); // orig, error message
            return 0;
        }
        return 1; // loaded chunk
    }]]
    ttt = ttt:gsub('@[%w_]+@',
        {['@basename@'] = basename,
        ['@lua_enc_dump@'] = lua_enc_dump})
    f_c:write(ttt)
    f_c:close()
end

return m
