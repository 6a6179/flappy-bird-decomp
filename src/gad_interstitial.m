#import <UIKit/UIKit.h>

@class GADSlot, GADInterstitial;

@interface GADWebView : UIWebView
- (void)setViewController:(UIViewController *)controller;
@end

@interface GADWebAppViewController : UIViewController
- (id)initWithWebView:(GADWebView *)view forInterstitial:(GADInterstitial *)interstitial;
- (void)setDelegateManager:(id)manager;
- (void)setSupportedOrientations:(int)orientations;
- (void)setSlot:(GADSlot *)slot;
- (void)presentFromViewController:(UIViewController *)root;
@end

@interface GADDelegateManager : NSObject
- (void)didFailToReceiveAdWithError:(NSError *)error;
- (void)setSDKInterstitialDelegate:(id)delegate;
@end

@interface GADSlotStatistics : NSObject
- (void)setAppOpenInterstitialTimeOut;
- (void)setAppOpenInterstitialNoFill;
@end

@interface GADSlot : NSObject
- (id)initWithFrame:(CGRect)frame;
@property(nonatomic, assign) GADInterstitial *interstitial;
@property(nonatomic, retain) GADWebView *webView;
@property(nonatomic) int state;
- (void)cancelPendingActions;
- (void)cancelPendingAndFutureActions;
- (GADDelegateManager *)delegateManager;
- (GADSlotStatistics *)slotStats;
- (void)loadRequest:(id)request;
- (BOOL)isMediating;
- (int)supportedOrientations;
- (NSArray *)pendingTrackingURLs;
- (void)presentMediatedInterstitialFromRootViewController:(UIViewController *)root;
- (void)setCalledLoadAndDisplayRequest:(BOOL)called;
@end

@interface GADInterstitial : NSObject {
    BOOL _hasBeenUsed;
    id _request;
    GADWebAppViewController *_viewController;
    GADSlot *_slot;
}
@property(nonatomic) BOOL hasBeenUsed;
@property(nonatomic, retain) id request;
@property(nonatomic, retain) GADWebAppViewController *viewController;
@property(nonatomic, retain) GADSlot *slot;
- (void)sendInterstitialUsageError;
- (id)privateRequest;
- (void)cancel;
@end

@interface GADInterstitialAppController : UIViewController {
    GADInterstitial *interstitial_;
    UIWindow *window_;
    NSArray *storedUserViews_;
    UIImageView *imageView_;
    NSTimer *timeout_;
    BOOL hideStatusBar_;
    UIViewController *originalRootViewController_;
}
- (id)initWithWindow:(UIWindow *)window image:(UIImage *)image timeout:(NSTimeInterval)timeout
        interstitial:(GADInterstitial *)interstitial;
- (void)removeSelfAsDelegate;
- (void)interstitialWillDismissScreen:(GADInterstitial *)interstitial;
@end

extern NSString *const kGADWebViewDelegateDidReceiveWebAction;

@interface GADNotificationCenter : NSNotificationCenter
@end
@interface GADClickTrackerCollection : NSObject
+ (id)sharedInstance;
- (void)trackURLs:(NSArray *)urls;
@end
@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end
@interface GADRequestError : NSError
+ (id)errorWithCode:(int)code request:(id)request;
@end

@implementation GADInterstitial
@dynamic hasBeenUsed, request, viewController, slot;

- (void)sendInterstitialError:(NSError *)error
{
    [GADMacros pubLog:[NSString stringWithFormat:@"%@", [error localizedDescription]]];
    self.slot.state = 7;
    [self.slot cancelPendingActions];
    [[self.slot delegateManager] didFailToReceiveAdWithError:error];
}

- (void)webAction:(NSNotification *)notification
{
    NSString *action = [[notification userInfo] objectForKey:@"a"];
    if (!action || [action isEqualToString:@"open"])
        [self.slot cancelPendingActions];
}

- (id)init
{
    self = [super init];
    if (self) {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        _slot = [[GADSlot alloc] initWithFrame:bounds];
        _slot.interstitial = self;
        _viewController = [[GADWebAppViewController alloc] initWithWebView:_slot.webView
                                                          forInterstitial:self];
        [_slot.webView setViewController:_viewController];
        [[GADNotificationCenter defaultCenter] addObserver:self selector:@selector(webAction:)
                                                     name:kGADWebViewDelegateDidReceiveWebAction
                                                   object:_slot.webView];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[GADNotificationCenter defaultCenter] removeObserver:self];
    [_request release];
    [_slot.webView setViewController:nil];
    [_viewController release];
    _slot.interstitial = nil;
    [_slot cancelPendingAndFutureActions];
    [_slot release];
    [super dealloc];
}

