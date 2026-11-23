#import <AdSupport/ASIdentifierManager.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIDevice.h>
#import <stdlib.h>

#import "gad_gesture_encoding.h"

NSString *const kAppSpecificDeviceIdKey = @"madAppId";

@interface GADGestureIdUtil : NSObject {
    NSUserDefaults *userDefaults_;
}
@property (nonatomic, retain) NSUserDefaults *userDefaults;
+ (id)sharedInstance;
- (NSString *)osVersion;
@end

@implementation GADGestureIdUtil

@synthesize userDefaults = userDefaults_;

+ (id)sharedInstance
{
    static GADGestureIdUtil *instance;
    if (!instance)
        instance = [[GADGestureIdUtil alloc] init];
    return instance;
}

- (id)init
{
    if ((self = [super init]))
        userDefaults_ = [[NSUserDefaults alloc] init];
    return self;
}

- (void)dealloc
{
    [userDefaults_ release];
    [super dealloc];
}

+ (void)getOSMajor:(int *)major minor:(int *)minor bugFix:(int *)bugFix
{
    NSString *version = [[GADGestureIdUtil sharedInstance] osVersion];
    NSArray *components = [version componentsSeparatedByString:@"."];
    if (major) {
        if ([components count])
            *major = [[components objectAtIndex:0] intValue];
        else
            *major = 0;
    }
    if (minor) {
        if ([components count] > 1)
            *minor = [[components objectAtIndex:1] intValue];
        else
            *minor = 0;
    }
    if (bugFix) {
        if ([components count] > 2)
            *bugFix = [[components objectAtIndex:2] intValue];
        else
            *bugFix = 0;
    }
}

+ (BOOL)isOSAtLeastMajor:(long)major minor:(long)minor bug:(long)bug
{
    int osMajor, osMinor, osBug;
    [GADGestureIdUtil getOSMajor:&osMajor minor:&osMinor bugFix:&osBug];
    if (osMajor > major) {
        return YES;
    } else if (osMajor == major) {
        if (osMinor > minor) {
            return YES;
        } else if (osMinor == minor) {
            if (osBug >= bug)
                return YES;
        }
    }
    return NO;
}

- (NSString *)osVersion
{
    return [[UIDevice currentDevice] systemVersion];
}

- (NSString *)deviceIdentifier
{
    if ([GADGestureIdUtil isOSAtLeastMajor:6 minor:0 bug:0])
        return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *value = [userDefaults_ stringForKey:kAppSpecificDeviceIdKey];
    if (!value) {
        CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
        value = [(NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid) autorelease];
        CFRelease(uuid);
        [userDefaults_ setObject:value forKey:kAppSpecificDeviceIdKey];
    }
    return value;
}

- (NSNumber *)deviceIdentifierType
{
    if ([GADGestureIdUtil isOSAtLeastMajor:6 minor:0 bug:0])
        return [NSNumber numberWithInt:4];
    return [NSNumber numberWithInt:1];
}

- (BOOL)deviceOptedOut
{
    if ([GADGestureIdUtil isOSAtLeastMajor:6 minor:0 bug:0]) {
        ASIdentifierManager *manager = [ASIdentifierManager sharedManager];
        return ![manager isAdvertisingTrackingEnabled];
    }
    return NO;
}

@end

typedef struct {
    CFStringRef identifier;
    int type;
    bool optedOut;
} GADGestureDeviceID;

bool ComputeDigest(CFStringRef string, unsigned char *digest)
{
    if (!digest || !string)
        return false;
    bool shouldFree = false;
    const char *bytes = CFStringToCString(string, &shouldFree);
    CFIndex length = CFStringGetLength(string);
    if (!bytes)
        return false;
    GAD_MD5(bytes, length, digest);
    if (shouldFree)
        free((void *)bytes);
    return true;
}

GADGestureDeviceID GetDeviceID(void)
{
    CFStringRef identifier = NULL;
    int type = 0;
    bool optedOut = false;
    GADGestureIdUtil *util = [GADGestureIdUtil sharedInstance];
    optedOut = [util deviceOptedOut];
    CFNumberRef typeNumber = (CFNumberRef)[util deviceIdentifierType];
    if (CFNumberGetValue(typeNumber, kCFNumberIntType, &type)) {
        CFStringRef deviceID = (CFStringRef)[util deviceIdentifier];
        if (type == 0) {
            identifier = deviceID;
        } else if (type == 4) {
            unsigned char bytes[16];
            NSUUID *uuid = [[[NSUUID alloc] initWithUUIDString:(NSString *)deviceID] autorelease];
            [uuid getUUIDBytes:bytes];
            identifier = GetWebSafeEncode(bytes, sizeof(bytes));
        } else {
            unsigned char digest[16];
            if (deviceID && ComputeDigest(deviceID, digest))
                identifier = GetWebSafeEncode(digest, sizeof(digest));
        }
    }
    GADGestureDeviceID result = {identifier, type, optedOut};
    return result;
}
