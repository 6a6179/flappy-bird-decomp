#import <Foundation/Foundation.h>

@interface GADDevice : NSObject
+ (void)getOSMajor:(NSInteger *)major minor:(NSInteger *)minor bugFix:(NSInteger *)bug;
@end
@interface GADRequestPrivate : NSObject
- (NSDictionary *)parameters;
@end
@interface GADRequestError : NSError
@end

static dispatch_once_t versionMessageOnce;
static NSString *versionMessage;

@implementation GADRequestError

+ (NSString *)localizedStringForErrorCode:(NSInteger)code
{
    dispatch_once(&versionMessageOnce, ^{
        NSInteger major, minor, bug;
        [GADDevice getOSMajor:&major minor:&minor bugFix:&bug];
        versionMessage = [[NSString stringWithFormat:
            @"This device's OS is %ld.%ld.%ld.It is below the minimum of %ld.%ld.",
            (long)major, (long)minor, (long)bug, 4L, 3L] retain];
    });
    NSString *invalid = @"Invalid ad request parameter(s).  Check the Xcode console for details.";
    NSString *message = nil;
    switch (code) {
        case 0: message = invalid; break;
        case 1: message = @"No ad to show."; break;
        case 2: message = @"A network error occurred."; break;
        case 3: message = @"Server error processing the request."; break;
        case 4: message = versionMessage; break;
        case 5: message = @"The Google Ad request was unable to be fulfilled before a timeout occurred."; break;
        case 6: message = @"Will not send request because interstitial object has been used."; break;
        case 7: message = @"The AdMob Mediation reponse was invalid."; break;
        case 8: message = @"Cannot find an ad network adapter for mediation."; break;
        case 9: message = @"No ad to show from all configured ad networks."; break;
        case 10: message = @"Incompatible ad type requested."; break;
    }
    return [NSString stringWithFormat:@"Request Error: %@", message ?: invalid];
}

- (id)initWithCode:(NSInteger)code request:(GADRequestPrivate *)request HTTPStatusCode:(NSInteger)status
     customMessage:(NSString *)message
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (!message)
        message = [[self class] localizedStringForErrorCode:code];
    [info setObject:message forKey:NSLocalizedDescriptionKey];
    [info setObject:message forKey:NSLocalizedFailureReasonErrorKey];
    if ([request parameters] && code == 0)
        [info addEntriesFromDictionary:[request parameters]];
    if (status > 0)
        [info setObject:[NSString stringWithFormat:@"HTTP status %ld: %@", (long)status,
                         [NSHTTPURLResponse localizedStringForStatusCode:status]] forKey:@"HttpStatus"];
    return [super initWithDomain:@"com.google.ads" code:code userInfo:info];
}

+ (id)errorWithCode:(NSInteger)code request:(GADRequestPrivate *)request HTTPStatusCode:(NSInteger)status
      customMessage:(NSString *)message
{
    return [[[self alloc] initWithCode:code request:request HTTPStatusCode:status customMessage:message] autorelease];
}

+ (id)errorWithCode:(NSInteger)code request:(GADRequestPrivate *)request HTTPStatusCode:(NSInteger)status
{
    return [self errorWithCode:code request:request HTTPStatusCode:status customMessage:nil];
}

+ (id)errorWithCode:(NSInteger)code request:(GADRequestPrivate *)request
{
    return [self errorWithCode:code request:request HTTPStatusCode:0];
}

+ (id)errorWithCode:(NSInteger)code
{
    return [self errorWithCode:code customMessage:nil];
}

+ (id)errorWithCode:(NSInteger)code customMessage:(NSString *)message
{
    return [self errorWithCode:code request:nil HTTPStatusCode:0 customMessage:message];
}

@end
