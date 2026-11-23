#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <SystemConfiguration/SCNetworkReachability.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "gad_gesture_encoding.h"
#include "gad_gesture_signals.h"
#include "gad_view_geometry.h"

typedef struct {
    unsigned char *bytes;
    size_t capacity;
    unsigned char *cursor;
} GADWireBuffer;

extern void SimpleWireFormatWriteVarint32(uint32_t value, GADWireBuffer *buffer);
extern void SimpleWireFormatWriteVarint64(uint64_t value, GADWireBuffer *buffer);
extern void SimpleWireFormatWriteRaw(const char *bytes, size_t length, GADWireBuffer *buffer);

void SimpleWireFormatFreeBuffer(GADWireBuffer *buffer)
{
    free(buffer->bytes);
    free(buffer);
}

void SimpleWireFormatWriteTag(int field, int type, GADWireBuffer *buffer)
{
    SimpleWireFormatWriteVarint32((field << 3) | type, buffer);
}

unsigned GADMaxWireBufferSize(unsigned a, unsigned b)
{
    return a > b ? a : b;
}

void SimpleWireFormatWriteInt64(int field, int64_t value, GADWireBuffer *buffer)
{
    SimpleWireFormatWriteTag(field, 0, buffer);
    SimpleWireFormatWriteVarint64(value, buffer);
}

void SimpleWireFormatWriteString(int field, const char *value, GADWireBuffer *buffer)
{
    SimpleWireFormatWriteTag(field, 2, buffer);
    size_t length = strlen(value);
    SimpleWireFormatWriteVarint64(length, buffer);
    SimpleWireFormatWriteRaw(value, length, buffer);
}

Method GADLookupInstanceMethod(const char *className, const char *selectorName)
{
    SEL selector = sel_registerName(selectorName);
    Class cls = objc_lookUpClass(className);
    return class_getInstanceMethod(cls, selector);
}

Method GADLookupClassMethod(const char *className, const char *selectorName)
{
    SEL selector = sel_registerName(selectorName);
    Class cls = objc_lookUpClass(className);
    return class_getClassMethod(cls, selector);
}

bool GADReadSignalInteger(CFDictionaryRef dict, CFStringRef key, int *output)
{
    CFNumberRef value;
    return CFDictionaryGetValueIfPresent(dict, key, (const void **)&value) &&
           CFNumberGetValue(value, kCFNumberSInt32Type, output);
}

bool GADReadSignalString(CFDictionaryRef dict, CFStringRef key, char *output, CFIndex capacity)
{
    CFStringRef value;
    return CFDictionaryGetValueIfPresent(dict, key, (const void **)&value) &&
           CFStringGetCString(value, output, capacity, kCFStringEncodingUTF8);
}

CGRect GADMakeSignalRect(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
    CGRect result = {{x, y}, {width, height}};
    return result;
}

int htoa(char digit)
{
    if (digit >= '0' && digit <= '9')
        return digit - '0';
    if (digit >= 'a' && digit <= 'f')
        return 10 + digit - 'a';
    if (digit >= 'A' && digit <= 'F')
        return 10 + digit - 'A';
    return -1;
}

void tohex(char *output, const unsigned char *bytes, size_t length)
{
    char *next = output;
    for (size_t index = 0; index < length && next; ++index) {
        sprintf(next, "%02x", bytes[index]);
        next += 2;
    }
    if (next)
        *next = '\0';
}

typedef struct {
    char *className;
    char *selectorName;
    unsigned flag;
} GADGestureMethod;

void GADSetGestureMethod(GADGestureMethod *method, char *className, char *selectorName, unsigned flag)
{
    method->className = className;
    method->selectorName = selectorName;
    method->flag = flag;
}

static bool appActive;
static time_t firstActivation = -1;
static time_t latestActivation = -1;
static int touchX, touchY, touchDuration;

