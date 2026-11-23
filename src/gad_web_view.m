#import <UIKit/UIKit.h>

@interface GADImpressionTicketGestureRecognizer : UIGestureRecognizer @end
@interface GADUIWebViewGestureDelgate : NSObject <UIGestureRecognizerDelegate> @end
@interface GADDevice : NSObject
+ (id)currentDevice;
- (NSString *)deviceSubmodel;
+ (BOOL)isOSAtLeastMajor:(NSInteger)major minor:(NSInteger)minor bug:(NSInteger)patch;
@end
@interface GADRequest : NSObject
+ (NSString *)sdkVersion;
@end
@interface GADNotificationCenter : NSObject
+ (id)defaultCenter;
- (void)postJSNotification:(NSString *)name userInfo:(NSDictionary *)userInfo webView:(UIWebView *)view;
- (void)postNotificationName:(NSString *)name object:(id)object userInfo:(NSDictionary *)userInfo;
- (void)postNotificationFromURL:(NSURL *)url object:(id)object withDelay:(NSTimeInterval)delay;
@end
@interface GADAdURLStash : NSObject
+ (void)remove:(NSURL *)url;
+ (void)add:(NSURL *)url forView:(UIWebView *)view;
@end
extern NSString *const kGADPublisherToolbarCustomURL;

@interface GADWebView : UIWebView <UIAlertViewDelegate> {
    GADImpressionTicketGestureRecognizer *_gesture;
    GADUIWebViewGestureDelgate *_gestureDelegate;
    BOOL _showDebug;
}
@property(nonatomic) BOOL savedState, touched, didReceiveLoadEvent;
@property(nonatomic) CGRect savedFrame;
@property(nonatomic, retain) UIView *savedSuperview;
@property(nonatomic, retain) id<UIWebViewDelegate> savedDelegate;
@property(nonatomic, assign) UIViewController *viewController, *viewControllerBeforeExpanded;
@property(nonatomic) UIInterfaceOrientation orientation;
@property(nonatomic, retain) UIAlertView *alertView;
- (BOOL)showDebug;
- (NSString *)adDebugDialog;
- (UIGestureRecognizer *)gesture;
- (void)reportBadAd:(NSString *)information;
- (void)forceRotateToOrientation:(UIInterfaceOrientation)orientation;
- (NSURL *)url;
- (NSURL *)URL;
- (void)setURL:(NSURL *)url;
@end

@implementation GADWebView

@dynamic savedState, touched, didReceiveLoadEvent, savedFrame, savedSuperview, savedDelegate;
@dynamic viewController, viewControllerBeforeExpanded, orientation, alertView;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if (NSClassFromString(@"UIGestureRecognizer")) {
            _gesture = [[GADImpressionTicketGestureRecognizer alloc] init];
            if ([_gesture respondsToSelector:@selector(locationInView:)]) {
                _gestureDelegate = [[GADUIWebViewGestureDelgate alloc] init];
            } else {
                [_gesture release];
                _gesture = nil;
            }
        }
        [_gesture setDelegate:_gestureDelegate];
        _showDebug = YES;
        [self reset];
    }
    return self;
}

- (void)reset
{
    [self setClipsToBounds:YES];
    [self setScalesPageToFit:YES];
    [self setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setOpaque:NO];
    [self setBackgroundColor:[UIColor clearColor]];
    [self setDataDetectorTypes:UIDataDetectorTypeNone];
    [self setAllowsInlineMediaPlayback:YES];
    [self setMediaPlaybackRequiresUserAction:NO];
    if ([self respondsToSelector:@selector(mediaPlaybackAllowsAirPlay)])
        [self setMediaPlaybackAllowsAirPlay:YES];
    if ([self respondsToSelector:@selector(scrollView)])
        [[self scrollView] setScrollsToTop:NO];
    [self createGestureRecognizer];
}

- (void)saveState
{
    [self setSavedFrame:[self frame]];
    [self setSavedSuperview:[self superview]];
    [self setSavedDelegate:[self delegate]];
    [self setViewControllerBeforeExpanded:[self viewController]];
    [self setSavedState:YES];
}

- (void)restoreState
{
    if (![self savedState])
        return;
    [[self retain] autorelease];
    [self removeFromSuperview];
    [self setFrame:[self savedFrame]];
    [self setSavedFrame:CGRectZero];
    [[self savedSuperview] addSubview:self];
    [self setSavedSuperview:nil];
    [self setDelegate:[self savedDelegate]];
    [self setSavedDelegate:nil];
    [self setViewController:[self viewControllerBeforeExpanded]];
    [self setViewControllerBeforeExpanded:nil];
    [self setSavedState:NO];
}

