#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach/mach_time.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface GADNetworkChecker : NSObject {
    unsigned _changeCount;
    unsigned _networkType;
    SCNetworkReachabilityRef _networkReachabilityRef;
    NSRecursiveLock *_lock;
}
@property (nonatomic, retain) NSRecursiveLock *lock;
- (BOOL)isEnabled;
- (void)setEnabled:(BOOL)enabled;
- (unsigned)networkType;
- (void)setNetworkType:(unsigned)type;
- (SCNetworkReachabilityRef)networkReachabilityRef;
- (void)setNetworkReachabilityRef:(SCNetworkReachabilityRef)ref;
- (void)setNetworkTypeFromFlags:(SCNetworkReachabilityFlags)flags;
- (void)startNetworkChecking;
- (void)stopNetworkChecking;
@end

static void GADNetworkReachabilityChanged(SCNetworkReachabilityRef reachability,
                                          SCNetworkReachabilityFlags flags, void *info)
{
    [(GADNetworkChecker *)info setNetworkTypeFromFlags:flags];
}

static struct {
    dispatch_once_t once;
    GADNetworkChecker *checker;
} gadSharedNetworkChecker;

@implementation GADNetworkChecker

+ (GADNetworkChecker *)sharedChecker
{
    dispatch_once(&gadSharedNetworkChecker.once, ^{
        gadSharedNetworkChecker.checker = [[GADNetworkChecker alloc] init];
        [gadSharedNetworkChecker.checker setEnabled:YES];
    });
    return gadSharedNetworkChecker.checker;
}

@synthesize lock = _lock;

- (void)dealloc
{
    [self stopNetworkChecking];
    [_lock release];
    [super dealloc];
}

- (id)init
{
    if ((self = [super init])) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (NSString *)networkTypeString
{
    [[self lock] lock];
    NSString *result = nil;
    if ([self networkType] != 0 && [self networkType] != 1) {
        result = [self networkType] == 2 ? @"wi" : @"ed";
    }
    [[self lock] unlock];
    return result;
}

- (unsigned)changeCount
{
    [[self lock] lock];
    unsigned count = _changeCount;
    [[self lock] unlock];
    return count;
}

- (BOOL)isEnabled
{
    [[self lock] lock];
    BOOL enabled = [self networkReachabilityRef] != NULL;
    [[self lock] unlock];
    return enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    [[self lock] lock];
    if ([self isEnabled] != enabled) {
        if (enabled) {
            [self startNetworkChecking];
        } else {
            [self stopNetworkChecking];
        }
    }
    [[self lock] unlock];
}

- (unsigned)networkType
{
    [[self lock] lock];
    unsigned type = _networkType;
    [[self lock] unlock];
    return type;
}

- (void)setNetworkType:(unsigned)type
{
    [[self lock] lock];
    if (type != _networkType) {
        if (type != 0) {
            _changeCount++;
        }
        _networkType = type;
    }
    [[self lock] unlock];
}

- (void)setNetworkTypeFromFlags:(SCNetworkReachabilityFlags)flags
{
    if (flags & kSCNetworkReachabilityFlagsReachable) {
        [self setNetworkType:2];
        if (flags & kSCNetworkReachabilityFlagsIsWWAN) {
            [self setNetworkType:3];
        }
    } else {
        [self setNetworkType:1];
    }
}

- (void)startNetworkChecking
{
    [[self lock] lock];
    if (![self networkReachabilityRef]) {
        [self setNetworkType:0];
        [self setNetworkReachabilityRef:SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, "www.google.com")];
        if ([self networkReachabilityRef]) {
            BOOL active = SCNetworkReachabilityScheduleWithRunLoop([self networkReachabilityRef],
                CFRunLoopGetMain(), kCFRunLoopCommonModes);
            if (active) {
                SCNetworkReachabilityContext context = {0, self, NULL, NULL, NULL};
                active = SCNetworkReachabilitySetCallback([self networkReachabilityRef],
                    GADNetworkReachabilityChanged, &context);
            }
            if (!active) {
                CFRelease([self networkReachabilityRef]);
                [self setNetworkReachabilityRef:NULL];
            }
        }
    }
    [[self lock] unlock];
}

