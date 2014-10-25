
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

static void xor_ctr(unsigned char* block, unsigned int ctr) {
    unsigned char* current_byte = block + BLOCK_BYTES - 1;
    while (ctr) {
        *current_byte ^= ctr & 0xFF;
        ctr >>= 8;
        current_byte -= 1;
    }
}

// If encr, encrypts, otherwise decrypts
// Lua arguments:
// string text (may be cleartext or encrypted text)
// string password
// sha256(password) is used as key for twofish
// returns cleartext or encrypted text
static int twofish_twoways(lua_State *L, int encr) {
    if (lua_gettop(L) != 2) {
        return 0;
    }
    if (lua_type(L, 1) != LUA_TSTRING) {
        return 0;
    }
    if (lua_type(L, 2) != LUA_TSTRING) {
        return 0;
    }
    size_t text_s;
    const char* text = lua_tolstring(L, 1, &text_s);
    size_t password_s;
    const char* password = lua_tolstring(L, 2, &password_s);
    //
    unsigned char sha256sum[32];
    // sha256
    sha256_context ctx;
    sha256_starts(&ctx);
    sha256_update(&ctx, (uint8*)password, password_s);
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
    int result_bytes;
    if (encr) {
        result_bytes = text_s + BLOCK_BYTES;
    } else {
        result_bytes = text_s - BLOCK_BYTES;
    }
    char* result = malloc(result_bytes);
    // twofish - make nonce (~IV) for CTR mode
    const char* nonce;
    const char* input; // points to first block of data
    char* output; // points to first block of data
    int normal_blocks;
    if (encr) {
        char* nonce_mut = result;
        nonce = nonce_mut;
        get_random_bytes(nonce_mut, BLOCK_BYTES);
        input = text;
        output = result + BLOCK_BYTES;
        normal_blocks = text_s / BLOCK_BYTES;
    } else {
        nonce = text;
        input = text + BLOCK_BYTES;
        output = result;
        normal_blocks = (text_s / BLOCK_BYTES) - 1;
    }
    int i;
    for (i = 0; i < normal_blocks; i++) {
        const char* b_in = input + i * BLOCK_BYTES;
        char* b_out = output + i * BLOCK_BYTES;
        memcpy(b_out, nonce, BLOCK_BYTES);
        xor_ctr(b_out, i);
        encrypt(K, QF, b_out);
        xor_block(b_out, b_in, BLOCK_BYTES);
    }
    int last_block_size = text_s % BLOCK_BYTES;
    if (last_block_size) {
        const char* b_in = input + normal_blocks * BLOCK_BYTES;
        char* b_out = output + normal_blocks * BLOCK_BYTES;
        char block[BLOCK_BYTES];
        memcpy(block, nonce, BLOCK_BYTES);
        xor_ctr(block, i);
        encrypt(K, QF, block);
        memcpy(b_out, block, last_block_size);
        xor_block(b_out, b_in, last_block_size);
    }
    lua_pushlstring(L, result, result_bytes);
    free(result);
    return 1;
}

static int twofish_encrypt(lua_State *L) {
    return twofish_twoways(L, 1);
}

static int twofish_decrypt(lua_State *L) {
    return twofish_twoways(L, 0);
}

