#import <UIKit/UIKit.h>
#import <float.h>
#import <math.h>

typedef struct GADAdSize { CGSize size; unsigned flags; } GADAdSize;
extern const GADAdSize kGADAdSizeInvalid;
extern BOOL GADAdSizeEqualToSize(GADAdSize a, GADAdSize b);
extern BOOL IsGADAdSizeValid(GADAdSize size);
extern NSString *NSStringFromGADAdSize(GADAdSize size);

@interface GADAdType : NSObject {
    BOOL _isInterstitial;
    GADAdSize _adSize;
}
@property (nonatomic, readonly) BOOL isInterstitial;
@property (nonatomic) GADAdSize adSize;
- (id)initWithAdSize:(GADAdSize)size;
- (id)initForInterstitial;
@end

@implementation GADAdType

@synthesize isInterstitial = _isInterstitial;
@synthesize adSize = _adSize;

- (id)initWithAdSize:(GADAdSize)size
{
    if ((self = [super init]))
        _adSize = size;
    return self;
}

- (id)initForInterstitial
{
    if ((self = [self initWithAdSize:kGADAdSizeInvalid]))
        _isInterstitial = YES;
    return self;
}

+ (id)bannerAdTypeForSize:(GADAdSize)size
{
    return [[[GADAdType alloc] initWithAdSize:size] autorelease];
}

+ (id)interstitialAdType
{
    return [[[GADAdType alloc] initForInterstitial] autorelease];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GADAdType class]])
        return NO;
    GADAdType *other = object;
    if ([other isInterstitial] && [self isInterstitial])
        return YES;
    return GADAdSizeEqualToSize([other adSize], [self adSize]);
}

- (BOOL)isValid
{
    if ([self isInterstitial])
        return YES;
    return IsGADAdSizeValid([self adSize]);
}

- (NSString *)description
{
    if ([self isInterstitial])
        return [NSString stringWithFormat:@"%@ interstitial type", NSStringFromClass([self class])];
    return [NSString stringWithFormat:@"%@ banner with size: %@", NSStringFromClass([self class]),
                                      NSStringFromGADAdSize([self adSize])];
}

@end

@interface GADLocation : NSObject <NSCopying> {
    float latitude_, longitude_, accuracy_;
    double timestamp_;
    NSDictionary *dictionaryRepresentation_;
    NSString *description_;
}
@property (nonatomic, readonly) float latitude, longitude, accuracy;
@property (nonatomic) double timestamp;
- (BOOL)isPreciseLocation;
- (id)initWithLatitude:(float)latitude longitude:(float)longitude accuracy:(float)accuracy;
- (id)initWithDescription:(NSString *)description;
@end

@implementation GADLocation

@synthesize latitude = latitude_, longitude = longitude_, accuracy = accuracy_;
@synthesize timestamp = timestamp_;

- (BOOL)isPreciseLocation
{
    if (fabsf(latitude_) <= 90 && fabsf(longitude_) <= 180 &&
        fabsf(latitude_) > FLT_EPSILON && fabsf(longitude_) > FLT_EPSILON)
        return YES;
    return NO;
}

- (NSString *)description
{
    if (description_)
        return description_;
    if ([self isPreciseLocation])
        return [NSString stringWithFormat:@"%f,%f", latitude_, longitude_];
    return @"";
}

- (NSDictionary *)dictionaryRepresentation
{
    if (dictionaryRepresentation_)
        return dictionaryRepresentation_;
    if (![self isPreciseLocation])
        return nil;

    double time = [self timestamp] * 1000000.0;
    int latitude = [self latitude] * 10000000.0;
    int longitude = [self longitude] * 10000000.0;
    float radius = [self accuracy] * 1000.0f;
    dictionaryRepresentation_ = [[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithDouble:time], @"time",
        [NSNumber numberWithInt:latitude], @"lat",
        [NSNumber numberWithInt:longitude], @"long",
        [NSNumber numberWithFloat:radius], @"radius", nil] retain];
    return dictionaryRepresentation_;
}

- (id)initWithLatitude:(float)latitude longitude:(float)longitude accuracy:(float)accuracy
{
    if ((self = [super init])) {
        latitude_ = latitude;
        longitude_ = longitude;
        accuracy_ = accuracy;
        timestamp_ = CFAbsoluteTimeGetCurrent() + 978307200.0;
    }
    if (![self isPreciseLocation]) {
        [self autorelease];
        return nil;
    }
    return self;
}