- (void)stopNetworkChecking
{
    [[self lock] lock];
    if ([self networkReachabilityRef]) {
        SCNetworkReachabilityUnscheduleFromRunLoop([self networkReachabilityRef], CFRunLoopGetMain(), kCFRunLoopCommonModes);
        CFRelease([self networkReachabilityRef]);
        [self setNetworkReachabilityRef:NULL];
        [self setNetworkType:0];
    }
    [[self lock] unlock];
}

- (SCNetworkReachabilityRef)networkReachabilityRef
{
    return _networkReachabilityRef;
}

- (void)setNetworkReachabilityRef:(SCNetworkReachabilityRef)ref
{
    _networkReachabilityRef = ref;
}
@end

@interface GADTiming : NSObject {
    NSMutableDictionary *_userData;
    BOOL _explicitEnd;
    NSString *_category;
    NSLock *_timeIntervalLock;
    double _startTimestamp;
    double _endTimestamp;
}
+ (double)counter;
- (id)initWithCategory:(NSString *)category;
- (id)initWithDictionaryRepresentation:(NSDictionary *)representation;
- (NSDictionary *)dictionaryRepresentation;
@property (nonatomic, copy) NSString *category;
@property (nonatomic, retain) NSLock *timeIntervalLock;
- (double)startTimestamp;
- (void)setStartTimestamp:(double)timestamp;
- (double)endTimestamp;
- (void)setEndTimestamp:(double)timestamp;
- (BOOL)explicitEnd;
- (unsigned)elapsedMilliseconds;
@end

static dispatch_once_t gadTimebaseOnce;
static double gadSecondsPerTick;

@implementation GADTiming

+ (double)counter
{
    dispatch_once(&gadTimebaseOnce, ^{
        mach_timebase_info_data_t timebase = {0};
        mach_timebase_info(&timebase);
        gadSecondsPerTick = (double)timebase.numer / timebase.denom / 1000000000.0;
    });
    return gadSecondsPerTick * mach_absolute_time();
}

@synthesize category = _category;
@synthesize timeIntervalLock = _timeIntervalLock;

- (signed char)explicitEnd
{
    return _explicitEnd;
}

- (void)setExplicitEnd:(signed char)value
{
    _explicitEnd = value;
}

- (double)startTimestamp
{
    return _startTimestamp;
}

- (void)setStartTimestamp:(double)value
{
    _startTimestamp = value;
}

- (double)endTimestamp
{
    return _endTimestamp;
}

- (void)setEndTimestamp:(double)value
{
    _endTimestamp = value;
}

- (id)init
{
    return [self initWithCategory:nil];
}

- (void)dealloc
{
    [_timeIntervalLock release];
    [_category release];
    [_userData release];
    [super dealloc];
}

- (id)initWithCategory:(NSString *)category
{
    if ((self = [super init])) {
        if (category) {
            _category = [category copy];
        } else {
            _category = [[NSString stringWithFormat:@"%@ (%p)", NSStringFromClass([self class]), self] retain];
        }
        if (!_category) {
            [self release];
            return nil;
        }
        _timeIntervalLock = [[NSLock alloc] init];
        _userData = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithDictionaryRepresentation:(NSDictionary *)representation
{
    if ((self = [self initWithCategory:[representation objectForKey:@"category"]])) {
        _startTimestamp = [[representation objectForKey:@"start"] doubleValue];
        _endTimestamp = [[representation objectForKey:@"end"] doubleValue];
        [_userData autorelease];
        _userData = [[representation objectForKey:@"userData"] mutableCopy];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ (%p): %@", NSStringFromClass([self class]), self, [self dictionaryRepresentation]];
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[GADTiming allocWithZone:zone] initWithDictionaryRepresentation:[self dictionaryRepresentation]];
}

- (NSDictionary *)dictionaryRepresentation
{
    @synchronized (self) {
        [[self timeIntervalLock] lock];
        NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
            @"category": [self category],
            @"start": @([self startTimestamp]),
            @"end": @([self endTimestamp])
        }];
        [[self timeIntervalLock] unlock];
        if ([_userData count]) {
            [result setObject:[NSDictionary dictionaryWithDictionary:_userData] forKey:@"userData"];
        }
        return result;
    }
}