- (void)notifyOfSdkEvent:(NSString *)name
{
    if ([self didReceiveLoadEvent]) {
        NSDictionary *info = @{@"version": [GADRequest sdkVersion],
                               @"device": [[GADDevice currentDevice] deviceSubmodel]};
        [[GADNotificationCenter defaultCenter] postJSNotification:name userInfo:info webView:self];
    }
}

- (void)setHtmlWindowWithOrientation:(UIInterfaceOrientation)orientation andFireEvent:(BOOL)fire
{
    if (!UIInterfaceOrientationIsPortrait(orientation) && !UIInterfaceOrientationIsLandscape(orientation))
        return;
    if ([self orientation] == orientation)
        return;
    [self setOrientation:orientation];
    NSInteger angle = 0;
    switch (orientation) {
        case UIInterfaceOrientationPortrait: angle = 0; break;
        case UIInterfaceOrientationPortraitUpsideDown: angle = 180; break;
        case UIInterfaceOrientationLandscapeLeft: angle = -90; break;
        case UIInterfaceOrientationLandscapeRight: angle = 90; break;
    }
    NSMutableString *script = [NSMutableString stringWithFormat:
        @"window.__defineGetter__('orientation',function(){return %ld;});", (long)angle];
    if (fire)
        [script appendString:@"(function(){var event = document.createEvent('Events');event.initEvent('orientationchange', true, false);window.dispatchEvent(event);})();"];
    [self stringByEvaluatingJavaScriptFromString:script];
}

- (void)didRotateToOrientation:(UIInterfaceOrientation)orientation
{
    [self setHtmlWindowWithOrientation:orientation andFireEvent:![GADDevice isOSAtLeastMajor:5 minor:0 bug:0]];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if ([event type] == UIEventTypeTouches)
        [self setTouched:YES];
    return [super hitTest:point withEvent:event];
}

- (void)createGestureRecognizer
{
    if ([self gesture] && [self respondsToSelector:@selector(addGestureRecognizer:)]) {
        [[self gesture] addTarget:self action:@selector(handleGesture:)];
        [self addGestureRecognizer:[self gesture]];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)index
{
    if (index == 1) {
        NSURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:kGADPublisherToolbarCustomURL]];
        [[self delegate] webView:self shouldStartLoadWithRequest:request navigationType:UIWebViewNavigationTypeOther];
    }
    if ([[self adDebugDialog] length]) {
        if (index == 2)
            [[UIPasteboard generalPasteboard] setString:[self adDebugDialog]];
        else if (index == 3)
            [self reportBadAd:[self adDebugDialog]];
    }
}

