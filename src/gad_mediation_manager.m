#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef struct { CGSize size; NSUInteger flags; } GADAdSize;
extern NSString *const kGADErrorDomain;
extern const GADAdSize kGADAdSizeBanner, kGADAdSizeMediumRectangle, kGADAdSizeFullBanner;
extern const GADAdSize kGADAdSizeLeaderboard, kGADAdSizeSkyscraper, kGADAdSizeInvalid;

@interface GADAdType : NSObject
+ (id)bannerAdTypeForSize:(GADAdSize)size;
+ (id)interstitialAdType;
- (BOOL)isInterstitial;
- (GADAdSize)adSize;
@end

@interface GADRequestError : NSError
+ (id)errorWithCode:(NSInteger)code;
+ (id)errorWithCode:(NSInteger)code customMessage:(NSString *)message;
@end

@interface GADMAdNetworkAdapter : NSObject
+ (BOOL)classImplementsCurrentAdapterAPI:(Class)adapter;
+ (BOOL)classIsAdapterClass:(Class)adapter;
@end

@interface GADMAdNetworkConfig : NSObject {
    Class _adapterClass;
    NSString *_networkID;
    NSDictionary *_credentials;
    NSDictionary *_extras;
    NSDictionary *_ad;
    NSString *_allocationID;
    NSArray *_impressionURLs;
    NSArray *_adapterList;
}
- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error;
- (NSString *)publisherID;
- (NSDictionary *)credentials;
- (NSString *)networkID;
- (NSString *)allocationID;
- (NSArray *)impressionURLs;
- (Class)adapterClass;
@end

@interface GADMConfig : NSObject {
    NSTimeInterval _refreshInterval;
    NSInteger _bannerAnimationType;
    NSTimeInterval _adNetworkTimeout;
    NSMutableArray *_adNetworkConfigs;
    NSString *_appKey;
}
- (void)setAdNetworkTimeout:(NSTimeInterval)timeout;
- (NSTimeInterval)adNetworkTimeout;
- (void)setBannerAnimationType:(NSInteger)animation;
- (void)setClickURLs:(NSArray *)urls;
- (void)setImpressionURLs:(NSArray *)urls;
- (void)setNoFillURLs:(NSArray *)urls;
- (void)setQdata:(NSString *)qdata;
- (void)setAdType:(GADAdType *)type;
- (BOOL)parseConfig:(NSDictionary *)config error:(NSError **)error;
- (NSString *)qdata;
- (GADAdType *)adType;
- (NSTimeInterval)refreshInterval;
- (NSInteger)bannerAnimationType;
- (NSMutableArray *)adNetworkConfigs;
- (NSArray *)clickURLs;
- (NSArray *)noFillURLs;
- (NSArray *)impressionURLs;
- (NSString *)appKey;
@end

@interface NSObject (GADMMediationMessages)
- (void)setGadmDelegate:(id)delegate;
- (void)setAdManager:(id)manager;
- (void)resetTimingAdapters;
- (void)startTimingAdapter;
- (void)getAdFromAdapterWithType:(GADAdType *)type;
- (void)endTimingAdapterWithExitCode:(NSInteger)code;
- (id)adapter;
- (void)changeAdSizeTo:(GADAdSize)size;
- (void)gadmDidFailToReceiveAdWithError:(NSError *)error;
- (void)gadmDidReceiveAd:(UIView *)view;
- (void)gadmDidReceiveInterstitial:(id)interstitial;
- (void)askAdapterToStopBeingDelegate;
- (BOOL)didNetworkRefresh;
- (void)gadmBannerAdRefreshFailedWithError:(NSError *)error;
- (NSString *)adapterDurationsParameter;
- (NSString *)adapterExitCodesParameter;
- (GADMConfig *)mediationConfig;
- (GADMAdNetworkConfig *)networkConfig;
@end

@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end
@interface GADMAdNetworkConnectorBanner : NSObject
- (id)initWithConfig:(GADMConfig *)config networkConfig:(GADMAdNetworkConfig *)network;
@end
@interface GADMAdNetworkConnectorInterstitial : NSObject
- (id)initWithConfig:(GADMConfig *)config networkConfig:(GADMAdNetworkConfig *)network;
@end
@interface GADSharedStatistics : NSObject
+ (id)sharedInstance;
- (NSString *)nextSequenceNumberAsString;
@end
@interface GADApplication : NSObject
+ (id)sharedApplication;
- (id)currentSession;
- (NSString *)sessionIDAsString;
@end
@interface GADClickTrackerCollection : NSObject
+ (id)sharedInstance;
- (void)trackURL:(NSURL *)url;
@end
@interface GADMUtilities : NSObject
+ (NSURL *)mediationUrlFrom:(NSString *)url adLocationId:(NSString *)appKey adNetworkRefresh:(BOOL)refresh
     allocationId:(NSString *)allocationID adNetworkId:(NSString *)networkID qData:(NSString *)qdata
     sessionId:(NSString *)session sequenceNum:(NSString *)sequence exitCodes:(NSString *)exitCodes durations:(NSString *)durations;
