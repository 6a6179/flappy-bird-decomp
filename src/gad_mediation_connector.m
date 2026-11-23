#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef struct { CGSize size; NSUInteger flags; } GADAdSize;
extern BOOL IsGADAdSizeValid(GADAdSize size);

@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end

@interface GADAdType : NSObject
- (BOOL)isInterstitial;
- (GADAdSize)adSize;
@end

@interface GADMAdNetworkConfig : NSObject
- (NSDictionary *)credentials;
- (Class)adapterClass;
@end

@interface GADLocation : NSObject
- (BOOL)isPreciseLocation;
- (float)latitude;
- (float)longitude;
- (float)accuracy;
@end

@interface NSObject (GADMConnectorMessages)
- (id)initWithGADMAdNetworkConnector:(id)connector;
- (void)getInterstitial;
- (void)getBannerWithSize:(GADAdSize)size;
- (void)stopBeingDelegate;
- (BOOL)gadmTestMode;
- (id)networkExtrasFor:(Class)type;
- (GADLocation *)userLocation;
- (void)gadmWillPresentFullScreenModal;
- (void)gadmWillDismissFullScreenModal;
- (void)gadmDidDismissFullScreenModal;
- (void)gadmWillLeaveApplication;
- (void)gadmWillPresentInterstitial;
- (void)gadmWillDismissInterstitial;
- (void)gadmDidDismissInterstitial;
- (void)reportClickFromConnector:(id)connector isRefresh:(BOOL)refresh;
- (void)reportImpressionFromConnector:(id)connector isRefresh:(BOOL)refresh;
@end

@interface GADMAdNetworkConnector : NSObject {
    id _mediationConfig;
    GADMAdNetworkConfig *_networkConfig;
    NSDictionary *_strippedCredentials;
    BOOL _shareLocation;
    id _adapter;
    id _adManager;
    id _gadmDelegate;
}
- (GADMAdNetworkConfig *)networkConfig;
- (id)adapter;
- (id)gadmDelegate;
- (id)adManager;
- (BOOL)didNetworkRefresh;
@end

@interface GADMAdNetworkConnectorBanner : GADMAdNetworkConnector
@end

@interface GADMAdNetworkConnectorInterstitial : GADMAdNetworkConnector
- (void)setCalledWillDismissInterstitial:(BOOL)flag;
- (BOOL)calledWillDismissInterstitial;
@end

@implementation GADMAdNetworkConnector
- (NSDictionary *)stripCredentials:(NSDictionary *)credentials andExtractShareLocationInto:(BOOL *)shareLocation
{
    NSMutableDictionary *stripped = [NSMutableDictionary dictionaryWithDictionary:credentials];
    NSString *setting = [stripped objectForKey:@"gwhirl_share_location"];
    [stripped removeObjectForKey:@"gwhirl_share_location"];
    if (shareLocation) *shareLocation = [setting isEqualToString:@"1"];
    if (setting && ![setting isEqualToString:@"0"]) [setting isEqualToString:@"1"];
    return stripped;
}

- (id)initWithConfig:(id)config networkConfig:(GADMAdNetworkConfig *)network
{
    if ((self = [super init])) {
        _mediationConfig = [config retain];
        _networkConfig = [network retain];
        _strippedCredentials = [[self stripCredentials:[[self networkConfig] credentials]
                           andExtractShareLocationInto:&_shareLocation] retain];
        _adapter = [[[[self networkConfig] adapterClass] alloc] initWithGADMAdNetworkConnector:self];
    }
    return self;
}

- (void)getAdFromAdapterWithType:(GADAdType *)type
{
    if (!type) return;
    if ([type isInterstitial]) {
        [[self adapter] getInterstitial];
    } else if (IsGADAdSizeValid([type adSize])) {
        [[self adapter] getBannerWithSize:[type adSize]];
    }
}