- (id)initWithDescription:(NSString *)description
{
    if ((self = [super init])) {
        description_ = [description copy];
        timestamp_ = CFAbsoluteTimeGetCurrent() + 978307200.0;
    }
    if (![description length]) {
        [self autorelease];
        return nil;
    }
    return self;
}

- (void)dealloc
{
    [dictionaryRepresentation_ release];
    [description_ release];
    [super dealloc];
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[GADLocation class]])
        return NO;
    GADLocation *other = object;
    if ([self isPreciseLocation] != [other isPreciseLocation])
        return NO;
    if ([self isPreciseLocation]) {
        return fabsf([self latitude] - [other latitude]) < FLT_EPSILON &&
               fabsf([self longitude] - [other longitude]) < FLT_EPSILON &&
               fabsf([self accuracy] - [other accuracy]) < FLT_EPSILON;
    }
    return [[self description] isEqualToString:[other description]];
}

- (id)copyWithZone:(NSZone *)zone
{
    GADLocation *location;
    if ([self isPreciseLocation]) {
        location = [[GADLocation alloc] initWithLatitude:[self latitude]
                                               longitude:[self longitude]
                                                accuracy:[self accuracy]];
    } else {
        location = [[GADLocation alloc] initWithDescription:[self description]];
    }
    [location setTimestamp:[self timestamp]];
    return location;
}

@end

extern NSString *const GADRequestPublisherIDKey;
extern NSString *const GADRequestAnalyticsIDKey;
extern NSString *const GADRequestBirthdayKey;
extern NSString *const GADRequestExtrasKey;
extern NSString *const GADRequestGenderKey;
extern NSString *const GADRequestKeywordsKey;
extern NSString *const GADRequestLocationKey;
extern NSString *const GADRequestAdaptersKey;
extern NSString *const GADRequestMediationExtrasKey;
extern NSString *const GADRequestNetworkKey;
extern NSString *const GADRequestSDKVersionKey;
extern NSString *const GADRequestChildDirectedKey;
extern NSString *const GADRequestTestDeviceKey;
extern NSString *const GADRequestTestingKey;
extern void GADConfigureSignalsForSDKVersion(NSString *version);
extern int GADCopyRequestSignalFields(NSMutableString *encoded);

@interface GADApplication : NSObject
+ (id)sharedApplication;
- (void)runEarlyActivities;
@end
@interface GADDevice : NSObject
+ (id)currentDevice;
+ (BOOL)isOSAtLeastMajor:(int)major minor:(int)minor bug:(int)bug;
- (NSString *)deviceIdentifier;
- (NSDictionary *)parameters;
@end
@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end
@interface GADSharedStatistics : NSObject
+ (id)sharedInstance;
- (NSDictionary *)parameters;
@end
@interface GADMAdNetworkAdapter : NSObject
+ (NSSet *)availableAdapterNames;
@end
@interface GADNetworkChecker : NSObject
+ (id)sharedChecker;
- (NSString *)networkTypeString;
@end
@interface GADAdMobExtras : NSObject
@property (nonatomic, copy) NSDictionary *additionalParameters;
@end
@interface DFPExtras : GADAdMobExtras
- (NSString *)publisherProvidedID;
@end

@interface GADRequest : NSObject <NSCopying> {
    int _gender;
    NSDate *_birthday;
    NSMutableArray *_keywords;
    BOOL _testing;
    NSDictionary *_mediationExtras;
    NSArray *_testDevices;
}
@property (nonatomic) int gender;
@property (nonatomic, getter=isTesting) BOOL testing;
@property (nonatomic, copy) NSDictionary *mediationExtras;
@property (nonatomic, copy) NSArray *testDevices;
@property (nonatomic, retain) NSDate *birthday;
@property (nonatomic, retain) NSMutableArray *keywords;
+ (NSString *)sdkVersion;
+ (NSString *)sdkVersionIdentifiers;
+ (NSString *)sdkVersionMetadata;
- (id)additionalParameters;
- (void)setAdditionalParameters:(id)parameters;
- (id)adNetworkExtrasFor:(Class)extrasClass;
- (void)registerAdNetworkExtras:(id)extras;
- (void)removeAdNetworkExtrasFor:(Class)extrasClass;
@end

