#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AdSupport/ASIdentifierManager.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#include <sys/utsname.h>

@interface GADNetworkChecker : NSObject
+ (id)sharedChecker;
- (int)networkType;
@end

@interface GADApplication : NSObject
+ (id)sharedApplication;
- (id)iTunesMetadata;
@end

@interface NSString (GADDeviceFormatting)
- (NSString *)gad_MD5String;
+ (NSString *)gad_shortStringWithCGFloat:(CGFloat)value;
@end

@interface GADDevice : NSObject {
    NSUserDefaults *_userDefaults;
    CTTelephonyNetworkInfo *_telephonyNetworkInfo;
    NSString *_cachedAdvertisingID;
    NSString *_cachedMD5AdvertisingID;
}
@property (nonatomic, retain) NSUserDefaults *userDefaults;
@property (nonatomic, retain) CTTelephonyNetworkInfo *telephonyNetworkInfo;
@property (nonatomic, copy) NSString *cachedAdvertisingID, *cachedMD5AdvertisingID;
+ (id)currentDevice;
- (NSString *)osVersion;
- (NSString *)deviceModel;
@end

extern NSString *const kGADParameterApplicationName;
extern NSString *const kGADParameterAudioOutput;
extern NSString *const kGADParameterBaseSdkVersion;
extern NSString *const kGADParameterCapabilitiesBookstore;
extern NSString *const kGADParameterDeviceModel;
extern NSString *const kGADParameterDeviceSubmodel;
extern NSString *const kGADParameterJailbroken;
extern NSString *const kGADParameterLocale;
extern NSString *const kGADParameterScreenDensity;
extern NSString *const kGADParameterScreenHeight;
extern NSString *const kGADParameterScreenOrientation;
extern NSString *const kGADParameterScreenWidth;
extern NSString *const kGADParameteriOSRadio;
extern NSString *const kGADParameteriPadCompatibilityMode;
extern NSString *const kGADParameteriTunesMetadata;

enum {
    GADAudioRouteSpeaker = 1,
    GADAudioRouteHeadphones = 2,
    GADAudioRouteNoOutput = 3,
    GADAudioRouteOther = 5
};

static inline NSString *DeviceDimensionString(CGFloat dimension)
{
    return [NSString gad_shortStringWithCGFloat:dimension];
}

static inline void AddDeviceParameter(NSMutableDictionary *parameters, NSString *key, id value)
{
    if (value)
        [parameters setObject:value forKey:key];
}

static BOOL deviceJailbroken;
static dispatch_once_t deviceOnce;
static GADDevice *sharedDevice;
static dispatch_once_t sdkOnce;
static NSString *baseSDKVersion;
static dispatch_once_t jailbreakOnce;
static dispatch_once_t modelOnce;
static NSString *cachedSubmodel;
static dispatch_once_t localeOnce;
static NSString *cachedLocale;

@implementation GADDevice

@synthesize userDefaults = _userDefaults;
@synthesize telephonyNetworkInfo = _telephonyNetworkInfo;
@synthesize cachedAdvertisingID = _cachedAdvertisingID;
@synthesize cachedMD5AdvertisingID = _cachedMD5AdvertisingID;

+ (id)currentDevice
{
    dispatch_once(&deviceOnce, ^{
        sharedDevice = [[self alloc] init];
    });
    return sharedDevice;
}

- (id)init
{
    if ((self = [super init]))
        _telephonyNetworkInfo = [[CTTelephonyNetworkInfo alloc] init];
    return self;
}

- (void)dealloc
{
    [_telephonyNetworkInfo release];
    [_cachedAdvertisingID release];
    [_cachedMD5AdvertisingID release];
    [super dealloc];
}

- (NSString *)baseSdkVersion
{
    dispatch_once(&sdkOnce, ^{
        @try {
            CFBundleRef bundle = CFBundleGetMainBundle();
            if (bundle) {
                CFDictionaryRef info = CFBundleGetInfoDictionary(bundle);
                NSString *name = (NSString *)CFDictionaryGetValue(info, CFSTR("DTSDKName"));
                if ([name isKindOfClass:[NSString class]])
                    baseSDKVersion = name;
                NSString *platform = (NSString *)CFDictionaryGetValue(info, CFSTR("DTPlatformName"));
                if ([platform isKindOfClass:[NSString class]])
                    baseSDKVersion = [baseSDKVersion
                        stringByReplacingOccurrencesOfString:platform withString:@""];
            }
        } @catch (NSException *exception) {
        }
        [baseSDKVersion retain];
    });
    return baseSDKVersion;
}