void GADGestureDidLaunch(CFNotificationCenterRef center, void *observer,
                           CFStringRef name, const void *object, CFDictionaryRef info)
{
    latestActivation = time(NULL);
    appActive = true;
    if (firstActivation == -1)
        firstActivation = time(NULL);
}

void GADGestureDidDeactivate(CFNotificationCenterRef center, void *observer,
                             CFStringRef name, const void *object, CFDictionaryRef info)
{
    latestActivation = -1;
    appActive = false;
}

bool IsAppActive(void)
{
    return appActive;
}

void GetAppUsageTime(int *first, int *elapsed, int *active)
{
    *first = firstActivation;
    time_t now = time(NULL);
    if (firstActivation > 0 && now >= firstActivation)
        *elapsed = now - firstActivation;
    else
        *elapsed = -1;
    if (latestActivation > 0 && now >= latestActivation)
        *active = now - latestActivation;
    else
        *active = -1;
}

void gad_htg(int x, int y, int duration)
{
    if (x != -1 && y != -1 && duration != -1) {
        touchX = x;
        touchY = y;
        touchDuration = duration;
    }
}

void GADClearGestureString(char *string)
{
    if (string) {
        memset(string, 0, strlen(string));
        free(string);
    }
}

extern bool IsReachable(SCNetworkReachabilityFlags *flags);

int GetNetworkType(void)
{
    SCNetworkReachabilityFlags flags;
    int type = -1;
    if (!IsReachable(&flags))
        return type;
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        if (flags & kSCNetworkReachabilityFlagsIsWWAN)
            type = 0;
        else
            type = 1;
    }
    return type;
}

bool GADGestureHasProperty(const char *className, const char *propertyName)
{
    Class cls = objc_lookUpClass(className);
    return class_getProperty(cls, propertyName) != NULL;
}

IMP GADGestureInstanceImplementation(const char *className, const char *selectorName)
{
    return method_getImplementation(GADLookupInstanceMethod(className, selectorName));
}

void GADWriteStringSignal(int field, const char *name, CFStringRef string,
                          CFMutableStringRef text, GADWireBuffer *buffer)
{
    bool shouldFree = false;
    const char *value = CFStringToCString(string, &shouldFree);
    if (value) {
        SimpleWireFormatWriteString(field, value, buffer);
        if (shouldFree)
            free((void *)value);
    }
}

void GADWriteIntegerSignal(int field, const char *name, int value,
                           CFMutableStringRef text, GADWireBuffer *buffer)
{
    SimpleWireFormatWriteInt64(field, value, buffer);
}

bool GADGestureHasClassMethod(const char *className, const char *selectorName)
{
    return GADLookupClassMethod(className, selectorName) != NULL;
}

int GADViewIntersectionArea(GADViewGeometry view, GADViewGeometry target)
{
    CGRect a = GADMakeSignalRect(view.x, view.y, view.width, view.height);
    CGRect b = GADMakeSignalRect(target.x, target.y, target.width, target.height);
    CGRect intersection = CGRectIntersection(a, b);
    return CGRectIsNull(intersection) ? 0 : intersection.size.width * intersection.size.height;
}

extern void GADInitializeGestureMethods(void);
extern void InitNotifications(void);

static bool gestureInitialized;
static CFStringRef gestureIdentifier;

void gad_gig(CFStringRef identifier)
{
    if (!gestureInitialized) {
        srand(time(NULL));
        GADGestureDidLaunch(NULL, NULL, NULL, NULL, NULL);
        GADInitializeGestureMethods();
        InitNotifications();
        gestureInitialized = true;
        gestureIdentifier = CFStringCreateCopy(kCFAllocatorDefault, identifier);
    }
}

extern bool IsInstanceMethodAvailable(const char *className, const char *selectorName);
extern bool SetBatteryMonitoringStatus(bool enabled);

static const char *deviceClass = "1f58a0d8a9395f57";
static const char *currentDeviceSelector = "296496cfba3e4876988b1c9615";
static const char *batteryLevelSelector = "287090c9ba22457e988b1099";
static const char *batteryStateSelector = "287090c9ba224561899c0190";
static const char *orientationEnabledSelector =
    "2362a3d8b1354e5389941b9234bd1078136b6c47b9b50e10c788a97820ebe4ee586b5e2564cc76ee3c1f";

