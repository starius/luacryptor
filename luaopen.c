LUALIB_API int luaopen_luacryptorext(lua_State *L) {
    lua_newtable(L);
    lua_pushcfunction(L, twofish_encrypt);
    lua_setfield(L, -2, "encrypt");
    lua_pushcfunction(L, twofish_decrypt);
    lua_setfield(L, -2, "decrypt");
    lua_pushlstring(L, luacryptorbase,
            sizeof(luacryptorbase));
    lua_setfield(L, -2, "luacryptorbase");
    lua_pushcfunction(L, lua_calc_sha256);
    lua_setfield(L, -2, "sha256");
    return 1;
}

