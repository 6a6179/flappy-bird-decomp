#import <Foundation/Foundation.h>

@class GADURLConnection;

@protocol GADURLConnectionDelegate
- (NSError *)connection:(GADURLConnection *)connection shouldRedirectToURL:(NSURL *)url;
- (void)connection:(GADURLConnection *)connection loadDidFail:(NSError *)error httpStatusCode:(NSInteger)code;
- (void)connection:(GADURLConnection *)connection loadDidReceiveRedirectResponse:(NSURLResponse *)response;
- (void)connection:(GADURLConnection *)connection loadDidReceiveCachedResponse:(NSURLResponse *)response;
- (BOOL)connection:(GADURLConnection *)connection loadShouldUseCachedResponse:(NSURLResponse *)response;
- (void)connection:(GADURLConnection *)connection loadDidFinish:(NSString *)text baseURL:(NSURL *)url;
@end

@interface GADCachedURLResponse : NSCachedURLResponse
@property (nonatomic, retain) NSDate *expireDate;
@property (nonatomic, retain) NSURL *destinationURL;
@end

@interface GADNetworkUtilities : NSObject
+ (NSString *)parameterValueForKey:(NSString *)key fromURL:(NSURL *)url;
+ (NSString *)userAgentString;
+ (NSDictionary *)headersFromResponse:(NSURLResponse *)response;
+ (NSDate *)expirationDateFromHeaders:(NSDictionary *)headers;
@end

@interface GADMNSURLConnectionFactory : NSObject
+ (GADMNSURLConnectionFactory *)sharedFactory;
- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)start;
@end

@interface GADRequestError : NSError
+ (NSError *)errorWithCode:(NSInteger)code customMessage:(NSString *)message;
@end

@interface NSString (GADHash)
- (NSString *)gad_MD5String;
@end

extern NSString *const GADParamUnitID;

@interface GADURLConnection : NSObject {
    BOOL _isInProgress, _allowCache;
    NSURL *_sourceURL, *_destinationURL;
    id<GADURLConnectionDelegate> _delegate;
    NSURLConnection *_connection;
    NSURLResponse *_response;
    NSMutableData *_receivedData;
}
@property (nonatomic, copy) NSURL *sourceURL;
@property (nonatomic, copy) NSURL *destinationURL;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSURLResponse *response;
@property (nonatomic, retain) NSMutableData *receivedData;
- (BOOL)startWithURL:(NSURL *)url withData:(NSData *)data andType:(NSString *)type
         forDelegate:(id<GADURLConnectionDelegate>)delegate error:(NSError **)error;
- (NSURLRequest *)requestForURL:(NSURL *)url withData:(NSData *)data andType:(NSString *)type;
- (GADCachedURLResponse *)cachedResponseForURL:(NSURL *)url;
+ (NSCache *)memoryCache;
@end

static struct {
    dispatch_once_t once;
    NSCache *responses;
} gadMemoryCache;

@implementation GADURLConnection

@synthesize sourceURL = _sourceURL;
@synthesize destinationURL = _destinationURL;
@synthesize connection = _connection;
@synthesize response = _response;
@synthesize receivedData = _receivedData;

- (signed char)isInProgress
{
    return _isInProgress;
}

- (void)setIsInProgress:(signed char)value
{
    _isInProgress = value;
}

- (signed char)allowCache
{
    return _allowCache;
}

- (void)setAllowCache:(signed char)value
{
    _allowCache = value;
}

- (id<GADURLConnectionDelegate>)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)value
{
    _delegate = value;
}

- (void)stop
{
    [[self connection] cancel];
    [self setConnection:nil];
    [self setSourceURL:nil];
    [self setDestinationURL:nil];
    [self setResponse:nil];
    [self setReceivedData:nil];
    [self setIsInProgress:0];
}

- (void)cancel
{
    [self setDelegate:nil];
    [self stop];
}

- (void)dealloc
{
    [self stop];
    [super dealloc];
}

- (GADMNSURLConnectionFactory *)connectionFactory
{
    return [GADMNSURLConnectionFactory sharedFactory];
}

+ (void)clearCache
{
    [[self memoryCache] removeAllObjects];
}


+ (NSCache *)memoryCache
{
    dispatch_once(&gadMemoryCache.once, ^{
        gadMemoryCache.responses = [[NSCache alloc] init];
        [gadMemoryCache.responses setCountLimit:25];
    });
    return gadMemoryCache.responses;
}

- (BOOL)startWithURL:(NSURL *)url forDelegate:(id<GADURLConnectionDelegate>)delegate
{
    return [self startWithURL:url withData:nil andType:nil forDelegate:delegate error:NULL];
}

- (BOOL)startWithURL:(NSURL *)url forDelegate:(id<GADURLConnectionDelegate>)delegate error:(NSError **)error
{
    return [self startWithURL:url withData:nil andType:nil forDelegate:delegate error:error];
}

- (BOOL)startWithURL:(NSURL *)url withData:(NSData *)data andType:(NSString *)type
         forDelegate:(id<GADURLConnectionDelegate>)delegate
{
    // This convenience method in the shipped SDK discards the supplied body and type.
    return [self startWithURL:url withData:nil andType:nil forDelegate:delegate error:NULL];
}