- (void)start
{
    [[self timeIntervalLock] lock];
    [self setStartTimestamp:[GADTiming counter]];
    [self setEndTimestamp:0.0];
    [[self timeIntervalLock] unlock];
}

- (void)end
{
    [[self timeIntervalLock] lock];
    if ([self startTimestamp] > 0) {
        [self setEndTimestamp:[GADTiming counter]];
    }
    [[self timeIntervalLock] unlock];
}

- (void)reset
{
    [[self timeIntervalLock] lock];
    [self setStartTimestamp:0];
    [self setEndTimestamp:0];
    [[self timeIntervalLock] unlock];
}

- (unsigned)elapsedMilliseconds
{
    [[self timeIntervalLock] lock];
    double end = [self endTimestamp];
    if (end < [self startTimestamp]) {
        if ([self explicitEnd]) {
            [[self timeIntervalLock] unlock];
            return 0;
        }
        end = [GADTiming counter];
    }
    double start = [self startTimestamp];
    [[self timeIntervalLock] unlock];
    return (end - start) * 1000.0;
}

- (NSString *)elapsedMillisecondsString
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)[self elapsedMilliseconds]];
}

- (BOOL)isActive
{
    [[self timeIntervalLock] lock];
    BOOL active = [self startTimestamp] > 0 && [self endTimestamp] == 0;
    [[self timeIntervalLock] unlock];
    return active;
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    @synchronized (self) {
        if (value && key) {
            [_userData setObject:value forKey:key];
        }
    }
}

- (id)valueForKey:(NSString *)key
{
    @synchronized (self) {
        return [_userData objectForKey:key];
    }
}

- (void)removeValueForKey:(NSString *)key
{
    @synchronized (self) {
        [_userData removeObjectForKey:key];
    }
}

- (NSDictionary *)keysAndValues
{
    @synchronized (self) {
        return [NSDictionary dictionaryWithDictionary:_userData];
    }
}
@end

@interface GADTimingManager : NSObject {
    NSString *identifier_;
    NSMutableDictionary *timings_;
    NSUserDefaults *userDefaults_;
    NSString *userDefaultsKey_;
    NSArray *transientTimings_;
}
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, retain) NSUserDefaults *userDefaults;
@property (nonatomic, retain) NSArray *transientTimings;
- (void)loadPersistentTimings;
- (void)savePersistentTimings;
- (NSString *)userDefaultsKey;
- (void)removeTimingForCategory:(NSString *)category;
@end

@implementation GADTimingManager

@synthesize identifier = identifier_;
@synthesize userDefaults = userDefaults_;
@synthesize transientTimings = transientTimings_;

- (NSArray *)timings
{
    return [timings_ allValues];
}

- (NSArray *)categories
{
    return [timings_ allKeys];
}

- (void)synchronize
{
    [self savePersistentTimings];
}

- (void)addTiming:(GADTiming *)timing
{
    if (timing == nil) {
        return;
    }
    [timings_ setObject:timing forKey:[timing category]];
}

- (id)addTimingWithCategory:(NSString *)category
{
    GADTiming *result = [[[GADTiming alloc] initWithCategory:category] autorelease];
    [self addTiming:result];
    return result;
}

- (id)timingForCategory:(NSString *)category
{
    return [timings_ objectForKey:category];
}

- (void)removeTiming:(GADTiming *)timing
{
    [timings_ removeObjectForKey:[timing category]];
}

- (void)removeTimingForCategory:(NSString *)category
{
    [timings_ removeObjectForKey:category];
}

- (void)removeAllTimings
{
    [timings_ removeAllObjects];
}

