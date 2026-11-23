static const char *monitoringProperty = "287090c9ba22457f92931c811faa0f7f174b4d54b2bc0500";

bool SetBatteryMonitoringStatus(bool enabled)
{
    bool previous = false;
    char *className = DECODE_GESTURE_NAME(deviceClass);
    char *property = DECODE_GESTURE_NAME(monitoringProperty);
    char *current = DECODE_GESTURE_NAME(currentDeviceSelector);
    char *getter = DECODE_GESTURE_NAME(isMonitoringSelector);
    char *setter = DECODE_GESTURE_NAME(setMonitoringSelector);
    if (GADGestureHasProperty(className, property)) {
        id device = objc_msgSend((id)objc_lookUpClass(className), sel_registerName(current));
        bool (*isMonitoring)(id, SEL) = (void *)objc_msgSend;
        previous = isMonitoring(device, sel_registerName(getter));
        objc_msgSend(device, sel_registerName(setter), enabled);
    }
    GADClearGestureString(className);
    GADClearGestureString(property);
    GADClearGestureString(current);
    GADClearGestureString(getter);
    GADClearGestureString(setter);
    return previous;
}

static const unsigned maximumRC4KeyLength = 32;

// The SDK evaluates each operand once and preserves its integer type.
#define GAD_MIN_VALUE(a, b) \
    ({ __typeof__(a) left = (a); __typeof__(b) right = (b); left < right ? left : right; })

CFStringRef GetEncryptedData(const unsigned char *bytes, size_t length, CFStringRef key)
{
    if (!bytes || length <= 0)
        return NULL;
    int capacity = 240;
    if (length + 1 > capacity)
        return GADEncodeOversizeSignal(key);
    uint8_t *data = malloc(capacity);
    if (!data)
        return NULL;
    int cursor = 0;
    unsigned boundedLength = GAD_MIN_VALUE(255, length);
    uint8_t lengthByte = boundedLength & 0xff;
    data[cursor++] = lengthByte;
    memcpy(&data[cursor], bytes, length);
    cursor += length;
    for (; cursor < capacity; cursor++) {
        uint8_t padding = (rand() % 256) & 0xff;
        data[cursor] = padding;
    }
    if (cursor + 16 != 256) {
        free(data);
        return GADEncodeOversizeSignal(key);
    }
    uint8_t digest[16];
    if (!GAD_MD5(data, cursor, digest)) {
        free(data);
        return NULL;
    }
    uint8_t *block = calloc(1, 256);
    if (!block) {
        free(data);
        return NULL;
    }
    memcpy(block, digest, 16);
    memcpy(block + 16, data, cursor);
    free(data);
    size_t outputLength = 256;
    uint8_t *output = calloc(1, outputLength);
    if (!output) {
        free(block);
        return NULL;
    }
    if (!GADTransformSignalBlock((const uint32_t *)block, (uint32_t *)output)) {
        free(block);
        free(output);
        return NULL;
    }
    free(block);
    unsigned char *ciphertext = NULL;
    if (key && CFStringGetLength(key) > 0) {
        bool shouldFree = false;
        const char *keyBytes = CFStringToCString(key, &shouldFree);
        size_t byteLength = strlen(keyBytes);
        size_t keyLength = GAD_MIN_VALUE(maximumRC4KeyLength, byteLength);
        ciphertext = do_rc4(keyBytes, keyLength, (const char *)output, outputLength, 2);
        if (shouldFree)
            free((void *)keyBytes);
        free(output);
        if (!ciphertext)
            return NULL;
    } else {
        ciphertext = output;
    }
    CFStringRef encoded = GetWebSafeEncode(ciphertext, outputLength);
    free(ciphertext);
    return encoded;
}

#undef GAD_MIN_VALUE
