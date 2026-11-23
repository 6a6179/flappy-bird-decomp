#import <UIKit/UIKit.h>
typedef struct GADAdSize { CGSize size; unsigned flags; } GADAdSize;

@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end

@interface GADCustomEventExtras : NSObject {
    NSMutableDictionary *extras_;
}
- (id)extrasForLabel:(NSString *)label;
@end

@class GADMAdNetworkConfig;
@interface GADMAdNetworkConnector : NSObject
- (NSNumber *)childDirectedTreatment;
- (GADMAdNetworkConfig *)networkConfig;
- (NSString *)publisherId;
- (UIViewController *)viewControllerForPresentingModalView;
- (NSDictionary *)credentials;
- (void)adapter:(id)adapter didFailAd:(NSError *)error;
- (void)adapter:(id)adapter didFailInterstitial:(NSError *)error;
- (int)userGender;
- (NSDate *)userBirthday;
- (BOOL)userHasLocation;
- (float)userLatitude;
- (float)userLongitude;
- (float)userLocationAccuracyInMeters;
- (NSString *)userLocationDescription;
- (NSArray *)userKeywords;
- (GADCustomEventExtras *)networkExtras;
- (BOOL)testMode;
@end

@interface GADCustomEventRequest : NSObject {
    int userGender_;
    NSDate *userBirthday_;
    BOOL userHasLocation_;
    float userLongitude_, userLatitude_, userLocationAccuracyInMeters_;
    NSString *userLocationDescription_;
    NSArray *userKeywords_;
    NSDictionary *additionalParameters_;
    BOOL isTesting_;
}
- (id)initWithConnector:(GADMAdNetworkConnector *)connector;
@end

@protocol GADCustomEventBanner <NSObject>
- (void)setDelegate:(id)delegate;
- (void)requestBannerAd:(GADAdSize)size parameter:(NSString *)parameter label:(NSString *)label
                request:(GADCustomEventRequest *)request;
@end
@protocol GADCustomEventInterstitial <NSObject>
- (void)setDelegate:(id)delegate;
- (void)requestInterstitialAdWithParameter:(NSString *)parameter label:(NSString *)label
                                   request:(GADCustomEventRequest *)request;
@end

@interface GADMAdapterCustomEvents : NSObject {
    GADMAdNetworkConnector *_connector;
    id _customEventBanner, _customEventInterstitial;
}
- (GADMAdNetworkConnector *)connector;
- (void)setCustomEventBanner:(id)event;
- (void)setCustomEventInterstitial:(id)event;
@end

@implementation GADMAdapterCustomEvents
- (id)initWithGADMAdNetworkConnector:(GADMAdNetworkConnector *)connector
{
    self = [super init];
    if (self)
        _connector = connector;
    return self;
}

- (void)callBackToConnectorWithError:(NSString *)message isInterstitial:(BOOL)interstitial
{
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey:message};
    NSError *error = [NSError errorWithDomain:@"ad_mediation" code:1 userInfo:userInfo];
    if (interstitial)
        [[self connector] adapter:self didFailInterstitial:error];
    else
        [[self connector] adapter:self didFailAd:error];
}

- (id)customEventWithCredentials:(NSDictionary *)credentials isInterstitial:(BOOL)interstitial
{
    NSString *name = [[[self connector] credentials] objectForKey:@"class_name"];
    if (!name) {
        [self callBackToConnectorWithError:@"No class name for the Custom Event." isInterstitial:interstitial];
        return nil;
    }
    Class event = NSClassFromString(name);
    if (!event) {
        NSString *reason = [NSString stringWithFormat:@"Cannot find Custom Event class named %@.", name];
        [self callBackToConnectorWithError:reason isInterstitial:interstitial];
        [GADMacros pubLog:[NSString stringWithFormat:@"%@", reason]];
        return nil;
    }
    return [[[event alloc] init] autorelease];
}

