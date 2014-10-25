
local m = {}

function m.cleanSource(src)
    src = src:gsub("function [%w_%.]+%(", "function (")
    src = src:gsub(".*function", "function")
    return src
end

function m.dump(str)
    if not m.numtab then
        m.numtab = {}
        for i = 0, 255 do
            m.numtab[string.char(i)] = ("%3d,"):format(i)
        end
    end
    str = str
        :gsub(".", m.numtab)
        :gsub(("."):rep(60), "%0\n")
    if str:sub(-1, -1) == ',' then
        str = str:sub(1, -2)
    end
    return str
end

function m.undump(str)
    local arr = loadstring('return {' .. str .. '}')()
    local unPack = unpack or table.unpack
    return string.char(unPack(arr))
end

function m.fileContent(fname)
    local f = assert(io.open(fname,"rb"))
    local content = f:read("*a")
    f:close()
    return content
end

function m.encryptFileContent(fname, password)
    local lc = require 'luacryptorext'
    local content = m.fileContent(fname)
    return lc.encrypt(content, password)
end

function m.decryptFileContent(fname, password)
    local lc = require 'luacryptorext'
    local content = m.fileContent(fname)
    return lc.decrypt(content, password)
end

function m.embed_luaopen() return [[
LUALIB_API int luaopen_@modname@(lua_State *L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "__luacryptor_pwd");
    const char* password = lua_tostring(L, -1);
    lua_pop(L, 1);
    if (!password) {
        printf("Set password in regiter property "
            "__luacryptor_pwd\n");
        return 0;
    }
    const char lua_enc_dump[] = { @lua_enc_dump@ };
    lua_pushcfunction(L, twofish_decrypt);
    lua_pushlstring(L, lua_enc_dump, sizeof(lua_enc_dump));
    lua_pushstring(L, password);
    lua_call(L, 2, 1);
    if (lua_type(L, -1) != LUA_TSTRING) {
        printf("Failed to decrypt Lua source\n");
        return 0;
    }
    size_t orig_size;
    const char* orig = lua_tolstring(L, -1, &orig_size);
    int status = luaL_loadbuffer(L, orig, orig_size,
        "@basename@");
    if (status) {
        printf("%s\n", lua_tostring(L, -1));
        printf("Wrong password?\n");
        lua_pop(L, 2); // orig, error message
        return 0;
    }
    lua_pcall(L, 0, 1, 0);
    return 1; // chunk execution result
}]] end

function m.module_names(fname_lua)
    local fname_c = fname_lua:gsub('.lua$', '.c')
    local basename = fname_lua:gsub('.lua$', '')
    local modname = basename
    modname = modname:gsub('.+/', '')
    modname = modname:gsub('.+\\', '')
    return fname_c, basename, modname
end

function m.embed(fname_lua, password)
    local lua_enc = m.encryptFileContent(fname_lua, password)
    local lua_enc_dump = m.dump(lua_enc)
    local fname_c, basename, modname = m.module_names(fname_lua)
    local f_c = io.open(fname_c, 'w')
    local lc = require 'luacryptorext'
    f_c:write(lc.luacryptorbase)
    local ttt = m.embed_luaopen():gsub('@[%w_]+@', {
        ['@modname@'] = modname,
        ['@basename@'] = basename,
        ['@lua_enc_dump@'] = lua_enc_dump,
    })
    f_c:write(ttt)
    f_c:close()
end

function m.get_lines_of_file(fname)
    local lines = {}
    for line in io.lines(fname) do
        table.insert(lines, line)
    end
    return lines
end

function m.get_source_of_function(name, func, lines)
    local info = debug.getinfo(func)
    local linedefined = info.linedefined
    local lastlinedefined = info.lastlinedefined
    local line1 = m.cleanSource(lines[linedefined])
    assert(line1:find("function") == 1,
        "Can't find start of function " .. name ..
        '. First line is ' .. line1)
    local src = 'return ' .. line1 .. '\n'
    for i = linedefined + 1, lastlinedefined do
        src = src .. lines[i] .. '\n'
    end
    return src
end

function m.encrypt_functions(mod, lines, password)
    local lc = require 'luacryptorext'
    local name2enc = {}
    for name, func in pairs(mod) do
        assert(type(func) == 'function',
            'Module must contain only functions!')
        local src = m.get_source_of_function(name, func, lines)
        local _, upv = debug.getupvalue(func, 1)
        if upv then
            assert(upv == mod,
                'You can use only module as upvalue')
            assert(not debug.getupvalue(func, 2),
                'You can use only one upvalue (module itself)')
        end
        local src_enc = lc.encrypt(src, password .. name)
        name2enc[name] = src_enc
    end
    return name2enc
