#import <UIKit/UIKit.h>

extern NSString *const kGADParameterPriorClickLatency;
extern NSString *const kGADParameterPriorLandingPageLoad;
extern NSString *const kGADParameterPriorLandingPageDuration;

@interface GADSlotStatistics : NSObject
- (void)endTimingNamed:(NSString *)name;
- (id)timingNamed:(NSString *)name;
- (void)startTimingNamed:(NSString *)name withExplicitEnd:(BOOL)explicitEnd;
- (void)incrementPageNavigationCount;
- (void)incrementSSLPageNavigationCount;
@end

@class GADDelegateManager;

@interface GADSlot : NSObject
- (BOOL)isMRAID;
- (GADDelegateManager *)delegateManager;
- (GADSlotStatistics *)slotStats;
@end

@interface GADDelegateManager : NSObject
- (void)willLeaveApplication;
- (void)didDismissScreen;
- (void)willDismissScreen;
- (void)willPresentScreen;
@end

@interface GADDevice : NSObject
+ (BOOL)isOSAtLeastMajor:(NSInteger)major minor:(NSInteger)minor bug:(NSInteger)bug;
@end

@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end

typedef enum {
    GADOrientationAny = 1,
    GADOrientationPortrait = 2,
    GADOrientationLandscape = 3
} GADOrientation;

@interface GADViewController : UIViewController
@property(nonatomic, assign) BOOL viewDidAppear, statusBarWasHidden, publisherIdleTimerDisabled;
@property(nonatomic, assign) BOOL appClosing, interactingWithParent, wasPresentedFromViewController;
@property(nonatomic, retain) GADDelegateManager *delegateManager;
@property(nonatomic, assign) GADOrientation supportedOrientations;
@property(nonatomic, retain) GADSlot *slot;
@end

@implementation GADViewController
@synthesize viewDidAppear = _viewDidAppear, statusBarWasHidden = _statusBarWasHidden;
@synthesize publisherIdleTimerDisabled = _publisherIdleTimerDisabled, appClosing = _appClosing;
@synthesize interactingWithParent = _interactingWithParent, wasPresentedFromViewController = _wasPresentedFromViewController;
@synthesize delegateManager = _delegateManager, supportedOrientations = _supportedOrientations, slot = _slot;

- (BOOL)shouldDismissOnAppClose
{
    return YES;
}

- (GADDelegateManager *)delegateManager
{
    if (!_delegateManager) _delegateManager = [[GADDelegateManager alloc] init];
    return _delegateManager;
}

- (UIViewController *)parent
{
    if ([self respondsToSelector:@selector(presentingViewController)])
        return [self performSelector:@selector(presentingViewController)];
    return [self parentViewController];
}

- (void)setSupportedOrientations:(GADOrientation)orientations
{
    if (orientations) _supportedOrientations = orientations;
}

- (BOOL)isFirstGADViewController
{
    return ![[self parent] isKindOfClass:[GADViewController class]];
}

