#import "gad_banner.h"

static inline void reportInvalidSize(GADAdSize size)
{
    [GADMacros pubLog:[NSString stringWithFormat:
        @"Unable to set adSize property with %@. Please use one of the standard ad sizes or create a custom ad size using GADAdSizeFromCGSize.",
        NSStringFromGADAdSize(size)]];
}

@implementation GADBannerView

@synthesize slot = _slot;

- (void)setAdSize:(GADAdSize)size andReload:(BOOL)reload
{
    if (![self slot] || GADAdSizeEqualToSize([[[self slot] adType] adSize], size))
        return;
    if (!IsGADAdSizeValid(size)) {
        reportInvalidSize(size);
        return;
    }
    CGRect frame = [self frame];
    [super setFrame:(frame.size = CGSizeFromGADAdSize(size), frame)];
    [[self slot] setAdType:[GADAdType bannerAdTypeForSize:size] andReloadRequest:reload];
}

- (void)commonInitializer
{
    [self setBackgroundColor:[UIColor clearColor]];
    [self setSlot:[[[GADSlot alloc] initWithView:self] autorelease]];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    if (!CGSizeEqualToSize(frame.size, CGSizeFromGADAdSize([self adSize])))
        [self setAdSize:GADAdSizeFromCGSize(frame.size)];
}

- (void)setBounds:(CGRect)bounds
{
    [super setBounds:bounds];
    [self setAdSize:GADAdSizeFromCGSize(bounds.size)];
}

- (CGSize)intrinsicContentSize
{
    return CGSizeFromGADAdSize([self adSize]);
}

- (GADAdSize)adSize
{
    return [[[self slot] adType] adSize];
}

- (void)setAdSize:(GADAdSize)size
{
    [self setAdSize:size andReload:YES];
    if ([self respondsToSelector:@selector(translatesAutoresizingMaskIntoConstraints)] &&
        ![self translatesAutoresizingMaskIntoConstraints])
        [self invalidateIntrinsicContentSize];
}

- (void)setAlpha:(CGFloat)alpha
{
    if (alpha != 0)
        alpha = 1;
    [super setAlpha:alpha];
}

- (id)init
{
    return [self initWithFrame:CGRectZero];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInitializer];
        [self setAdSize:GADAdSizeFromCGSize(frame.size)];
    }
    return self;
}

- (id)initWithAdSize:(GADAdSize)size
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        if (!IsGADAdSizeValid(size)) {
            reportInvalidSize(size);
            [self release];
            return nil;
        }
        [self commonInitializer];
        [self setAdSize:size];
    }
    return self;
}

- (id)initWithAdSize:(GADAdSize)size origin:(CGPoint)origin
{
    self = [self initWithAdSize:size];
    if (self) {
        CGRect frame = [self frame];
        frame.origin = origin;
        [self setFrame:frame];
    }
    return self;
}

- (void)awakeFromNib
{
    [self commonInitializer];
    GADAdSize size = GADAdSizeFromCGSize([self frame].size);
    [[self slot] setAdType:[GADAdType bannerAdTypeForSize:size] andReloadRequest:NO];
}

- (void)dealloc
{
    [_slot cancelPendingAndFutureActions];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_slot release];
    [super dealloc];
}

- (void)loadRequest:(id)request
{
    if (![self rootViewController]) {
        [GADMacros pubLog:[NSString stringWithFormat:
            @"Must set the rootViewController property of GADBannerView before calling %@",
            NSStringFromSelector(@selector(loadRequest:))]];
        id error = [GADRequestError errorWithCode:0 request:request];
        [[[self slot] delegateManager] didFailToReceiveAdWithError:error];
        return;
    }
    [[self slot] loadRequest:request];
}

@end

@implementation GADSlot

@synthesize delegateManager = _delegateManager;
@synthesize adUnitID = _adUnitID;

- (NSArray *)pendingClickURLs { return [_pendingClickURLs allObjects]; }
- (NSArray *)pendingTrackingURLs { return [_pendingTrackingURLs allObjects]; }
- (NSArray *)pendingManualTrackingURLs { return [_pendingManualTrackingURLs allObjects]; }

