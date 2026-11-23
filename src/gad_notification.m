#import <UIKit/UIKit.h>

@interface GADGMSGHandler : NSObject
+ (BOOL)isGMSG:(NSURL *)url;
@end
@interface GADNetworkUtilities : NSObject
+ (NSDictionary *)dictionaryFromQueryString:(NSString *)query withLowercaseKeys:(BOOL)lowercase;
@end
@interface GADMacros : NSObject
+ (NSString *)dictionaryToJSONString:(NSDictionary *)dictionary;
@end
@interface GADNotification : NSObject {
    NSString *name_;
    NSDictionary *parameters_;
}
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSDictionary *parameters;
@end

@implementation GADNotification

@synthesize name = name_, parameters = parameters_;

+ (BOOL)isNotificationURL:(NSURL *)url
{
    return [GADGMSGHandler isGMSG:url];
}

- (id)initWithNotificationURL:(NSURL *)url
{
    if ((self = [self init])) {
        @try {
            if ([[self class] isNotificationURL:url]) {
                name_ = [[[url path] substringFromIndex:1] retain];
                NSString *query = [url query];
                parameters_ = [GADNetworkUtilities dictionaryFromQueryString:query withLowercaseKeys:NO];
                [parameters_ retain];
            } else {
                [self release];
                self = nil;
            }
        } @catch (NSException *exception) {
            [self release];
            self = nil;
        }
    }
    return self;
}

+ (id)notificationFromURL:(NSURL *)url
{
    return [[[GADNotification alloc] initWithNotificationURL:url] autorelease];
}

- (void)dealloc
{
    [name_ release];
    [parameters_ release];
    [super dealloc];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@<%p>: name:%@ parameters:%@",
            NSStringFromClass([self class]), self, [self name], [self parameters]];
}

@end

@interface GADNotificationCenter : NSNotificationCenter
@end

@implementation GADNotificationCenter

- (void)postNotificationFromURL:(NSURL *)url object:(id)object
{
    GADNotification *notification = [GADNotification notificationFromURL:url];
    if (notification)
        [self postNotificationName:[notification name] object:object userInfo:[notification parameters]];
}

- (void)delayedPosting:(NSDictionary *)info
{
    [self postNotificationFromURL:[info objectForKey:@"url"] object:[info objectForKey:@"object"]];
}

- (void)postNotificationFromURL:(NSURL *)url object:(id)object withDelay:(NSTimeInterval)delay
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:url forKey:@"url"];
    if (object)
        [info setObject:object forKey:@"object"];
    [self performSelector:@selector(delayedPosting:) withObject:info afterDelay:delay inModes:@[NSRunLoopCommonModes]];
}

- (void)postJSNotification:(NSString *)name userInfo:(NSDictionary *)info webView:(UIWebView *)webView
{
    NSMutableString *script = [NSMutableString string];
    if (info)
        [script appendFormat:@"%@('%@', %@);", @"AFMA_ReceiveMessage", name, [GADMacros dictionaryToJSONString:info]];
    else
        [script appendFormat:@"%@('%@');", @"AFMA_ReceiveMessage", name];
    [webView stringByEvaluatingJavaScriptFromString:script];
}

@end
