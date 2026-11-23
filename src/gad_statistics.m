// The SDK exposes its dispatch queue as a C pointer in the Objective-C runtime.
#define OS_OBJECT_USE_OBJC 0
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>
#import <math.h>
#import "gad_gesture_signals.h"

@class GADStatisticDictionary;
@protocol GADStatisticDictionaryDelegate
- (void)didUpdateStatisticDictionary:(GADStatisticDictionary *)dictionary;
@end

@interface GADStatisticDictionary : NSObject {
    NSMutableDictionary *_statistics;
    BOOL _allowDictionaryModification;
    BOOL _hasEnqueuedNotificationBlock;
    id<GADStatisticDictionaryDelegate> _delegate;
    BOOL *_wasDeallocated;
    dispatch_queue_t _queue;
}
@property(nonatomic, assign) dispatch_queue_t queue;
@property(nonatomic, assign) id<GADStatisticDictionaryDelegate> delegate;
@property(nonatomic) BOOL allowDictionaryModification;
@property(nonatomic) BOOL hasEnqueuedNotificationBlock;
- (void)addDecimalNumber:(NSDecimalNumber *)value toNumberForKey:(id)key
    shouldNotifyDelegate:(BOOL)notify;
@end

static struct {
    dispatch_once_t once;
    NSDecimalNumber *value;
} gadMinusOne;

@implementation GADStatisticDictionary
@synthesize queue = _queue;
@dynamic delegate, allowDictionaryModification, hasEnqueuedNotificationBlock;

- (id)initWithQueueLabel:(const char *)label delegate:(id)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _statistics = [[NSMutableDictionary alloc] init];
        _queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
        _allowDictionaryModification = YES;
    }
    return self;
}

- (id)initWithDelegate:(id)delegate
{
    return [self initWithQueueLabel:"com.google.admob.statistics" delegate:delegate];
}

- (void)dealloc
{
    [_statistics release];
    dispatch_release(_queue);
    if (_wasDeallocated)
        *_wasDeallocated = YES;
    [super dealloc];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>\nqueue: %s\nstatistics: %@",
            NSStringFromClass([self class]), self, dispatch_queue_get_label(self.queue), _statistics];
}

- (void)didFinishModifying
{
    dispatch_sync(self.queue, ^{
        self.allowDictionaryModification = NO;
    });
}

- (void)enqueueNotificationBlock
{
    self.hasEnqueuedNotificationBlock = YES;
    dispatch_async(self.queue, ^{
        self.hasEnqueuedNotificationBlock = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self delegate] didUpdateStatisticDictionary:self];
        });
    });
}

- (void)dispatchAsyncShouldNotifyDelegate:(BOOL)notify block:(void (^)(void))block
{
    dispatch_async(self.queue, ^{
        if (self.allowDictionaryModification) {
            block();
            if (notify && !self.hasEnqueuedNotificationBlock)
                [self enqueueNotificationBlock];
        }
    });
}

- (void)setObject:(id)object forKey:(id)key shouldNotifyDelegate:(BOOL)notify
{
    [self dispatchAsyncShouldNotifyDelegate:notify block:^{
        [_statistics setObject:object forKey:key];
    }];
}

- (id)objectForKey:(id)key
{
    __block id value = nil;
    dispatch_sync(self.queue, ^{
        value = [[_statistics objectForKey:key] retain];
    });
    return [value autorelease];
}

- (void)addDecimalNumber:(NSDecimalNumber *)value toNumberForKey:(id)key
    shouldNotifyDelegate:(BOOL)notify
{
    [self dispatchAsyncShouldNotifyDelegate:notify block:^{
        NSDecimalNumber *number = [_statistics objectForKey:key];
        if (!number)
            number = [NSDecimalNumber zero];
        if ([number isKindOfClass:[NSDecimalNumber class]]) {
            NSDecimalNumber *sum = [number decimalNumberByAdding:value];
            [_statistics setObject:sum forKey:key];
        }
    }];
}