@end
@interface GADMAdManager : NSObject {
    id _delegate;
    NSMutableArray *_adNetworkConfigQueue;
    id _lastConnectorNotifiedForAClick;
}
- (id)delegate;
- (id)receivedConnector;
- (id)requestingConnector;
- (void)setRequestingConnector:(id)connector;
- (void)setReceivedConnector:(id)connector;
- (GADAdType *)adType;
- (void)setAdType:(GADAdType *)type;
- (GADMConfig *)config;
- (void)setConfig:(GADMConfig *)config;
- (BOOL)requestInProgress;
- (void)setRequestInProgress:(BOOL)flag;
- (NSTimer *)adNetworkTimeoutTimer;
- (void)setAdNetworkTimeoutTimer:(NSTimer *)timer;
- (void)makeAdRequest;
- (void)setLastRequestTime:(NSDate *)date;
- (void)requestNextAdNetwork;
+ (void)pingMediationURLs:(NSArray *)urls defaultURL:(NSString *)url withNetworkID:(NSString *)networkID
             allocationID:(NSString *)allocationID qData:(NSString *)qdata appKey:(NSString *)appKey
                  refresh:(BOOL)refresh durations:(NSString *)durations andExitCodes:(NSString *)exitCodes;
@end

@implementation GADMAdManager
- (void)makeAdRequest
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(makeAdRequest) withObject:nil waitUntilDone:NO];
        return;
    }
    GADMAdNetworkConfig *network = [self dequeueAdNetworkConfig];
    if (!network) {
        [[self adNetworkTimeoutTimer] invalidate];
        [self setAdNetworkTimeoutTimer:nil];
        [self reportNoFill];
        [self notifyDelegateOfFailureToReceiveWithError:[GADRequestError errorWithCode:9]];
        return;
    }
    [self requestInProgress];
    [self setRequestInProgress:YES];
    [[self delegate] startTimingAdapter];
    id connector;
    if ([[self adType] isInterstitial]) {
        connector = [[[GADMAdNetworkConnectorInterstitial alloc] initWithConfig:[self config] networkConfig:network] autorelease];
    } else {
        connector = [[[GADMAdNetworkConnectorBanner alloc] initWithConfig:[self config] networkConfig:network] autorelease];
    }
    [connector setGadmDelegate:[self delegate]];
    [connector setAdManager:self];
    [self setRequestingConnector:connector];
    [self setLastRequestTime:[NSDate date]];
    SEL handler = @selector(adNetworkTimeoutHandler:);
    if ([self adNetworkTimeoutTimer]) {
        [[self adNetworkTimeoutTimer] invalidate];
        [self setAdNetworkTimeoutTimer:nil];
    }
    [self setAdNetworkTimeoutTimer:[NSTimer scheduledTimerWithTimeInterval:[[self config] adNetworkTimeout]
                   target:self selector:handler userInfo:[self requestingConnector] repeats:NO]];
    [[self requestingConnector] getAdFromAdapterWithType:[self adType]];
}

+ (void)pingMediationURLs:(NSArray *)urls defaultURL:(NSString *)defaultURL withNetworkID:(NSString *)networkID
             allocationID:(NSString *)allocationID qData:(NSString *)qdata appKey:(NSString *)appKey
                  refresh:(BOOL)refresh durations:(NSString *)durations andExitCodes:(NSString *)exitCodes
{
    if (urls && ![urls count]) return;
    if (!urls && defaultURL) urls = @[defaultURL];
    if (!qdata) qdata = @"";
    for (NSString *url in urls) {
        if (![url isKindOfClass:[NSString class]]) continue;
        NSString *sequence = [[GADSharedStatistics sharedInstance] nextSequenceNumberAsString];
        NSString *session = [[[GADApplication sharedApplication] currentSession] sessionIDAsString];
        NSURL *trackingURL = [GADMUtilities mediationUrlFrom:url adLocationId:appKey adNetworkRefresh:refresh
                allocationId:allocationID adNetworkId:networkID qData:qdata sessionId:session
                sequenceNum:sequence exitCodes:exitCodes durations:durations];
        [[GADClickTrackerCollection sharedInstance] trackURL:trackingURL];
    }
}

