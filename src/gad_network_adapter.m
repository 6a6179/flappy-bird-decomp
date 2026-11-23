#import <UIKit/UIKit.h>
#import <objc/runtime.h>

typedef struct GADAdSize {
    CGSize size;
    NSUInteger flags;
} GADAdSize;

@protocol GADMAdNetworkAdapter <NSObject>
+ (NSString *)adapterVersion;
+ (Class)networkExtrasClass;
- (id)initWithGADMAdNetworkConnector:(id)connector;
- (void)getBannerWithSize:(GADAdSize)size;
- (void)getInterstitial;
- (void)stopBeingDelegate;
- (BOOL)isBannerAnimationOK:(int)animation;
- (void)presentInterstitialFromRootViewController:(UIViewController *)controller;
@optional
- (void)changeAdSizeTo:(GADAdSize)size;
@end

@interface GADMAdNetworkAdapter : NSObject
@end

static struct {
    dispatch_once_t once;
    NSSet *names;
} gadAvailableAdapters;

static BOOL conformsToAdapterProtocol(Class candidate, Protocol *protocol)
{
    if (!protocol || !candidate) return NO;
    for (Class ancestor = candidate; ancestor; ancestor = class_getSuperclass(ancestor)) {
        if (class_conformsToProtocol(ancestor, protocol)) return YES;
    }
    return NO;
}

@implementation GADMAdNetworkAdapter
+ (NSSet *)availableAdapterNames
{
    dispatch_once(&gadAvailableAdapters.once, ^{
        NSMutableSet *names = nil;
        int count = objc_getClassList(NULL, 0);
        if (count > 0) {
            Class *classes = calloc(count, sizeof(*classes));
            count = objc_getClassList(classes, count);
            if (count > 0) {
                int i = 0;
                do {
                    Class candidate = classes[i];
                    if (conformsToAdapterProtocol(candidate, @protocol(GADMAdNetworkAdapter))) {
                        if (!names) names = [[[NSMutableSet alloc] init] autorelease];
                        const char *className = class_getName(candidate);
                        [names addObject:[NSString stringWithUTF8String:className]];
                    }
                } while (++i < count);
            }
            free(classes);
        }
        gadAvailableAdapters.names = [names copy];
    });
    return gadAvailableAdapters.names;
}

+ (BOOL)classIsAdapterClass:(Class)candidate
{
    return [candidate conformsToProtocol:@protocol(GADMAdNetworkAdapter)];
}

+ (BOOL)classImplementsCurrentAdapterAPI:(Class)candidate
{
    return [candidate instancesRespondToSelector:@selector(getBannerWithSize:)];
}
@end
