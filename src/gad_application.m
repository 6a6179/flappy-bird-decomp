#import <UIKit/UIKit.h>

@interface GADSession : NSObject
@end
@interface GADMRAIDInterceptor : NSObject
+ (void)allow;
@end
@interface GADMAdNetworkAdapter : NSObject
+ (NSSet *)availableAdapterNames;
@end
@interface NSError (GADITunesMetadata)
+ (NSString *)gad_localizedDescriptionForErrorCode:(NSInteger)code;
+ (NSError *)gad_errorWithCode:(NSInteger)code description:(NSString *)message;
@end

NSDictionary *GADiTunesMetadataForFileAtPath(NSString *path, NSError **error)
{
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if (error) {
            NSString *description = [NSError gad_localizedDescriptionForErrorCode:1];
            *error = [NSError gad_errorWithCode:1 description:description];
        }
        return nil;
    }
    id metadata = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:error];
    if ([metadata isKindOfClass:[NSDictionary class]])
        return metadata;
    return nil;
}

@interface GADApplication : NSObject {
    GADSession *_currentSession;
    BOOL _appFinishedLaunching;
}
@property (nonatomic, retain) GADSession *currentSession;
@property (nonatomic) BOOL appFinishedLaunching;
+ (GADApplication *)sharedApplication;
- (void)runEarlyActivities;
@end

static dispatch_once_t applicationOnce;
static GADApplication *application;
static dispatch_once_t earlyActivitiesOnce;
static dispatch_once_t metadataOnce;
static NSDictionary *cachedMetadata;

@implementation GADApplication

@synthesize currentSession = _currentSession, appFinishedLaunching = _appFinishedLaunching;

+ (void)load
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
            [[GADApplication sharedApplication] setAppFinishedLaunching:YES];
            [[GADApplication sharedApplication] runEarlyActivities];
        }];
    [pool drain];
}

+ (GADApplication *)sharedApplication
{
    dispatch_once(&applicationOnce, ^{
        application = [[self alloc] init];
    });
    return application;
}

- (id)init
{
    if ((self = [super init]))
        _currentSession = [[GADSession alloc] init];
    return self;
}

- (void)dealloc
{
    [_currentSession release];
    [super dealloc];
}

- (void)runEarlyActivities
{
    dispatch_once(&earlyActivitiesOnce, ^{
        [GADMRAIDInterceptor allow];
        [GADMAdNetworkAdapter availableAdapterNames];
    });
}

- (BOOL)isAppActive
{
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        return ![self appFinishedLaunching];
    return YES;
}

- (NSString *)iTunesMetadataPath
{
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
        NSUserDomainMask, YES) firstObject];
    if (documents) {
        NSArray *components = @[documents, @"..", @"iTunesMetadata.plist"];
        return [[NSString pathWithComponents:components] stringByStandardizingPath];
    }
    return nil;
}

- (NSDictionary *)iTunesMetadata
{
    dispatch_once(&metadataOnce, ^{
        NSError *error = nil;
        cachedMetadata = [GADiTunesMetadataForFileAtPath([self iTunesMetadataPath], &error) retain];
        if (!cachedMetadata)
            cachedMetadata = [[NSDictionary alloc] init];
    });
    return cachedMetadata;
}

@end