- (id)delegateManager
{
    [[self retain] autorelease];
    return _delegateManager;
}

- (void)setRootViewController:(UIViewController *)controller
{
    _rootViewController = controller;
    GADBannerView *view = [self mediatedAdView];
    if ([view isKindOfClass:[GADBannerView class]])
        [view setRootViewController:controller];
}

- (id)mediatedAdView
{
    if (![self isMediating])
        return nil;
    [[[self adView] subviews] count];
    return [[[self adView] subviews] lastObject];
}

- (NSString *)adNetworkClassName
{
    if ([self state] != 6)
        return nil;
    if (![self isMediating])
        return NSStringFromClass([GADMAdapterGoogleAdMobAds class]);
    if (![[[self adMediationGlue] mediationManager] receivedConnector])
        return nil;
    id connector = [[[self adMediationGlue] mediationManager] receivedConnector];
    return NSStringFromClass([[connector networkConfig] adapterClass]);
}

- (void)setAdUnitID:(NSString *)unitID
{
    [_adUnitID autorelease];
    _adUnitID = [unitID copy];
    [_slotStats setIdentifier:unitID];
}

- (void)reloadCurrentRequest
{
    if (![[self adType] isInterstitial] && ![_adView isHidden] && [_adView superview])
        [self loadPrivateRequest:[self requestPrivate] autoRefresh:YES];
}

- (void)resetReloadTimer
{
    [_reloadTimer invalidate];
    [_reloadTimer release];
    _reloadTimer = nil;
}

- (void)scheduleReloadTimer:(double)interval
{
    [self resetReloadTimer];
    if (interval > 0) {
        _reloadTimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self
            selector:@selector(reloadCurrentRequest) userInfo:nil repeats:NO] retain];
        [self setReloadInterval:interval];
    } else {
        [self setReloadInterval:0];
    }
}

- (void)activateReloadTimer
{
    [self scheduleReloadTimer:[self reloadInterval]];
}

- (BOOL)isMakingRequest
{
    return [self state] != 0 && [self state] != 1 && [self state] != 6 && [self state] != 7;
}

- (BOOL)shouldMakeRequest:(id)request
{
    return [self state] != 8 && ![self isMakingRequest] &&
        [[GADApplication sharedApplication] isAppActive] && [GADDevice osIsSupported];
}

- (void)mediatedAdNetworkAutoRefreshed
{
    _hasAutoRefreshed = YES;
}

- (void)resetRequestState
{
    [_pendingClickURLs removeAllObjects];
    [_pendingTrackingURLs removeAllObjects];
    [_pendingManualTrackingURLs removeAllObjects];
    [_adDebugDialog release];
    _adDebugDialog = nil;
    _isMRAID = NO;
}

- (void)cancelPendingActions
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self resetReloadTimer];
    [[self adFetcher] cancel];
    [self setAdFetcher:nil];
    [[self adMediationGlue] cancel];
    [self setState:0];
}

- (void)cancelPendingAndFutureActions
{
    [self cancelPendingActions];
    _adView = nil;
    [self setState:8];
}

- (void)presentMediatedInterstitialFromRootViewController:(UIViewController *)controller
{
    if ([self isMediating] && [[self adType] isInterstitial])
        [[self adMediationGlue] presentInterstitialFromRootViewController:controller];
}

- (void)addClickTrackingURLs:(NSArray *)urls
{
    if (_pendingClickURLs)
        [_pendingClickURLs addObjectsFromArray:urls];
    else
        _pendingClickURLs = [[NSMutableSet setWithArray:urls] retain];
}

- (void)addTrackingURLs:(NSArray *)urls
{
    if (_pendingTrackingURLs)
        [_pendingTrackingURLs addObjectsFromArray:urls];
    else
        _pendingTrackingURLs = [[NSMutableSet setWithArray:urls] retain];
}

- (void)addManualTrackingURLs:(NSArray *)urls
{
    if (_pendingManualTrackingURLs)
        [_pendingManualTrackingURLs addObjectsFromArray:urls];
    else
        _pendingManualTrackingURLs = [[NSMutableSet setWithArray:urls] retain];
}