// The three fallback tracking URLs preserve the hostname present in the shipped app.
- (void)reportNoFill
{
    NSString *durations = [[[[self delegate] adapterDurationsParameter] copy] autorelease];
    NSString *exitCodes = [[[[self delegate] adapterExitCodesParameter] copy] autorelease];
    [[self delegate] resetTimingAdapters];
    [GADMAdManager pingMediationURLs:[[self config] noFillURLs] defaultURL:@"http://e.bdmpb.cpm/nofill?ad_loc=@gw_adlocid@&qdata=@gw_qdata@&js=@gw_sdkver@&session_id=@gw_sessid@&seq_num=@gw_seqnum@&aec=@gw_aec@&adt=@gw_adt@"
            withNetworkID:nil allocationID:nil qData:[[self config] qdata] appKey:[[self config] appKey]
            refresh:NO durations:durations andExitCodes:exitCodes];
}

- (void)reportClickFromConnector:(id)connector isRefresh:(BOOL)refresh
{
    if ([self receivedConnector] != connector || ![self receivedConnector] ||
            _lastConnectorNotifiedForAClick == [self receivedConnector]) return;
    _lastConnectorNotifiedForAClick = [self receivedConnector];
    [GADMAdManager pingMediationURLs:[[connector mediationConfig] clickURLs] defaultURL:@"http://e.bdmpb.cpm/clk?ad_loc=@gw_adlocid@&qdata=@gw_qdata@&ad_network_id=@gw_adnetid@&js=@gw_sdkver@&session_id=@gw_sessid@&seq_num=@gw_seqnum@&nr=@gw_adnetrefresh@"
        withNetworkID:[[connector networkConfig] networkID] allocationID:[[connector networkConfig] allocationID]
        qData:[[connector mediationConfig] qdata] appKey:[[connector mediationConfig] appKey]
        refresh:refresh durations:nil andExitCodes:nil];
}

- (void)reportImpressionFromConnector:(id)connector isRefresh:(BOOL)refresh
{
    if ([self receivedConnector] != connector) return;
    NSString *durations = [[[[self delegate] adapterDurationsParameter] copy] autorelease];
    NSString *exitCodes = [[[[self delegate] adapterExitCodesParameter] copy] autorelease];
    [[self delegate] resetTimingAdapters];
    NSArray *urls = [[connector networkConfig] impressionURLs] ?
        [[connector networkConfig] impressionURLs] : [[connector mediationConfig] impressionURLs];
    [GADMAdManager pingMediationURLs:urls defaultURL:@"http://e.bdmpb.cpm/imp?ad_loc=@gw_adlocid@&qdata=@gw_qdata@&ad_network_id=@gw_adnetid@&js=@gw_sdkver@&session_id=@gw_sessid@&seq_num=@gw_seqnum@&nr=@gw_adnetrefresh@&adt=@gw_adt@&aec=@gw_aec@"
        withNetworkID:[[connector networkConfig] networkID] allocationID:[[connector networkConfig] allocationID]
        qData:[[connector mediationConfig] qdata] appKey:[[connector mediationConfig] appKey]
        refresh:refresh durations:durations andExitCodes:exitCodes];
}

- (void)setDelegate:(id)delegate
{
    [[self requestingConnector] setGadmDelegate:delegate];
    [[self receivedConnector] setGadmDelegate:delegate];
    _delegate = delegate;
}

- (void)mediateForAdType:(GADAdType *)type config:(GADMConfig *)config
{
    [self setAdType:type];
    [self setConfig:config];
    if ([self requestInProgress]) return;
    [_adNetworkConfigQueue autorelease];
    _adNetworkConfigQueue = [[[self config] adNetworkConfigs] mutableCopy];
    [[self delegate] resetTimingAdapters];
    [self makeAdRequest];
}

- (void)cancelPendingActions
{
    [NSThread isMainThread];
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [[self adNetworkTimeoutTimer] invalidate];
    [self setAdNetworkTimeoutTimer:nil];
}