- (void)getBannerWithSize:(GADAdSize)size
{
    id<GADCustomEventBanner> event = [self customEventWithCredentials:[[self connector] credentials] isInterstitial:NO];
    if (!event)
        return;
    GADCustomEventRequest *request = [[[GADCustomEventRequest alloc] initWithConnector:[self connector]] autorelease];
    Protocol *protocol = @protocol(GADCustomEventBanner);
    if (![event conformsToProtocol:protocol]) {
        NSString *reason = [NSString stringWithFormat:@"Custom Event class %@ does not conform to the %@ protocol.",
                            NSStringFromClass([event class]), NSStringFromProtocol(protocol)];
        [self callBackToConnectorWithError:reason isInterstitial:NO];
        [GADMacros pubLog:[NSString stringWithFormat:@"%@", reason]];
        return;
    }
    NSString *parameter = [[[self connector] credentials] objectForKey:@"parameter"];
    NSString *label = [[[self connector] credentials] objectForKey:@"label"];
    [event setDelegate:self];
    [event requestBannerAd:size parameter:parameter label:label request:request];
    [self setCustomEventBanner:event];
}

- (void)getInterstitial
{
    id<GADCustomEventInterstitial> event = [self customEventWithCredentials:[[self connector] credentials] isInterstitial:YES];
    if (!event)
        return;
    GADCustomEventRequest *request = [[[GADCustomEventRequest alloc] initWithConnector:[self connector]] autorelease];
    Protocol *protocol = @protocol(GADCustomEventInterstitial);
    if (![event conformsToProtocol:protocol]) {
        NSString *reason = [NSString stringWithFormat:@"Custom Event class %@ does not conform to the %@ protocol.",
                            NSStringFromClass([event class]), NSStringFromProtocol(protocol)];
        [self callBackToConnectorWithError:reason isInterstitial:YES];
        [GADMacros pubLog:[NSString stringWithFormat:@"%@", reason]];
        return;
    }
    NSString *parameter = [[[self connector] credentials] objectForKey:@"parameter"];
    NSString *label = [[[self connector] credentials] objectForKey:@"label"];
    [event setDelegate:self];
    [event requestInterstitialAdWithParameter:parameter label:label request:request];
    [self setCustomEventInterstitial:event];
}
@end

@implementation GADCustomEventRequest
- (id)initWithConnector:(GADMAdNetworkConnector *)connector
{
    self = [super init];
    if (self) {
        userGender_ = [connector userGender];
        userBirthday_ = [[connector userBirthday] retain];
        userHasLocation_ = [connector userHasLocation];
        userLatitude_ = [connector userLatitude];
        userLongitude_ = [connector userLongitude];
        userLocationAccuracyInMeters_ = [connector userLocationAccuracyInMeters];
        userLocationDescription_ = [[connector userLocationDescription] retain];
        userKeywords_ = [[connector userKeywords] retain];
        additionalParameters_ = [[[connector networkExtras] extrasForLabel:[[connector credentials] objectForKey:@"label"]] retain];
        isTesting_ = [connector testMode];
    }
    return self;
}
@end

@implementation GADCustomEventExtras
- (id)init
{
    self = [super init];
    if (self)
        extras_ = [[NSMutableDictionary dictionary] retain];
    return self;
}

- (void)dealloc
{
    [extras_ release];
    extras_ = nil;
    [super dealloc];
}

- (void)setExtras:(NSDictionary *)extras forLabel:(NSString *)label
{
    if (label)
        [extras_ setValue:extras forKey:label];
    else
        [GADMacros pubLog:[NSString stringWithFormat:@"Must specify a label for extras."]];
}
@end