- (void)setRequestedOrientation:(int)orientation
{
    if (orientation)
        _supportedOrientations = orientation;
}

- (void)setRefreshInterval:(double)interval
{
    [self setReloadInterval:interval];
}

- (void)setNewAdSize:(CGSize)size
{
    if ([[self adType] isInterstitial])
        _newAdSize = CGSizeZero;
    else
        _newAdSize = size;
}

- (void)handleAdResponse:(id)response withBaseURL:(NSURL *)url
{
    if ([self isMediating])
        [self processMediationResponse:response];
    else
        [self showAd:response withBaseURL:url];
}

- (void)didDisableScrollingAndActivationOverlay:(BOOL)disabled
{
    if ([[self webView] respondsToSelector:@selector(scrollView)])
        [[[self webView] scrollView] setScrollEnabled:!disabled];
    if (disabled) {
        [_activationView removeFromSuperview];
        _shouldShowActivationOverlay = NO;
    } else {
        _shouldShowActivationOverlay = YES;
    }
}


- (id)initWithFrame:(CGRect)frame
{
    self = [super init];
    if (self) {
        _state = 0;
        _supportedOrientations = 1;
        _delegateManager = [[GADDelegateManager alloc] init];
        _webView = [[GADWebView alloc] initWithFrame:frame];
        [_webView setScalesPageToFit:NO];
        [_webView setMediaPlaybackRequiresUserAction:YES];
        [_webView setHidden:YES];
        _webViewDelegate = [[GADBannerWebViewDelegate alloc] initWithSlot:self];
        [_webView setDelegate:_webViewDelegate];

        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(appDidBecomeInactive:)
                       name:UIApplicationWillResignActiveNotification object:nil];
        [center addObserver:self selector:@selector(appDidBecomeActive:)
                       name:UIApplicationDidBecomeActiveNotification object:nil];
        if ([GADDevice isOSAtLeastMajor:4 minor:0 bug:0]) {
            [center addObserver:self selector:@selector(appDidBecomeInactive:)
                           name:UIApplicationDidEnterBackgroundNotification object:nil];
            [center addObserver:self selector:@selector(appDidBecomeActive:)
                           name:UIApplicationWillEnterForegroundNotification object:nil];
        }
        [center addObserver:self selector:@selector(adWillPresentFullScreen:)
                       name:@"kAdModalViewControllerWillPresentFullScreen" object:nil];
        [center addObserver:self selector:@selector(adDidRelinquishFullScreen:)
                       name:@"kAdModalViewControllerDidDismissFullScreen" object:nil];

        _adType = [[GADAdType interstitialAdType] retain];
        _slotStats = [[GADSlotStatistics alloc] init];
        _adMediationGlue = [[GADMToGADGlue alloc] init];
        [_adMediationGlue setSlot:self];
        _adTimer = [[GADTiming alloc] initWithCategory:[NSString stringWithFormat:
            @"%@ (%p): Ad Timer", NSStringFromClass([self class]), self]];
    }
    return self;
}

- (id)initWithView:(GADBannerView *)view
{
    self = [self initWithFrame:[view bounds]];
    if (self) {
        _adView = view;
        [_adView setBackgroundColor:[UIColor clearColor]];
        [_adView setClipsToBounds:YES];
        [_adView addSubview:_webView];
    }
    return self;
}

- (id)initSwipeableWithView:(GADBannerView *)view
{
    self = [self initWithView:view];
    if (self) {
        _activationView = [[GADActivationView alloc] initWithFrame:[view bounds]];
        _activationViewDelegate = [[GADActivationViewDelegate alloc] init];
        [_activationViewDelegate setSlot:self];
        [_activationView setDelegate:_activationViewDelegate];
        _shouldShowActivationOverlay = YES;
        [_adView addSubview:_activationView];
        [[_webViewDelegate opener] setDelegate:_activationView];
    }
    return self;
}

