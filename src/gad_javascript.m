#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface GADCachedFile : NSObject
- (id)initWithDelegate:(id)delegate URL:(NSURL *)url;
- (void)setDelegate:(id)delegate;
- (NSURL *)sourceURL;
- (NSString *)contentAsString;
- (void)cancel;
- (void)validate;
@end

@interface GADStatisticsCore : NSObject
- (void)setIdentifier:(NSString *)identifier;
- (NSDate *)dateForKey:(NSString *)key;
- (void)setDate:(NSDate *)date forKey:(NSString *)key;
- (void)synchronize;
@end

@interface GADWebView : UIWebView
@end

@interface GADWebViewDelegate : NSObject <UIWebViewDelegate>
- (BOOL)hasLoadedAtLeastOnce;
@end

@interface GADNotificationCenter : NSNotificationCenter
@end

@interface GADMacros : NSObject
+ (NSString *)dictionaryToJSONString:(NSDictionary *)dictionary;
+ (void)pubLog:(NSString *)message;
@end

@interface GADMRAIDInterceptor : NSObject
+ (void)setBannerImplementationPath:(NSString *)path;
+ (void)setInterstitialImplementationPath:(NSString *)path;
+ (void)setExpandedBannerImplementationPath:(NSString *)path;
+ (void)allow;
+ (void)disallow;
@end

@protocol GADJavaScriptControllerDelegate
- (void)setRequestId:(NSString *)requestId;
- (NSDictionary *)requestParameters;
- (void)invalidJavaScriptRequest;
- (void)loadAdURL:(NSNotification *)notification;
- (void)failedJavaScriptFile;
@end

extern NSString *const kGADWebViewDelegateWebViewDidFinishLoad;
extern NSString *const kGADWebViewDelegateWebViewDidFailLoad;
extern NSString *const kGADParameterRequestId;

@interface GADJavaScriptController : NSObject {
    GADWebViewDelegate *buildAdWebViewDelegate_;
    NSMutableArray *pendingDelegates_;
    NSMutableDictionary *delegates_;
    NSMutableArray *pendingJavaScriptCommands_;
    unsigned int requestId_;
    BOOL _shouldCheckOreoID;
    GADCachedFile *_buildAdJS;
    UIWebView *_buildAdWebView;
}
@property (nonatomic, retain) GADCachedFile *buildAdJS;
@property (nonatomic, retain) UIWebView *buildAdWebView;
@property (nonatomic, assign) BOOL shouldCheckOreoID;
@end

static GADJavaScriptController *gadSharedJavaScriptController;

@implementation GADJavaScriptController

@dynamic buildAdJS, buildAdWebView, shouldCheckOreoID;

- (id)init
{
    self = [super init];
    if (self) {
        buildAdWebViewDelegate_ = [[GADWebViewDelegate alloc] init];
        pendingDelegates_ = [[NSMutableArray alloc] initWithCapacity:5];
        delegates_ = [[NSMutableDictionary alloc] initWithCapacity:5];
        pendingJavaScriptCommands_ = [[NSMutableArray alloc] initWithCapacity:5];
        requestId_ = 1;
        [self registerForJavaScriptNotifications];
    }
    return self;
}

