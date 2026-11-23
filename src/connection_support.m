#import <Foundation/Foundation.h>

@interface GADCachedURLResponse : NSCachedURLResponse {
    NSDate *expireDate_;
    NSURL *destinationURL_;
}
@property (nonatomic, retain) NSDate *expireDate;
@property (nonatomic, retain) NSURL *destinationURL;
@end

@interface GADMNSURLConnectionFactory : NSObject
+ (GADMNSURLConnectionFactory *)sharedFactory;
+ (void)setSharedFactory:(GADMNSURLConnectionFactory *)factory;
- (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate;
- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)start;
@end

@implementation GADCachedURLResponse

@synthesize expireDate = expireDate_;
@synthesize destinationURL = destinationURL_;

- (id)initWithCoder:(NSCoder *)coder
{
    self = [self initWithResponse:[coder decodeObjectForKey:@"response"] data:[coder decodeDataObject]];
    if (self) {
        [self setDestinationURL:[coder decodeObjectForKey:@"destinationURL"]];
        [self setExpireDate:[coder decodeObjectForKey:@"expireDate"]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeDataObject:[self data]];
    [coder encodeObject:[self response] forKey:@"response"];
    [coder encodeObject:[self destinationURL] forKey:@"destinationURL"];
    [coder encodeObject:[self expireDate] forKey:@"expireDate"];
}

- (void)dealloc
{
    [expireDate_ release];
    expireDate_ = nil;
    [destinationURL_ release];
    destinationURL_ = nil;
    [super dealloc];
}
@end

static struct {
    dispatch_once_t once;
    GADMNSURLConnectionFactory *factory;
} gadConnectionFactory;

@implementation GADMNSURLConnectionFactory

- (void)dealloc
{
    [super dealloc];
}

+ (GADMNSURLConnectionFactory *)sharedFactory
{
    dispatch_once(&gadConnectionFactory.once, ^{
        gadConnectionFactory.factory = [[GADMNSURLConnectionFactory alloc] init];
    });
    return gadConnectionFactory.factory;
}

+ (void)setSharedFactory:(GADMNSURLConnectionFactory *)factory
{
    [gadConnectionFactory.factory autorelease];
    gadConnectionFactory.factory = [factory retain];
}

- (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate
{
    return [NSURLConnection connectionWithRequest:request delegate:delegate];
}

- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request delegate:(id)delegate
                              startImmediately:(BOOL)start
{
    return [[NSURLConnection alloc] initWithRequest:request delegate:delegate startImmediately:start];
}
@end