- (void)loadRequest:(id)request
{
    self.request = request;
    if (self.hasBeenUsed)
        [self sendInterstitialUsageError];
    else
        [self.slot loadRequest:request];
}

- (BOOL)isReady
{
    return self.slot.state == 6;
}

- (void)presentFromRootViewController:(UIViewController *)root
{
    if (self.hasBeenUsed) {
        [self sendInterstitialUsageError];
        return;
    }
    if (![self isReady]) {
        [GADMacros pubLog:[NSString stringWithFormat:@"Cannot present interstitial.  It is not ready."]];
        return;
    }
    if ([self.slot isMediating]) {
        [self.slot presentMediatedInterstitialFromRootViewController:root];
    } else {
        self.slot.webView.delegate = nil;
        [self.viewController setDelegateManager:[self.slot delegateManager]];
        [self.viewController setSupportedOrientations:[self.slot supportedOrientations]];
        [self.viewController setSlot:self.slot];
        self.slot.webView = nil;
        NSArray *urls = [self.slot pendingTrackingURLs];
        [[GADClickTrackerCollection sharedInstance] trackURLs:urls];
        [self.viewController presentFromViewController:root];
        self.viewController = nil;
    }
    self.hasBeenUsed = YES;
}

- (void)loadAndDisplayRequest:(id)request usingWindow:(UIWindow *)window initialImage:(UIImage *)image
{
    [self.slot setCalledLoadAndDisplayRequest:YES];
    self.request = request;
    if (self.hasBeenUsed) {
        [self sendInterstitialUsageError];
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval timeout = [defaults objectForKey:@"applicationTimeout"]
                           ? [defaults doubleForKey:@"applicationTimeout"] : 5.0;
    if (timeout <= 0) {
        [GADMacros pubLog:[NSString stringWithFormat:@"Interstitial has zero timeout.  Not displaying."]];
        return;
    }
    GADInterstitialAppController *controller = [[[GADInterstitialAppController alloc]
        initWithWindow:window image:image timeout:timeout interstitial:self] autorelease];
    [[self.slot delegateManager] setSDKInterstitialDelegate:controller];
    [self.slot loadRequest:request];
}
@end

@implementation GADInterstitialAppController
- (void)timeout:(NSTimer *)timer
{
    [timeout_ invalidate];
    [[[interstitial_ slot] slotStats] setAppOpenInterstitialTimeOut];
    [GADMacros pubLog:[NSString stringWithFormat:@"Interstitial request timed out."]];
    [self interstitialWillDismissScreen:interstitial_];
    NSError *error = [GADRequestError errorWithCode:5 request:[interstitial_ privateRequest]];
    [interstitial_ sendInterstitialError:error];
    [interstitial_ cancel];
}

- (id)initWithWindow:(UIWindow *)window image:(UIImage *)image timeout:(NSTimeInterval)timeout
        interstitial:(GADInterstitial *)interstitial
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        interstitial_ = [interstitial retain];
        [self retain];
        window_ = window;
        originalRootViewController_ = [[window rootViewController] retain];
        if ([[window subviews] count]) {
            storedUserViews_ = [[window subviews] retain];
            [storedUserViews_ makeObjectsPerformSelector:@selector(removeFromSuperview)];
        }
        hideStatusBar_ = [[UIApplication sharedApplication] isStatusBarHidden];
        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        timeout_ = [[NSTimer scheduledTimerWithTimeInterval:timeout target:self selector:@selector(timeout:)
                                                    userInfo:nil repeats:NO] retain];
        CGRect frame = window.frame;
        frame.origin = CGPointZero;
        self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
        if ([window respondsToSelector:@selector(setRootViewController)])
            window.rootViewController = self;
        else
            [window addSubview:self.view];
        imageView_ = [[UIImageView alloc] initWithImage:image];
        [self.view addSubview:imageView_];
    }
    return self;
}

- (void)restoreWindowAndRelease
{
    [[UIApplication sharedApplication] setStatusBarHidden:hideStatusBar_];
    [imageView_ removeFromSuperview];
    for (UIView *view in storedUserViews_)
        [window_ addSubview:view];
    if ([window_ respondsToSelector:@selector(rootViewController)])
        window_.rootViewController = originalRootViewController_;
    [self autorelease];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return orientation == UIInterfaceOrientationPortrait;
}

- (void)interstitial:(GADInterstitial *)interstitial didFailToReceiveAdWithError:(NSError *)error
{
    [timeout_ invalidate];
    if ([error code] == 1)
        [[[interstitial_ slot] slotStats] setAppOpenInterstitialNoFill];
    [self removeSelfAsDelegate];
    [self restoreWindowAndRelease];
}
@end