- (void)dealloc
{
    [self unregisterFromJavaScriptNotifications];
    [self clearCachedFile];
    [_buildAdWebView setDelegate:nil];
    [_buildAdWebView release];
    [buildAdWebViewDelegate_ release];
    buildAdWebViewDelegate_ = nil;
    [self removeAllDelegates];
    [pendingDelegates_ release];
    pendingDelegates_ = nil;
    [delegates_ release];
    delegates_ = nil;
    [pendingJavaScriptCommands_ release];
    pendingJavaScriptCommands_ = nil;
    [[GADNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

+ (id)sharedInstance
{
    if (!gadSharedJavaScriptController)
        gadSharedJavaScriptController = [[GADJavaScriptController alloc] init];
    return gadSharedJavaScriptController;
}

- (void)executeJavaScriptFileFromURL:(NSString *)urlString withDelegate:(id<GADJavaScriptControllerDelegate>)delegate
{
    [self addPendingDelegate:delegate];
    if (![[self cachedJavaScriptFileURL] isEqualToString:urlString]) {
        [self clearCachedFile];
        NSURL *url = [NSURL URLWithString:urlString];
        self.buildAdJS = [[[GADCachedFile alloc] initWithDelegate:self URL:url] autorelease];
    }
    GADStatisticsCore *statistics = [[GADStatisticsCore alloc] init];
    [statistics setIdentifier:@"GADSlot"];
    NSComparisonResult expiry = [[statistics dateForKey:@"expireDate"] compare:[NSDate date]];
    NSUInteger length = [[self.buildAdJS contentAsString] length];
    if (expiry == NSOrderedAscending || !length) {
        [statistics setDate:[NSDate dateWithTimeIntervalSinceNow:3600] forKey:@"expireDate"];
        [statistics synchronize];
        [self.buildAdJS validate];
    } else {
        [self cachedFileDownloadDidEnd:self.buildAdJS];
    }
    [statistics release];
}

- (NSString *)cachedJavaScriptFileURL
{
    return self.buildAdJS ? [[self.buildAdJS sourceURL] absoluteString] : @"";
}

- (void)clearCachedFile
{
    [_buildAdJS setDelegate:nil];
    [_buildAdJS cancel];
    [_buildAdJS release];
    _buildAdJS = nil;
}

+ (void)clear
{
    [gadSharedJavaScriptController release];
    gadSharedJavaScriptController = nil;
}

- (void)addPendingDelegate:(id<GADJavaScriptControllerDelegate>)delegate
{
    [pendingDelegates_ insertObject:delegate atIndex:0];
}

- (void)addDelegate:(id<GADJavaScriptControllerDelegate>)delegate
{
    if (delegate) {
        @synchronized(self) {
            NSString *requestId = [NSString stringWithFormat:@"%lu", (unsigned long)requestId_];
            [delegate setRequestId:requestId];
            [delegates_ setObject:delegate forKey:requestId];
            ++requestId_;
        }
    }
}

- (void)removeDelegateWithRequestId:(NSString *)requestId
{
    @synchronized(delegates_) {
        [delegates_ removeObjectForKey:requestId];
    }
}

- (void)removeAllDelegates
{
    [self unregisterFromJavaScriptNotifications];
    if ([pendingDelegates_ count])
        [pendingDelegates_ removeAllObjects];
    if ([delegates_ count])
        [delegates_ removeAllObjects];
}

- (void)registerForJavaScriptNotifications
{
    NSNotificationCenter *center = [GADNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(loadAdURL:) name:@"loadAdURL" object:self.buildAdWebView];
    [center addObserver:self selector:@selector(invalidRequest:) name:@"invalidRequest" object:self.buildAdWebView];
    [center addObserver:self selector:@selector(loadSdkConstants:) name:@"loadSdkConstants" object:self.buildAdWebView];
}

- (void)unregisterFromJavaScriptNotifications
{
    NSNotificationCenter *center = [GADNotificationCenter defaultCenter];
    [center removeObserver:self name:@"loadAdURL" object:self.buildAdWebView];
    [center removeObserver:self name:@"invalidRequest" object:self.buildAdWebView];
    [center removeObserver:self name:@"loadSdkConstants" object:self.buildAdWebView];
}

- (void)registerForWebViewNotifications
{
    NSNotificationCenter *center = [GADNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(webViewDidFinishLoad) name:kGADWebViewDelegateWebViewDidFinishLoad object:self.buildAdWebView];
    [center addObserver:self selector:@selector(webViewDidFailLoad) name:kGADWebViewDelegateWebViewDidFailLoad object:self.buildAdWebView];
}

- (void)unregisterFromWebViewNotifications
{
    NSNotificationCenter *center = [GADNotificationCenter defaultCenter];
    [center removeObserver:self name:kGADWebViewDelegateWebViewDidFinishLoad object:self.buildAdWebView];
    [center removeObserver:self name:kGADWebViewDelegateWebViewDidFailLoad object:self.buildAdWebView];
}

- (void)webViewDidFinishLoad
{
    [self unregisterFromWebViewNotifications];
    while ([pendingJavaScriptCommands_ count]) {
        NSString *command = [pendingJavaScriptCommands_ lastObject];
        [self.buildAdWebView stringByEvaluatingJavaScriptFromString:command];
        [pendingJavaScriptCommands_ removeLastObject];
    }
}

- (void)webViewDidFailLoad
{
    SEL failed = @selector(failedJavaScriptFile);
    [[delegates_ allValues] makeObjectsPerformSelector:failed];
    [pendingDelegates_ makeObjectsPerformSelector:failed];
    [self unregisterFromWebViewNotifications];
}

- (void)setupBuildAdWebView
{
    self.buildAdWebView = [[[GADWebView alloc] initWithFrame:CGRectZero] autorelease];
    [self.buildAdWebView setHidden:YES];
    [self.buildAdWebView setDelegate:buildAdWebViewDelegate_];
    [self registerForWebViewNotifications];
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<html><head><script>"];
    [html appendString:[self.buildAdJS contentAsString]];
    [html appendString:@"</script>"];
    [html appendFormat:@"</head><body></body></html>"];
    NSURL *baseURL = [NSURL URLWithString:@"http://googleads.g.dpvblfcljck.nft"];
    [self.buildAdWebView loadHTMLString:html baseURL:baseURL];
}

- (void)runCommandOnWebView:(NSString *)command
{
    if ([buildAdWebViewDelegate_ hasLoadedAtLeastOnce])
        [self.buildAdWebView stringByEvaluatingJavaScriptFromString:command];
    else
        [pendingJavaScriptCommands_ insertObject:command atIndex:0];
}

- (void)buildAdURLFromRequestParameters:(NSDictionary *)parameters
{
    if (![[self.buildAdJS contentAsString] length]) {
        [self failedToDownloadJavaScriptWithError:nil];
        return;
    }
    if (!self.buildAdWebView)
        [self setupBuildAdWebView];
    if (parameters) {
        NSString *json = [GADMacros dictionaryToJSONString:parameters];
        [self runCommandOnWebView:[NSString stringWithFormat:@"%@(%@);", @"AFMA_buildAdURL", json]];
    }
}

- (void)buildAdURLForPendingDelegates
{
    @synchronized(pendingDelegates_) {
        while ([pendingDelegates_ count]) {
            id<GADJavaScriptControllerDelegate> delegate = [pendingDelegates_ lastObject];
            [self addDelegate:delegate];
            [self buildAdURLFromRequestParameters:[delegate requestParameters]];
            [pendingDelegates_ removeLastObject];
        }
    }
}

- (void)invalidRequest:(NSNotification *)notification
{
    [GADMacros pubLog:[NSString stringWithFormat:@"Invalid Request: %@", [notification userInfo]]];
    NSString *requestId = [[notification userInfo] objectForKey:kGADParameterRequestId];
    id<GADJavaScriptControllerDelegate> delegate = [delegates_ objectForKey:requestId];
    if (delegate)
        [self removeDelegateWithRequestId:requestId];
    [delegate invalidJavaScriptRequest];
}

- (void)loadSdkConstants:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    NSString *bannerPath = [info objectForKey:@"mraid_banner_path"];
    [GADMRAIDInterceptor setBannerImplementationPath:bannerPath];
    NSString *interstitialPath = [info objectForKey:@"mraid_interstitial_path"];
    [GADMRAIDInterceptor setInterstitialImplementationPath:interstitialPath];
    NSString *expandedPath = [info objectForKey:@"mraid_expanded_banner_path"];
    [GADMRAIDInterceptor setExpandedBannerImplementationPath:expandedPath];
    if ([[info objectForKey:@"mraid_disable_redirect"] isEqualToString:@"1"])
        [GADMRAIDInterceptor disallow];
    else
        [GADMRAIDInterceptor allow];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *reportPath = [info objectForKey:@"bad_ad_report_path"];
    if ([reportPath length])
        [defaults setObject:reportPath forKey:@"bad_ad_report_path"];
    NSString *domains = [info objectForKey:@"as_domains"];
    if ([domains length])
        [defaults setObject:domains forKey:@"as_domains"];
}

- (void)loadAdURL:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    NSString *requestId = [info objectForKey:kGADParameterRequestId];
    NSString *check = [info objectForKey:@"check_oid"];
    self.shouldCheckOreoID = !check || [check isEqualToString:@"1"];
    id<GADJavaScriptControllerDelegate> delegate = [delegates_ objectForKey:requestId];
    if (delegate) {
        [delegate loadAdURL:notification];
        [self removeDelegateWithRequestId:requestId];
    }
}

- (void)failedToDownloadJavaScriptWithError:(NSError *)error
{
    if ([[self.buildAdJS contentAsString] length]) {
        [self buildAdURLForPendingDelegates];
    } else {
        [delegates_ count];
        [pendingDelegates_ makeObjectsPerformSelector:@selector(failedJavaScriptFile)];
    }
}

- (void)cachedFileDownloadDidEnd:(GADCachedFile *)file
{
    [self buildAdURLForPendingDelegates];
    [self runCommandOnWebView:[NSString stringWithFormat:@"%@();", @"AFMA_getSdkConstants"]];
}

@end
