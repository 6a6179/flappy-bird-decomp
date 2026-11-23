#import <UIKit/UIKit.h>

@class GADRequestPrivate;

@interface GADTiming : NSObject
- (id)initWithCategory:(NSString *)category;
@end
@interface GADURLConnection : NSObject
- (BOOL)startWithURL:(NSURL *)url forDelegate:(id)delegate error:(NSError **)error;
- (void)cancel;
- (void)stop;
@end
@interface GADNetworkUtilities : NSObject
+ (NSDictionary *)headersFromResponse:(NSURLResponse *)response;
+ (NSArray *)createArrayOfURLsfromHeader:(NSString *)value;
@end
@interface GADRequestError : NSError
+ (id)errorWithCode:(int)code customMessage:(NSString *)message;
+ (id)errorWithCode:(int)code request:(GADRequestPrivate *)request;
+ (id)errorWithCode:(int)code request:(GADRequestPrivate *)request HTTPStatusCode:(NSInteger)status;
@end
@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end
@interface GADAd : NSObject
- (BOOL)shouldLoadActivationOverlayHTML;
- (BOOL)isActivationAndScrollEnabled;
- (BOOL)shouldLoadAdHTML;
- (NSString *)activationOverlayHTML;
- (NSURL *)activationOverlayBaseURL;
- (NSURL *)activationOverlayURL;
- (NSString *)adHTML;
- (NSURL *)adBaseURL;
- (NSURL *)adURL;
@end
@protocol GADAdFetcherDelegate <NSObject>
- (void)handleActivationOverlayResponse:(NSString *)html withBaseURL:(NSURL *)url;
- (void)handleAdResponse:(NSString *)html withBaseURL:(NSURL *)url;
- (void)didFailToReceiveAdWithError:(NSError *)error;
- (void)addTrackingURLs:(NSArray *)urls;
- (void)addManualTrackingURLs:(NSArray *)urls;
- (void)addClickTrackingURLs:(NSArray *)urls;
- (void)setRequestedOrientation:(int)orientation;
- (void)setRefreshInterval:(NSTimeInterval)interval;
- (void)setIsMediating:(BOOL)mediating;
- (BOOL)isMediating;
- (void)setAdDebugDialog:(NSString *)dialog;
- (void)setNewAdSize:(CGSize)size;
- (void)didDisableScrollingAndActivationOverlay:(BOOL)disabled;
@end

extern int GADAdSupportedOrientationsFromString(NSString *orientation);
extern CGSize GADCGSizeFromString(NSString *dimensions);

@interface GADAdFetcher : NSObject {
    dispatch_once_t _startOncePredicate, _notifyOncePredicate;
    BOOL _shouldLoadActivationOverlay, _adConnectionHasCompleted, _activationOverlayConnectionHasCompleted;
    NSRecursiveLock *_recursiveLock;
    GADRequestPrivate *_request;
    id<GADAdFetcherDelegate> _delegate;
    GADTiming *_timer;
    GADURLConnection *_adConnection, *_activationOverlayConnection;
    NSString *_activationOverlayHTML;
    NSURL *_activationOverlayBaseURL;
    NSString *_adResponse;
    NSURL *_adBaseURL;
    BOOL *_wasDeallocated;
}
@property(nonatomic, retain) NSRecursiveLock *recursiveLock;
@property(nonatomic, retain) GADRequestPrivate *request;
@property(nonatomic, assign) id<GADAdFetcherDelegate> delegate;
@property(nonatomic, retain) GADTiming *timer;
@property(nonatomic, retain) GADURLConnection *adConnection, *activationOverlayConnection;
@property(nonatomic, copy) NSString *adResponse, *activationOverlayHTML;
@property(nonatomic, copy) NSURL *adBaseURL, *activationOverlayBaseURL;
@property(nonatomic) BOOL shouldLoadActivationOverlay, adConnectionHasCompleted, activationOverlayConnectionHasCompleted;
- (void)markFetchStart;
- (void)markFetchComplete;
@end

@implementation GADAdFetcher

@dynamic recursiveLock, request, delegate, timer, adConnection, activationOverlayConnection;
@dynamic adResponse, activationOverlayHTML, adBaseURL, activationOverlayBaseURL;
@dynamic shouldLoadActivationOverlay, adConnectionHasCompleted, activationOverlayConnectionHasCompleted;

