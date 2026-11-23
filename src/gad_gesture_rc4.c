#include <stdlib.h>
#include <string.h>

#include "gad_gesture_encoding.h"

typedef struct {
    unsigned char permutation[256];
    unsigned char x;
    unsigned char y;
} GADRC4State;

int htoa(char digit);
void tohex(char *output, const unsigned char *bytes, size_t length);

void set_crypt_key(GADRC4State *state, const unsigned char *key, size_t keyLength)
{
    unsigned char *permutation = state->permutation;
    int i;
    for (i = 0; i < 256; ++i)
        permutation[i] = i;

    int j = 0;
    for (i = 0; i < 256; ++i) {
        j = (j + permutation[i] + key[i % keyLength]) & 255;
        unsigned char saved = permutation[i];
        permutation[i] = permutation[j];
        permutation[j] = saved;
    }
    state->x = 0;
    state->y = 0;
}

int gethex(unsigned char *output, const char *hex, size_t length)
{
    while (length--) {
        int high = htoa(*hex++);
        int low = htoa(*hex++);
        if (high == -1 || low == -1)
            return 1;
        *output = high << 4;
        *output++ |= low;
    }
    return 0;
}

enum {
    GADRC4DecodeHex,
    GADRC4EncodeHex,
    GADRC4Raw
};

unsigned char *do_rc4(const char *key, size_t keyLength, const char *input,
                      size_t inputLength, int mode)
{
    if (!key || !strlen(key) || !input || !strlen(input) ||
        mode > GADRC4Raw || mode < GADRC4DecodeHex)
        return NULL;

    unsigned char *bytes = (unsigned char *)input;
    size_t length = inputLength;
    if (mode == GADRC4DecodeHex) {
        length /= 2;
        bytes = calloc(1, length);
        if (!bytes || gethex(bytes, input, length)) {
            free(bytes);
            return NULL;
        }
    }

    GADRC4State state;
    set_crypt_key(&state, (const unsigned char *)key, keyLength);
    unsigned char *output = calloc(1, length + 1);
    if (!output) {
        free(bytes);
        return NULL;
    }

    unsigned char x = state.x;
    unsigned char y = state.y;
    unsigned char *permutation = state.permutation;
    for (size_t index = 0; index < length; ++index) {
        x = (x + 1) & 255;
        y = (y + permutation[x]) & 255;
        unsigned char saved = permutation[x];
        permutation[x] = permutation[y];
        permutation[y] = saved;

        if (bytes) {
            if (output)
                output[index] = bytes[index] ^ permutation[(permutation[x] + permutation[y]) & 255];
        } else if (output) {
            output[index] = permutation[(permutation[x] + permutation[y]) & 255];
        }
    }
    state.x = x;
    state.y = y;

    unsigned char *result = output;
    if (mode == GADRC4EncodeHex) {
        result = calloc(1, 2 * length + 1);
        if (!result) {
            free(output);
            return NULL;
        }
        tohex((char *)result, output, length);
        free(output);
    } else if (mode == GADRC4DecodeHex) {
        free(bytes);
    }
    return result;
}
