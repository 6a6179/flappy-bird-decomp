#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef struct {
    uint8_t *bytes;
    size_t capacity;
    uint8_t *cursor;
} GADWireBuffer;

extern unsigned GADMaxWireBufferSize(unsigned a, unsigned b);

GADWireBuffer *SimpleWireFormatMakeBuffer(size_t capacity)
{
    GADWireBuffer *buffer = malloc(sizeof(*buffer));
    buffer->bytes = malloc(sizeof(*buffer->bytes) * capacity);
    buffer->capacity = capacity;
    buffer->cursor = buffer->bytes;
    return buffer;
}

void GADReserveWireBuffer(GADWireBuffer *buffer, size_t needed)
{
    size_t used = buffer->cursor - buffer->bytes;
    if (buffer->capacity - used < needed) {
        size_t capacity = GADMaxWireBufferSize(buffer->capacity * 2, used + needed);
        buffer->bytes = realloc(buffer->bytes, sizeof(*buffer->bytes) * capacity);
        buffer->capacity = capacity;
        buffer->cursor = buffer->bytes + used;
    }
}

void SimpleWireFormatWriteRaw(const char *bytes, size_t length, GADWireBuffer *buffer)
{
    GADReserveWireBuffer(buffer, length);
    memcpy(buffer->cursor, bytes, length);
    buffer->cursor += length;
}

void SimpleWireFormatWriteVarint32(uint32_t value, GADWireBuffer *buffer)
{
    GADReserveWireBuffer(buffer, 5);
    buffer->cursor[0] = value | 0x80;
    if (value >= (1U << 7)) {
        buffer->cursor[1] = (value >> 7) | 0x80;
        if (value >= (1U << 14)) {
            buffer->cursor[2] = (value >> 14) | 0x80;
            if (value >= (1U << 21)) {
                buffer->cursor[3] = (value >> 21) | 0x80;
                if (value >= (1U << 28)) {
                    buffer->cursor[4] = value >> 28;
                    buffer->cursor += 5;
                    return;
                } else {
                    buffer->cursor[3] &= 0x7f;
                    buffer->cursor += 4;
                    return;
                }
            } else {
                buffer->cursor[2] &= 0x7f;
                buffer->cursor += 3;
                return;
            }
        } else {
            buffer->cursor[1] &= 0x7f;
            buffer->cursor += 2;
            return;
        }
    } else {
        buffer->cursor[0] &= 0x7f;
        buffer->cursor++;
    }
}

void SimpleWireFormatWriteVarint64(uint64_t value, GADWireBuffer *buffer)
{
    GADReserveWireBuffer(buffer, 10);
    uint32_t low = value;
    uint32_t middle = value >> 28;
    uint32_t high = value >> 56;
    unsigned length;
    if (high == 0) {
        if (middle == 0) {
            if (low < (1U << 14)) {
                if (low < (1U << 7)) {
                    length = 1;
                    goto byte1;
                }
                length = 2;
                goto byte2;
            }
            if (low < (1U << 21)) {
                length = 3;
                goto byte3;
            }
            length = 4;
            goto byte4;
        }
        if (middle < (1U << 14)) {
            if (middle < (1U << 7)) {
                length = 5;
                goto byte5;
            }
            length = 6;
            goto byte6;
        }
        if (middle < (1U << 21)) {
            length = 7;
            goto byte7;
        }
        length = 8;
        goto byte8;
    }
    if (high < (1U << 7)) {
        length = 9;
        goto byte9;
    }
    length = 10;
    goto byte10;
byte10:
    buffer->cursor[9] = (high >> 7) | 0x80;
byte9:
    buffer->cursor[8] = high | 0x80;
byte8:
    buffer->cursor[7] = (middle >> 21) | 0x80;
byte7:
    buffer->cursor[6] = (middle >> 14) | 0x80;
byte6:
    buffer->cursor[5] = (middle >> 7) | 0x80;
byte5:
    buffer->cursor[4] = middle | 0x80;
byte4:
    buffer->cursor[3] = (low >> 21) | 0x80;
byte3:
    buffer->cursor[2] = (low >> 14) | 0x80;
byte2:
    buffer->cursor[1] = (low >> 7) | 0x80;
byte1:
    buffer->cursor[0] = low | 0x80;
    buffer->cursor[length - 1] &= 0x7f;
    buffer->cursor += length;
}