- (id)init
{
    self = [super init];
    if (self) {
        _recursiveLock = [[NSRecursiveLock alloc] init];
        _adConnection = [[GADURLConnection alloc] init];
        _activationOverlayConnection = [[GADURLConnection alloc] init];
        NSString *category = [NSString stringWithFormat:@"%@ (%p)", NSStringFromClass([self class]), self];
        _timer = [[GADTiming alloc] initWithCategory:category];
    }
    return self;
}

- (void)dealloc
{
    [_recursiveLock lock];
    [self cancel];
    [_request release];
    [_timer release];
    [_adConnection release];
    [_activationOverlayConnection release];
    [_activationOverlayHTML release];
    [_activationOverlayBaseURL release];
    [_adResponse release];
    [_adBaseURL release];
    [_recursiveLock unlock];
    [_recursiveLock release];
    if (_wasDeallocated)
        *_wasDeallocated = YES;
    [super dealloc];
}

- (void)cancel
{
    [_recursiveLock lock];
    _delegate = nil;
    [_adConnection cancel];
    [_activationOverlayConnection cancel];
    [_activationOverlayBaseURL release];
    _activationOverlayBaseURL = nil;
    [_activationOverlayHTML release];
    _activationOverlayHTML = nil;
    [_adBaseURL release];
    _adBaseURL = nil;
    [_adResponse release];
    _adResponse = nil;
    [self setAdConnectionHasCompleted:YES];
    [self setActivationOverlayConnectionHasCompleted:YES];
    [_recursiveLock unlock];
}

- (BOOL)fetchRemainingContentForAd:(GADAd *)ad headers:(NSDictionary *)headers
                          delegate:(id<GADAdFetcherDelegate>)delegate
                           request:(GADRequestPrivate *)request error:(NSError **)error
{
    __block BOOL firstFetch = NO;
    dispatch_once(&_startOncePredicate, ^{ firstFetch = YES; });
    if (!firstFetch) {
        if (error)
            *error = [GADRequestError errorWithCode:2 customMessage:
                @"Could not start fetch. This object has already been used to fetch."];
        return NO;
    }
    [[self recursiveLock] lock];
    [self markFetchStart];
    [self setDelegate:delegate];
    [self setRequest:request];
    NSURL *overlayURL = nil;
    if ([ad shouldLoadActivationOverlayHTML]) {
        overlayURL = [[[ad activationOverlayURL] copy] autorelease];
    } else {
        [self setActivationOverlayHTML:[ad activationOverlayHTML]];
        [self setActivationOverlayBaseURL:[ad activationOverlayBaseURL]];
    }
    [self setShouldLoadActivationOverlay:[ad isActivationAndScrollEnabled]];
    NSURL *adURL = nil;
    if ([ad shouldLoadAdHTML]) {
        adURL = [[[ad adURL] copy] autorelease];
    } else {
        [self setAdResponse:[ad adHTML]];
        [self setAdBaseURL:[ad adBaseURL]];
    }
    BOOL started = [self startFetchWithAdURL:adURL activationOverlayURL:overlayURL headers:headers error:error];
    [[self recursiveLock] unlock];
    return started;
}

- (BOOL)startFetchWithAdURL:(NSURL *)adURL activationOverlayURL:(NSURL *)overlayURL
                     headers:(NSDictionary *)headers error:(NSError **)error
{
    NSError *connectionError = nil;
    if (adURL && ![[self adConnection] startWithURL:adURL forDelegate:self error:&connectionError]) {
        if (error)
            *error = [GADRequestError errorWithCode:2 customMessage:@"Failed to start ad connection."];
        [self setAdConnectionHasCompleted:YES];
        [self setActivationOverlayConnectionHasCompleted:YES];
    } else {
        if (!adURL)
            [self setAdConnectionHasCompleted:YES];
        if (overlayURL && [[self activationOverlayConnection] startWithURL:overlayURL forDelegate:self error:&connectionError]) {
            [self setShouldLoadActivationOverlay:YES];
        } else {
            if (overlayURL && error)
                *error = [GADRequestError errorWithCode:2 customMessage:@"Failed to start activation overlay connection."];
            [self setActivationOverlayConnectionHasCompleted:YES];
        }
    }
    if (headers)
        [self processHTTPHeaders:headers];
    if (connectionError) {
        [self resourceFailedToLoadWithError:connectionError];
        return NO;
    }
    if ([self adConnectionHasCompleted] && [self activationOverlayConnectionHasCompleted])
        dispatch_async(dispatch_get_main_queue(), ^{ [self didCompleteURLConnection]; });
    return YES;
}