- (void)dealloc
{
    [_adFetcher cancel];
    [_adFetcher release];
    [[_webViewDelegate opener] setDelegate:nil];
    [_activationView setDelegate:nil];
    [_activationView release];
    [_activationViewDelegate setSlot:nil];
    [_activationViewDelegate release];
    [_requestId release];
    _requestId = nil;
    _adView = nil;
    [_adType release];
    _adType = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_adMediationGlue setSlot:nil];
    [_adMediationGlue release];
    [_adDebugDialog release];
    _adDebugDialog = nil;
    [_slotStats release];
    _slotStats = nil;
    [_webView setDelegate:nil];
    [_webView release];
    _webView = nil;
    [_webViewDelegate release];
    [_adUnitID release];
    _adUnitID = nil;
    [_requestPrivate release];
    [self resetRequestState];
    [_delegateManager release];
    [_pendingTrackingURLs release];
    _pendingTrackingURLs = nil;
    [_pendingClickURLs release];
    _pendingClickURLs = nil;
    [_pendingManualTrackingURLs release];
    _pendingManualTrackingURLs = nil;
    [_adTimer release];
    _adTimer = nil;
    [super dealloc];
}

- (void)loadAdHTMLFromURL:(NSURL *)url usingActivationOverlayURL:(NSURL *)overlay
{
    [self resetRequestState];
    if (!overlay && [[self adView] isKindOfClass:[DFPSwipeableBannerView class]]) {
        [self setState:1];
        id error = [GADRequestError errorWithCode:3 customMessage:@"No Activation Overlay URL"];
        [[self delegateManager] didFailToReceiveAdWithError:error];
        return;
    }

    GADAd *ad = [[[GADAd alloc] init] autorelease];
    [ad setAdURL:url];
    [ad setActivationOverlayURL:overlay];
    [[self adFetcher] cancel];
    [self setAdFetcher:[[[GADAdFetcher alloc] init] autorelease]];
    [[self adFetcher] fetchRemainingContentForAd:ad headers:nil delegate:self
                                        request:[self requestPrivate] error:NULL];
}

- (void)loadAd:(GADAd *)ad headers:(NSDictionary *)headers
{
    [self resetRequestState];
    [_slotStats startTimingNamed:GADTimingPRL withExplicitEnd:YES];
    [_slotStats startTimingNamed:GADTimingPRNL withExplicitEnd:YES];
    [self addClickTrackingURLs:[ad clickURLs]];
    [self addTrackingURLs:[ad impressionURLs]];
    [self addManualTrackingURLs:[ad manualImpressionURLs]];
    [self setSupportedOrientations:[ad supportedOrientations]];
    [self setAdDebugDialog:[ad debugDialog]];
    if (![[self adType] isInterstitial] && [ad isKindOfClass:[GADAdBanner class]]) {
        GADAdBanner *banner = (GADAdBanner *)ad;
        [self setNewAdSize:[banner size].size];
        [self setReloadInterval:[banner refreshInterval]];
    }
    [[self adFetcher] cancel];
    [self setAdFetcher:[[[GADAdFetcher alloc] init] autorelease]];
    [[self adFetcher] fetchRemainingContentForAd:ad headers:headers delegate:self
                                        request:[self requestPrivate] error:NULL];
}

- (void)showAd:(NSString *)html withBaseURL:(NSURL *)url
{
    NSString *trimmed = [html stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self activateReloadTimer];
    if (![trimmed length]) {
        [self setState:7];
        id error = [GADRequestError errorWithCode:1 request:[self requestPrivate]];
        [[self delegateManager] didFailToReceiveAdWithError:error];
        return;
    }
    [_webView setAdDebugDialog:[self adDebugDialog]];
    [self setState:5];
    [_webView loadHTMLString:trimmed baseURL:url];
    [self setViewForAdUsingView:_webView];
}

- (void)setAdType:(id)type andReloadRequest:(BOOL)reload
{
    if ([type isEqual:_adType])
        return;
    [_adType release];
    _adType = [type retain];
    if (CGSizeEqualToSize([self newAdSize], CGSizeZero) && reload)
        [_webView setHidden:YES];
    if ([self isMediating]) {
        if ([_adMediationGlue changeAdTypeTo:type])
            return;
        [[self mediatedAdView] removeFromSuperview];
    }
    if (reload) {
        if ([self isMakingRequest])
            [self cancelPendingActions];
        if ([self requestPrivate])
            [self loadPrivateRequest:[self requestPrivate] autoRefresh:NO];
    }
}