- (GADMAdNetworkConfig *)dequeueAdNetworkConfig
{
    while ([_adNetworkConfigQueue count]) {
        GADMAdNetworkConfig *config = [[[_adNetworkConfigQueue objectAtIndex:0] retain] autorelease];
        [_adNetworkConfigQueue removeObjectAtIndex:0];
        if ([config adapterClass]) return config;
        [[self delegate] endTimingAdapterWithExitCode:4];
    }
    return nil;
}

- (BOOL)changeAdTypeTo:(GADAdType *)type
{
    [self setAdType:type];
    if (![[[self receivedConnector] adapter] respondsToSelector:@selector(changeAdSizeTo:)]) return NO;
    [[[self receivedConnector] adapter] changeAdSizeTo:[type adSize]];
    return YES;
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)controller
{
    id adapter = [[self receivedConnector] adapter];
    if ([adapter respondsToSelector:@selector(presentInterstitialFromRootViewController:)]) {
        [adapter presentInterstitialFromRootViewController:controller];
    }
}

- (void)notifyDelegateOfFailureToReceiveWithError:(NSError *)error
{
    if ([[self delegate] respondsToSelector:@selector(gadmDidFailToReceiveAdWithError:)]) {
        [[self retain] autorelease];
        [[self delegate] gadmDidFailToReceiveAdWithError:error];
    }
}

- (void)resetRequestingState
{
    [NSThread isMainThread];
    [[self adNetworkTimeoutTimer] invalidate];
    [self setAdNetworkTimeoutTimer:nil];
    [self setRequestInProgress:NO];
}

- (void)adNetworkTimeoutHandler:(NSTimer *)timer
{
    [[self delegate] endTimingAdapterWithExitCode:3];
    id connector = [timer userInfo];
    [self resetRequestingState];
    [connector askAdapterToStopBeingDelegate];
    if (connector != [self receivedConnector]) {
        [connector setAdManager:nil];
        [connector setGadmDelegate:nil];
    }
    [self setRequestingConnector:nil];
    [self requestNextAdNetwork];
}

- (BOOL)shouldProcessResponseFromConnector:(id)connector
{
    [self resetRequestingState];
    if (connector != [self requestingConnector] && connector != [self receivedConnector]) return NO;
    return YES;
}

- (void)adRequestReturnsFromConnector:(id)connector withView:(UIView *)view
{
    [[self adType] isInterstitial];
    if (![self shouldProcessResponseFromConnector:connector]) return;
    [[self delegate] endTimingAdapterWithExitCode:0];
    if ([self receivedConnector] != connector) {
        [[self receivedConnector] setGadmDelegate:nil];
        [[self receivedConnector] setAdManager:nil];
        [self setReceivedConnector:connector];
    }
    if ([[self delegate] respondsToSelector:@selector(gadmDidReceiveAd:)]) {
        [[self delegate] gadmDidReceiveAd:view];
    }
}

- (void)adRequestReturnsFromConnector:(id)connector withInterstitial:(id)interstitial
{
    if (![self shouldProcessResponseFromConnector:connector]) return;
    if ([self receivedConnector] != connector) {
        [[self delegate] endTimingAdapterWithExitCode:0];
        [[self receivedConnector] setGadmDelegate:nil];
        [[self receivedConnector] setAdManager:nil];
        [self setReceivedConnector:connector];
    }
    if ([[self delegate] respondsToSelector:@selector(gadmDidReceiveInterstitial:)]) {
        [[self delegate] gadmDidReceiveInterstitial:interstitial];
    }
    [self setRequestingConnector:nil];
}

- (void)updateAdapterTimingsForError:(NSError *)error
{
    if ([[error domain] isEqualToString:kGADErrorDomain] && [error code] == 1) {
        [[self delegate] endTimingAdapterWithExitCode:1];
    } else {
        [[self delegate] endTimingAdapterWithExitCode:2];
    }
}

- (void)adRequestFailedFromConnector:(id)connector withError:(NSError *)error
{
    if (![self shouldProcessResponseFromConnector:connector]) return;
    BOOL refresh = [connector didNetworkRefresh];
    if ([self requestingConnector] != [self receivedConnector]) {
        [[self requestingConnector] setAdManager:nil];
        [[self requestingConnector] setGadmDelegate:nil];
    }
    [self setRequestingConnector:nil];
    if ([[self adType] isInterstitial]) {
        [self updateAdapterTimingsForError:error];
        [self requestNextAdNetwork];
    } else if (refresh) {
        [[self delegate] gadmBannerAdRefreshFailedWithError:
            [GADRequestError errorWithCode:3 customMessage:[error localizedDescription]]];
    } else {
        [self updateAdapterTimingsForError:error];
        [self requestNextAdNetwork];
    }
}
@end