- (void)didCompleteURLConnection
{
    [[self recursiveLock] lock];
    BOOL completed = [self adConnectionHasCompleted] && [self activationOverlayConnectionHasCompleted];
    [[self recursiveLock] unlock];
    if (!completed)
        return;
    dispatch_once(&_notifyOncePredicate, ^{
        [[self recursiveLock] lock];
        GADAdFetcher *fetcher = [[self retain] autorelease];
        id<GADAdFetcherDelegate> delegate = [[[fetcher delegate] retain] autorelease];
        BOOL showOverlay = [fetcher shouldLoadActivationOverlay];
        NSString *overlay = [[[fetcher activationOverlayHTML] copy] autorelease];
        NSURL *overlayURL = [[[fetcher activationOverlayBaseURL] copy] autorelease];
        NSString *response = [[[fetcher adResponse] copy] autorelease];
        NSURL *url = [[[fetcher adBaseURL] copy] autorelease];
        [fetcher markFetchComplete];
        [[fetcher recursiveLock] unlock];
        if ([fetcher delegate] == delegate && overlay && showOverlay)
            [delegate handleActivationOverlayResponse:overlay withBaseURL:overlayURL];
        if ([fetcher delegate] == delegate && response)
            [delegate handleAdResponse:response withBaseURL:url];
    });
}

- (void)resourceFailedToLoadWithError:(NSError *)error
{
    [[self recursiveLock] lock];
    id<GADAdFetcherDelegate> delegate = [[[self delegate] retain] autorelease];
    [[self recursiveLock] unlock];
    [delegate didFailToReceiveAdWithError:error];
    [self cancel];
}

- (void)processHTTPHeaders:(NSDictionary *)headers
{
    if (!headers)
        return;
    NSString *trackingHeader = [headers objectForKey:@"X-Afma-Tracking-Urls"];
    NSArray *tracking = [GADNetworkUtilities createArrayOfURLsfromHeader:trackingHeader];
    [[self delegate] addTrackingURLs:tracking];
    NSString *manualHeader = [headers objectForKey:@"X-Afma-Manual-Tracking-Urls"];
    NSArray *manual = [GADNetworkUtilities createArrayOfURLsfromHeader:manualHeader];
    [[self delegate] addManualTrackingURLs:manual];
    NSString *clicksHeader = [headers objectForKey:@"X-Afma-Click-Tracking-Urls"];
    NSArray *clicks = [GADNetworkUtilities createArrayOfURLsfromHeader:clicksHeader];
    [[self delegate] addClickTrackingURLs:clicks];
    int orientation = GADAdSupportedOrientationsFromString([headers objectForKey:@"X-Afma-Orientation"]);
    if (orientation)
        [[self delegate] setRequestedOrientation:orientation];
    NSString *timeout = [headers objectForKey:@"X-Afma-Interstitial-Timeout"];
    if ([timeout length])
        [[NSUserDefaults standardUserDefaults] setDouble:[timeout doubleValue] forKey:@"applicationTimeout"];
    NSString *rate = [headers objectForKey:@"X-Afma-Refresh-Rate"];
    if ([rate length] && [rate doubleValue] >= 0)
        [[self delegate] setRefreshInterval:[rate doubleValue]];
    BOOL mediated = [[headers objectForKey:@"X-Afma-Mediation"] isEqualToString:@"true"];
    BOOL json = [[headers objectForKey:@"Content-Type"] hasPrefix:@"application/json"];
    if (mediated) {
        if (json)
            [[self delegate] setIsMediating:YES];
        else
            [self resourceFailedToLoadWithError:[GADRequestError errorWithCode:3 request:[self request]]];
    } else {
        [[self delegate] setIsMediating:NO];
    }
    [[self delegate] setAdDebugDialog:[headers objectForKey:@"X-Afma-Debug-Dialog"]];
    if ([headers objectForKey:@"X-Afma-Ad-Size"])
        [[self delegate] setNewAdSize:GADCGSizeFromString([headers objectForKey:@"X-Afma-Ad-Size"])];
    if ([[headers objectForKey:@"X-Afma-Disable-Activation-And-Scroll"] isEqualToString:@"1"]) {
        [[self delegate] didDisableScrollingAndActivationOverlay:YES];
        [self setShouldLoadActivationOverlay:NO];
        [[self activationOverlayConnection] stop];
    } else {
        [[self delegate] didDisableScrollingAndActivationOverlay:NO];
    }
}