- (void)incrementNumberForKey:(id)key shouldNotifyDelegate:(BOOL)notify
{
    [self addDecimalNumber:[NSDecimalNumber one] toNumberForKey:key shouldNotifyDelegate:notify];
}

- (void)decrementNumberForKey:(id)key shouldNotifyDelegate:(BOOL)notify
{
    dispatch_once(&gadMinusOne.once, ^{
        gadMinusOne.value = [[NSDecimalNumber alloc] initWithMantissa:1 exponent:0 isNegative:YES];
    });
    [self addDecimalNumber:gadMinusOne.value toNumberForKey:key shouldNotifyDelegate:notify];
}
- (void)addObject:(id)object toArrayWithKey:(id)key shouldNotifyDelegate:(BOOL)notify
{
    [self dispatchAsyncShouldNotifyDelegate:notify block:^{
        NSMutableArray *array = [_statistics objectForKey:key];
        if (!array)
            array = [[[NSMutableArray alloc] init] autorelease];
        if ([array isKindOfClass:[NSMutableArray class]]) {
            [array addObject:object];
            [_statistics setObject:array forKey:key];
        }
    }];
}

- (NSDictionary *)dictionary
{
    __block NSDictionary *result = nil;
    dispatch_sync(self.queue, ^{
        result = [_statistics copy];
    });
    return [result autorelease];
}
@end

@interface GADStatisticsCore : NSObject {
    NSMutableDictionary *_statistics;
    NSString *_identifier;
    NSUserDefaults *_userDefaults;
    NSArray *_transientStats;
    NSString *_userDefaultsKey;
    NSLock *_lock;
}
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *userDefaultsKey;
- (NSLock *)lock;
- (NSNumber *)numberForKey:(NSString *)key;
- (NSArray *)arrayForKey:(NSString *)key;
- (void)appendValue:(id)value arrayForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key;
@end

@implementation GADStatisticsCore
@synthesize identifier = _identifier;
@synthesize userDefaultsKey = _userDefaultsKey;

- (void)loadPersistentStatistics
{
    if (![self userDefaultsKey])
        return;
    NSDictionary *saved = [_userDefaults objectForKey:[self userDefaultsKey]];
    [_statistics addEntriesFromDictionary:saved];
    for (NSString *key in _transientStats)
        [_statistics removeObjectForKey:key];
}

- (void)savePersistentStatistics
{
    if (![self userDefaultsKey])
        return;
    NSMutableDictionary *saved = [NSMutableDictionary dictionaryWithDictionary:_statistics];
    for (NSString *key in _transientStats)
        [saved removeObjectForKey:key];
    [_userDefaults setObject:saved forKey:[self userDefaultsKey]];
    [_userDefaults synchronize];
}

- (void)setObject:(id)value forKey:(NSString *)key matchingClass:(Class)expected
{
    if ([value isKindOfClass:expected])
        [_statistics setObject:value forKey:key];
}

- (id)init
{
    self = [super init];
    if (self) {
        _statistics = [[NSMutableDictionary alloc] init];
        _userDefaults = [[NSUserDefaults alloc] init];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self savePersistentStatistics];
    [_userDefaults release];
    [_statistics release];
    [_identifier release];
    [_userDefaultsKey release];
    [_transientStats release];
    [_lock release];
    [super dealloc];
}

- (NSString *)userDefaultsKey
{
    if (!_userDefaultsKey && _identifier)
        _userDefaultsKey = [[NSString stringWithFormat:@"google_stats_%@", _identifier] retain];
    return _userDefaultsKey;
}

- (void)setIdentifier:(NSString *)identifier
{
    if (_identifier != identifier) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [_identifier release];
        _identifier = [identifier copy];
        [self loadPersistentStatistics];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(savePersistentStatistics)
                                                     name:UIApplicationWillTerminateNotification object:nil];
    }
}