@implementation GADMAdNetworkConfig
- (id)initWithDictionary:(NSDictionary *)dictionary error:(NSError **)error
{
    self = [super init];
    if (!self) return nil;
    id networkID = [dictionary objectForKey:@"id"];
    if (!networkID) {
        if (error) *error = [GADRequestError errorWithCode:7 customMessage:
                @"The AdMob Mediation response was invalid: An ad network config has no network ID."];
        [self release];
        return nil;
    }
    if ([networkID isKindOfClass:[NSString class]]) {
        _networkID = [networkID copy];
    } else if ([networkID isKindOfClass:[NSNumber class]]) {
        _networkID = [[networkID stringValue] retain];
    }
    if (!_networkID) {
        if (error) *error = [GADRequestError errorWithCode:7 customMessage:
                @"The AdMob Mediation response was invalid: An ad network config has an invalid network ID."];
        [self release];
        return nil;
    }
    id data = [dictionary objectForKey:@"data"];
    if ([data isKindOfClass:[NSDictionary class]]) {
        _credentials = [[NSDictionary alloc] initWithDictionary:data copyItems:YES];
    }
    id extras = [dictionary objectForKey:@"extras"];
    if ([extras isKindOfClass:[NSDictionary class]]) {
        _extras = [[NSDictionary alloc] initWithDictionary:extras copyItems:YES];
    }
    id ad = [dictionary objectForKey:@"ad"];
    if ([ad isKindOfClass:[NSDictionary class]]) {
        _ad = [[NSDictionary alloc] initWithDictionary:ad copyItems:YES];
    }
    _allocationID = [[dictionary objectForKey:@"allocation_id"] copy];
    id impressionURLs = [dictionary objectForKey:@"imp_urls"];
    if ([impressionURLs isKindOfClass:[NSArray class]]) {
        _impressionURLs = [[NSArray alloc] initWithArray:impressionURLs copyItems:YES];
    }
    id adapters = [dictionary objectForKey:@"adapters"];
    if ([adapters isKindOfClass:[NSArray class]]) {
        _adapterList = [[NSArray alloc] initWithArray:adapters copyItems:YES];
    }

    NSMutableArray *outdated = [[[NSMutableArray alloc] init] autorelease];
    for (NSString *name in _adapterList) {
        Class adapter = NSClassFromString(name);
        if (!adapter) continue;
        if (![GADMAdNetworkAdapter classImplementsCurrentAdapterAPI:adapter]) {
            [outdated addObject:name];
        } else if ([GADMAdNetworkAdapter classIsAdapterClass:adapter]) {
            _adapterClass = adapter;
            break;
        }
    }
    if ([outdated count]) {
        NSString *format = [outdated count] == 1 ?
                @"Ad network adapter %@ implements an old API. Please update the adapter.%@" :
                @"Ad network adapters (%@) implement an old API. Please update the adapters.%@";
        NSString *suffix = _adapterClass ? @"" : @" No valid adapters found for this ad network.";
        NSString *names = [outdated componentsJoinedByString:@", "];
        NSString *message = [NSString stringWithFormat:format, names, suffix];
        if (error) *error = [GADRequestError errorWithCode:8 customMessage:message];
    } else if (!_adapterClass) {
        NSString *message = [NSString stringWithFormat:@"Cannot find an ad network adapter with the name(s): %@. Remember to link all required ad network adapters and SDKs, and set -ObjC in the 'Other Linker Flags' setting of your build target.", _adapterList];
        if (error) *error = [GADRequestError errorWithCode:8 customMessage:message];
    }
    return self;
}

- (NSString *)description
{
    NSString *data = [self publisherID];
    if (!data) data = [[self credentials] description];
    return [NSString stringWithFormat:@"networkID:%@ adapter:%@ data:%@",
                    [self networkID], [self adapterClass], data];
}
@end

static __attribute__((noinline)) BOOL objectToInteger(id object, NSInteger *value)
{
    if (!value) return NO;
    if ([object respondsToSelector:@selector(integerValue)]) {
        *value = [object integerValue];
        return YES;
    }
    *value = 0;
    return NO;
}

