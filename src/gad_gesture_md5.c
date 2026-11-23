#include <stdint.h>
#include <string.h>

#include "gad_gesture_encoding.h"

typedef struct GADMD5Methods GADMD5Methods;

typedef struct {
    const GADMD5Methods *methods;
    uint64_t count;
    uint8_t buffer[64];
    uint32_t state[8];
} GADMD5Context;

struct GADMD5Methods {
    void (*init)(GADMD5Context *);
    void (*update)(GADMD5Context *, const void *, unsigned);
    const uint8_t *(*final)(GADMD5Context *);
    const uint8_t *(*hash)(const void *, unsigned, uint8_t *);
    unsigned digestSize;
};

static void GADMD5Init(GADMD5Context *ctx);
static void GADMD5Update(GADMD5Context *ctx, const void *data, unsigned length);
static const uint8_t *GADMD5Final(GADMD5Context *ctx);
static void GADMD5Transform(GADMD5Context *ctx);

const uint8_t *GAD_MD5(const void *data, unsigned length, uint8_t *digest)
{
    GADMD5Context ctx;
    GADMD5Init(&ctx);
    GADMD5Update(&ctx, data, length);
    memcpy(digest, GADMD5Final(&ctx), 16);
    return digest;
}

static const GADMD5Methods gadMD5Methods = {
    GADMD5Init, GADMD5Update, GADMD5Final, GAD_MD5, 16
};

static void GADMD5Init(GADMD5Context *ctx)
{
    ctx->methods = &gadMD5Methods;
    ctx->state[0] = 0x67452301;
    ctx->state[1] = 0xefcdab89;
    ctx->state[2] = 0x98badcfe;
    ctx->state[3] = 0x10325476;
    ctx->count = 0;
}

static void GADMD5Update(GADMD5Context *ctx, const void *data, unsigned length)
{
    int i = ctx->count & 63;
    const uint8_t *p = data;
    ctx->count += length;
    while (length--) {
        ctx->buffer[i++] = *p++;
        if (i == 64) {
            GADMD5Transform(ctx);
            i = 0;
        }
    }
}

static const uint8_t *GADMD5Final(GADMD5Context *ctx)
{
    static const char zeroPadding[] = "\0";
    uint8_t *p = ctx->buffer;
    uint64_t bits = ctx->count * 8;
    int i;
    GADMD5Update(ctx, "\x80", 1);
    while ((ctx->count & 63) != 56) {
        GADMD5Update(ctx, zeroPadding, 1);
    }
    for (i = 0; i < 8; ++i) {
        uint8_t b = bits >> (i * 8);
        GADMD5Update(ctx, &b, 1);
    }
    for (i = 0; i < 4; ++i) {
        uint32_t word = ctx->state[i];
        *p++ = word;
        *p++ = word >> 8;
        *p++ = word >> 16;
        *p++ = word >> 24;
    }
    return ctx->buffer;
}

static const uint32_t gadMD5Constants[64] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee,
    0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
    0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be,
    0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
    0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
    0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
    0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c,
    0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05,
    0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
    0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039,
    0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391,
};

static const signed char gadMD5Shifts[64] = {
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
    5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
    4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21
};

#define GAD_MD5_ROL(word, bits) (((word) << (bits)) | ((word) >> (32 - (bits))))

static void GADMD5Transform(GADMD5Context *ctx)
{
    uint32_t words[64];
    uint32_t a, b, c, d;
    const uint8_t *p = ctx->buffer;
    int i;
    for (i = 0; i < 16; ++i) {
        uint32_t word = *p++;
        word |= (uint32_t)*p++ << 8;
        word |= (uint32_t)*p++ << 16;
        word |= (uint32_t)*p++ << 24;
        words[i] = word;
    }
    a = ctx->state[0];
    b = ctx->state[1];
    c = ctx->state[2];
    d = ctx->state[3];
    for (i = 0; i < 64; ++i) {
        uint32_t f, previousD;
        int g;
        if (i < 16) {
            f = d ^ (b & (c ^ d));
            g = i;
        } else if (i < 32) {
            f = c ^ (d & (b ^ c));
            g = (5 * i + 1) & 15;
        } else if (i < 48) {
            f = b ^ c ^ d;
            g = (3 * i + 5) & 15;
        } else {
            f = c ^ (b | ~d);
            g = (7 * i) & 15;
        }
        previousD = d;
        d = c;
        c = b;
        b = b + GAD_MD5_ROL(a + f + gadMD5Constants[i] + words[g], gadMD5Shifts[i]);
        a = previousD;
    }
    ctx->state[0] += a;
    ctx->state[1] += b;
    ctx->state[2] += c;
    ctx->state[3] += d;
}