#define DECODE_GESTURE_NAME(name) (char *)do_rc4("7a8f7h58", 8, name, strlen(name), 0)

int GetDeviceBatteryLevel(void)
{
    int level = -100;
    char *className = DECODE_GESTURE_NAME(deviceClass);
    char *selector = DECODE_GESTURE_NAME(batteryLevelSelector);
    char *current = DECODE_GESTURE_NAME(currentDeviceSelector);
    if (IsInstanceMethodAvailable(className, selector)) {
        id device = objc_msgSend((id)objc_lookUpClass(className), sel_registerName(current));
        bool previous = SetBatteryMonitoringStatus(true);
        float (*getLevel)(id, SEL) = (void *)objc_msgSend;
        level = getLevel(device, sel_registerName(selector)) * 100;
        SetBatteryMonitoringStatus(previous);
    }
    GADClearGestureString(className);
    GADClearGestureString(selector);
    GADClearGestureString(current);
    return level;
}

int GetDeviceBatteryState(void)
{
    int state = 0;
    char *className = DECODE_GESTURE_NAME(deviceClass);
    char *selector = DECODE_GESTURE_NAME(batteryStateSelector);
    char *current = DECODE_GESTURE_NAME(currentDeviceSelector);
    if (IsInstanceMethodAvailable(className, selector)) {
        bool previous = SetBatteryMonitoringStatus(true);
        id device = objc_msgSend((id)objc_lookUpClass(className), sel_registerName(current));
        int (*getState)(id, SEL) = (void *)objc_msgSend;
        state = getState(device, sel_registerName(selector));
        SetBatteryMonitoringStatus(previous);
    }
    GADClearGestureString(className);
    GADClearGestureString(selector);
    GADClearGestureString(current);
    return state;
}

bool IsDeviceOrientationEnabled(void)
{
    bool enabled = false;
    char *className = DECODE_GESTURE_NAME(deviceClass);
    char *current = DECODE_GESTURE_NAME(currentDeviceSelector);
    char *selector = DECODE_GESTURE_NAME(orientationEnabledSelector);
    if (GADGestureHasClassMethod(className, current) && IsInstanceMethodAvailable(className, selector)) {
        id device = objc_msgSend((id)objc_lookUpClass(className), sel_registerName(current));
        bool (*getEnabled)(id, SEL) = (void *)objc_msgSend;
        enabled = getEnabled(device, sel_registerName(selector));
    }
    GADClearGestureString(className);
    GADClearGestureString(current);
    GADClearGestureString(selector);
    return enabled;
}

extern GADWireBuffer *SimpleWireFormatMakeBuffer(size_t capacity);
extern CFStringRef GetEncryptedData(const unsigned char *bytes, size_t length, CFStringRef key);
static const char *oversizeSignalName = "Poison";

CFStringRef GADEncodeOversizeSignal(CFStringRef key)
{
    GADWireBuffer *buffer = SimpleWireFormatMakeBuffer(256);
    GADWriteIntegerSignal(20, oversizeSignalName, 1, NULL, buffer);
    CFStringRef value = GetEncryptedData(buffer->bytes, buffer->cursor - buffer->bytes, key);
    SimpleWireFormatFreeBuffer(buffer);
    return value;
}

static const char *modelSelector = "277e80d8b3";
static const char *idiomSelector = "3f6281cf963e48578f9b1496159102781f63";
static const char *versionSelector = "396897c9ba3d6a578f8e1c9a1e";