- (void)loadPersistentTimings
{
    NSString *key = [self userDefaultsKey];
    if (!key) {
        return;
    }
    NSDictionary *saved = [userDefaults_ objectForKey:key];
    for (NSString *category in [saved allKeys]) {
        if ([transientTimings_ containsObject:category]) {
            [timings_ removeObjectForKey:category];
        } else {
            NSDictionary *representation = [saved objectForKey:category];
            GADTiming *timing = [[GADTiming alloc] initWithDictionaryRepresentation:representation];
            [timings_ setObject:timing forKey:category];
            [timing release];
        }
    }
}

- (void)savePersistentTimings
{
    NSString *key = [self userDefaultsKey];
    if (!key) {
        return;
    }
    NSMutableDictionary *saved = [NSMutableDictionary dictionary];
    for (NSString *category in [timings_ allKeys]) {
        if (![transientTimings_ containsObject:category]) {
            [saved setObject:[[timings_ objectForKey:category] dictionaryRepresentation] forKey:category];
        }
    }
    [userDefaults_ setObject:saved forKey:key];
    [userDefaults_ synchronize];
}

- (id)init
{
    if ((self = [super init])) {
        timings_ = [[NSMutableDictionary alloc] init];
        userDefaults_ = [[NSUserDefaults alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self savePersistentTimings];
    [userDefaults_ release];
    userDefaults_ = nil;
    [timings_ release];
    timings_ = nil;
    [identifier_ release];
    identifier_ = nil;
    [userDefaultsKey_ release];
    userDefaultsKey_ = nil;
    [transientTimings_ release];
    transientTimings_ = nil;
    [super dealloc];
}

- (NSString *)userDefaultsKey
{
    if (!userDefaultsKey_) {
        if (!identifier_) {
            return nil;
        }
        userDefaultsKey_ = [NSString stringWithFormat:@"google_timing_%@", identifier_];
        [userDefaultsKey_ retain];
    }
    return userDefaultsKey_;
}

- (void)setIdentifier:(NSString *)identifier
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [identifier_ autorelease];
    identifier_ = [identifier copy];
    [self loadPersistentTimings];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(savePersistentTimings)
        name:UIApplicationWillTerminateNotification object:nil];
}

- (void)removeTimingsForCategories:(NSArray *)categories
{
    for (NSString *category in categories) {
        [self removeTimingForCategory:category];
    }
}
@end

#import <sys/stat.h>
#import <sys/time.h>

@class GADCachedFile;

@protocol GADCachedFileDelegate
- (NSError *)cachedFile:(GADCachedFile *)file shouldRedirectToURL:(NSURL *)url;
- (void)cachedFile:(GADCachedFile *)file downloadDidFail:(NSError *)error;
- (void)cachedFileDownloadDidEnd:(GADCachedFile *)file;
@end

@interface GADNetworkUtilities : NSObject
+ (NSURL *)appendQueryKey:(NSString *)key value:(NSString *)value toURL:(NSURL *)url;
+ (NSString *)userAgentString;
+ (NSURL *)appendQueryParameters:(NSDictionary *)parameters toURL:(NSURL *)url;
+ (NSString *)encodeURL:(NSString *)value;
@end

@interface GADMNSURLConnectionFactory : NSObject
+ (GADMNSURLConnectionFactory *)sharedFactory;
- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)start;
@end

@interface GADCachedFile : NSObject {
    id<GADCachedFileDelegate> delegate_;
    NSURL *sourceURL_;
    NSString *filePath_;
    NSURLConnection *connection_;
    NSMutableData *receivedData_;
    NSString *receivedModificationDate_;
    NSURL *httpDestinationURL_;
    NSInteger httpStatusCode_;
    NSDictionary *httpHeaders_;
    NSDictionary *userInfo_;
}
@property (nonatomic, retain) NSDictionary *userInfo;
@property (nonatomic, retain) NSURL *sourceURL;
@property (nonatomic, retain) NSURL *httpDestinationURL;
- (id<GADCachedFileDelegate>)delegate;
- (void)beginFetchWithCacheBuster:(BOOL)cacheBuster;
- (void)clear;
- (void)invalidate;
- (void)saveDataToFile;
- (void)cleanUpConnection;
- (void)saveHeadersFromResponse:(NSURLResponse *)response;
- (void)processResponse:(NSURLResponse *)response;
@end

