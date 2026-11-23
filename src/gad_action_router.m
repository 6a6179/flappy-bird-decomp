#import <Foundation/Foundation.h>

@interface GADActionRouter : NSObject {
    id _receiver;
    NSMutableDictionary *_cachedActions;
}
@property(nonatomic, assign) id receiver;
@property(nonatomic, readonly) NSMutableDictionary *cachedActions;
+ (NSString *)encodeSelector:(SEL)selector;
+ (SEL)decodeSelector:(NSString *)name;
@end

@implementation GADActionRouter
@dynamic receiver;
@synthesize cachedActions = _cachedActions;

- (id)initWithReceiver:(id)receiver
{
    self = [super init];
    if (self) {
        _cachedActions = [[NSMutableDictionary alloc] init];
        _receiver = receiver;
    }
    return self;
}

- (void)dealloc
{
    [_cachedActions release];
    _receiver = nil;
    [super dealloc];
}

- (void)addSelector:(SEL)selector name:(NSString *)name
{
    @synchronized(self) {
        NSMutableArray *actions = [self.cachedActions objectForKey:name];
        if (!actions)
            actions = [[[NSMutableArray alloc] init] autorelease];
        [actions addObject:[GADActionRouter encodeSelector:selector]];
        [self.cachedActions setObject:actions forKey:name];
    }
}

- (NSUInteger)postNotificationName:(NSString *)name arguments:(id)arguments
{
    NSArray *actions;
    @synchronized(self) {
        actions = [[[self.cachedActions objectForKey:name] copy] autorelease];
    }
    for (NSString *action in actions) {
        SEL selector = [GADActionRouter decodeSelector:action];
        if ([self.receiver respondsToSelector:selector])
            [self.receiver performSelector:selector withObject:arguments];
    }
    return [actions count];
}

+ (NSString *)encodeSelector:(SEL)selector
{
    return NSStringFromSelector(selector);
}

+ (SEL)decodeSelector:(NSString *)name
{
    return NSSelectorFromString(name);
}
@end
