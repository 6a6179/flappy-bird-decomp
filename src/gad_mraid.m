#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GADAdType : NSObject
- (BOOL)isInterstitial;
@end

@interface GADSlot : NSObject
- (GADAdType *)adType;
- (void)setIsMRAID:(BOOL)isMRAID;
- (id)delegateManager;
- (id)adView;
- (id)interstitial;
@end

@interface GADBannerWebViewDelegate : NSObject <UIWebViewDelegate>
- (GADSlot *)slot;
@end

@interface GADAdURLStash : NSObject
+ (BOOL)hasStashedURLs;
+ (UIWebView *)viewForURL:(NSURL *)url;
@end

@interface GADMRAIDInterceptor : NSURLProtocol {
    NSString *_mraidLocationToLoad;
}
@property (copy) NSString *mraidLocationToLoad;
+ (void)resetToDefaultPaths;
@end

static BOOL mraidAllowed;
static dispatch_once_t mraidLockOnce;
static NSLock *mraidClassLock;
static unsigned int mraidRequestCount;
static NSSet *mraidImplementationPaths;
static NSString *mraidBannerPath;
static NSString *mraidExpandedPath;
static NSString *mraidInterstitialPath;

@implementation GADMRAIDInterceptor

@dynamic mraidLocationToLoad;

+ (NSLock *)classLock
{
    dispatch_once(&mraidLockOnce, ^{
        mraidClassLock = [[NSLock alloc] init];
    });
    return mraidClassLock;
}

+ (void)enableCanInitWithRequest
{
    NSLock *lock = [self classLock];
    [lock lock];
    ++mraidRequestCount;
    [lock unlock];
}

+ (void)disableCanInitWithRequest
{
    NSLock *lock = [self classLock];
    [lock lock];
    --mraidRequestCount;
    [lock unlock];
}

+ (BOOL)canInitWithRequestIsEnabled
{
    NSLock *lock = [self classLock];
    [lock lock];
    if (mraidAllowed == YES) {
        unsigned int count = mraidRequestCount;
        [lock unlock];
        if (count && [GADAdURLStash hasStashedURLs])
            return YES;
        return NO;
    }
    [lock unlock];
    return NO;
}

+ (void)disallow
{
    NSLock *lock = [self classLock];
    [lock lock];
    if (mraidAllowed == YES)
        mraidAllowed = NO;
    [lock unlock];
}

+ (void)allow
{
    NSLock *lock = [self classLock];
    [lock lock];
    if (!mraidAllowed)
        mraidAllowed = YES;
    [lock unlock];
}

+ (void)initialize
{
    if (self == [GADMRAIDInterceptor class]) {
        [self resetToDefaultPaths];
        [NSURLProtocol registerClass:[self class]];
        [self allow];
    }
}

+ (BOOL)urlIsAnImplementationPath:(NSURL *)url
{
    NSLock *lock = [self classLock];
    NSString *path = [url absoluteString];
    [lock lock];
    BOOL found = [mraidImplementationPaths containsObject:path];
    [lock unlock];
    return found;
}

+ (void)updateImplementationsPaths
{
    if (mraidBannerPath && mraidExpandedPath && mraidInterstitialPath) {
        [mraidImplementationPaths release];
        mraidImplementationPaths = [[NSSet setWithArray:@[
            mraidBannerPath, mraidExpandedPath, mraidInterstitialPath]] retain];
    }
}

+ (void)setBannerImplementationPath:(NSString *)path
{
    NSLock *lock = [self classLock];
    [lock lock];
    if (mraidBannerPath != path) {
        [mraidBannerPath release];
        mraidBannerPath = [path copy];
        [self updateImplementationsPaths];
    }
    [lock unlock];
}

+ (NSString *)bannerImplementationPath
{
    NSLock *lock = [self classLock];
    [lock lock];
    NSString *path = [[mraidBannerPath retain] autorelease];
    [lock unlock];
    return path;
}