static NSDateFormatter *gadHTTPDateFormatter;

@implementation GADCachedFile

@synthesize userInfo = userInfo_;
@synthesize sourceURL = sourceURL_;
@synthesize httpDestinationURL = httpDestinationURL_;

- (void)setDelegate:(id)value
{
    delegate_ = value;
}

- (int)httpStatusCode
{
    return httpStatusCode_;
}

- (id)httpHeaders
{
    return httpHeaders_;
}

- (id<GADCachedFileDelegate>)delegate
{
    [[self retain] autorelease];
    return delegate_;
}

- (void)validate
{
    if (connection_ != nil) {
        return;
    }
    [self beginFetchWithCacheBuster:0];
}

- (void)validateWithCacheBuster
{
    if (connection_ != nil) {
        return;
    }
    [self beginFetchWithCacheBuster:1];
}

- (void)cancel
{
    [self cleanUpConnection];
}

- (void)connectionDidFinishLoading:(id)connection
{
    [self saveDataToFile];
    [self cleanUpConnection];
}

- (void)connection:(id)connection didFailWithError:(id)error
{
    [self cleanUpConnection];
    [[self delegate] cachedFile:self downloadDidFail:error];
}


+ (NSDateFormatter *)formatterForHTTPDate
{
    if (!gadHTTPDateFormatter) {
        gadHTTPDateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        [gadHTTPDateFormatter setDateFormat:@"EEE, dd MMM yyyy HH:mm:ss"];
        [gadHTTPDateFormatter setLocale:locale];
        [gadHTTPDateFormatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        [locale release];
    }
    return gadHTTPDateFormatter;
}

- (NSString *)filePath
{
    if (![filePath_ length]) {
        NSArray *directories = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if ([directories count]) {
            NSString *host = [sourceURL_ host];
            unsigned long hashValue = [[sourceURL_ absoluteString] hash];
            NSString *hash = [NSString stringWithFormat:@"%lx", hashValue];
            NSString *relative = [(host ? host : @"@local") stringByAppendingPathComponent:hash];
            filePath_ = [[[directories objectAtIndex:0] stringByAppendingPathComponent:relative] retain];
        }
    }
    return filePath_;
}

- (BOOL)fileExists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self filePath]];
}

- (NSString *)fileModificationDate
{
    struct stat attributes;
    if (stat([[self filePath] fileSystemRepresentation], &attributes) == -1) {
        return nil;
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:attributes.st_mtime];
    return [[GADCachedFile formatterForHTTPDate] stringFromDate:date];
}

- (id)initWithDelegate:(id<GADCachedFileDelegate>)delegate URL:(NSURL *)url
{
    if ((self = [super init])) {
        sourceURL_ = [url copy];
        httpDestinationURL_ = [url copy];
        delegate_ = delegate;
    }
    return self;
}

- (void)validateWithDelegate:(id<GADCachedFileDelegate>)delegate URL:(NSURL *)url
{
    [self invalidate];
    [self clear];
    sourceURL_ = [url copy];
    httpDestinationURL_ = [url copy];
    delegate_ = delegate;
    [self validate];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> HTTP code: %ld\n\turl: %@\n\tfile: %@",
        NSStringFromClass([self class]), self, (long)httpStatusCode_, [sourceURL_ absoluteString], [self filePath]];
}

- (void)dealloc
{
    delegate_ = nil;
    [userInfo_ release];
    [self clear];
    [super dealloc];
}