- (NSString *)jsBuildAdURL
{
    return @"http://googleads.g.dpvblfcljck.nft/mads/static/sdk/native/sdk-core-v40.js";
}

- (void)failedJavaScriptFile
{
    [self setState:1];
    id error = [GADRequestError errorWithCode:2 request:nil];
    [[self delegateManager] didFailToReceiveAdWithError:error];
}

- (void)invalidJavaScriptRequest
{
    [self setState:7];
    id error = [GADRequestError errorWithCode:0 request:[self requestPrivate]];
    [[self delegateManager] didFailToReceiveAdWithError:error];
}

- (void)loadPrivateRequest:(id)request autoRefresh:(BOOL)refresh
{
    if (!request)
        request = [[[GADRequestPrivate alloc] init] autorelease];
    if (![self shouldMakeRequest:request])
        return;
    [self setRequestPrivate:request];
    _hasAutoRefreshed = refresh;
    GADSharedStatistics *statistics = [GADSharedStatistics sharedInstance];
    if (![statistics timingNamed:GADTimingPTime])
        [statistics startTimingNamed:GADTimingPTime withExplicitEnd:NO];
    [statistics incrementAdRequestCount];
    [self setState:2];

    NSDictionary *extras = [[self requestPrivate] networkExtrasAdditionalParameters];
    NSString *orientation = [extras objectForKey:GADOrientationKey];
    if ([orientation isKindOfClass:[NSString class]]) {
        if ([orientation isEqualToString:@"p"])
            [self setSupportedOrientations:2];
        else if ([orientation isEqualToString:@"l"])
            [self setSupportedOrientations:3];
    }
    NSDictionary *payload = [extras objectForKey:@"_ad"];
    if ([payload isKindOfClass:[NSDictionary class]]) {
        GADAd *ad;
        if ([[self adType] isInterstitial])
            ad = [GADAdInterstitial adWithDictionary:payload];
        else
            ad = [GADAdBanner adWithDictionary:payload];
        [self loadAd:ad headers:[extras objectForKey:@"_adHeaders"]];
        return;
    }

    NSURL *url = nil;
    NSURL *overlay = nil;
    id provided = [extras objectForKey:GADRequestURLKey];
    if (provided && [provided isKindOfClass:[NSURL class]]) {
        [GADMRAIDInterceptor allow];
        url = provided;
    }
    provided = [extras objectForKey:GADActivationOverlayURLKey];
    if (provided && [provided isKindOfClass:[NSURL class]])
        overlay = provided;
    if (url)
        [self loadAdHTMLFromURL:url usingActivationOverlayURL:overlay];
    else
        [[GADJavaScriptController sharedInstance] executeJavaScriptFileFromURL:[self jsBuildAdURL]
                                                                withDelegate:self];
}


- (BOOL)validateAdResponseWithAdSize:(GADAdSize)size andValidAdSizes:(NSArray *)validSizes
{
    for (NSUInteger i = 0; i < [validSizes count]; ++i) {
        if (![[validSizes objectAtIndex:i] isKindOfClass:[NSValue class]])
            continue;
        NSValue *value = [validSizes objectAtIndex:i];
        if (strcmp([value objCType], @encode(GADAdSize)) == 0) {
            GADAdSize supported;
            [value getValue:&supported];
            if (GADAdSizeEqualToSize(supported, size))
                return YES;
        }
    }
    return NO;
}