+ (void)setInterstitialImplementationPath:(NSString *)path
{
    NSLock *lock = [self classLock];
    [lock lock];
    if (mraidInterstitialPath != path) {
        [mraidInterstitialPath release];
        mraidInterstitialPath = [path copy];
        [self updateImplementationsPaths];
    }
    [lock unlock];
}

+ (NSString *)interstitialImplementationPath
{
    NSLock *lock = [self classLock];
    [lock lock];
    NSString *path = [[mraidInterstitialPath retain] autorelease];
    [lock unlock];
    return path;
}

+ (void)setExpandedBannerImplementationPath:(NSString *)path
{
    NSLock *lock = [self classLock];
    [lock lock];
    if (mraidExpandedPath != path) {
        [mraidExpandedPath release];
        mraidExpandedPath = [path copy];
        [self updateImplementationsPaths];
    }
    [lock unlock];
}

+ (NSString *)expandedBannerImplementationPath
{
    NSLock *lock = [self classLock];
    [lock lock];
    NSString *path = [[mraidExpandedPath retain] autorelease];
    [lock unlock];
    return path;
}

+ (NSURL *)refererURLFromRequest:(NSURLRequest *)request
{
    NSString *referer = [request valueForHTTPHeaderField:@"referer"];
    return [referer length] ? [NSURL URLWithString:referer] : nil;
}

+ (BOOL)shouldRedirectForMRAID:(NSURLRequest *)request
{
    NSURL *url = [request URL];
    if ([self urlIsAnImplementationPath:url])
        return NO;
    return [[[url path] lastPathComponent] isEqualToString:@"mraid.js"];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if (![self canInitWithRequestIsEnabled])
        return NO;
    [request retain];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [request autorelease];
    BOOL redirect;
    if ([self shouldRedirectForMRAID:request]) {
        NSURL *referer = [self refererURLFromRequest:request];
        if ([GADAdURLStash viewForURL:referer]) {
            redirect = YES;
            goto finish;
        }
    }
    redirect = NO;
finish:
    [pool drain];
    return redirect;
}

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)response
               client:(id<NSURLProtocolClient>)client
{
    self = [super initWithRequest:request cachedResponse:response client:client];
    if (self) {
        NSURL *referer = [GADMRAIDInterceptor refererURLFromRequest:request];
        if (referer) {
            UIWebView *view = [GADAdURLStash viewForURL:referer];
            if ([[view delegate] isKindOfClass:[GADBannerWebViewDelegate class]]) {
                GADSlot *slot = [(GADBannerWebViewDelegate *)[view delegate] slot];
                if ([[slot adType] isInterstitial])
                    _mraidLocationToLoad = [[GADMRAIDInterceptor interstitialImplementationPath] copy];
                else
                    _mraidLocationToLoad = [[GADMRAIDInterceptor bannerImplementationPath] copy];
                [slot setIsMRAID:YES];
            } else {
                _mraidLocationToLoad = [[GADMRAIDInterceptor expandedBannerImplementationPath] copy];
            }
        }
    }
    return self;
}

- (void)startLoading
{
    if (![self mraidLocationToLoad]) {
        NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSURLErrorBadURL userInfo:nil];
        [[self client] URLProtocol:self didFailWithError:error];
        return;
    }
    NSURL *url = [NSURL URLWithString:[self mraidLocationToLoad]];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSURLResponse *response = [[[NSURLResponse alloc] initWithURL:url MIMEType:@"application/javascript"
                                          expectedContentLength:[data length] textEncodingName:nil] autorelease];
    id<NSURLProtocolClient> client = [self client];
    [client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    [client URLProtocol:self didLoadData:data];
    [client URLProtocolDidFinishLoading:self];
}

+ (BOOL)isAllowed
{
    NSLock *lock = [self classLock];
    [lock lock];
    BOOL allowed = mraidAllowed;
    [lock unlock];
    return allowed;
}

+ (void)resetCanInitWithRequestCounter
{
    NSLock *lock = [self classLock];
    [lock lock];
    mraidRequestCount = 0;
    [lock unlock];
}

@end