- (void)beginFetchWithCacheBuster:(BOOL)cacheBuster
{
    NSMutableURLRequest *request;
    if (cacheBuster) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        NSString *unique = [NSString stringWithFormat:@"%.0f", now];
        NSURL *url = [GADNetworkUtilities appendQueryKey:@"unique" value:unique toURL:sourceURL_];
        request = [NSMutableURLRequest requestWithURL:url];
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    } else {
        request = [NSMutableURLRequest requestWithURL:sourceURL_];
    }
    [request setHTTPShouldHandleCookies:YES];
    NSString *userAgent = [GADNetworkUtilities userAgentString];
    if ([userAgent length]) {
        [request setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    }
    NSString *modified = [self fileModificationDate];
    if (modified) {
        [request setValue:modified forHTTPHeaderField:@"If-Modified-Since"];
    }
    connection_ = [[GADMNSURLConnectionFactory sharedFactory] newConnectionWithRequest:request
        delegate:self startImmediately:NO];
    if (connection_) {
        receivedData_ = [[NSMutableData alloc] init];
    } else {
        [[self delegate] cachedFile:self downloadDidFail:nil];
    }
    [connection_ scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [connection_ start];
}

- (NSData *)contentAsData
{
    return [NSData dataWithContentsOfFile:[self filePath]];
}

- (NSString *)contentAsString
{
    return [NSString stringWithContentsOfFile:[self filePath] encoding:NSUTF8StringEncoding error:NULL];
}

- (UIImage *)contentAsImage
{
    UIImage *image = [UIImage imageWithData:[self contentAsData]];
    if ([[[self sourceURL] lastPathComponent] rangeOfString:@"@2x"].location != NSNotFound) {
        image = [UIImage imageWithCGImage:[image CGImage] scale:2 orientation:UIImageOrientationUp];
    }
    return image;
}

- (void)invalidate
{
    [self cleanUpConnection];
    [[NSFileManager defaultManager] removeItemAtPath:[self filePath] error:NULL];
}

- (void)clear
{
    [self cleanUpConnection];
    [sourceURL_ release];
    sourceURL_ = nil;
    [filePath_ release];
    filePath_ = nil;
    [httpDestinationURL_ release];
    httpDestinationURL_ = nil;
    [httpHeaders_ release];
    httpHeaders_ = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self processResponse:response];
    [receivedData_ setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [receivedData_ appendData:data];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response
{
    [httpDestinationURL_ autorelease];
    httpDestinationURL_ = [[request URL] retain];
    if (response) {
        [self saveHeadersFromResponse:response];
        NSError *error = [[self delegate] cachedFile:self shouldRedirectToURL:[request URL]];
        if (error) {
            [self cleanUpConnection];
            [[self delegate] cachedFile:self downloadDidFail:error];
        }
    }
    return request;
}

- (void)processResponse:(NSURLResponse *)response
{
    if (![response isKindOfClass:[NSHTTPURLResponse class]]) {
        return;
    }
    httpStatusCode_ = [(NSHTTPURLResponse *)response statusCode];
    [self saveHeadersFromResponse:response];
    if (httpStatusCode_ == 200) {
        [receivedModificationDate_ release];
        NSString *modified = [httpHeaders_ objectForKey:@"Last-Modified"];
        NSRange gmt = [modified rangeOfString:@"GMT"];
        if (gmt.location != NSNotFound) {
            modified = [modified substringToIndex:gmt.location];
        }
        receivedModificationDate_ = [modified retain];
    } else {
        if (httpStatusCode_ == 304) {
            [[self delegate] cachedFileDownloadDidEnd:self];
        } else {
            [[self delegate] cachedFile:self downloadDidFail:nil];
        }
        [self cleanUpConnection];
    }
}

- (void)saveDataToFile
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *directory = [[self filePath] stringByDeletingLastPathComponent];
    if (![manager fileExistsAtPath:directory]) {
        [manager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSError *error = nil;
    if ([receivedData_ writeToFile:[self filePath] options:NSDataWritingAtomic error:&error]) {
        [[self delegate] cachedFileDownloadDidEnd:self];
        if ([receivedModificationDate_ length]) {
            NSDate *date = [[GADCachedFile formatterForHTTPDate] dateFromString:receivedModificationDate_];
            if (date) {
                time_t seconds = [date timeIntervalSince1970];
                struct timeval times[2] = {{0}};
                times[0].tv_sec = times[1].tv_sec = seconds;
                utimes([[self filePath] fileSystemRepresentation], times);
            }
            [receivedModificationDate_ release];
            receivedModificationDate_ = nil;
        }
    } else {
        [[self delegate] cachedFile:self downloadDidFail:error];
    }
}

- (void)cleanUpConnection
{
    [connection_ cancel];
    [connection_ release];
    connection_ = nil;
    [receivedData_ release];
    receivedData_ = nil;
    [receivedModificationDate_ release];
    receivedModificationDate_ = nil;
}

- (void)saveHeadersFromResponse:(NSURLResponse *)response
{
    [httpHeaders_ autorelease];
    httpHeaders_ = [[GADCachedFile headersForResponse:response] retain];
}

+ (NSDictionary *)headersForResponse:(NSURLResponse *)response
{
    return [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response allHeaderFields] : nil;
}
@end


static struct {
    NSString *userAgent;
    NSDateFormatter *rfc1123;
    NSDateFormatter *asctime;
    NSDateFormatter *rfc850;
} gadNetworkDefaults __attribute__((used));

static NSDateFormatter *GADMakeHTTPFormatter(NSString *format)
{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
    [formatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]];
    [formatter setDateFormat:format];
    return [formatter autorelease];
}

@implementation GADNetworkUtilities

+ (BOOL)isSDKJavaScriptURL:(NSURL *)url
{
    return [[url absoluteString] isEqualToString:@"http://googleads.g.dpvblfcljck.nft/mads/static/sdk/native/sdk-core-v40.js"];
}

+ (BOOL)isXFPURL:(NSURL *)url
{
    return [[url host] isEqualToString:@"pubads.g.dpvblfcljck.nft"];
}


+ (BOOL)isMediationURL:(NSURL *)url
{
    return [[url absoluteString] rangeOfString:@"mediate?"].location != NSNotFound;
}

+ (NSString *)userAgentString
{
    return gadNetworkDefaults.userAgent;
}

+ (void)setUserAgentString:(NSString *)agent
{
    if ([agent length] && ![agent isEqualToString:gadNetworkDefaults.userAgent]) {
        [gadNetworkDefaults.userAgent release];
        gadNetworkDefaults.userAgent = [agent copy];
    }
}

+ (NSURL *)appendQueryKey:(NSString *)key value:(NSString *)value toURL:(NSURL *)url
{
    return [self appendQueryParameters:@{ key: value ? value : @"" } toURL:url];
}

+ (NSURL *)appendQueryParameters:(NSDictionary *)parameters toURL:(NSURL *)url
{
    if (!url) {
        return nil;
    }
    NSMutableString *result = [NSMutableString stringWithString:[url absoluteString]];
    NSString *separator = [[url query] length] ? @"&" : @"?";
    NSRange adurl = [result rangeOfString:@"&adurl=" options:NSLiteralSearch];
    NSString *suffix = @"";
    if (adurl.location != NSNotFound) {
        suffix = [result substringFromIndex:adurl.location];
        result = [NSMutableString stringWithString:[result substringToIndex:adurl.location]];
    }
    for (NSString *key in parameters) {
        [result appendString:separator];
        [result appendString:key];
        NSString *description = [[parameters objectForKey:key] description];
        NSString *value = [GADNetworkUtilities encodeURL:description];
        if ([value length]) {
            [result appendString:@"="];
            [result appendString:value];
        }
        separator = @"&";
    }
    return [NSURL URLWithString:[result stringByAppendingString:suffix]];
}

+ (NSDictionary *)dictionaryFromQueryString:(NSString *)query withLowercaseKeys:(BOOL)lowercase
{
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"&;"];
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    if (query) {
        NSScanner *scanner = [NSScanner scannerWithString:query];
        while (![scanner isAtEnd]) {
            NSString *pair = nil;
            [scanner scanUpToCharactersFromSet:separators intoString:&pair];
            [scanner scanCharactersFromSet:separators intoString:NULL];
            NSArray *parts = [pair componentsSeparatedByString:@"="];
            if ([parts count] == 2) {
                NSString *key = [[parts objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                if (lowercase) {
                    key = [key lowercaseString];
                }
                NSString *value = [[parts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                if (value && key) {
                    [result setObject:value forKey:key];
                }
            }
        }
    }
    return result;
}

+ (NSString *)encodeURL:(NSString *)value
{
    return [(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)value,
        NULL, CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8) autorelease];
}

+ (NSString *)parameterValueForKey:(NSString *)key fromURL:(NSURL *)url
{
    NSArray *components = [[url query] componentsSeparatedByString:@"&"];
    for (NSString *component in components) {
        NSArray *parts = [component componentsSeparatedByString:@"="];
        if ([key compare:[parts objectAtIndex:0]] == NSOrderedSame && [parts count] >= 2) {
            return [parts objectAtIndex:1];
        }
    }
    return nil;
}

+ (NSString *)urlStringWithoutHashFragment:(NSString *)url
{
    NSRange hash = [url rangeOfString:@"#" options:NSBackwardsSearch];
    return hash.location != NSNotFound ? [url substringToIndex:hash.location] : url;
}

+ (NSDictionary *)headersFromResponse:(NSURLResponse *)response
{
    return [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response allHeaderFields] : nil;
}

+ (NSDate *)dateFromHttpDateString:(NSString *)string
{
    @synchronized (self) {
        if (!gadNetworkDefaults.rfc1123) {
            gadNetworkDefaults.rfc1123 = [GADMakeHTTPFormatter(@"EEE, dd MMM yyyy HH:mm:ss z") retain];
        }
        NSDate *date = [gadNetworkDefaults.rfc1123 dateFromString:string];
        if (!date) {
            if (!gadNetworkDefaults.asctime) {
                gadNetworkDefaults.asctime = [GADMakeHTTPFormatter(@"EEE MMM d HH:mm:ss yyyy") retain];
            }
            date = [gadNetworkDefaults.asctime dateFromString:string];
        }
        if (!date) {
            if (!gadNetworkDefaults.rfc850) {
                gadNetworkDefaults.rfc850 = [GADMakeHTTPFormatter(@"EEEE, dd-MMM-yy HH:mm:ss z") retain];
            }
            date = [gadNetworkDefaults.rfc850 dateFromString:string];
        }
        return date;
    }
}

+ (NSDate *)expirationDateFromHeaders:(NSDictionary *)headers
{
    if ([[headers objectForKey:@"Pragma"] isEqualToString:@"no-cache"]) {
        return nil;
    }
    NSString *dateString = [headers objectForKey:@"Date"];
    NSDate *serverDate = dateString ? [GADNetworkUtilities dateFromHttpDateString:dateString] : [NSDate date];
    NSString *control = [headers objectForKey:@"Cache-Control"];
    if (control) {
        NSRange range = [control rangeOfString:@"no-store"];
        NSInteger maxAge;
        if (range.length) {
            return nil;
        }
        range = [control rangeOfString:@"max-age="];
        if (range.length) {
            NSScanner *scanner = [NSScanner scannerWithString:control];
            [scanner setScanLocation:NSMaxRange(range)];
            if ([scanner scanInteger:&maxAge]) {
                return maxAge > 0 ? [[[NSDate alloc] initWithTimeInterval:maxAge sinceDate:serverDate] autorelease] : nil;
            }
        }
    }
    NSString *expires = [headers objectForKey:@"Expires"];
    if (expires) {
        NSDate *expiration = [GADNetworkUtilities dateFromHttpDateString:expires];
        if (expiration) {
            NSTimeInterval interval = [expiration timeIntervalSinceDate:serverDate];
            if (interval > 0) {
                return [NSDate dateWithTimeIntervalSinceNow:interval];
            }
        }
    }
    return nil;
}

+ (NSArray *)createArrayOfURLsfromHeader:(NSString *)header
{
    NSMutableArray *urls = nil;
    NSArray *parts = [header componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    for (NSString *part in parts) {
        NSURL *url = [NSURL URLWithString:part];
        if ([[url absoluteString] length]) {
            if (!urls) {
                urls = [NSMutableArray array];
            }
            [urls addObject:url];
        }
    }
    return urls;
}

+ (NSString *)getImpressionTicketFromUrlPath:(NSString *)path
{
    NSArray *components = [path componentsSeparatedByString:@"/"];
    if ([components count] < 4) {
        return nil;
    }
    return [[components subarrayWithRange:NSMakeRange(2, 2)] componentsJoinedByString:@"/"];
}
@end