@interface GADRequestPrivate : GADRequest {
    GADLocation *_location;
    NSNumber *_childDirectedTreatment;
    NSMutableDictionary *_networkExtrasMap;
}
@property (nonatomic, retain) GADLocation *location;
@property (nonatomic, retain) NSNumber *childDirectedTreatment;
@property (nonatomic, retain) NSMutableDictionary *networkExtrasMap;
- (id)initWithRequest:(GADRequestPrivate *)request;
- (NSDictionary *)networkExtrasAdditionalParameters;
@end

struct {
    dispatch_once_t once;
    NSString *text;
} GADRequestSDKVersionCache = {0}, GADRequestExtendedVersionCache = {0};

@implementation GADRequest

@synthesize mediationExtras = _mediationExtras;
@synthesize testDevices = _testDevices;
@synthesize birthday = _birthday;
@synthesize keywords = _keywords;

- (void)setBirthdayWithMonth:(int)month day:(int)day year:(int)year
{
}

- (void)setLocationWithLatitude:(float)latitude longitude:(float)longitude accuracy:(float)accuracy
{
}

- (void)setLocationWithDescription:(id)description
{
}

- (void)addKeyword:(id)keyword
{
}

- (id)additionalParameters
{
    return nil;
}

- (void)setAdditionalParameters:(id)value
{
}

- (void)registerAdNetworkExtras:(id)extras
{
}

- (id)adNetworkExtrasFor:(Class)extrasClass
{
    return nil;
}

- (void)removeAdNetworkExtrasFor:(Class)extrasClass
{
}

- (void)tagForChildDirectedTreatment:(signed char)childDirected
{
}

- (int)gender
{
    return _gender;
}

- (void)setGender:(int)value
{
    _gender = value;
}

- (signed char)isTesting
{
    return _testing;
}

- (void)setTesting:(signed char)value
{
    _testing = value;
}

+ (id)request
{
    return [[[GADRequestPrivate alloc] init] autorelease];
}

+ (id)alloc
{
    return [GADRequestPrivate allocWithZone:0];
}

- (void)dealloc
{
    [_mediationExtras release];
    [_testDevices release];
    [_birthday release];
    [_keywords release];
    [super dealloc];
}


+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject([GADRequestPrivate class], 0, zone);
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[GADRequestPrivate alloc] initWithRequest:(GADRequestPrivate *)self];
}

+ (NSString *)sdkVersion
{
    dispatch_once(&GADRequestSDKVersionCache.once, ^{
        GADRequestSDKVersionCache.text = [[NSString alloc] initWithFormat:@"afma-sdk-i-v%d.%d.%d", 6, 8, 0];
    });
    return GADRequestSDKVersionCache.text;
}

+ (NSString *)extendedSDKVersionNumber
{
    dispatch_once(&GADRequestExtendedVersionCache.once, ^{
        GADRequestExtendedVersionCache.text = [[NSString alloc] initWithFormat:@"afma-sdk-i-v%d.%d.%d%@%@",
            6, 8, 0, [self sdkVersionIdentifiers], [self sdkVersionMetadata]];
    });
    return GADRequestExtendedVersionCache.text;
}

+ (NSString *)sdkVersionMetadata
{
    return [@"4299" length] ? [NSString stringWithFormat:@"+%@", @"4299"] : @"";
}

+ (NSString *)sdkVersionIdentifiers
{
    return [@"rc.1" length] ? [NSString stringWithFormat:@"-%@", @"rc.1"] : @"";
}

@end

@implementation GADRequestPrivate

@synthesize location = _location;
@synthesize childDirectedTreatment = _childDirectedTreatment;
@synthesize networkExtrasMap = _networkExtrasMap;

- (void)setAdditionalParameters:(id)value
{
    id result = [[[GADAdMobExtras alloc] init] autorelease];
    [result setAdditionalParameters:value];
    [self registerAdNetworkExtras:result];
}

- (id)additionalParameters
{
    return [self networkExtrasAdditionalParameters];
}

- (void)setLocationWithDescription:(id)description
{
    id initWithDescription = [[GADLocation alloc] initWithDescription:description];
    [self setLocation:initWithDescription];
    [initWithDescription release];
}

- (void)tagForChildDirectedTreatment:(signed char)childDirected
{
    [self setChildDirectedTreatment:[NSNumber numberWithBool:childDirected]];
}

- (void)dealloc
{
    [_networkExtrasMap release];
    [_location release];
    [_childDirectedTreatment release];
    [super dealloc];
}