- (void)handleGesture:(UIGestureRecognizer *)gesture
{
    NSString *message = [self adDebugDialog] ? [self adDebugDialog] : @"Creative information is not available";
    if ([self showDebug]) {
        [self setAlertView:[[[UIAlertView alloc] initWithTitle:@"Debug Creative Info" message:message
            delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease]];
        [[self alertView] addButtonWithTitle:@"Publisher Toolbar"];
        if ([self adDebugDialog]) {
            [[self alertView] addButtonWithTitle:@"Copy"];
            [[self alertView] addButtonWithTitle:@"Report"];
        }
        [[self alertView] show];
    }
}

- (void)setURL:(NSURL *)url forView:(UIWebView *)view
{
    if ([self URL])
        [GADAdURLStash remove:[self URL]];
    [self setURL:url];
    [[view retain] autorelease];
    [GADAdURLStash add:url forView:view];
}

@end

@interface GADSlot : NSObject
- (BOOL)isMRAID;
@end
@interface GADOpener : NSObject
- (void)openPublisherToolbar:(NSString *)adUnit withAdContent:(NSString *)html;
- (void)setViewController:(UIViewController *)controller;
- (void)setWebView:(GADWebView *)view;
- (GADSlot *)slot;
- (void)openBrowserToURL:(NSURL *)url supportedOrientations:(int)orientations;
- (void)openEmailComposer:(NSURL *)url;
- (void)openSmsComposer:(NSURL *)url;
- (void)openApp:(NSURL *)url;
@end
@interface GADGMSGHandler : NSObject
+ (BOOL)isGMSG:(NSURL *)url;
- (BOOL)handleRequest:(NSURLRequest *)request webView:(GADWebView *)view;
@end
@interface GADDefaultGMSGHandler : GADGMSGHandler @end
@interface GADOpenerGMSGHandler : GADGMSGHandler
- (id)initWithOpener:(GADOpener *)opener;
@end
@interface GADNetworkUtilities : NSObject
+ (void)setUserAgentString:(NSString *)userAgent;
+ (NSString *)urlStringWithoutHashFragment:(NSString *)url;
@end
@interface GADNotification : NSObject
+ (id)notificationFromURL:(NSURL *)url;
- (NSString *)name;
@end
@interface GADBannerView : UIView
- (NSString *)adUnitID;
@end

@interface GADWebViewDelegate : NSObject <UIWebViewDelegate> {
    GADOpener *opener_;
    BOOL hasLoadedAtLeastOnce_;
    NSMutableArray *_gmsgHandlers;
    GADOpenerGMSGHandler *_openerGMSGHandler;
}
- (void)loadedFirstPage:(UIWebView *)view;
- (GADOpener *)opener;
- (NSArray *)gmsgHandlers;
- (BOOL)allowFileAccess;
@end

@implementation GADWebViewDelegate

- (id)init
{
    self = [super init];
    if (self) {
        opener_ = [[GADOpener alloc] init];
        _gmsgHandlers = [[NSMutableArray alloc] init];
        _openerGMSGHandler = [[GADOpenerGMSGHandler alloc] initWithOpener:opener_];
        [_gmsgHandlers addObject:_openerGMSGHandler];
        [_gmsgHandlers addObject:[[[GADDefaultGMSGHandler alloc] init] autorelease]];
    }
    return self;
}

- (BOOL)webView:(UIWebView *)view shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)type
{
    NSURL *url = [request URL];
    if (!url)
        return NO;
    if ([[url absoluteString] isEqualToString:kGADPublisherToolbarCustomURL]) {
        NSString *html = [view stringByEvaluatingJavaScriptFromString:@"document.body.innerHTML"];
        NSString *unit = nil;
        if ([[view superview] isKindOfClass:[GADBannerView class]])
            unit = [(GADBannerView *)[view superview] adUnitID];
        [[self opener] openPublisherToolbar:unit withAdContent:html];
        return NO;
    }
    if (![view isKindOfClass:[GADWebView class]])
        return YES;
    GADWebView *webView = (GADWebView *)view;
    NSString *scheme = [[url scheme] lowercaseString];
    if ([request respondsToSelector:@selector(valueForHTTPHeaderField:)]) {
        NSString *agent = [request valueForHTTPHeaderField:@"User-Agent"];
        [GADNetworkUtilities setUserAgentString:agent];
    }
    [opener_ setViewController:[webView viewController]];
    if ([view isKindOfClass:[GADWebView class]])
        [opener_ setWebView:webView];
    if (type == UIWebViewNavigationTypeLinkClicked) {
        if ([url fragment]) {
            NSString *current = [GADNetworkUtilities urlStringWithoutHashFragment:[[[view request] URL] absoluteString]];
            NSString *next = [GADNetworkUtilities urlStringWithoutHashFragment:[url absoluteString]];
            if ([current isEqualToString:next])
                return NO;
        }
        if ([scheme hasPrefix:@"http"] && [[[self opener] slot] isMRAID]) {
            [[self opener] openBrowserToURL:url supportedOrientations:1];
            return NO;
        }
    }
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    [info setObject:[url absoluteString] forKey:@"u"];
    if ([GADGMSGHandler isGMSG:url]) {
        GADNotification *notification = [GADNotification notificationFromURL:url];
        [info setObject:[notification name] forKey:@"a"];
        [center postNotificationName:@"didReceiveWebAction" object:view userInfo:info];
        if (![self handleGMSGRequest:request webView:webView])
            [[GADNotificationCenter defaultCenter] postNotificationFromURL:url object:view withDelay:0];
        return NO;
    }
    if (type != UIWebViewNavigationTypeOther || [[url path] length] > 1)
        [center postNotificationName:@"didReceiveWebAction" object:view userInfo:info];
    if ([scheme isEqualToString:@"mailto"])
        [opener_ openEmailComposer:url];
    else if ([scheme isEqualToString:@"sms"])
        [opener_ openSmsComposer:url];
    else if ([scheme isEqualToString:@"file"])
        return [self allowFileAccess];
    else if ([scheme isEqualToString:@"about"])
        return YES;
    else if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        if ([view isKindOfClass:[GADWebView class]] && ![[webView url] isEqual:url])
            [webView setURL:url forView:webView];
        return YES;
    } else {
        [opener_ openApp:url];
    }
    return NO;
}