@implementation GADMConfig
- (BOOL)parseSettingsConfig:(NSDictionary *)settings error:(NSError **)error
{
    NSInteger value;
    if (objectToInteger([settings objectForKey:@"refresh"], &value)) {
        [self setRefreshInterval:value];
    }
    if (objectToInteger([settings objectForKey:@"ad_network_timeout_millis"], &value)) {
        [self setAdNetworkTimeout:value / 1000.0];
    }
    NSInteger animation = 0;
    if (objectToInteger([settings objectForKey:@"ad_transition_anim"], &animation)) {
        switch (animation) {
            case 0: [self setBannerAnimationType:0]; break;
            case 1: [self setBannerAnimationType:1]; break;
            case 2: [self setBannerAnimationType:2]; break;
            case 3: [self setBannerAnimationType:3]; break;
            case 4: [self setBannerAnimationType:4]; break;
            case 5: [self setBannerAnimationType:5]; break;
            case 6: [self setBannerAnimationType:6]; break;
            case 7: [self setBannerAnimationType:7]; break;
            case 8: [self setBannerAnimationType:8]; break;
        }
    }
    id impression = [settings objectForKey:@"imp_urls"];
    if ([impression isKindOfClass:[NSArray class]]) [self setImpressionURLs:impression];
    id clicks = [settings objectForKey:@"click_urls"];
    if ([clicks isKindOfClass:[NSArray class]]) [self setClickURLs:clicks];
    id noFill = [settings objectForKey:@"nofill_urls"];
    if ([noFill isKindOfClass:[NSArray class]]) [self setNoFillURLs:noFill];
    return YES;
}

- (BOOL)parseConfig:(NSDictionary *)config error:(NSError **)error
{
    [self setAdType:[GADMConfig peekAdTypeFromConfig:config]];
    id settings = [config objectForKey:@"settings"];
    if ([settings isKindOfClass:[NSDictionary class]] && ![self parseSettingsConfig:settings error:error]) return NO;
    NSString *qdata = [config objectForKey:@"qdata"];
    if (qdata) [self setQdata:qdata];
    id networks = [config objectForKey:@"ad_networks"];
    if (![networks isKindOfClass:[NSArray class]]) {
        if (error) *error = [GADRequestError errorWithCode:7];
        return NO;
    }
    for (id item in networks) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;
        NSError *networkError = nil;
        GADMAdNetworkConfig *network = [[[GADMAdNetworkConfig alloc] initWithDictionary:item error:&networkError] autorelease];
        if (network) [[self adNetworkConfigs] addObject:network];
        if (networkError) {
            if ([networkError code] != 8) {
                if (error) *error = networkError;
                return NO;
            }
            [GADMacros pubLog:[NSString stringWithFormat:@"%@", [networkError localizedDescription]]];
        }
    }
    return YES;
}

- (void)setRefreshInterval:(NSTimeInterval)interval
{
    if (interval >= 30000.0) interval = 0.0;
    _refreshInterval = interval;
}

- (id)initWithAppKey:(NSString *)key configDict:(NSDictionary *)config error:(NSError **)error
{
    if ((self = [super init])) {
        _appKey = [key copy];
        _adNetworkConfigs = [[NSMutableArray alloc] init];
        _bannerAnimationType = 8;
        _adNetworkTimeout = 10.0;
        if (![self parseConfig:config error:error]) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (NSString *)description
{
    NSString *base = [super description];
    NSString *details = [NSString stringWithFormat:@"qdata:%@ adTypeString:%@ refresh:%f transition:%ld",
                                  [self qdata], [self adType], [self refreshInterval], (long)[self bannerAnimationType]];
    return [NSString stringWithFormat:@"%@:\n%@ ad_networks:%@", base, details, [self adNetworkConfigs]];
}

+ (GADAdType *)peekAdTypeFromConfig:(NSDictionary *)config
{
    NSString *name = [config objectForKey:@"ad_type"];
    return [GADMConfig adTypeFromString:name];
}

+ (GADAdType *)adTypeFromString:(NSString *)name
{
    NSDictionary *types = @{
        @"banner": [GADAdType bannerAdTypeForSize:kGADAdSizeBanner],
        @"mrec": [GADAdType bannerAdTypeForSize:kGADAdSizeMediumRectangle],
        @"fullbanner": [GADAdType bannerAdTypeForSize:kGADAdSizeFullBanner],
        @"leaderboard": [GADAdType bannerAdTypeForSize:kGADAdSizeLeaderboard],
        @"skyscraper": [GADAdType bannerAdTypeForSize:kGADAdSizeSkyscraper],
        @"interstitial": [GADAdType interstitialAdType]
    };
    return [types objectForKey:name] ?: [GADAdType bannerAdTypeForSize:kGADAdSizeInvalid];
}
@end