+ (id)requestPrivateWithRequest:(GADRequest *)request
{
    if (request && [request isKindOfClass:[GADRequestPrivate class]])
        return request;
    if (!request)
        return [[[GADRequest alloc] init] autorelease];
    return nil;
}

- (void)registerAdNetworkExtras:(id)extras
{
    if (!extras) {
        [GADMacros pubLog:[NSString stringWithFormat:@"Must specify extras for %@.", NSStringFromSelector(_cmd)]];
        return;
    }
    [[self networkExtrasMap] setValue:extras forKey:NSStringFromClass([extras class])];
}

- (id)adNetworkExtrasFor:(Class)extrasClass
{
    return [[self networkExtrasMap] valueForKey:NSStringFromClass(extrasClass)];
}

- (void)removeAdNetworkExtrasFor:(Class)extrasClass
{
    [[self networkExtrasMap] removeObjectForKey:NSStringFromClass(extrasClass)];
}

- (NSDictionary *)networkExtrasAdditionalParameters
{
    DFPExtras *dfp = [self adNetworkExtrasFor:[DFPExtras class]];
    if (dfp)
        return [dfp additionalParameters];
    GADAdMobExtras *extras = [self adNetworkExtrasFor:[GADAdMobExtras class]];
    if ([[[extras additionalParameters] objectForKey:@"_useOnce"] boolValue])
        [self removeAdNetworkExtrasFor:[GADAdMobExtras class]];
    return [extras additionalParameters];
}

- (NSString *)genderString
{
    if ([self gender] == 1)
        return @"1";
    if ([self gender] == 2)
        return @"2";
    return nil;
}

- (void)setBirthdayWithMonth:(int)month day:(int)day year:(int)year
{
    NSDateComponents *components = [[[NSDateComponents alloc] init] autorelease];
    [components setMonth:month];
    [components setDay:day];
    [components setYear:year];
    NSCalendar *calendar = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    [self setBirthday:[calendar dateFromComponents:components]];
}

- (NSString *)birthdayString
{
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
    [formatter setDateFormat:@"yyyyMMdd"];
    return [formatter stringFromDate:[self birthday]];
}

- (void)setLocationWithLatitude:(float)latitude longitude:(float)longitude accuracy:(float)accuracy
{
    GADLocation *location = [[GADLocation alloc] initWithLatitude:latitude longitude:longitude accuracy:accuracy];
    [self setLocation:location];
    [location release];
}

- (void)addKeyword:(NSString *)keyword
{
    if (![keyword length])
        return;
    if ([self keywords])
        [[self keywords] addObject:keyword];
    else
        [self setKeywords:[NSMutableArray arrayWithObject:keyword]];
}

+ (int)requestTypeFromString:(NSString *)type
{
    if ([type isEqualToString:@"admob"])
        return 2;
    if ([type isEqualToString:@"xfp"])
        return 3;
    return [type isEqualToString:@"adsense"] ? 1 : 0;
}

+ (void)initialize
{
    if (self != [GADRequestPrivate class])
        return;
    [[GADApplication sharedApplication] runEarlyActivities];
    NSString *identifier = [[GADDevice currentDevice] deviceIdentifier];
    NSString *quotedID = [NSString stringWithFormat:@"@\"%@\"", identifier];
    if ([GADDevice isOSAtLeastMajor:6 minor:0 bug:0]) {
        [GADMacros pubLog:[NSString stringWithFormat:
            @"To get test ads on this device, call: request.testDevices = @[ %@ ];", quotedID]];
    } else {
        [GADMacros pubLog:[NSString stringWithFormat:@"Test ads are only available on iOS 6+."]];
    }
}

- (id)init
{
    if ((self = [super init])) {
        [self setNetworkExtrasMap:[NSMutableDictionary dictionary]];
        [self setChildDirectedTreatment:nil];
    }
    return self;
}

- (id)initWithRequest:(GADRequestPrivate *)request
{
    if ((self = [self init])) {
        self.testDevices = request.testDevices;
        self.testing = request.isTesting;
        self.networkExtrasMap = request.networkExtrasMap;
        self.mediationExtras = request.mediationExtras;
        [self setAdditionalParameters:[request additionalParameters]];
        self.gender = request.gender;
        self.birthday = request.birthday;
        self.location = request.location;
        self.keywords = request.keywords;
        self.childDirectedTreatment = request.childDirectedTreatment;
    }
    return self;
}

