#import <UIKit/UIKit.h>

@interface GADAdURLStash : NSObject
+ (NSURL *)canonicalURLForURL:(NSURL *)url;
+ (CFMutableDictionaryRef)urlStash;
+ (NSLock *)urlStashLock;
@end

struct {
    dispatch_once_t dictionaryOnce;
    CFMutableDictionaryRef dictionary;
    dispatch_once_t lockOnce;
    NSLock *lock;
} GADAdURLStashStorage = {0};

@implementation GADAdURLStash

+ (void)add:(NSURL *)url forView:(UIWebView *)view
{
    NSURL *key = [self canonicalURLForURL:url];
    if (key) {
        [[self urlStashLock] lock];
        CFDictionarySetValue([self urlStash], key, view);
        [[self urlStashLock] unlock];
    }
}

+ (void)remove:(NSURL *)url
{
    NSURL *key = [self canonicalURLForURL:url];
    if (key) {
        [[self urlStashLock] lock];
        CFDictionaryRemoveValue([self urlStash], key);
        [[self urlStashLock] unlock];
    }
}

+ (UIWebView *)viewForURL:(NSURL *)url
{
    NSURL *key = [self canonicalURLForURL:url];
    if (!key)
        return nil;
    [[self urlStashLock] lock];
    UIWebView *view = (UIWebView *)CFDictionaryGetValue([self urlStash], key);
    [[self urlStashLock] unlock];
    return view;
}

+ (BOOL)hasStashedURLs
{
    [[self urlStashLock] lock];
    CFIndex count = CFDictionaryGetCount([self urlStash]);
    [[self urlStashLock] unlock];
    return count != 0;
}

+ (NSURL *)canonicalURLForURL:(NSURL *)url
{
    if (!url)
        return nil;
    if ([url port])
        return url;
    NSString *host = [url host];
    if (!host)
        return url;
    NSString *hostWithPort = [host stringByAppendingString:@":80"];
    NSString *value = [[url absoluteString] stringByReplacingOccurrencesOfString:host withString:hostWithPort];
    NSRange fragment = [value rangeOfString:@"#" options:NSBackwardsSearch];
    if (fragment.location != NSNotFound)
        value = [value substringToIndex:fragment.location];
    NSRange slash = [value rangeOfString:@"/" options:NSBackwardsSearch];
    if (slash.location == [value length] - 1)
        value = [value stringByReplacingCharactersInRange:slash withString:@""];
    return [NSURL URLWithString:value];
}

+ (CFMutableDictionaryRef)urlStash
{
    dispatch_once(&GADAdURLStashStorage.dictionaryOnce, ^{
        CFDictionaryValueCallBacks callbacks = kCFTypeDictionaryValueCallBacks;
        callbacks.retain = NULL;
        callbacks.release = NULL;
        callbacks.copyDescription = NULL;
        GADAdURLStashStorage.dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0,
            &kCFTypeDictionaryKeyCallBacks, &callbacks);
    });
    return GADAdURLStashStorage.dictionary;
}

+ (NSLock *)urlStashLock
{
    dispatch_once(&GADAdURLStashStorage.lockOnce, ^{
        GADAdURLStashStorage.lock = [[NSLock alloc] init];
    });
    return GADAdURLStashStorage.lock;
}

@end

extern NSString *const kGADErrorDomain;

@class GADClickTracker;
@protocol GADClickTrackerDelegate <NSObject>
- (void)tracker:(GADClickTracker *)tracker didRedirect:(NSURL *)url;
- (void)tracker:(GADClickTracker *)tracker didFailWithError:(NSError *)error;
@end
@interface GADCachedFile : NSObject
- (id)initWithDelegate:(id)delegate URL:(NSURL *)url;
- (void)validate;
- (void)invalidate;
- (void)setDelegate:(id)delegate;
@end
@interface GADClickTracker : NSObject {
    GADCachedFile *tracker_;
    id<GADClickTrackerDelegate> delegate_;
    BOOL hasTracked_;
    UIBackgroundTaskIdentifier backgroundTaskID_;
}
- (NSURL *)trackingURL;
- (void)setDelegate:(id<GADClickTrackerDelegate>)delegate;
- (BOOL)hasTracked;
@end

@implementation GADClickTracker

- (void)trackURL:(NSURL *)url
{
    if (url) {
        [self reset];
        [self beginBackgroundTask];
        tracker_ = [[GADCachedFile alloc] initWithDelegate:self URL:url];
        [tracker_ validate];
    }
}

- (void)reset
{
    hasTracked_ = NO;
    [tracker_ setDelegate:nil];
    [tracker_ invalidate];
    [tracker_ release];
    tracker_ = nil;
    [self endBackgroundTask];
}

- (NSError *)cachedFile:(GADCachedFile *)file shouldRedirectToURL:(NSURL *)url
{
    if ([[[url scheme] lowercaseString] hasPrefix:@"http"])
        return nil;
    [self cachedFileDownloadDidEnd:file];
    return [NSError errorWithDomain:kGADErrorDomain code:0 userInfo:nil];
}

- (void)cachedFileDownloadDidEnd:(GADCachedFile *)file
{
    if (!hasTracked_) {
        hasTracked_ = YES;
        if ([delegate_ respondsToSelector:@selector(tracker:didRedirect:)])
            [delegate_ tracker:self didRedirect:[self trackingURL]];
        [self endBackgroundTask];
    }
}

- (void)cachedFile:(GADCachedFile *)file downloadDidFail:(NSError *)error
{
    if (!hasTracked_) {
        hasTracked_ = YES;
        if ([delegate_ respondsToSelector:@selector(tracker:didFailWithError:)])
            [delegate_ tracker:self didFailWithError:error];
        [self endBackgroundTask];
    }
}

