#ifndef GAD_GESTURE_ENCODING_H
#define GAD_GESTURE_ENCODING_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

const char *CFStringToCString(CFStringRef string, bool *needsFree);
CFStringRef GetWebSafeEncode(const void *bytes, size_t length);

const uint8_t *GAD_MD5(const void *bytes, unsigned length, uint8_t *digest);
unsigned char *do_rc4(const char *key, size_t keyLength, const char *input,
                      size_t inputLength, int mode);

#endif