CFStringRef CopySystemInformation(void)
{
    CFStringRef result = NULL;
    char *className = DECODE_GESTURE_NAME(deviceClass);
    char *current = DECODE_GESTURE_NAME(currentDeviceSelector);
    char *model = DECODE_GESTURE_NAME(modelSelector);
    char *idiom = DECODE_GESTURE_NAME(idiomSelector);
    char *version = DECODE_GESTURE_NAME(versionSelector);
    CFStringRef deviceName = NULL;
    id device = objc_msgSend((id)objc_lookUpClass(className), sel_registerName(current));
    if (IsInstanceMethodAvailable(className, model))
        deviceName = (CFStringRef)objc_msgSend(device, sel_registerName(model));
    if (IsInstanceMethodAvailable(className, idiom)) {
        int (*getIdiom)(id, SEL) = (void *)objc_msgSend;
        int deviceIdiom = getIdiom(device, sel_registerName(idiom));
        if (deviceIdiom == 1)
            deviceName = CFSTR("iPad");
    }
    if (IsInstanceMethodAvailable(className, version)) {
        CFStringRef systemVersion = (CFStringRef)objc_msgSend(device, sel_registerName(version));
        if (deviceName && systemVersion)
            result = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@ %@"),
                                               deviceName, systemVersion);
    }
    GADClearGestureString(className);
    GADClearGestureString(current);
    GADClearGestureString(model);
    GADClearGestureString(idiom);
    GADClearGestureString(version);
    return result;
}

static const char *isMonitoringSelector = "2362a6dcab24594084b01a9b19ac096319604470beb10208c398";
static const char *setMonitoringSelector = "397490ffbe2448578f84389a1eb1127e02674d5295be0106ca99a42d";
static const char *orientationSelector = "25638dd8b1245d4694921b";
static const char *responderClass = "1f58b6d8ac20535c999807";
static const char *touchBeganSelector = "3e7e91deb7354f70989a149b4aaf0f65184b5550bea45a";
static const char *touchEndedSelector = "3e7e91deb7354f77939910914aaf0f65184b5550bea45a";
static const char *viewClass = "1f58b2d4ba27";
static const char *hiddenSelector = "2362acd4bb34595c";
/* The SDK reserves a final zero record after the twelve monitored methods. */
static GADGestureMethod gestureMethods[13];

#define SET_GESTURE_METHOD(index, cls, selector) \
    GADSetGestureMethod(&gestureMethods[index], DECODE_GESTURE_NAME(cls), \
                        DECODE_GESTURE_NAME(selector), 1u << (index))

void GADInitializeGestureMethods(void)
{
    SET_GESTURE_METHOD(0, deviceClass, isMonitoringSelector);
    SET_GESTURE_METHOD(1, deviceClass, setMonitoringSelector);
    SET_GESTURE_METHOD(2, deviceClass, batteryLevelSelector);
    SET_GESTURE_METHOD(3, deviceClass, batteryStateSelector);
    SET_GESTURE_METHOD(4, responderClass, touchBeganSelector);
    SET_GESTURE_METHOD(5, responderClass, touchEndedSelector);
    SET_GESTURE_METHOD(6, deviceClass, orientationSelector);
    SET_GESTURE_METHOD(7, deviceClass, orientationEnabledSelector);
    SET_GESTURE_METHOD(8, deviceClass, versionSelector);
    SET_GESTURE_METHOD(9, deviceClass, idiomSelector);
    SET_GESTURE_METHOD(10, deviceClass, modelSelector);
    SET_GESTURE_METHOD(11, viewClass, hiddenSelector);
}

bool IsInstanceMethodAvailable(const char *className, const char *selectorName)
{
    bool available = GADLookupInstanceMethod(className, selectorName) != NULL;
    return available;
}

void GADGestureDidBecomeActive(CFNotificationCenterRef center, void *observer,
                               CFStringRef name, const void *object, CFDictionaryRef info)
{
    latestActivation = time(NULL);
    appActive = true;
}

static const char *didLaunchName =
    "1f58a5cdaf3c55519c891c9a1e9c0f7536674d5ca3b82c05d392a37f27cbecd45e795e206cdb7ef53b030c";
static const char *didBecomeActiveName =
    "1f58a5cdaf3c55519c891c9a1e9c0f75326b405abdb52107d295b67200cafff35764542771d170ef";