- (void)beginBackgroundTask
{
    backgroundTaskID_ = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self reset];
    }];
}

- (void)endBackgroundTask
{
    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskID_];
    backgroundTaskID_ = 0;
}

@end

@interface GADClickTrackerCollection : NSObject <GADClickTrackerDelegate> {
    NSMutableSet *trackers_;
}
@end

struct {
    GADClickTrackerCollection *instance;
    dispatch_once_t once;
} GADClickTrackerCollectionStorage = {0};

@implementation GADClickTrackerCollection

+ (id)sharedInstance
{
    dispatch_once(&GADClickTrackerCollectionStorage.once, ^{
        GADClickTrackerCollectionStorage.instance = [[GADClickTrackerCollection alloc] init];
    });
    return GADClickTrackerCollectionStorage.instance;
}

- (id)init
{
    self = [super init];
    if (self)
        trackers_ = [[NSMutableSet alloc] init];
    return self;
}

- (void)dealloc
{
    [trackers_ makeObjectsPerformSelector:@selector(reset)];
    [trackers_ release];
    trackers_ = nil;
    [super dealloc];
}

- (void)trackURLs:(NSArray *)urls
{
    for (id value in urls) {
        NSURL *url = value;
        if ([value isKindOfClass:[NSString class]])
            url = [NSURL URLWithString:value];
        if ([url isKindOfClass:[NSURL class]]) {
            GADClickTracker *tracker = [[[GADClickTracker alloc] init] autorelease];
            [tracker setDelegate:self];
            [tracker trackURL:url];
            [trackers_ addObject:tracker];
        }
    }
}

- (void)cleanupTrackers
{
    NSMutableSet *completed = [NSMutableSet set];
    for (GADClickTracker *tracker in trackers_) {
        if ([tracker hasTracked])
            [completed addObject:tracker];
    }
    [trackers_ minusSet:completed];
}

- (void)tracker:(GADClickTracker *)tracker didRedirect:(NSURL *)url
{
    [self performSelector:@selector(cleanupTrackers) withObject:nil afterDelay:0];
}

- (void)tracker:(GADClickTracker *)tracker didFailWithError:(NSError *)error
{
    [self performSelector:@selector(cleanupTrackers) withObject:nil afterDelay:0];
}

@end

#import <CommonCrypto/CommonDigest.h>

unsigned long long GADSessionGenerateSessionID(void)
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFUUIDBytes bytes = CFUUIDGetUUIDBytes(uuid);
    CFRelease(uuid);
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(&bytes, sizeof(bytes), digest);
    unsigned long long identifier;
    memcpy(&identifier, digest + sizeof(identifier), sizeof(identifier));
    return identifier;
}

@interface GADSession : NSObject {
    unsigned long long _sessionID;
}
- (unsigned long long)sessionID;
@end

@implementation GADSession
- (id)init
{
    self = [super init];
    if (self)
        _sessionID = GADSessionGenerateSessionID();
    return self;
}

- (NSString *)sessionIDAsString
{
    return [NSString stringWithFormat:@"%qu", [self sessionID]];
}
@end

@interface GADURLConnection : NSObject
- (void)setDelegate:(id)delegate;
- (void)startWithURL:(NSURL *)url withData:(NSData *)data andType:(NSString *)type forDelegate:(id)delegate;
@end
@interface NSDictionary (GADJSONAdditions)
- (NSString *)gad_JSONStringPretty:(BOOL)pretty sortKeys:(BOOL)sortKeys error:(NSError **)error;
@end
@interface GADBadAdUtil : NSObject
- (GADURLConnection *)connection;
- (GADURLConnection *)urlConnection;
- (void)setConnection:(GADURLConnection *)connection;
@end

struct {
    GADBadAdUtil *instance;
    dispatch_once_t once;
} GADBadAdUtilStorage = {0};

@implementation GADBadAdUtil

+ (id)sharedInstance
{
    dispatch_once(&GADBadAdUtilStorage.once, ^{
        GADBadAdUtilStorage.instance = [[GADBadAdUtil alloc] init];
    });
    return GADBadAdUtilStorage.instance;
}

- (void)reportBadAd:(NSString *)dialog
{
    NSURL *url = [self badAdURL];
    if (url) {
        NSData *payload = [self jsonData:dialog];
        [[self connection] setDelegate:nil];
        [self setConnection:[self urlConnection]];
        [[self connection] startWithURL:url withData:payload andType:@"application/json" forDelegate:self];
    }
}

- (NSData *)jsonData:(NSString *)dialog
{
    id header = dialog ?: [NSNull null];
    NSDictionary *fields = [NSDictionary dictionaryWithObject:header forKey:@"debugHeader"];
    NSString *json = [fields gad_JSONStringPretty:NO sortKeys:NO error:NULL];
    return [(json ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSURL *)badAdURL
{
    NSString *custom = [[NSUserDefaults standardUserDefaults] stringForKey:@"bad_ad_report_path"];
    NSString *url = [custom length] ? custom : @"https://badad.googleplex.com/s/reportAd";
    return [NSURL URLWithString:url];
}
@end

int GADAdSupportedOrientationsFromString(NSString *orientation)
{
    if (![orientation length])
        return 0;
    if ([orientation isEqualToString:@"any"])
        return 1;
    if ([orientation isEqualToString:@"portrait"])
        return 2;
    return [orientation isEqualToString:@"landscape"] ? 3 : 0;
}
