
#include <stdio.h>

#define LUA_LIB
#include "lua.h"
#include "lauxlib.h"

static void get_random_bytes(char* buffer, int size) {
    FILE* urandom = fopen("/dev/urandom", "r");
    fread(buffer, size, 1, urandom);
    fclose(urandom);
}

static void xor_block(BYTE* dst, const BYTE* src, int size) {
    int i;
    for (i = 0; i < size; i++) {
        dst[i] ^= src[i];
    }
}

#define BLOCK_BYTES 16

// arguments:
// string cleartext
// string key
// sha256(key) is used as key for twofish
// returns cryptotext
static int twofish_encrypt(lua_State *L) {
    if (lua_gettop(L) != 2) {
        return 0;
    }
    if (lua_type(L, 1) != LUA_TSTRING) {
        return 0;
    }
    if (lua_type(L, 2) != LUA_TSTRING) {
        return 0;
    }
    size_t cleartext_s;
    const char* cleartext = lua_tolstring(L, 1, &cleartext_s);
    size_t key_s;
    const char* key = lua_tolstring(L, 1, &key_s);
    //
    unsigned char sha256sum[32];
    // sha256
    sha256_context ctx;
    sha256_starts(&ctx);
    sha256_update(&ctx, (uint8*)key, key_s);
    sha256_finish(&ctx, sha256sum);
    // twofish - prepare key
    u32 *S;
    u32 K[40];
    int k;
    keySched(sha256sum, 128, &S, K, &k);
    u32 QF[4][256];
    fullKey(S, k, QF);
    free(S);
    // allocate output string
    // nonce is stored in the beginning
    int out_bytes = cleartext_s + BLOCK_BYTES;
    char* out = malloc(out_bytes);
    // twofish - make nonce (~IV) for CTR mode
    char* nonce = out;
    get_random_bytes(nonce, BLOCK_BYTES);
    char* encrypted = out + BLOCK_BYTES;
    int normal_blocks = cleartext_s / BLOCK_BYTES;
    int i;
    for (i = 0; i < normal_blocks; i++) {
        char* b_in = cleartext + i * BLOCK_BYTES;
        char* b_out = encrypted + i * BLOCK_BYTES;
        memcpy(b_out, nonce, BLOCK_BYTES);
        int* ctr = (int*)b_out;
        // FIXME int is assumed 32bit value
        // FIXME order of bytes in int
        *ctr ^= i;
        encrypt(K, QF, b_out);
        xor_block(b_out, b_in, BLOCK_BYTES);
    }
    int last_block_size = cleartext_s % BLOCK_BYTES;
    if (last_block_size) {
        char* b_in = cleartext + normal_blocks * BLOCK_BYTES;
        char* b_out = encrypted + normal_blocks * BLOCK_BYTES;
        char block[BLOCK_BYTES];
        memcpy(block, nonce, BLOCK_BYTES);
        int* ctr = (int*)block;
        *ctr ^= i;
        encrypt(K, QF, block);
        memcpy(b_out, block, last_block_size);
        xor_block(b_out, b_in, last_block_size);
    }
    lua_pushlstring(L, out, out_bytes);
    return 1;
}

LUALIB_API int luaopen_encrypt_lib(lua_State *L) {
    lua_pushcfunction(L, twofish_encrypt);
    return 1;
}