static const char *willResignActiveName =
    "1f58a5cdaf3c55519c891c9a1e8f0f7d1c5c4646b9b70e25c588a9612bebe4ee586b5e2564cc76ee3c";

void InitNotifications(void)
{
    char *launch = DECODE_GESTURE_NAME(didLaunchName);
    CFStringRef launchNotification =
        CFStringCreateWithCString(kCFAllocatorDefault, launch, kCFStringEncodingUTF8);
    char *active = DECODE_GESTURE_NAME(didBecomeActiveName);
    CFStringRef activeNotification =
        CFStringCreateWithCString(kCFAllocatorDefault, active, kCFStringEncodingUTF8);
    char *inactive = DECODE_GESTURE_NAME(willResignActiveName);
    CFStringRef inactiveNotification =
        CFStringCreateWithCString(kCFAllocatorDefault, inactive, kCFStringEncodingUTF8);
    CFNotificationCenterRef center = CFNotificationCenterGetLocalCenter();
    CFNotificationCenterAddObserver(center, NULL, GADGestureDidLaunch, launchNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, GADGestureDidBecomeActive, activeNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(center, NULL, GADGestureDidDeactivate, inactiveNotification, NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    CFRelease(launchNotification);
    CFRelease(activeNotification);
    CFRelease(inactiveNotification);
    GADClearGestureString(launch);
    GADClearGestureString(active);
    GADClearGestureString(inactive);
}

int GetDeviceOrientation(void)
{
    int orientation = -1;
    char *className = DECODE_GESTURE_NAME(deviceClass);
    char *current = DECODE_GESTURE_NAME(currentDeviceSelector);
    char *selector = DECODE_GESTURE_NAME(orientationSelector);
    if (IsDeviceOrientationEnabled()) {
        id device = objc_msgSend((id)objc_lookUpClass(className), sel_registerName(current));
        int (*getOrientation)(id, SEL) = (void *)objc_msgSend;
        orientation = getOrientation(device, sel_registerName(selector));
    }
    GADClearGestureString(className);
    GADClearGestureString(current);
    GADClearGestureString(selector);
    return orientation;
}

int ObfuscateBinaryValue(bool value)
{
    int result = rand() % 64 + 1;
    int mask = 16;
    if (value)
        result |= mask;
    else
        result &= mask ^ -1;
    return result;
}

extern void ad_transform_block(const uint32_t *input, uint32_t *output);

bool GADTransformSignalBlock(const uint32_t *input, uint32_t *output)
{
    if (!input || !output)
        return false;
    ad_transform_block(input, output);
    return true;
}

extern CFStringRef GetHintTrace(void);
extern CFStringRef CopyParentMethodFromCallStack(CFStringRef trace);

CFStringRef GADCopyParentMethod(void)
{
    CFStringRef trace = GetHintTrace();
    return CopyParentMethodFromCallStack(trace);
}

extern int GatherSignals(unsigned mask, CFStringRef input, CFMutableStringRef output);

bool gad_gmcs(CFStringRef input, CFMutableStringRef output)
{
    if (!output)
        return false;
    CFMutableStringRef signals = CFStringCreateMutable(kCFAllocatorDefault, 0);
    if (!GatherSignals(0x3bff, input, signals))
        CFStringAppendFormat(output, NULL, CFSTR("ms=%d"), 5);
    else
        CFStringAppendFormat(output, NULL, CFSTR("ms=%@"), signals);
    CFRelease(signals);
    return true;
}

bool gad_gmrs(CFMutableStringRef output)
{
    if (!output)
        return false;
    CFMutableStringRef signals = CFStringCreateMutable(kCFAllocatorDefault, 0);
    if (!signals)
        return false;
    if (!GatherSignals(0xe000, NULL, signals))
        CFStringAppendFormat(output, NULL, CFSTR("ms=%d"), 5);
    else
        CFStringAppendFormat(output, NULL, CFSTR("ms=%@"), signals);
    CFRelease(signals);
    return true;
}

static const char *signalSystemInfo = "SystemInfo";
static const char *signalVersionNumber = "VersionNumber";
static const char *signalEventTime = "EventTime";
static const char *signalIsAppActive = "IsAppActive";
static const char *signalBatteryState = "BatteryState";
static const char *signalBatteryLevel = "BatteryLevel";
static const char *signalAppActiveTime = "AppActiveTime";
static const char *signalAppUpTime = "AppUpTime";
static const char *signalAppUsage = "AppUsage";
static const char *signalNetworkType = "NetworkType";
static const char *signalOrientation = "Orientation";
static const char *signalStacktrace = "Stacktrace";
static const char *signalTouchX = "TouchX";
static const char *signalTouchY = "TouchY";
static const char *signalTouchD = "TouchD";
static const char *signalBannerViewName = "0d50a0ffbe3e52578fab1c9007e2335826674642ea852936c38fb07820c1eee80b43640967d27ae226";
static const char *signalAdVisibility = "AdVisibility";
static const char *signalJailBreak = "JailBreak";
static const char *signalApplicationsPath = "655094cdb3395f5389941a9b03f7";
static const char *signalSwizzle = "Swizzle";
static const char *signalDeviceID = "DeviceID";
static const char *signalDeviceIDType = "DeviceIDType";
static const char *signalDeviceIDOptOut = "DeviceIDOptOut";
static const char *signalScreenWidth = "ScreenWidth";
static const char *signalScreenHeight = "ScreenHeight";
static const char *signalTimeZoneOffset = "TimeZoneOffset";

typedef struct {
    CFStringRef identifier;
    int type;
    bool optedOut;
} GADGestureDeviceID;

typedef struct {
    int width;
    int height;
} GADScreenDimensions;

extern GADGestureDeviceID GetDeviceID(void);
extern GADScreenDimensions GetScreenDimensions(void);
extern int GetTimeZoneUTCOffsetMinutesPlusOneDay(void);
extern int GetAdVisibility(const char *className);
extern int CheckJailBreakStatus(void);
extern int FindSwizzling(const char *path);

enum {
    GADSignalActive = 1u << 0,
    GADSignalBattery = 1u << 1,
    GADSignalActiveTime = 1u << 2,
    GADSignalNetwork = 1u << 3,
    GADSignalOrientation = 1u << 4,
    GADSignalStacktrace = 1u << 5,
    GADSignalTouch = 1u << 6,
    GADSignalUptime = 1u << 7,
    GADSignalVisibility = 1u << 8,
    GADSignalSwizzling = 1u << 9,
    GADSignalJailBreak = 1u << 11,
    GADSignalFirstUse = 1u << 12,
    GADSignalDeviceID = 1u << 13,
    GADSignalScreenSize = 1u << 14,
    GADSignalTimeZone = 1u << 15,
};

int GatherSignals(unsigned mask, CFStringRef key, CFMutableStringRef output)
{
    int count = 0;
    if (!output || !mask)
        return count;
    if (!gestureInitialized)
        gad_gig(CFSTR("missing"));
    GADWireBuffer *buffer = SimpleWireFormatMakeBuffer(256);
    CFStringRef system = CopySystemInformation();
    if (system) {
        GADWriteStringSignal(1, signalSystemInfo, system, output, buffer);
        CFRelease(system);
    }
    if (gestureIdentifier)
        GADWriteStringSignal(2, signalVersionNumber, gestureIdentifier, output, buffer);
    GADWriteIntegerSignal(25, signalEventTime, time(NULL), output, buffer);

    if (mask & GADSignalActive) {
        GADWriteIntegerSignal(3, signalIsAppActive, ObfuscateBinaryValue(IsAppActive()), output, buffer);
        ++count;
    }
    if (mask & GADSignalBattery) {
        GADWriteIntegerSignal(5, signalBatteryState, GetDeviceBatteryState(), output, buffer);
        GADWriteIntegerSignal(6, signalBatteryLevel, GetDeviceBatteryLevel(), output, buffer);
        ++count;
    }
    if ((mask & GADSignalUptime) || (mask & GADSignalActiveTime) || (mask & GADSignalFirstUse)) {
        int uptime, activeTime, first;
        GetAppUsageTime(&first, &uptime, &activeTime);
        if (mask & GADSignalActiveTime) {
            GADWriteIntegerSignal(4, signalAppActiveTime, activeTime, output, buffer);
            ++count;
        }
        if (mask & GADSignalUptime) {
            GADWriteIntegerSignal(17, signalAppUpTime, uptime, output, buffer);
            ++count;
        }
        if (mask & GADSignalFirstUse) {
            GADWriteIntegerSignal(23, signalAppUsage, first, output, buffer);
            ++count;
        }
    }
    if (mask & GADSignalNetwork) {
        GADWriteIntegerSignal(11, signalNetworkType, GetNetworkType(), output, buffer);
        ++count;
    }
    if (mask & GADSignalOrientation) {
        GADWriteIntegerSignal(12, signalOrientation, GetDeviceOrientation(), output, buffer);
        ++count;
    }
    if (mask & GADSignalStacktrace) {
        CFStringRef parent = GADCopyParentMethod();
        if (parent) {
            GADWriteStringSignal(13, signalStacktrace, parent, output, buffer);
            ++count;
            CFRelease(parent);
        }
    }
    if (mask & GADSignalTouch) {
        GADWriteIntegerSignal(14, signalTouchX, touchX, output, buffer);
        GADWriteIntegerSignal(15, signalTouchY, touchY, output, buffer);
        GADWriteIntegerSignal(16, signalTouchD, touchDuration, output, buffer);
        ++count;
    }
    if (mask & GADSignalVisibility) {
        char *name = DECODE_GESTURE_NAME(signalBannerViewName);
        GADWriteIntegerSignal(18, signalAdVisibility, GetAdVisibility(name), output, buffer);
        ++count;
        GADClearGestureString(name);
    }
    if (mask & GADSignalJailBreak) {
        GADWriteIntegerSignal(22, signalJailBreak, CheckJailBreakStatus(), output, buffer);
        ++count;
    }
    if (mask & GADSignalSwizzling) {
        char *path = DECODE_GESTURE_NAME(signalApplicationsPath);
        GADWriteIntegerSignal(19, signalSwizzle, FindSwizzling(path), output, buffer);
        ++count;
        GADClearGestureString(path);
    }
    if (mask & GADSignalDeviceID) {
        GADGestureDeviceID device = GetDeviceID();
        if (device.identifier) {
            GADWriteStringSignal(24, signalDeviceID, device.identifier, output, buffer);
            GADWriteIntegerSignal(26, signalDeviceIDType, device.type, output, buffer);
            GADWriteIntegerSignal(28, signalDeviceIDOptOut, device.optedOut ? 1 : 0, output, buffer);
            ++count;
        }
    }
    if (mask & GADSignalScreenSize) {
        GADScreenDimensions dimensions = GetScreenDimensions();
        GADWriteIntegerSignal(31, signalScreenWidth, dimensions.width, output, buffer);
        GADWriteIntegerSignal(32, signalScreenHeight, dimensions.height, output, buffer);
        ++count;
    }
    if (mask & GADSignalTimeZone) {
        GADWriteIntegerSignal(33, signalTimeZoneOffset, GetTimeZoneUTCOffsetMinutesPlusOneDay(), output, buffer);
        ++count;
    }
    CFStringRef result = GetEncryptedData(buffer->bytes, buffer->cursor - buffer->bytes, key);
    if (result)
        CFStringAppend(output, result);
    else
        CFStringAppendFormat(output, NULL, CFSTR("%d"), 7);
    SimpleWireFormatFreeBuffer(buffer);
    return count;
}

#include "gad_gesture_introspection.inc"
#include "gad_gesture_encryption.inc"