end

function m.encrypted_selector(name2enc)
    local t = [[static void luacryptor_get_encrypted(
        const char* name, const char** result,
        size_t* result_size) {
            *result = 0;
            *result_size = 0;]]
    for name, src_enc in pairs(name2enc) do
        t = t .. 'if (strcmp(name, "' .. name .. '") == 0) {'
        t = t .. 'const char cc[] = {' ..
            m.dump(src_enc) .. '};'
        t = t .. '*result = cc;'
        t = t .. '*result_size = ' .. #src_enc .. '; }'
    end
    t = t .. '}'
    return t
end

function m.enc_func_luaopen() return [[
static int enc_func_call(lua_State* L) {
    lua_getfield(L, LUA_REGISTRYINDEX, "__luacryptor_pwd");
    if (lua_type(L, -1) != LUA_TSTRING) {
        printf("Set password in regiter property "
            "__luacryptor_pwd\n");
        return 0;
    }
    lua_getfield(L, 1, "name");
    const char* name = lua_tostring(L, -1);
    if (!name) {
        printf("Unknown function name\n");
        return 0;
    }
    lua_concat(L, 2); // password .. name
    const char* password_name = lua_tostring(L, -1);
    lua_pop(L, 1);
    if (!password_name) {
        printf("Failed to get final password\n");
        return 0;
    }
    const char* src_enc;
    size_t src_enc_size;
    luacryptor_get_encrypted(name, &src_enc, &src_enc_size);
    if (!src_enc) {
        printf("Wrong function name\n");
        return 0;
    }
    // decrypt
    lua_pushcfunction(L, twofish_decrypt);
    lua_pushlstring(L, src_enc, src_enc_size);
    lua_pushstring(L, password_name);
    lua_call(L, 2, 1);
    if (lua_type(L, -1) != LUA_TSTRING) {
        printf("Failed to decrypt Lua source\n");
        return 0;
    }
    size_t orig_size;
    const char* orig = lua_tolstring(L, -1, &orig_size);
    int status = luaL_loadbuffer(L, orig, orig_size,
        "@basename@");
    if (status) {
        printf("%s\n", lua_tostring(L, -1));
        printf("Wrong password?\n");
        return 0;
    }
    lua_pcall(L, 0, 1, 0); // get original function
    lua_pcall(L, 0, 0, 0); // call original function
    return 0;
}

static int enc_func_index(lua_State* L) {
    lua_newtable(L); // function
    lua_pushvalue(L, -2); // name
    lua_setfield(L, -2, "name"); // function.name = name
    lua_newtable(L); // metatable
    lua_pushcfunction(L, enc_func_call);
    lua_setfield(L, -2, "__call");
    lua_setmetatable(L, -2);
    return 1; // function table
}

LUALIB_API int luaopen_@modname@(lua_State *L) {
    lua_newtable(L); // module
    lua_newtable(L); // metatable
    lua_pushcfunction(L, enc_func_index);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    return 1; // module table
}]] end

function m.encfunc(fname_lua, password)
    local mod = assert(loadfile(fname_lua))()
    local lines = m.get_lines_of_file(fname_lua)
    local name2enc = m.encrypt_functions(mod, lines, password)
    local encrypted_selector = m.encrypted_selector(name2enc)
    local fname_c, basename, modname = m.module_names(fname_lua)
    local f_c = io.open(fname_c, 'w')
    local lc = require 'luacryptorext'
    f_c:write(lc.luacryptorbase)
    f_c:write(encrypted_selector)
    local ttt = m.enc_func_luaopen():gsub('@[%w_]+@', {
        ['@modname@'] = modname,
        ['@basename@'] = basename,
    })
    f_c:write(ttt)
    f_c:close()
end

-- http://stackoverflow.com/a/4521960
if not pcall(debug.getlocal, 4, 1) then
    local unPack = unpack or table.unpack
    local cmd, a1, a2, a3, a4 = unPack(arg)
    local f = m[cmd]
    if f then
        print(f(a1, a2, a3, a4))
    else
        print([[Usage:
        lua luacryptor.lua dump any_file
        lua luacryptor.lua embed target.lua password
        lua luacryptor.lua encfunc target.lua password
        ]])
    end
end

return m