- (NSInteger)addValue:(NSInteger)value numberForKey:(NSString *)key
{
    [[self lock] lock];
    NSInteger previous = [[self numberForKey:key] integerValue];
    NSNumber *number = [NSNumber numberWithInteger:previous + value];
    [_statistics setObject:number forKey:key];
    NSInteger result = [number integerValue];
    [[self lock] unlock];
    return result;
}

- (void)appendValue:(id)value arrayForKey:(NSString *)key
{
    if (!value)
        return;
    [[self lock] lock];
    NSArray *existing = [_statistics objectForKey:key];
    if (!existing || [existing isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray arrayWithArray:existing];
        [array addObject:value];
        [_statistics setObject:array forKey:key];
    }
    [[self lock] unlock];
}
@end

@interface GADTimingManager : NSObject
- (void)setIdentifier:(NSString *)identifier;
@end

@interface GADTiming : NSObject
- (NSString *)elapsedMillisecondsString;
- (NSUInteger)elapsedMilliseconds;
- (void)removeValueForKey:(NSString *)key;
- (NSDictionary *)keysAndValues;
@end

@interface GADStatistics : NSObject {
    GADStatisticsCore *_statistics;
    GADTimingManager *_timingMgr;
}
- (void)startTimingNamed:(NSString *)name withExplicitEnd:(BOOL)explicitEnd;
- (void)removeTimingNamed:(NSString *)name;
- (void)resetParameterCount:(NSString *)name;
- (void)endTimingNamed:(NSString *)name;
- (GADTiming *)timingNamed:(NSString *)name;
- (void)incrementParameterCount:(NSString *)name;
- (void)setFlagWithParameterName:(NSString *)name;
@end

extern NSString *const kGADParameterAppOpenInterstitialNoFill;
extern NSString *const kGADParameterAppOpenInterstitialTimedOut;
extern NSString *const kGADParameterPriorClickBackgroundedApp;
extern NSString *const kGADParameterPriorClickBreakOut;
extern NSString *const kGADParameterPriorClickCount;
extern NSString *const kGADParameterPriorClickLatency;
extern NSString *const kGADParameterPriorImpressionTicketString;
extern NSString *const kGADParameterPriorLandingPageDuration;
extern NSString *const kGADParameterPriorLandingPageLoad;
extern NSString *const kGADParameterPriorLandingPageNavCount;
extern NSString *const kGADParameterPriorLandingPageSSLNavCount;
extern NSString *const kGADParameterPriorPreClickLatency;
extern NSString *const kGADParameterPriorRequestLatency;
extern NSString *const kGADParameterPriorRequestNetworkLatency;


@interface GADNotification : NSObject
+ (BOOL)isNotificationURL:(NSURL *)URL;
@end

@interface GADNetworkUtilities : NSObject
+ (NSString *)getImpressionTicketFromUrlPath:(NSString *)path;
+ (NSString *)parameterValueForKey:(NSString *)key fromURL:(NSURL *)url;
+ (NSURL *)appendQueryKey:(NSString *)key value:(NSString *)value toURL:(NSURL *)url;
@end

@interface GADSlotStatistics : GADStatistics {
    NSString *_identifier;
}
@property(nonatomic, copy) NSString *identifier;
@end

@implementation GADSlotStatistics
@synthesize identifier = _identifier;