- (void)connection:(GADURLConnection *)connection loadDidReceiveRedirectResponse:(NSURLResponse *)response
{
    if (connection == [self adConnection]) {
        [[self recursiveLock] lock];
        [self processHTTPHeaders:[GADNetworkUtilities headersFromResponse:response]];
        [[self recursiveLock] unlock];
    }
}

- (BOOL)connection:(GADURLConnection *)connection loadShouldUseCachedResponse:(NSURLResponse *)response
{
    if (connection != [self adConnection])
        return NO;
    [[self recursiveLock] lock];
    [self processHTTPHeaders:[GADNetworkUtilities headersFromResponse:response]];
    BOOL mediated = [[self delegate] isMediating];
    [[self recursiveLock] unlock];
    return mediated;
}

- (void)connection:(GADURLConnection *)connection loadDidReceiveCachedResponse:(NSURLResponse *)response
{
    if (connection == [self adConnection]) {
        [[self recursiveLock] lock];
        [self processHTTPHeaders:[GADNetworkUtilities headersFromResponse:response]];
        [[self recursiveLock] unlock];
    }
    [self activationOverlayConnection];
}

- (void)connection:(GADURLConnection *)connection loadDidFinish:(NSString *)response baseURL:(NSURL *)url
{
    if (connection == [self adConnection]) {
        [[self recursiveLock] lock];
        [self setAdResponse:response];
        [self setAdBaseURL:url];
        [self setAdConnectionHasCompleted:YES];
        [[self recursiveLock] unlock];
    }
    if (connection == [self activationOverlayConnection]) {
        [[self recursiveLock] lock];
        [self setActivationOverlayHTML:response];
        [self setActivationOverlayBaseURL:url];
        [self setActivationOverlayConnectionHasCompleted:YES];
        [[self recursiveLock] unlock];
    }
    [self didCompleteURLConnection];
}

- (void)connection:(GADURLConnection *)connection loadDidFail:(NSError *)error httpStatusCode:(int)status
{
    NSError *failure = nil;
    if (connection == [self adConnection]) {
        [[self recursiveLock] lock];
        [self setAdBaseURL:nil];
        [self setAdResponse:nil];
        [[self recursiveLock] unlock];
        if (status == 400) {
            [GADMacros pubLog:[NSString stringWithFormat:
                @"Server rejected ad parameters. Typically this is because the ad unit ID is incorrect."]];
            failure = [GADRequestError errorWithCode:0 request:[self request]];
        } else if (status > 400) {
            failure = [GADRequestError errorWithCode:3 request:[self request] HTTPStatusCode:status];
        } else {
            failure = [GADRequestError errorWithCode:2 request:[self request] HTTPStatusCode:status];
        }
    }
    if (connection == [self activationOverlayConnection]) {
        [[self recursiveLock] lock];
        [self setActivationOverlayBaseURL:nil];
        [self setActivationOverlayHTML:nil];
        BOOL required = [self shouldLoadActivationOverlay];
        [[self recursiveLock] unlock];
        if (required) {
            NSString *message = [NSString stringWithFormat:
                @"Unable to retrieve Activation Overlay from server. Status code: %ld", (long)status];
            failure = [GADRequestError errorWithCode:3 customMessage:message];
        } else {
            [[self recursiveLock] lock];
            [self setActivationOverlayConnectionHasCompleted:YES];
            [[self recursiveLock] unlock];
            [self didCompleteURLConnection];
        }
    }
    if (failure)
        [self resourceFailedToLoadWithError:failure];
}

@end