- (void)processMediationResponse:(id)response
{
    [self setState:4];
    NSDictionary *payload = [GADMacros readJsonIntoDictionary:response];
    NSError *error = nil;
    GADMConfig *config = [[[GADMConfig alloc] initWithAppKey:[self adUnitID]
                                                  configDict:payload error:&error] autorelease];
    if (error) {
        [self setState:7];
        [[self delegateManager] didFailToReceiveAdWithError:error];
        return;
    }

    GADAdType *type = [self adType];
    if (![[self adType] isInterstitial] && !CGSizeEqualToSize([self newAdSize], CGSizeZero))
        type = [GADAdType bannerAdTypeForSize:GADAdSizeFromCGSize([self newAdSize])];
    if (![[config adType] isValid]) {
        [GADMacros pubLog:[NSString stringWithFormat:
            @"Warning: mediated ad type is unknown or invalid. Resetting type to %@.", type]];
        [config setAdType:type];
    }
    [[self adMediationGlue] requestAdWithType:type mediationConfig:config];
    if (![[self adType] isInterstitial])
        [self scheduleReloadTimer:[config refreshInterval]];
}

- (void)loadAdURL:(NSNotification *)notification
{
    [self setState:3];
    if ([[notification userInfo] objectForKey:@"errors"]) {
        id error = [GADRequestError errorWithCode:0 request:[self requestPrivate]];
        [self setState:7];
        [[self delegateManager] didFailToReceiveAdWithError:error];
        return;
    }

    GADSharedStatistics *statistics = [GADSharedStatistics sharedInstance];
    NSString *scenario = [[notification userInfo] objectForKey:@"request_scenario"];
    if ([scenario isEqualToString:@"offline_empty"]) {
        [statistics incrementParameterCount:GADOfflineAdRequestCount];
    } else if ([scenario isEqualToString:@"offline_buffer"]) {
        [statistics incrementParameterCount:GADOfflineBufferCount];
        [statistics incrementParameterCount:GADOfflineAdRequestCount];
    } else if ([scenario isEqualToString:@"online_buffer"]) {
        [statistics incrementParameterCount:GADOnlineBufferCount];
    } else if ([scenario isEqualToString:@"online_request"]) {
        [statistics resetParameterCount:GADOfflineAdRequestCount];
        [statistics resetParameterCount:GADOnlineBufferCount];
        [statistics resetParameterCount:GADOfflineBufferCount];
    }

    NSString *overlayString = [[notification userInfo] objectForKey:@"activation_overlay_url"];
    NSURL *overlay = [NSURL URLWithString:overlayString];
    [self setState:4];
    NSString *urlString = [[notification userInfo] objectForKey:@"url"];
    NSURL *url = [NSURL URLWithString:urlString];
    [[self slotStats] startTimingNamed:GADTimingPRL withExplicitEnd:YES];
    [[self slotStats] startTimingNamed:GADTimingPRNL withExplicitEnd:YES];
    [self loadAdHTMLFromURL:url usingActivationOverlayURL:overlay];
}


- (void)setViewForAdUsingView:(UIView *)view
{
    for (UIView *subview in [[self adView] subviews]) {
        if (subview != _webView || _webView != view)
            [subview removeFromSuperview];
    }
    [[self adView] addSubview:view];
    if (!CGSizeEqualToSize([self newAdSize], CGSizeZero)) {
        GADAdSize size = GADAdSizeFromCGSize([self newAdSize]);
        if ([[self adView] respondsToSelector:@selector(validAdSizes)]) {
            NSArray *sizes = [[self adView] performSelector:@selector(validAdSizes)];
            if ([self validateAdResponseWithAdSize:size andValidAdSizes:sizes]) {
                if (!CGSizeEqualToSize(CGSizeFromGADAdSize([[self adType] adSize]), [self newAdSize]))
                    [[self adSizeDelegate] adView:[self adView] willChangeAdSizeTo:size];
                [[self adView] setAdSize:size andReload:NO];
                if (_webView == view)
                    [_webView setFrame:[[self adView] bounds]];
            }
        }
        [self setNewAdSize:CGSizeZero];
    }
    if (_shouldShowActivationOverlay) {
        [[self activationView] setFrame:[[self adView] bounds]];
        [[self adView] addSubview:[self activationView]];
    }
}