- (BOOL)startWithURL:(NSURL *)url withData:(NSData *)data andType:(NSString *)type
         forDelegate:(id<GADURLConnectionDelegate>)delegate error:(NSError **)error
{
    if ([self isInProgress]) {
        NSString *message = [NSString stringWithFormat:@"Ignoring -- Currently loading %@", [self sourceURL]];
        if (error) {
            *error = [GADRequestError errorWithCode:2 customMessage:message];
        }
        return NO;
    }
    [self setDelegate:delegate];
    [self setSourceURL:url];
    [self setDestinationURL:url];
    if ([self allowCache]) {
        GADCachedURLResponse *cached = [self cachedResponseForURL:url];
        if (cached) {
            NSString *text = [[[NSString alloc] initWithData:[cached data] encoding:NSUTF8StringEncoding] autorelease];
            [[self delegate] connection:self loadDidReceiveCachedResponse:[cached response]];
            [[self delegate] connection:self loadDidFinish:text baseURL:[cached destinationURL]];
            return YES;
        }
    }
    NSURLRequest *request = [self requestForURL:url withData:data andType:type];
    [self setConnection:[[[self connectionFactory] newConnectionWithRequest:request delegate:self
        startImmediately:NO] autorelease]];
    if ([self connection]) {
        [self setReceivedData:[[[NSMutableData alloc] init] autorelease]];
    } else {
        [[self delegate] connection:self loadDidFail:nil httpStatusCode:-1];
    }
    [[self connection] scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [[self connection] start];
    [self setIsInProgress:YES];
    return YES;
}

+ (NSString *)defaultCachePath
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"AdMob"];
}

+ (NSString *)cacheKeyForURL:(NSURL *)url
{
    NSString *text = [url absoluteString];
    NSString *unit = [GADNetworkUtilities parameterValueForKey:GADParamUnitID fromURL:url];
    if (unit) {
        text = [NSString stringWithFormat:@"%@%@%@", [url host], [url path], unit];
    }
    return [text gad_MD5String];
}

- (NSURLRequest *)requestForURL:(NSURL *)url withData:(NSData *)data andType:(NSString *)type
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSString *agent = [GADNetworkUtilities userAgentString];
    if ([agent length]) {
        [request setValue:agent forHTTPHeaderField:@"User-Agent"];
    }
    if (data && type) {
        [request setHTTPMethod:@"POST"];
        [request setHTTPBody:data];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[data length]]
            forHTTPHeaderField:@"Content-Length"];
        [request setValue:type forHTTPHeaderField:@"Content-Type"];
    }
    return request;
}

- (GADCachedURLResponse *)cachedResponseForURL:(NSURL *)url
{
    GADCachedURLResponse *entry = [[[self class] memoryCache] objectForKey:[GADURLConnection cacheKeyForURL:url]];
    if (entry) {
        if ([[entry expireDate] timeIntervalSinceNow] > 0) {
            return entry;
        }
        [[[self class] memoryCache] removeObjectForKey:[GADURLConnection cacheKeyForURL:url]];
    }
    return nil;
}

- (BOOL)tryToStoreResponseAndData
{
    NSDictionary *headers = [GADNetworkUtilities headersFromResponse:[self response]];
    NSDate *expires = [GADNetworkUtilities expirationDateFromHeaders:headers];
    if (!expires || [expires timeIntervalSinceNow] < 0) {
        return NO;
    }
    GADCachedURLResponse *cached = [[[GADCachedURLResponse alloc] initWithResponse:[self response]
        data:[self receivedData]] autorelease];
    [cached setExpireDate:expires];
    [cached setDestinationURL:[self destinationURL]];
    [[[self class] memoryCache] setObject:cached forKey:[GADURLConnection cacheKeyForURL:[self sourceURL]]];
    return YES;
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request
            redirectResponse:(NSURLResponse *)response
{
    if (response) {
        NSError *error = [[self delegate] connection:self shouldRedirectToURL:[request URL]];
        if (error) {
            [self stop];
            [[self delegate] connection:self loadDidFail:error httpStatusCode:-1];
        }
        [self setDestinationURL:[request URL]];
        [[self delegate] connection:self loadDidReceiveRedirectResponse:response];
    }
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [self setResponse:response];
    [[self receivedData] setLength:0];
    if ([[self delegate] connection:self loadShouldUseCachedResponse:[self response]]) {
        [self setAllowCache:YES];
        GADCachedURLResponse *cached = [self cachedResponseForURL:[self sourceURL]];
        if (cached) {
            NSString *text = [[[NSString alloc] initWithData:[cached data] encoding:NSUTF8StringEncoding] autorelease];
            [[self delegate] connection:self loadDidReceiveCachedResponse:[cached response]];
            [[self delegate] connection:self loadDidFinish:text baseURL:[cached destinationURL]];
            [self stop];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [[self receivedData] appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if ([self allowCache]) {
        [self tryToStoreResponseAndData];
    }
    NSString *text = [[[NSString alloc] initWithData:[self receivedData] encoding:NSUTF8StringEncoding] autorelease];
    [[self delegate] connection:self loadDidFinish:text baseURL:[self destinationURL]];
    [self stop];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([[self response] isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger code = [(NSHTTPURLResponse *)[self response] statusCode];
        [[self delegate] connection:self loadDidFail:error httpStatusCode:code];
    } else {
        [[self delegate] connection:self loadDidFail:error httpStatusCode:-1];
    }
    [self stop];
}
@end