+ (void)getOSMajor:(int *)major minor:(int *)minor bugFix:(int *)bugFix
{
    NSString *version = [[GADDevice currentDevice] osVersion];
    NSArray *components = [version componentsSeparatedByString:@"."];
    if (major) {
        if ([components count])
            *major = [[components objectAtIndex:0] integerValue];
        else
            *major = 0;
    }
    if (minor) {
        if ([components count] > 1)
            *minor = [[components objectAtIndex:1] integerValue];
        else
            *minor = 0;
    }
    if (bugFix) {
        if ([components count] > 2)
            *bugFix = [[components objectAtIndex:2] integerValue];
        else
            *bugFix = 0;
    }
}

+ (BOOL)isOSAtLeastMajor:(int)major minor:(int)minor bug:(int)bug
{
    int osMajor, osMinor, osBug;
    [self getOSMajor:&osMajor minor:&osMinor bugFix:&osBug];
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

+ (BOOL)osIsSupported
{
    return [self isOSAtLeastMajor:4 minor:3 bug:0];
}

- (NSDictionary *)canOpenURLs:(NSArray *)urls
{
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:[urls count]];
    UIApplication *application = [UIApplication sharedApplication];
    for (NSString *url in urls) {
        BOOL canOpen = [application canOpenURL:[NSURL URLWithString:url]];
        [result setObject:[NSNumber numberWithBool:canOpen] forKey:url];
    }
    return result;
}

- (BOOL)isJailbroken
{
    dispatch_once(&jailbreakOnce, ^{
        @try {
            // The supplied executable contains this spelling in its NSString pool.
            if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/Czdjb.bpp"])
                deviceJailbroken = YES;
        } @catch (NSException *exception) {
        }
    });
    return deviceJailbroken;
}

- (NSString *)osVersion
{
    return [[UIDevice currentDevice] systemVersion];
}

- (NSString *)deviceIdentifier
{
    if ([[self class] isOSAtLeastMajor:6 minor:0 bug:0]) {
        NSString *identifier = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
        if (identifier) {
            @synchronized(self) {
                if (![[self cachedAdvertisingID] isEqualToString:identifier]) {
                    [self setCachedAdvertisingID:identifier];
                    [self setCachedMD5AdvertisingID:[[self cachedAdvertisingID] gad_MD5String]];
                }
                return [self cachedMD5AdvertisingID];
            }
        }
    }
    return @"";
}