- (NSString *)multipleAdSizeParameterFromSizes:(NSArray *)sizes
{
    NSMutableArray *dimensions = [[[NSMutableArray alloc] init] autorelease];
    for (NSValue *value in sizes) {
        if ([value isKindOfClass:[NSValue class]] && strcmp([value objCType], @encode(GADAdSize)) == 0) {
            GADAdSize size = kGADAdSizeInvalid;
            [value getValue:&size];
            CGSize pixels = CGSizeFromGADAdSize(size);
            NSString *dimension = [NSString stringWithFormat:@"%lux%lu",
                                    (unsigned long)pixels.width, (unsigned long)pixels.height];
            if (dimension)
                [dimensions addObject:dimension];
        }
    }
    return [dimensions componentsJoinedByString:@"|"];
}

- (NSMutableDictionary *)requestParameters
{
    NSMutableDictionary *parameters = [self requestPrivate] ? [[self requestPrivate] parameters] :
                                                              [NSMutableDictionary dictionary];
    if ([[self adUnitID] length])
        [parameters setObject:[self adUnitID] forKey:GADParamUnitID];
    if ([[self adType] isInterstitial]) {
        [parameters setObject:@"interstitial_mb" forKey:GADParamFormat];
    } else {
        if ([[self adView] respondsToSelector:@selector(validAdSizes)]) {
            NSArray *sizes = [[self adView] performSelector:@selector(validAdSizes)];
            NSString *dimensions = [self multipleAdSizeParameterFromSizes:sizes];
            if ([dimensions length])
                [parameters setObject:dimensions forKey:GADParamSizes];
        }
        CGRect rect = [self adView] ? [[self adView] frame] : [[self webView] frame];
        NSDictionary *frame = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:rect.origin.x], @"x", [NSNumber numberWithFloat:rect.origin.y], @"y",
            [NSNumber numberWithFloat:rect.size.width], @"w", [NSNumber numberWithFloat:rect.size.height], @"h", nil];
        [parameters setObject:frame forKey:GADParamFrame];
        rect = [self adView] ? [[self adView] bounds] : [[self webView] bounds];
        NSDictionary *bounds = [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:rect.origin.x], @"x", [NSNumber numberWithFloat:rect.origin.y], @"y",
            [NSNumber numberWithFloat:rect.size.width], @"w", [NSNumber numberWithFloat:rect.size.height], @"h", nil];
        [parameters setObject:bounds forKey:GADParamBounds];
    }
    if (GADAdSizeIsFullWidth([[self adType] adSize])) {
        [parameters setObject:@"full" forKey:GADParamSmartWidth];
        if (GADAdSizeIsAutoHeight([[self adType] adSize]))
            [parameters setObject:@"auto" forKey:GADParamSmartHeight];
    }
    if ([self requestId])
        [parameters setObject:[self requestId] forKey:GADParamRequestID];
    if ([self adView]) {
        id position = [GADViewUtilities positionOf:[self adView] in:[UIScreen mainScreen]];
        if (position)
            [parameters setObject:position forKey:GADParamPosition];
    }
    if ([[self adView] isKindOfClass:[DFPSwipeableBannerView class]])
        [parameters setObject:@"1" forKey:GADParamSwipeable];
    [parameters addEntriesFromDictionary:[[self slotStats] parameters]];
    if ([GADPublisherToolbarCredentials hasToolbarCredentials])
        [parameters setObject:@"1" forKey:GADParamToolbar];
    if ([self calledLoadAndDisplayRequest]) {
        [parameters setObject:@"1" forKey:GADParamLoadAndDisplay];
        [self setCalledLoadAndDisplayRequest:NO];
    }
    if ([self manualImpressionsEnabled])
        [parameters setObject:@"1" forKey:GADParamManualImpression];
    return parameters;
}

@end

@implementation DFPBannerView

- (void)resize:(GADAdSize)size
{
    [super setAdSize:size andReload:NO];
}

- (void)recordImpression
{
    NSArray *urls = [[self slot] pendingManualTrackingURLs];
    [[GADClickTrackerCollection sharedInstance] trackURLs:urls];
}

@end

@implementation DFPSwipeableBannerView

- (void)commonInitializer
{
    [self setBackgroundColor:[UIColor clearColor]];
    [self setSlot:[[[GADSlot alloc] initSwipeableWithView:self] autorelease]];
}

@end