- (id)init
{
    self = [super init];
    if (self) {
        _statistics = [[GADStatisticsCore alloc] init];
        _timingMgr = [[GADTimingManager alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [_statistics release];
    [_timingMgr release];
    [_identifier release];
    [super dealloc];
}

- (void)setIdentifier:(NSString *)identifier
{
    if (_identifier != identifier) {
        [_identifier release];
        _identifier = [identifier copy];
        [_statistics setIdentifier:_identifier];
        [_timingMgr setIdentifier:_identifier];
    }
}

- (void)setBreakOutToSafari
{
    [self setFlagWithParameterName:kGADParameterPriorClickBreakOut];
}

- (void)setClickBackgroundedApp
{
    [self setFlagWithParameterName:kGADParameterPriorClickBackgroundedApp];
}

- (void)incrementPageNavigationCount
{
    [self incrementParameterCount:kGADParameterPriorLandingPageNavCount];
}

- (void)incrementSSLPageNavigationCount
{
    [self incrementParameterCount:kGADParameterPriorLandingPageSSLNavCount];
}

- (void)incrementClickCount
{
    [self incrementParameterCount:kGADParameterPriorClickCount];
}

- (void)setAppOpenInterstitialTimeOut
{
    [self setFlagWithParameterName:kGADParameterAppOpenInterstitialTimedOut];
}

- (void)setAppOpenInterstitialNoFill
{
    [self setFlagWithParameterName:kGADParameterAppOpenInterstitialNoFill];
}

+ (NSArray *)allCounterNames
{
    return @[kGADParameterPriorClickBreakOut, kGADParameterPriorClickBackgroundedApp,
             kGADParameterPriorLandingPageNavCount, kGADParameterPriorLandingPageSSLNavCount,
             kGADParameterPriorClickCount];
}

+ (NSArray *)allTimingNames
{
    return @[kGADParameterPriorRequestLatency, kGADParameterPriorClickLatency,
             kGADParameterPriorPreClickLatency, kGADParameterPriorLandingPageLoad,
             kGADParameterPriorLandingPageDuration, kGADParameterPriorRequestNetworkLatency];
}

- (NSDictionary *)parameters
{
    NSArray *names = [GADSlotStatistics allTimingNames];
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    if (![self timingNamed:kGADParameterPriorClickLatency])
        [self removeTimingNamed:kGADParameterPriorPreClickLatency];
    GADTiming *click = [self timingNamed:kGADParameterPriorClickLatency];
    NSUInteger backgroundTime = 0;
    if ([_statistics numberForKey:kGADParameterPriorClickBackgroundedApp]) {
        NSDate *date = [click valueForKey:@"date"];
        backgroundTime = fabs([date timeIntervalSinceNow]) * 1000.0;
    }
    [click removeValueForKey:@"date"];
    for (NSString *name in names) {
        GADTiming *timing = [self timingNamed:name];
        if ([timing elapsedMilliseconds]) {
            NSString *elapsed = [timing elapsedMillisecondsString];
            if (elapsed)
                [parameters setObject:elapsed forKey:name];
        }
        NSDictionary *values = [timing keysAndValues];
        for (NSString *key in [values allKeys])
            [parameters setObject:[values objectForKey:key] forKey:key];
        [self removeTimingNamed:name];
    }
    if (backgroundTime)
        [parameters setObject:[NSNumber numberWithUnsignedInteger:backgroundTime]
                       forKey:kGADParameterPriorClickLatency];
    for (NSString *name in [GADSlotStatistics allCounterNames]) {
        NSNumber *counter = [_statistics numberForKey:name];
        if ([counter intValue])
            [parameters setObject:counter forKey:name];
        [self resetParameterCount:name];
    }
    return [NSDictionary dictionaryWithDictionary:parameters];
}

- (NSURL *)updateStatsAndReturnSpamClickURL:(NSURL *)url
{
    if ([GADNotification isNotificationURL:url] || [[url absoluteString] isEqualToString:@"about:blank"])
        return url;
    [self incrementClickCount];
    [self startTimingNamed:kGADParameterPriorClickLatency withExplicitEnd:YES];
    [self endTimingNamed:kGADParameterPriorPreClickLatency];
    NSString *ticket = [GADNetworkUtilities getImpressionTicketFromUrlPath:[url path]];
    if (ticket)
        [[self timingNamed:kGADParameterPriorClickLatency] setValue:ticket
                                                            forKey:kGADParameterPriorImpressionTicketString];
    if ([[url query] length] && [self isGoogleAdUrl:url]) {
        [[self timingNamed:kGADParameterPriorClickLatency] setValue:[NSDate date] forKey:@"date"];
        NSString *ai = [GADNetworkUtilities parameterValueForKey:@"ai" fromURL:url];
        if ([ai length]) {
            NSMutableString *value = [NSMutableString string];
            if (gad_gmcs((CFStringRef)ai, (CFMutableStringRef)value) == 1)
                return [GADNetworkUtilities appendQueryKey:value value:nil toURL:url];
        }
    }
    return url;
}

- (BOOL)isGoogleAdUrl:(NSURL *)url
{
    NSString *domains = [[NSUserDefaults standardUserDefaults] stringForKey:@"as_domains"];
    // Preserve the domain spellings embedded in the supplied 1.2 executable.
    if (![domains length])
        domains = @".dpvblfcljck.nft,.googleadservices.com,.gppglfszndjcbtjpn.cpm";
    NSArray *suffixes = [domains componentsSeparatedByString:@","];
    for (NSString *domain in suffixes) {
        if ([[url host] hasSuffix:domain])
            return YES;
    }
    return NO;
}

- (void)endTimingAdapterWithExitCode:(int)code
{
    [self endTimingNamed:@"adapter"];
    GADTiming *timing = [self timingNamed:@"adapter"];
    [_statistics appendValue:[timing elapsedMillisecondsString] arrayForKey:@"adapter_duration"];
    [_statistics appendValue:[NSString stringWithFormat:@"%lu", (unsigned long)code] arrayForKey:@"adapter_exit"];
}

- (void)resetTimingAdapters
{
    [_statistics removeObjectForKey:@"adapter_exit"];
    [_statistics removeObjectForKey:@"adapter_duration"];
}

- (NSString *)adapterExitCodesParameter
{
    return [[_statistics arrayForKey:@"adapter_exit"] componentsJoinedByString:@","];
}

- (NSString *)adapterDurationsParameter
{
    return [[_statistics arrayForKey:@"adapter_duration"] componentsJoinedByString:@","];
}
@end

extern NSString *const kGADParameterBufferedAdsShownOfflineCount;
extern NSString *const kGADParameterBufferedAdsShownOnlineCount;
extern NSString *const kGADParameterOfflineAdRequestsCount;
extern NSString *const kGADParameterSequenceNumber;
extern NSString *const kGADParameterSessionID;
extern NSString *const kGADParameterTimeSinceFirstRequest;
extern NSString *const kGADParameterTotalAdRequests;

@interface GADSession : NSObject
- (NSString *)sessionIDAsString;
@end

@interface GADApplication : NSObject
+ (GADApplication *)sharedApplication;
- (GADSession *)currentSession;
@end

@interface GADTimingManager (SharedStatistics)
- (void)synchronize;
- (void)setTransientTimings:(NSArray *)names;
@end

@interface GADStatisticsCore (SharedStatistics)
- (void)synchronize;
- (void)setTransientStats:(NSArray *)names;
- (void)setNumber:(NSNumber *)value forKey:(NSString *)key;
- (NSInteger)addValue:(NSInteger)value numberForKey:(NSString *)key;
@end

@interface GADSharedStatistics : GADStatistics {
    unsigned long long _sequenceNumber;
}
@property(nonatomic) unsigned long long sequenceNumber;
@end

static struct {
    dispatch_once_t once;
    GADSharedStatistics *instance;
} gadSharedStatistics;

@implementation GADSharedStatistics

- (NSInteger)adRequestCount
{
    return [[_statistics numberForKey:kGADParameterTotalAdRequests] integerValue];
}

- (void)setAdRequestCount:(NSInteger)count
{
    [_statistics setNumber:[NSNumber numberWithInteger:count] forKey:kGADParameterTotalAdRequests];
}

+ (GADSharedStatistics *)sharedInstance
{
    dispatch_once(&gadSharedStatistics.once, ^{
        gadSharedStatistics.instance = [[GADSharedStatistics alloc] init];
    });
    return gadSharedStatistics.instance;
}

+ (NSArray *)allTimingNames
{
    return @[kGADParameterTimeSinceFirstRequest];
}

+ (NSArray *)allCounterNames
{
    return @[kGADParameterOfflineAdRequestsCount, kGADParameterBufferedAdsShownOnlineCount,
             kGADParameterBufferedAdsShownOfflineCount, kGADParameterTotalAdRequests];
}

+ (NSArray *)sessionTimingNames
{
    return @[kGADParameterTimeSinceFirstRequest];
}

+ (NSArray *)sessionStatsNames
{
    return @[kGADParameterTotalAdRequests];
}

- (NSDictionary *)parameters
{
    NSArray *timingNames = [GADSharedStatistics allTimingNames];
    NSMutableDictionary *parameters = [[[NSMutableDictionary alloc] init] autorelease];
    NSString *sessionID = [[[GADApplication sharedApplication] currentSession] sessionIDAsString];
    if (sessionID)
        [parameters setObject:sessionID forKey:kGADParameterSessionID];
    NSString *sequence = [self nextSequenceNumberAsString];
    if (sequence)
        [parameters setObject:sequence forKey:kGADParameterSequenceNumber];

    for (NSString *name in timingNames) {
        GADTiming *timing = [self timingNamed:name];
        NSString *elapsed = [timing elapsedMillisecondsString];
        if (elapsed)
            [parameters setObject:elapsed forKey:name];
        NSDictionary *values = [timing keysAndValues];
        for (NSString *key in [values allKeys])
            [parameters setObject:[values objectForKey:key] forKey:key];
        if (![name isEqualToString:kGADParameterTimeSinceFirstRequest])
            [self removeTimingNamed:name];
    }
    for (NSString *name in [GADSharedStatistics allCounterNames]) {
        NSNumber *value = [_statistics numberForKey:name];
        if ([name isEqualToString:kGADParameterTotalAdRequests]) {
            if (value)
                [parameters setObject:value forKey:name];
        } else if ([value integerValue]) {
            [parameters setObject:value forKey:name];
        }
    }
    return [NSDictionary dictionaryWithDictionary:parameters];
}

- (id)init
{
    self = [super init];
    if (self) {
        _statistics = [[GADStatisticsCore alloc] init];
        [_statistics setTransientStats:[GADSharedStatistics sessionStatsNames]];
        [_statistics setIdentifier:@"shared"];
        _timingMgr = [[GADTimingManager alloc] init];
        [_timingMgr setTransientTimings:[GADSharedStatistics sessionTimingNames]];
        [_timingMgr setIdentifier:@"shared"];
        [_statistics setNumber:[NSNumber numberWithInteger:-1] forKey:kGADParameterTotalAdRequests];
        [self resetParameterCount:kGADParameterOfflineAdRequestsCount];
        [self resetParameterCount:kGADParameterBufferedAdsShownOfflineCount];
        [self resetParameterCount:kGADParameterBufferedAdsShownOnlineCount];
    }
    return self;
}

- (void)dealloc
{
    [_statistics release];
    [_timingMgr release];
    [super dealloc];
}

- (void)synchronize
{
    [_statistics synchronize];
    [_timingMgr synchronize];
}

- (NSString *)nextSequenceNumberAsString
{
    @synchronized(self) {
        self.sequenceNumber++;
        return [NSString stringWithFormat:@"%qu", self.sequenceNumber];
    }
}

- (void)incrementAdRequestCount
{
    [_statistics addValue:1 numberForKey:kGADParameterTotalAdRequests];
}
@end