- (NSString *)description
{
    NSString *gender = @"";
    if ([self gender] == 1)
        gender = @"\ngender:Male";
    else if ([self gender] == 2)
        gender = @"\ngender:Female";
    NSString *birthday = [self birthday] ? [NSString stringWithFormat:@"\nbirthday:%@", [self birthday]] : @"";
    NSString *location = [self location] ? [NSString stringWithFormat:@"\nlocation:%@", [self location]] : @"";
    NSString *keywords = [self keywords] ? [NSString stringWithFormat:@"\nkeywords:%@", [self keywords]] : @"";
    NSString *extras = [self additionalParameters] ?
        [NSString stringWithFormat:@"\nadditionalParameters:%@", [self additionalParameters]] : @"";
    return [NSString stringWithFormat:@"%@<%p>: %@%@%@%@%@", NSStringFromClass([GADRequest class]), self,
                                      gender, birthday, location, keywords, extras];
}

- (NSDictionary *)analyticsIds
{
    id value = [NSClassFromString(@"GAIAdMobInfo") performSelector:@selector(adMobInfo)];
    if (!value)
        return nil;
    if ([value isKindOfClass:[NSDictionary class]])
        return value;
    return nil;
}

- (BOOL)isATestDevice
{
    NSString *identifier = [GADDevice isOSAtLeastMajor:6 minor:0 bug:0] ?
        [[GADDevice currentDevice] deviceIdentifier] : @"";
    for (NSString *device in [self testDevices]) {
        if ([device isEqualToString:identifier])
            return YES;
    }
    return NO;
}

- (NSDictionary *)spamSignals
{
    NSMutableDictionary *signals = [NSMutableDictionary dictionary];
    NSMutableString *encoded = [NSMutableString string];
    GADConfigureSignalsForSDKVersion([GADRequest sdkVersion]);
    if (GADCopyRequestSignalFields(encoded) == 1) {
        NSArray *fields = [encoded componentsSeparatedByString:@"="];
        if ([fields count] > 1) {
            NSString *key = [fields objectAtIndex:0];
            NSString *value = [fields objectAtIndex:1];
            if ([value length])
                [signals setObject:value forKey:key];
        }
    }
    return signals;
}

- (void)addDFPParameters:(NSMutableDictionary *)parameters
{
    DFPExtras *extras = [self adNetworkExtrasFor:[DFPExtras class]];
    if (extras) {
        NSString *publisherID = [[extras publisherProvidedID]
            stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([publisherID length] && publisherID)
            [parameters setObject:publisherID forKey:GADRequestPublisherIDKey];
    }
}

static inline void AddRequestParameter(NSMutableDictionary *parameters, id value, NSString *const *key)
{
    if (value)
        [parameters setObject:value forKey:*key];
}

- (NSDictionary *)parameters
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params addEntriesFromDictionary:[[GADDevice currentDevice] parameters]];
    AddRequestParameter(params, [[GADMAdNetworkAdapter availableAdapterNames] allObjects], &GADRequestAdaptersKey);
    AddRequestParameter(params, [GADRequest sdkVersion], &GADRequestSDKVersionKey);
    AddRequestParameter(params, [[GADNetworkChecker sharedChecker] networkTypeString], &GADRequestNetworkKey);
    if ([self isTesting])
        [params setObject:@"1" forKey:GADRequestTestingKey];
    if ([self isATestDevice])
        [params setObject:@"on" forKey:GADRequestTestDeviceKey];
    AddRequestParameter(params, [self additionalParameters], &GADRequestExtrasKey);
    AddRequestParameter(params, [self mediationExtras], &GADRequestMediationExtrasKey);
    AddRequestParameter(params, [self genderString], &GADRequestGenderKey);
    AddRequestParameter(params, [self birthdayString], &GADRequestBirthdayKey);
    AddRequestParameter(params, [self keywords], &GADRequestKeywordsKey);
    AddRequestParameter(params, [[self childDirectedTreatment] stringValue], &GADRequestChildDirectedKey);
    AddRequestParameter(params, [[self location] dictionaryRepresentation], &GADRequestLocationKey);
    [params addEntriesFromDictionary:[[GADSharedStatistics sharedInstance] parameters]];
    AddRequestParameter(params, [self analyticsIds], &GADRequestAnalyticsIDKey);
    NSDictionary *signals = [self spamSignals];
    for (id key in signals) {
        id value = [signals objectForKey:key];
        if (value)
            [params setObject:value forKey:key];
    }
    [self addDFPParameters:params];
    return params;
}

@end