- (BOOL)deviceOptedOut
{
    return [[self class] isOSAtLeastMajor:6 minor:0 bug:0] &&
        ![[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
}

- (NSString *)deviceModel
{
    return [[UIDevice currentDevice] model];
}

- (NSString *)deviceSubmodel
{
    dispatch_once(&modelOnce, ^{
        struct utsname model;
        uname(&model);
        cachedSubmodel = [[NSString stringWithCString:model.machine
                                                       encoding:NSASCIIStringEncoding] retain];
    });
    return cachedSubmodel;
}

- (NSString *)locale
{
    dispatch_once(&localeOnce, ^{
        @try {
            NSArray *languages = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
            cachedLocale = [[[languages objectAtIndex:0] lowercaseString] retain];
        } @catch (NSException *exception) {
        }
    });
    return cachedLocale;
}

- (NSUInteger)audioRouteUsingAVAudioSession
{
    NSArray *outputs = [[[AVAudioSession sharedInstance] currentRoute] outputs];
    if ([outputs count] == 0)
        return GADAudioRouteNoOutput;
    if ([outputs count] > 1)
        return GADAudioRouteOther;
    NSString *port = [[outputs objectAtIndex:0] portName];
    if ([port isEqualToString:AVAudioSessionPortHeadphones])
        return GADAudioRouteHeadphones;
    if ([port isEqualToString:AVAudioSessionPortBuiltInSpeaker])
        return GADAudioRouteSpeaker;
    return GADAudioRouteOther;
}

- (NSUInteger)audioRouteUsingAudioToolkit
{
    OSStatus result = AudioSessionInitialize(NULL, NULL, NULL, NULL);
    if (result != noErr && result != kAudioSessionAlreadyInitialized)
        return GADAudioRouteSpeaker;
    NSString *route = nil;
    UInt32 size = sizeof(route);
    result = AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &size, &route);
    [route autorelease];
    if (result != noErr)
        return GADAudioRouteSpeaker;
    if (![route length])
        return GADAudioRouteNoOutput;
    if ([route isEqualToString:@"Headphone"] || [route isEqualToString:@"Headset"])
        return GADAudioRouteHeadphones;
    if ([route isEqualToString:@"Speaker"])
        return GADAudioRouteSpeaker;
    return GADAudioRouteOther;
}

- (NSUInteger)audioRoute
{
    if ([[AVAudioSession sharedInstance] respondsToSelector:@selector(currentRoute)])
        return [self audioRouteUsingAVAudioSession];
    return [self audioRouteUsingAudioToolkit];
}

- (BOOL)isOrientationLandscape
{
    UIApplication *app = [UIApplication sharedApplication];
    return [app statusBarOrientation] == UIInterfaceOrientationLandscapeRight ||
        [app statusBarOrientation] == UIInterfaceOrientationLandscapeLeft;
}

- (CGFloat)screenDensity
{
    UIScreen *screen = [UIScreen mainScreen];
    return [screen respondsToSelector:@selector(scale)] ? [screen scale] : 1.0f;
}

- (CGSize)screenSize
{
    return [[UIScreen mainScreen] bounds].size;
}

- (NSString *)currentRadioAccessTechnology
{
    if ([GADDevice isOSAtLeastMajor:7 minor:0 bug:0] &&
        [[GADNetworkChecker sharedChecker] networkType] == 3)
        return [[self telephonyNetworkInfo] currentRadioAccessTechnology];
    return nil;
}

- (NSDictionary *)parameters
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:15];
    if ([[self deviceModel] isEqualToString:@"iPad"] &&
        [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        [parameters setObject:@"1" forKey:kGADParameteriPadCompatibilityMode];
    AddDeviceParameter(parameters, kGADParameteriTunesMetadata, [[GADApplication sharedApplication] iTunesMetadata]);
    AddDeviceParameter(parameters, kGADParameterBaseSdkVersion, [self baseSdkVersion]);

    NSMutableString *app = [NSMutableString string];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
    if (version)
        [app appendFormat:@"%@.", version];
    [app appendFormat:@"iphone.%@", [[NSBundle mainBundle] bundleIdentifier]];
    AddDeviceParameter(parameters, kGADParameterApplicationName, app);

    NSString *audio = [NSString stringWithFormat:@"%lu", (unsigned long)[self audioRoute]];
    BOOL landscape = [self isOrientationLandscape];
    if ([self isJailbroken])
        [parameters setObject:@"1" forKey:kGADParameterJailbroken];
    AddDeviceParameter(parameters, kGADParameterDeviceModel, [self deviceModel]);
    AddDeviceParameter(parameters, kGADParameterDeviceSubmodel, [self deviceSubmodel]);
    AddDeviceParameter(parameters, kGADParameterLocale, [self locale]);
    AddDeviceParameter(parameters, kGADParameterAudioOutput, audio);
    [parameters setObject:landscape ? @"l" : @"p" forKey:kGADParameterScreenOrientation];
    AddDeviceParameter(parameters, kGADParameteriOSRadio, [self currentRadioAccessTechnology]);
    AddDeviceParameter(parameters, kGADParameterScreenDensity, DeviceDimensionString([self screenDensity]));
    AddDeviceParameter(parameters, kGADParameterScreenWidth, DeviceDimensionString([self screenSize].width));
    AddDeviceParameter(parameters, kGADParameterScreenHeight, DeviceDimensionString([self screenSize].height));

    NSDictionary *stores = [self canOpenURLs:@[@"itms-books://", @"kindle://home"]];
    NSUInteger supported = [[stores objectForKey:@"itms-books://"] boolValue] ? 1 : 0;
    if ([[stores objectForKey:@"kindle://home"] boolValue])
        supported |= 2;
    if (supported)
        AddDeviceParameter(parameters, kGADParameterCapabilitiesBookstore, [NSNumber numberWithUnsignedInteger:supported]);
    return parameters;
}

@end