@interface GADMAdNetworkConfig : NSObject
- (NSDictionary *)extras;
- (id)ad;
@end
@interface GADAdMobExtras : NSObject
@property (nonatomic, copy) NSDictionary *additionalParameters;
@end
@interface GADDevice : NSObject
+ (GADDevice *)currentDevice;
- (NSString *)deviceIdentifier;
@end
@interface GADRequest : NSObject
+ (GADRequest *)request;
- (void)setTestDevices:(NSArray *)devices;
- (void)tagForChildDirectedTreatment:(BOOL)value;
- (void)setGender:(int)gender;
- (void)setBirthday:(NSDate *)birthday;
- (void)setKeywords:(NSMutableArray *)keywords;
- (void)setLocationWithLatitude:(float)latitude longitude:(float)longitude accuracy:(float)accuracy;
- (void)setLocationWithDescription:(NSString *)description;
- (void)registerAdNetworkExtras:(id)extras;
@end
@interface GADBannerView : UIView
- (id)initWithAdSize:(GADAdSize)size;
- (void)setAdSize:(GADAdSize)size;
- (void)setAdUnitID:(NSString *)identifier;
- (void)setDelegate:(id)delegate;
- (void)setRootViewController:(UIViewController *)controller;
- (void)loadRequest:(GADRequest *)request;
@end

extern NSString *const kGADAdMobExtrasKeyAd;

@interface GADMAdapterGoogleAdMobAds : NSObject {
    GADBannerView *_banner;
    id _interstitial;
    GADMAdNetworkConnector *_connector;
}
- (GADMAdNetworkConnector *)connector;
- (GADBannerView *)banner;
- (void)setBanner:(GADBannerView *)view;
@end

@implementation GADMAdapterGoogleAdMobAds
- (GADRequest *)request
{
    GADRequest *request = [GADRequest request];
    if ([[self connector] testMode])
        [request setTestDevices:@[@"Simulator", [[GADDevice currentDevice] deviceIdentifier]]];
    if ([[self connector] childDirectedTreatment])
        [request tagForChildDirectedTreatment:[[[self connector] childDirectedTreatment] boolValue]];
    [request setGender:[[self connector] userGender]];
    [request setBirthday:[[self connector] userBirthday]];
    if ([[self connector] userHasLocation]) {
        [request setLocationWithLatitude:[[self connector] userLatitude]
                               longitude:[[self connector] userLongitude]
                                accuracy:[[self connector] userLocationAccuracyInMeters]];
    } else {
        NSString *location = [[self connector] userLocationDescription];
        if (location)
            [request setLocationWithDescription:location];
    }
    [request setKeywords:[[[[self connector] userKeywords] mutableCopy] autorelease]];

    NSDictionary *existing = [(GADAdMobExtras *)[[self connector] networkExtras] additionalParameters];
    NSMutableDictionary *parameters;
    if (existing)
        parameters = [[existing mutableCopy] autorelease];
    else
        parameters = [[[NSMutableDictionary alloc] init] autorelease];
    id houseAd = [[[self connector] credentials] objectForKey:@"mad_hac"];
    if (houseAd)
        [parameters setValue:houseAd forKey:@"mad_hac"];
    [parameters setValue:@"1" forKey:@"gw"];

    NSDictionary *extras = [[[self connector] networkConfig] extras];
    for (id key in extras) {
        id value = [extras objectForKey:key];
        if ([key isKindOfClass:[NSString class]] && [value isKindOfClass:[NSString class]])
            [parameters setValue:value forKey:key];
    }
    id ad = [[[self connector] networkConfig] ad];
    if (ad)
        [parameters setValue:ad forKey:kGADAdMobExtrasKeyAd];
    GADAdMobExtras *adMobExtras = [[[GADAdMobExtras alloc] init] autorelease];
    [adMobExtras setAdditionalParameters:parameters];
    [request registerAdNetworkExtras:adMobExtras];
    return request;
}

- (id)initWithGADMAdNetworkConnector:(GADMAdNetworkConnector *)connector
{
    self = [super init];
    if (self)
        _connector = connector;
    return self;
}

- (void)getBannerWithSize:(GADAdSize)size
{
    GADRequest *request = [self request];
    [self setBanner:[[[GADBannerView alloc] initWithAdSize:size] autorelease]];
    [[self banner] setAdUnitID:[[self connector] publisherId]];
    [[self banner] setDelegate:self];
    [[self banner] setRootViewController:[[self connector] viewControllerForPresentingModalView]];
    [[self banner] loadRequest:request];
}

- (void)changeAdSizeTo:(GADAdSize)size
{
    [[self banner] setAdSize:size];
}
@end
