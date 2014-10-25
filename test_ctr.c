#include <assert.h>

#include "twofish.c"

void printHex(BYTE b[], int lim)
{
    int i;
    for (i = 0; i < lim; i++) {
        printf("%02X", (u32)b[i]);
    }
    printf("\n");
}

void sprintHex(BYTE dst[], BYTE b[], int lim)
{
    int i;
    for (i = 0; i < lim; i++) {
        sprintf(dst + 2 * i, "%02X", (u32)b[i]);
    }
}

static void printCtr(int ctr) {
    printf("%032X\n", ctr);
    BYTE block[BLOCK_BYTES];
    memset(block, 0, BLOCK_BYTES);
    xor_ctr(block, ctr);
    printHex(block, BLOCK_BYTES);
    printf("\n");
    //
    BYTE buffer[BLOCK_BYTES * 2 + 1];
    sprintHex(buffer, block, BLOCK_BYTES);
    BYTE reference[BLOCK_BYTES * 2 + 1];
    sprintf(reference, "%032X", ctr);
    assert(memcmp(buffer, reference, BLOCK_BYTES * 2) == 0);
}

int main() {
    printCtr(0);
    printCtr(1);
    printCtr(2);
    printCtr(100);
    printCtr(1000);
    printCtr(1000000);
    printCtr(2000000000);
    return 0;
}

