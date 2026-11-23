#import <UIKit/UIKit.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netinet/in.h>
#import <stdbool.h>
#import <stdlib.h>
#import <string.h>

#import "gad_gesture_encoding.h"

#define GTMStringEncoding GAD_GTMStringEncoding
#import "library_upstream/GTMStringEncoding.h"

@interface GADGestureUtil : UIViewController
+ (void)reachability:(SCNetworkReachabilityFlags *)flags;
+ (NSString *)viewInheritenceHierarchy:(UIView *)view maxSize:(NSUInteger)maxSize;
+ (NSArray *)walkViews:(NSString *)stopAt;
@end

extern NSString *GAD_GTMStackTrace(void);

const char *CFStringToCString(CFStringRef string, bool *needsFree)
{
    if (!string)
        return NULL;
    const char *direct = CFStringGetCStringPtr(string, kCFStringEncodingUTF8);
    char *result = NULL;
    *needsFree = false;
    if (direct) {
        result = (char *)direct;
    } else {
        CFIndex length = CFStringGetMaximumSizeForEncoding(CFStringGetLength(string), kCFStringEncodingUTF8);
        result = calloc(1, length + 1);
        if (result && !CFStringGetCString(string, result, length, kCFStringEncodingUTF8)) {
            free(result);
            return NULL;
        }
        *needsFree = true;
    }
    return result;
}

NSString *GetHintTrace(void)
{
    return GAD_GTMStackTrace();
}

bool IsReachable(SCNetworkReachabilityFlags *flags)
{
    [GADGestureUtil reachability:flags];
    return flags != NULL;
}

NSArray *GetWalkViews(NSString *stopAt)
{
    return [GADGestureUtil walkViews:stopAt];
}

void DumpViews(UIView *view, NSMutableArray *result, NSString *stopAt)
{
    if ([view isHidden])
        return;
    NSString *name = [GADGestureUtil viewInheritenceHierarchy:view maxSize:128];
    CGRect frame = [view convertRect:[view frame] toView:[[UIApplication sharedApplication] keyWindow]];
    NSDictionary *entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                           name, @"ViewName",
                           [NSNumber numberWithFloat:frame.origin.x], @"x",
                           [NSNumber numberWithFloat:frame.origin.y], @"y",
                           [NSNumber numberWithFloat:frame.size.width], @"w",
                           [NSNumber numberWithFloat:frame.size.height], @"h", nil];
    [result addObject:entry];
    if (![name isEqualToString:stopAt]) {
        for (UIView *child in [view subviews])
            DumpViews(child, result, stopAt);
    }
}

@implementation GADGestureUtil

+ (void)reachability:(SCNetworkReachabilityFlags *)flags
{
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&address);
    if (reachability) {
        if (!SCNetworkReachabilityGetFlags(reachability, flags))
            flags = NULL;
        CFRelease(reachability);
    }
}

+ (NSString *)viewInheritenceHierarchy:(UIView *)view maxSize:(NSUInteger)maxSize
{
    if (!view)
        return @"";
    Class type = [view class];
    NSMutableString *name = [NSMutableString stringWithString:NSStringFromClass(type)];
    while ([type superclass]) {
        type = [type superclass];
        [name appendFormat:@":%@", NSStringFromClass(type)];
    }
    NSString *result = name;
    if ([result length] > maxSize)
        result = [result substringToIndex:maxSize];
    return result;
}

+ (NSArray *)walkViews:(NSString *)stopAt
{
    NSMutableArray *result = [NSMutableArray array];
    DumpViews([[UIApplication sharedApplication] keyWindow], result, stopAt);
    return result;
}
@end

CFStringRef GetWebSafeEncode(const void *bytes, size_t length)
{
    GAD_GTMStringEncoding *encoding = [GAD_GTMStringEncoding rfc4648Base64WebsafeStringEncoding];
    [encoding setDoPad:NO];
    NSData *data = [NSData dataWithBytesNoCopy:(void *)bytes length:length freeWhenDone:NO];
    return (CFStringRef)[encoding encode:data];
}