- (BOOL)handleGMSGRequest:(NSURLRequest *)request webView:(GADWebView *)view
{
    BOOL handled = NO;
    for (GADGMSGHandler *handler in [self gmsgHandlers])
        handled |= [handler handleRequest:request webView:view];
    return handled;
}

- (void)webViewDidFinishLoad:(UIWebView *)view
{
    if ([view isKindOfClass:[GADWebView class]]) {
        [(GADWebView *)view forceRotateToOrientation:[[UIApplication sharedApplication] statusBarOrientation]];
        [(GADWebView *)view setDidReceiveLoadEvent:YES];
    }
    if (!hasLoadedAtLeastOnce_) {
        hasLoadedAtLeastOnce_ = YES;
        [[GADNotificationCenter defaultCenter] postNotificationName:@"webViewDidFinishLoad" object:view userInfo:nil];
        [self loadedFirstPage:view];
    }
}

- (void)webView:(UIWebView *)view didFailLoadWithError:(NSError *)error
{
    [[GADNotificationCenter defaultCenter] postNotificationName:@"webViewDidFailLoad" object:view userInfo:nil];
}

@end

extern NSString *const kGADParameterPriorLandingPageLoad;
extern NSString *const kGADParameterPriorLandingPageDuration;

@interface GADSlotStatistics : NSObject
- (id)timingNamed:(NSString *)name;
- (void)startTimingNamed:(NSString *)name withExplicitEnd:(BOOL)explicitEnd;
- (void)endTimingNamed:(NSString *)name;
@end
@interface GADSlot (WebAppStatistics)
- (GADSlotStatistics *)slotStats;
@end
@interface GADInterstitial : NSObject
- (GADSlot *)slot;
@end
@interface GADWebAppViewController : UIViewController
- (GADWebView *)webView;
- (GADSlot *)slot;
- (GADInterstitial *)interstitial;
@end
@interface GADWebAppGMSGHandler : GADGMSGHandler @end
@interface GADAppEventGMSGHandler : GADGMSGHandler
- (id)initWithSlot:(GADSlot *)slot;
@end
@interface GADWebViewDelegate (MessageHandlers)
- (void)addGMSGHandler:(GADGMSGHandler *)handler;
@end

@interface GADWebAppWebViewDelegate : GADWebViewDelegate {
    GADWebAppViewController *_webAppViewController;
    BOOL _pendingOnShow, _calledOnShow;
}
- (GADWebAppViewController *)webAppViewController;
- (BOOL)pendingOnShow;
- (BOOL)calledOnShow;
@end

@implementation GADWebAppWebViewDelegate

- (void)postOnShowEvent
{
    if ([self pendingOnShow] && ![self calledOnShow]) {
        [[[self webAppViewController] webView] notifyOfSdkEvent:@"onshow"];
        [self setPendingOnShow:NO];
        [self setCalledOnShow:YES];
    }
}

- (void)setPendingOnShow:(BOOL)pending
{
    _pendingOnShow = pending;
    if ([[[self webAppViewController] webView] didReceiveLoadEvent])
        [self postOnShowEvent];
}

- (void)setCalledOnShow:(BOOL)called
{
    _calledOnShow = called;
}

- (id)initWithWebAppViewController:(GADWebAppViewController *)controller
{
    self = [super init];
    if (self) {
        _webAppViewController = controller;
        [self addGMSGHandler:[[[GADWebAppGMSGHandler alloc] init] autorelease]];
        if ([_webAppViewController interstitial]) {
            GADSlot *slot = [[_webAppViewController interstitial] slot];
            [self addGMSGHandler:[[[GADAppEventGMSGHandler alloc] initWithSlot:slot] autorelease]];
        }
    }
    return self;
}

- (void)webViewDidStartLoad:(UIWebView *)view
{
    GADSlotStatistics *stats = [[[self webAppViewController] slot] slotStats];
    if (![stats timingNamed:kGADParameterPriorLandingPageLoad])
        [stats startTimingNamed:kGADParameterPriorLandingPageLoad withExplicitEnd:YES];
    [super webViewDidStartLoad:view];
}

- (void)webViewDidFinishLoad:(UIWebView *)view
{
    GADSlotStatistics *stats = [[[self webAppViewController] slot] slotStats];
    if (![stats timingNamed:kGADParameterPriorLandingPageDuration]) {
        [stats endTimingNamed:kGADParameterPriorLandingPageLoad];
        [stats startTimingNamed:kGADParameterPriorLandingPageDuration withExplicitEnd:YES];
    }
    [super webViewDidFinishLoad:view];
    [self postOnShowEvent];
}

@end