- (id)init
{
    self = [super init];
    if (self) {
        _supportedOrientations = GADOrientationAny;
        [self setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if ([self isFirstGADViewController]) [[self delegateManager] didDismissScreen];
    [_delegateManager release];
    [_slot release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self view] setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [[self view] setOpaque:YES];
    [[self view] setBackgroundColor:[UIColor blackColor]];
    [[self view] setClipsToBounds:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (![[self view] isUserInteractionEnabled]) {
        [super viewDidAppear:animated];
        [[self view] setUserInteractionEnabled:YES];
        if ([self isFirstGADViewController] && [self interactingWithParent]) [self setInteractingWithParent:NO];
    }
    [self setViewDidAppear:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    GADSlotStatistics *statistics = [[self slot] slotStats];
    [statistics endTimingNamed:kGADParameterPriorLandingPageDuration];
    [statistics endTimingNamed:kGADParameterPriorClickLatency];
    if ([self isFirstGADViewController] && [self interactingWithParent]) {
        [self setInteractingWithParent:NO];
        if ([self appClosing]) [[self delegateManager] willLeaveApplication];
    }
    [self setViewDidAppear:NO];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    switch ([self supportedOrientations]) {
        case GADOrientationPortrait: return orientation == UIInterfaceOrientationPortrait;
        case GADOrientationLandscape: return UIInterfaceOrientationIsLandscape(orientation);
        default: return YES;
    }
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    switch ([self supportedOrientations]) {
        case GADOrientationPortrait: return UIInterfaceOrientationMaskPortrait;
        case GADOrientationLandscape: return UIInterfaceOrientationMaskLandscape;
        default: return UIInterfaceOrientationMaskAll;
    }
}

- (void)restoreStatusBar
{
    if ([self statusBarWasHidden]) return;
    UIApplication *app = [UIApplication sharedApplication];
    if ([GADDevice isOSAtLeastMajor:3 minor:2 bug:0] && [self modalPresentationStyle] == UIModalPresentationFullScreen)
        [app setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
}

- (void)hideStatusBar
{
    UIApplication *app = [UIApplication sharedApplication];
    if ([GADDevice isOSAtLeastMajor:3 minor:2 bug:0] && [self modalPresentationStyle] == UIModalPresentationFullScreen) {
        [self setStatusBarWasHidden:[app isStatusBarHidden]];
        if (![self statusBarWasHidden]) [app setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
    }
}

- (void)ensureStatusBarHidden
{
    BOOL previous = [self statusBarWasHidden];
    [self hideStatusBar];
    [self setStatusBarWasHidden:previous];
}

- (void)appDidEnterForeground:(NSNotification *)note
{
    if (![self shouldDismissOnAppClose]) {
        [self ensureStatusBarHidden];
    } else if (![self isFirstGADViewController] && [(GADViewController *)[self parent] shouldDismissOnAppClose]) {
        [self autorelease];
    } else {
        [self performSelector:@selector(relinquishScreen) withObject:nil afterDelay:0];
    }
}

- (void)presentSelfFrom:(UIViewController *)controller
{
    if (!controller) return;
    if ([controller respondsToSelector:@selector(presentViewController:animated:completion:)])
        [controller presentViewController:self animated:YES completion:nil];
    else
        [controller presentModalViewController:self animated:YES];
    [self performSelector:@selector(viewDidAppear:) withObject:nil afterDelay:0.6];
}

- (void)presentFromViewController:(UIViewController *)controller
{
    if (!controller) {
        [GADMacros pubLog:[NSString stringWithFormat:@"No UIViewController supplied to the ad.  Cannot continue."]];
        return;
    }
    [[self view] setUserInteractionEnabled:NO];
    if ([GADDevice isOSAtLeastMajor:4 minor:0 bug:0])
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification object:nil];
    [self retain];
    [self setWasPresentedFromViewController:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kAdModalViewControllerWillPresentFullScreen" object:self];
    if (![controller isKindOfClass:[GADViewController class]]) {
        [self setInteractingWithParent:YES];
        [[self delegateManager] willPresentScreen];
        [self hideStatusBar];
        UIApplication *app = [UIApplication sharedApplication];
        [self setPublisherIdleTimerDisabled:[app isIdleTimerDisabled]];
        [app setIdleTimerDisabled:YES];
        [self presentSelfFrom:controller];
    } else {
        [self setInteractingWithParent:NO];
        if ([controller respondsToSelector:@selector(presentViewController:animated:completion:)])
            [controller presentViewController:self animated:YES completion:nil];
        else
            [controller presentModalViewController:self animated:YES];
    }
}

- (void)relinquishScreen
{
    [[self view] setUserInteractionEnabled:NO];
    if ([self wasPresentedFromViewController]) {
        [self autorelease];
        [self setWasPresentedFromViewController:NO];
    }
    if ([self isFirstGADViewController]) {
        [self setInteractingWithParent:YES];
        [[self delegateManager] willDismissScreen];
        [self restoreStatusBar];
        [[UIApplication sharedApplication] setIdleTimerDisabled:[self publisherIdleTimerDisabled]];
    } else {
        [self setInteractingWithParent:NO];
    }
    SEL dismiss = @selector(dismissViewControllerAnimated:completion:);
    if ([[self parent] respondsToSelector:dismiss])
        [[self parent] dismissViewControllerAnimated:YES completion:nil];
    else
        [[self parent] dismissModalViewControllerAnimated:YES];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kAdModalViewControllerDidDismissFullScreen" object:self];
}
@end

@interface GADBrowserController : GADViewController
- (void)refreshToolbar;
@end

@interface GADWebView : UIWebView
@property(nonatomic, assign) UIViewController *viewController;
- (void)saveState;
- (void)restoreState;
- (void)reset;
- (void)notifyOfSdkEvent:(NSString *)event;
- (void)didRotateToOrientation:(UIInterfaceOrientation)orientation;
- (void)forceRotateToOrientation:(UIInterfaceOrientation)orientation;
@end

@interface GADBrowserWebView : GADWebView
- (GADBrowserController *)gadBrowserController;
@end

@class GADOpener;

@interface GADWebViewDelegate : NSObject <UIWebViewDelegate>
- (GADOpener *)opener;
- (BOOL)allowFileAccess;
- (void)setAllowFileAccess:(BOOL)value;
- (BOOL)hasLoadedAtLeastOnce;
@end

@interface GADBrowserWebViewDelegate : GADWebViewDelegate
@end

@implementation GADBrowserWebViewDelegate
- (GADBrowserController *)browserControllerForWebView:(UIWebView *)webView
{
    if ([webView isKindOfClass:[GADBrowserWebView class]]) return [(GADBrowserWebView *)webView gadBrowserController];
    return nil;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type
{
    GADBrowserController *browser = [self browserControllerForWebView:webView];
    if (browser && (type == UIWebViewNavigationTypeLinkClicked || type == UIWebViewNavigationTypeFormSubmitted)) {
        NSString *scheme = [[[request URL] scheme] lowercaseString];
        if ([scheme isEqualToString:@"http"]) [[[browser slot] slotStats] incrementPageNavigationCount];
        else if ([scheme isEqualToString:@"https"]) [[[browser slot] slotStats] incrementSSLPageNavigationCount];
    }
    return [super webView:webView shouldStartLoadWithRequest:request navigationType:type];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    GADBrowserController *browser = [self browserControllerForWebView:webView];
    if (browser) {
        GADSlotStatistics *stats = [[browser slot] slotStats];
        if (![stats timingNamed:kGADParameterPriorLandingPageLoad])
            [stats startTimingNamed:kGADParameterPriorLandingPageLoad withExplicitEnd:YES];
    }
    [super webViewDidStartLoad:webView];
    if (browser) [browser refreshToolbar];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    GADBrowserController *browser = [self browserControllerForWebView:webView];
    if (browser) {
        GADSlotStatistics *stats = [[browser slot] slotStats];
        if (![stats timingNamed:kGADParameterPriorLandingPageDuration]) {
            [stats endTimingNamed:kGADParameterPriorLandingPageLoad];
            [stats startTimingNamed:kGADParameterPriorLandingPageDuration withExplicitEnd:YES];
        }
    }
    [super webViewDidFinishLoad:webView];
    if (browser) [browser refreshToolbar];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    [super webView:webView didFailLoadWithError:error];
    GADBrowserController *browser = [self browserControllerForWebView:webView];
    if (browser) [browser refreshToolbar];
}
@end

@class GADWebAppViewController, GADInterstitial;

@interface GADOpener : NSObject
@property(nonatomic, assign) GADSlot *slot;
@property(nonatomic, retain) GADDelegateManager *delegateManager;
@property(nonatomic, assign) BOOL didOpenAnotherApplication;
@end

@interface GADIntrinsicImages : NSObject
+ (GADIntrinsicImages *)sharedInstance;
+ (UIImage *)screenshotOfView:(UIView *)view;
- (UIImage *)closeButton;
@end

@interface GADWebAppWebViewDelegate : GADWebViewDelegate
- (id)initWithWebAppViewController:(GADWebAppViewController *)controller;
- (void)setPendingOnShow:(BOOL)value;
@end

@interface GADWebAppViewController : GADViewController
@property(nonatomic, assign) BOOL useCustomClose, viewHasAppeared, isExpandable, isCollapsing;
@property(nonatomic, retain) GADWebView *webView;
@property(nonatomic, retain) UIImageView *bannerScreenshot;
@property(nonatomic, retain) NSURL *URLToLoad, *HTMLBaseURLToLoad;
@property(nonatomic, retain) NSString *HTMLToLoad;
@property(nonatomic, retain) GADWebAppWebViewDelegate *webViewDelegate;
@property(nonatomic, retain) UIButton *closeButton;
@property(nonatomic, assign) GADInterstitial *interstitial;
@end

@implementation GADWebAppViewController
@synthesize useCustomClose = _useCustomClose, viewHasAppeared = _viewHasAppeared, isExpandable = _isExpandable, isCollapsing = _isCollapsing;
@synthesize webView = _webView, bannerScreenshot = _bannerScreenshot, URLToLoad = _URLToLoad;
@synthesize HTMLToLoad = _HTMLToLoad, HTMLBaseURLToLoad = _HTMLBaseURLToLoad, webViewDelegate = _webViewDelegate;
@synthesize closeButton = _closeButton, interstitial = _interstitial;

- (BOOL)allowFileAccess
{
    return [(GADWebViewDelegate *)[[self webView] delegate] allowFileAccess];
}

- (void)setAllowFileAccess:(BOOL)allow
{
    [(GADWebViewDelegate *)[[self webView] delegate] setAllowFileAccess:allow];
}

- (void)setUseCustomClose:(BOOL)custom
{
    if (custom) {
        [[self closeButton] setImage:nil forState:UIControlStateNormal];
    } else {
        UIImage *image = [[GADIntrinsicImages sharedInstance] closeButton];
        [[self closeButton] setImage:image forState:UIControlStateNormal];
    }
    _useCustomClose = custom;
}

- (BOOL)shouldDismissOnAppClose
{
    if (([[self webViewDelegate] hasLoadedAtLeastOnce] || [self isExpandable]) &&
        [[[self webViewDelegate] opener] didOpenAnotherApplication]) {
        [[[self webViewDelegate] opener] setDidOpenAnotherApplication:NO];
        return NO;
    }
    return [super shouldDismissOnAppClose];
}

- (void)relinquishScreen
{
    [[self webView] notifyOfSdkEvent:@"onhide"];
    if ([self isExpandable]) {
        [self setIsCollapsing:YES];
        [[self webView] restoreState];
    }
    [super relinquishScreen];
}

- (id)init
{
    return [self initWithWebView:nil forInterstitial:nil];
}

- (id)initWithWebView:(GADWebView *)webView
{
    return [self initWithWebView:webView forInterstitial:nil];
}

- (id)initWithWebView:(GADWebView *)webView forInterstitial:(GADInterstitial *)interstitial
{
    self = [super init];
    if (self) {
        if (webView) {
            [self setIsExpandable:YES];
        } else {
            webView = [[[GADWebView alloc] initWithFrame:[[self view] bounds]] autorelease];
            [webView setViewController:self];
        }
        _interstitial = interstitial;
        _webView = [webView retain];
    }
    return self;
}

- (void)dealloc
{
    if ([_webView viewController] == self) [_webView setViewController:nil];
    [[_webViewDelegate opener] setSlot:nil];
    [[_webViewDelegate opener] setDelegateManager:nil];
    if ([_webView delegate] == _webViewDelegate) [_webView setDelegate:nil];
    [_webViewDelegate release];
    [_webView release];
    [_bannerScreenshot removeFromSuperview];
    [_bannerScreenshot release];
    [_URLToLoad release];
    [_HTMLBaseURLToLoad release];
    [_HTMLToLoad release];
    [_closeButton release];
    [super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self viewHasAppeared]) return;
    [self setViewHasAppeared:YES];
    if ([self isExpandable]) {
        [[self webView] saveState];
        [[self webView] setViewController:self];
        [self setBannerScreenshot:[[[UIImageView alloc] initWithFrame:[[self webView] frame]] autorelease]];
        [[self bannerScreenshot] setImage:[GADIntrinsicImages screenshotOfView:[self webView]]];
        [[[self webView] superview] addSubview:[self bannerScreenshot]];
        [[self webView] removeFromSuperview];
        [[self webView] reset];
        [[self webView] notifyOfSdkEvent:@"expanding"];
    }
    CGRect bounds = [[self view] bounds];
    [[self webView] setFrame:bounds];
    [[self webView] setHidden:NO];
    [[self view] addSubview:[self webView]];
    [self setWebViewDelegate:[[[GADWebAppWebViewDelegate alloc] initWithWebAppViewController:self] autorelease]];
    [[[self webViewDelegate] opener] setSlot:[self slot]];
    [[[self webViewDelegate] opener] setDelegateManager:[[self slot] delegateManager]];
    [[self webViewDelegate] setAllowFileAccess:[self allowFileAccess]];
    [[self webView] setDelegate:[self webViewDelegate]];
    if ([self URLToLoad]) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[self URLToLoad]];
        [[self webView] loadRequest:request];
        [self setURLToLoad:nil];
    } else if ([self HTMLToLoad]) {
        [[self webView] loadHTMLString:[self HTMLToLoad] baseURL:[self HTMLBaseURLToLoad]];
        [self setHTMLToLoad:nil];
        [self setHTMLBaseURLToLoad:nil];
    }
    UIImage *close = [[GADIntrinsicImages sharedInstance] closeButton];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setImage:close forState:UIControlStateNormal];
    [button setShowsTouchWhenHighlighted:YES];
    [button setEnabled:YES];
    [button setAccessibilityLabel:@"Close Advertisement"];
    CGRect frame = CGRectMake(0, 0, 32, 32);
    if ([[self slot] isMRAID]) frame = CGRectMake(bounds.size.width - 50, 0, 50, 50);
    [button setFrame:frame];
    [button addTarget:self action:@selector(relinquishScreen) forControlEvents:UIControlEventTouchUpInside];
    [[self view] addSubview:button];
    [self setCloseButton:button];
    if ([self useCustomClose]) [button setImage:nil forState:UIControlStateNormal];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[self webView] forceRotateToOrientation:[self interfaceOrientation]];
    [[self webViewDelegate] setPendingOnShow:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if ([self isCollapsing]) [[self webView] notifyOfSdkEvent:@"collapsed"];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)orientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:orientation duration:duration];
    if ([[self slot] isMRAID]) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        [UIView setAnimationDelegate:self];
        [[self closeButton] setHidden:YES];
        [UIView commitAnimations];
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    [super didRotateFromInterfaceOrientation:orientation];
    if ([[self slot] isMRAID]) {
        CGRect frame = [[self closeButton] frame];
        frame.origin.x = [[self webView] frame].size.width - 50;
        [[self closeButton] setFrame:frame];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        [UIView setAnimationDelegate:self];
        [[self closeButton] setHidden:NO];
        [UIView commitAnimations];
    }
    [[self webView] didRotateToOrientation:[self interfaceOrientation]];
}

- (void)load:(NSURL *)url
{
    if (!url) return;
    if ([self webView]) [[self webView] loadRequest:[NSURLRequest requestWithURL:url]];
    else [self setURLToLoad:url];
}

- (void)loadHTML:(NSString *)html baseURL:(NSURL *)url
{
    if (!html) return;
    if ([self webView]) [[self webView] loadHTMLString:html baseURL:url];
    else {
        [self setHTMLToLoad:html];
        [self setHTMLBaseURLToLoad:url];
    }
}
@end