- (void)dealloc
{
    _adManager = nil;
    _gadmDelegate = nil;
    [_adapter stopBeingDelegate];
    [_mediationConfig release];
    [_networkConfig release];
    [_adapter release];
    [_strippedCredentials release];
    [super dealloc];
}

- (BOOL)testMode
{
    if ([_gadmDelegate respondsToSelector:@selector(gadmTestMode)]) return [_gadmDelegate gadmTestMode];
    return NO;
}

- (id)networkExtras
{
    Class adapter = [[self networkConfig] adapterClass];
    SEL selector = @selector(networkExtrasClass);
    if ([adapter respondsToSelector:selector]) {
        Class type = [adapter performSelector:@selector(networkExtrasClass)];
        return [_gadmDelegate networkExtrasFor:type];
    }
    [GADMacros pubLog:[NSString stringWithFormat:@"Adapter class %@ does not response to SEL: %@. Unable to retrieve network extras.",
                      NSStringFromClass(adapter), NSStringFromSelector(selector)]];
    return nil;
}

- (BOOL)userHasLocation
{
    return _shareLocation ? [[_gadmDelegate userLocation] isPreciseLocation] : NO;
}

- (float)userLatitude
{
    return [self userHasLocation] ? [[_gadmDelegate userLocation] latitude] : 0;
}

- (float)userLongitude
{
    return [self userHasLocation] ? [[_gadmDelegate userLocation] longitude] : 0;
}

- (float)userLocationAccuracyInMeters
{
    return [self userHasLocation] ? [[_gadmDelegate userLocation] accuracy] : 0;
}

- (NSString *)userLocationDescription
{
    return _shareLocation ? [[_gadmDelegate userLocation] description] : nil;
}
@end

@implementation GADMAdNetworkConnectorBanner
- (void)adapterWillPresentFullScreenModal:(id)adapter
{
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmWillPresentFullScreenModal)]) {
        [[self gadmDelegate] gadmWillPresentFullScreenModal];
    }
    [[self adManager] reportClickFromConnector:self isRefresh:[self didNetworkRefresh]];
}

- (void)adapterWillDismissFullScreenModal:(id)adapter
{
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmWillDismissFullScreenModal)]) {
        [[self gadmDelegate] gadmWillDismissFullScreenModal];
    }
}

- (void)adapterDidDismissFullScreenModal:(id)adapter
{
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmDidDismissFullScreenModal)]) {
        [[self gadmDelegate] gadmDidDismissFullScreenModal];
    }
}

- (void)adapterWillLeaveApplication:(id)adapter
{
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmWillLeaveApplication)]) {
        [[self gadmDelegate] gadmWillLeaveApplication];
    }
    [[self adManager] reportClickFromConnector:self isRefresh:[self didNetworkRefresh]];
}

@end

@implementation GADMAdNetworkConnectorInterstitial
- (void)adapterWillPresentInterstitial:(id)adapter
{
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmWillPresentInterstitial)]) {
        [[self gadmDelegate] gadmWillPresentInterstitial];
    }
    [[self adManager] reportImpressionFromConnector:self isRefresh:NO];
}

- (void)adapterWillDismissInterstitial:(id)adapter
{
    [self setCalledWillDismissInterstitial:YES];
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmWillDismissInterstitial)]) {
        [[self gadmDelegate] gadmWillDismissInterstitial];
    }
}

- (void)adapterDidDismissInterstitial:(id)adapter
{
    if (![self calledWillDismissInterstitial]) [self adapterWillDismissInterstitial:adapter];
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmDidDismissInterstitial)]) {
        [[self gadmDelegate] gadmDidDismissInterstitial];
    }
}

- (void)adapterWillLeaveApplication:(id)adapter
{
    if ([[self gadmDelegate] respondsToSelector:@selector(gadmWillLeaveApplication)]) {
        [[self gadmDelegate] gadmWillLeaveApplication];
    }
}

@end
