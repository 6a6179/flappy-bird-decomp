#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <StoreKit/StoreKit.h>

typedef enum {
    GADOrientationAny = 1,
    GADOrientationPortrait = 2,
    GADOrientationLandscape = 3
} GADOrientation;

@interface GADSlotStatistics : NSObject
- (NSURL *)updateStatsAndReturnSpamClickURL:(NSURL *)url;
- (void)setClickBackgroundedApp;
- (void)setBreakOutToSafari;
@end

@interface GADSlot : NSObject
- (NSArray *)pendingClickURLs;
- (GADSlotStatistics *)slotStats;
- (NSString *)adUnitID;
@end

@interface GADClickTrackerCollection : NSObject
+ (GADClickTrackerCollection *)sharedInstance;
- (void)trackURLs:(NSArray *)urls;
- (void)trackURL:(NSURL *)url;
@end

@interface GADDevice : NSObject
+ (GADDevice *)currentDevice;
- (BOOL)isOrientationLandscape;
+ (BOOL)isOSAtLeastMajor:(NSInteger)major minor:(NSInteger)minor bug:(NSInteger)bug;
@end

@interface GADInAppPurchase : NSObject
+ (BOOL)quantityIsValid:(NSUInteger)quantity;
- (void)setProductID:(NSString *)product;
- (void)setQuantity:(NSUInteger)quantity;
@end

@interface GADDelegateManager : NSObject
- (void)didReceiveInAppPurchase:(GADInAppPurchase *)purchase;
- (void)willLeaveApplication;
@end

@interface GADViewController : UIViewController
- (GADSlot *)slot;
- (GADDelegateManager *)delegateManager;
- (BOOL)viewDidAppear;
- (void)relinquishScreen;
- (void)setSupportedOrientations:(GADOrientation)orientations;
- (void)setSlot:(GADSlot *)slot;
- (void)setDelegateManager:(GADDelegateManager *)manager;
- (void)presentFromViewController:(UIViewController *)controller;
@end

@class GADBrowserController;

@interface GADWebView : UIWebView
@end

@interface GADBrowserWebView : GADWebView
- (void)setViewController:(GADBrowserController *)controller;
- (void)setShowDebug:(BOOL)show;
- (void)didRotateToOrientation:(UIInterfaceOrientation)orientation;
@end

@interface GADWebViewDelegate : NSObject <UIWebViewDelegate>
@end

@interface GADBrowserWebViewDelegate : GADWebViewDelegate
@end

@interface GADIntrinsicImages : NSObject
+ (GADIntrinsicImages *)sharedInstance;
- (UIImage *)browserBackButton;
- (UIImage *)browserForwardButton;
@end

@interface GADBrowserController : GADViewController
@property(nonatomic, retain) NSURL *URLToLoad, *referringURLToLoad;
@property(nonatomic, retain) GADBrowserWebViewDelegate *webViewDelegate;
@property(nonatomic, retain) GADBrowserWebView *webView;
@property(nonatomic, retain) UIToolbar *toolbar;
@property(nonatomic, retain) UIBarButtonItem *flexibleSpaceButton, *backButton, *backButtonDisabled;
@property(nonatomic, retain) UIBarButtonItem *forwardButton, *forwardButtonDisabled, *reloadButton;
@property(nonatomic, retain) UIBarButtonItem *safariButton, *doneButton, *spinnerContainingButton;
@property(nonatomic, retain) UIActivityIndicatorView *spinner;
- (void)load:(NSURL *)url referringURL:(NSURL *)referrer;
@end

@interface GADWebAppViewController : GADViewController
- (id)initWithWebView:(GADWebView *)webView;
- (void)setUseCustomClose:(BOOL)custom;
- (void)load:(NSURL *)url;
- (void)loadHTML:(NSString *)html baseURL:(NSURL *)url;
@end

@interface GADNetworkUtilities : NSObject
+ (NSDictionary *)dictionaryFromQueryString:(NSString *)query withLowercaseKeys:(BOOL)lowercase;
@end

@interface GADPublisherToolbarController : GADViewController
- (id)initWithAdContent:(id)content adUnitID:(NSString *)unit;
@end

@protocol GADOpenerDelegate
- (void)didLeaveApplication;
- (void)didOpenInApplication;
@end

@interface GADOpener : NSObject <MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate,
                                 SKStoreProductViewControllerDelegate> {
    GADDelegateManager *delegateManager_;
    UIViewController *viewController_;
    NSURL *referringURL_;
    GADWebView *webView_;
    GADSlot *slot_;
    BOOL didOpenAnotherApplication_;
    id<GADOpenerDelegate> delegate_;
}
@property(nonatomic, retain) GADDelegateManager *delegateManager;
@property(nonatomic, assign) UIViewController *viewController;
@property(nonatomic, retain) NSURL *referringURL;
@property(nonatomic, assign) GADWebView *webView;
@property(nonatomic, assign) GADSlot *slot;
@property(nonatomic, assign) BOOL didOpenAnotherApplication;
@property(nonatomic, assign) id<GADOpenerDelegate> delegate;
@end

@implementation GADOpener
@synthesize delegateManager = delegateManager_, viewController = viewController_, referringURL = referringURL_;
@synthesize webView = webView_, slot = slot_, didOpenAnotherApplication = didOpenAnotherApplication_, delegate = delegate_;

- (void)dealloc
{
    [delegateManager_ release];
    [referringURL_ release];
    [super dealloc];
}

- (BOOL)checkStateWithParamter:(id)parameter
{
    return [self viewController] && parameter;
}

- (void)didOpen
{
    NSArray *urls = [[self slot] pendingClickURLs];
    [[GADClickTrackerCollection sharedInstance] trackURLs:urls];
}

- (void)didOpenExternalApp
{
    [self didOpen];
    [[self delegate] didLeaveApplication];
}

- (void)didOpenInApp
{
    [self didOpen];
    [[self delegate] didOpenInApplication];
}

- (void)openInAppStore:(NSString *)identifier fallbackURLString:(NSURL *)url
{
    if (![self isInAppStoreSupported]) {
        [self openApp:url];
        return;
    }
    SKStoreProductViewController *product = [[[SKStoreProductViewController alloc] init] autorelease];
    [product setDelegate:self];
    NSDictionary *parameters = @{SKStoreProductParameterITunesItemIdentifier : @([identifier integerValue])};
    [product loadProductWithParameters:parameters completionBlock:^(BOOL loaded, NSError *error) {
        if (loaded) {
            if ([self viewController] && ![[self viewController] isBeingDismissed]) {
                [[self viewController] presentViewController:product animated:YES completion:nil];
                [self didOpenInApp];
            }
        } else {
            [self openApp:url];
        }
    }];
}

- (void)openInAppPurchase:(NSString *)product quantity:(NSUInteger)quantity
{
    GADInAppPurchase *purchase = [[[GADInAppPurchase alloc] init] autorelease];
    [purchase setProductID:product];
    [purchase setQuantity:quantity];
    [[self delegateManager] didReceiveInAppPurchase:purchase];
    [self didOpenInApp];
    if ([[self viewController] isKindOfClass:[GADViewController class]])
        [(GADViewController *)viewController_ relinquishScreen];
}

- (void)openBrowserToURL:(NSURL *)url supportedOrientations:(GADOrientation)orientations
{
    if (![self checkStateWithParamter:url]) return;
    GADBrowserController *browser = [[GADBrowserController alloc] init];
    [browser setSupportedOrientations:orientations];
    [browser setSlot:slot_];
    [browser load:url referringURL:referringURL_];
    [browser setDelegateManager:[self delegateManager]];
    [browser presentFromViewController:[self viewController]];
    [browser release];
    [self didOpenInApp];
}

- (GADWebAppViewController *)overlayWithWebView:(GADWebView *)webView orientations:(GADOrientation)orientations
                               usingCustomClose:(BOOL)custom
{
    GADWebAppViewController *overlay = [[GADWebAppViewController alloc] initWithWebView:webView];
    [overlay setSupportedOrientations:orientations];
    [overlay setDelegateManager:[self delegateManager]];
    [overlay setSlot:[self slot]];
    [overlay setUseCustomClose:custom];
    return [overlay autorelease];
}

- (void)openWebApp:(NSURL *)url supportedOrientations:(GADOrientation)orientations usingCustomClose:(BOOL)custom
{
    if (![self checkStateWithParamter:url]) return;
    GADWebAppViewController *overlay = [self overlayWithWebView:nil orientations:orientations usingCustomClose:custom];
    [overlay load:url];
    [overlay presentFromViewController:[self viewController]];
    [self didOpenInApp];
}

- (void)openWebAppWithHTML:(NSString *)html supportedOrientations:(GADOrientation)orientations usingCustomClose:(BOOL)custom
{
    if (![self checkStateWithParamter:html]) return;
    GADWebAppViewController *overlay = [self overlayWithWebView:nil orientations:orientations usingCustomClose:custom];
    [overlay loadHTML:html baseURL:nil];
    [overlay presentFromViewController:[self viewController]];
    [self didOpenInApp];
}

- (void)expandToWebAppWithSupportedOrientations:(GADOrientation)orientations usingCustomClose:(BOOL)custom
{
    if (![self checkStateWithParamter:webView_] || [[self viewController] isKindOfClass:[GADViewController class]]) return;
    GADWebAppViewController *overlay = [self overlayWithWebView:webView_ orientations:orientations usingCustomClose:custom];
    [overlay presentFromViewController:[self viewController]];
    [self didOpenInApp];
}

- (void)openApp:(NSURL *)url
{
    if (!url) return;
    [self didOpenExternalApp];
    [[self delegateManager] willLeaveApplication];
    didOpenAnotherApplication_ = YES;
    [[[self slot] slotStats] setClickBackgroundedApp];
    [[UIApplication sharedApplication] performSelector:@selector(openURL:) withObject:url afterDelay:0];
}

- (void)presentComposerController:(UIViewController *)composer
{
    if (!composer) return;
    if ([[viewController_ class] isSubclassOfClass:[GADViewController class]] && ![(GADViewController *)viewController_ viewDidAppear]) {
        [self performSelector:@selector(presentComposerController:) withObject:composer afterDelay:0.25];
        return;
    }
    BOOL hidden = [[UIApplication sharedApplication] isStatusBarHidden] && [GADDevice isOSAtLeastMajor:5 minor:0 bug:0];
    if ([viewController_ respondsToSelector:@selector(presentViewController:animated:completion:)])
        [viewController_ presentViewController:composer animated:YES completion:nil];
    else
        [viewController_ presentModalViewController:composer animated:YES];
    if (hidden) [[UIApplication sharedApplication] setStatusBarHidden:YES];
}

- (void)openEmailComposer:(NSURL *)url
{
    if (![self checkStateWithParamter:url]) return;
    NSString *recipient = [[url absoluteString] substringFromIndex:[@"mailto:" length]];
    NSUInteger query = [recipient rangeOfString:@"?"].location;
    NSDictionary *parameters = nil;
    if (query != NSNotFound) {
        NSString *full = recipient;
        recipient = [full substringToIndex:query];
        NSString *queryString = [full substringFromIndex:query + 1];
        parameters = [GADNetworkUtilities dictionaryFromQueryString:queryString withLowercaseKeys:YES];
    }
    MFMailComposeViewController *composer = [[MFMailComposeViewController alloc] init];
    [composer setMailComposeDelegate:self];
    [composer setToRecipients:[NSArray arrayWithObject:recipient]];
    [composer setCcRecipients:[[parameters objectForKey:@"cc"] componentsSeparatedByString:@","]];
    [composer setBccRecipients:[[parameters objectForKey:@"bcc"] componentsSeparatedByString:@","]];
    [composer setSubject:[parameters objectForKey:@"subject"]];
    [composer setMessageBody:[parameters objectForKey:@"body"] isHTML:NO];
    [composer setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    if (composer) [self presentComposerController:composer];
    [composer release];
    [self didOpenExternalApp];
}

- (void)openSmsComposer:(NSURL *)url
{
    if (![self checkStateWithParamter:url] || ![GADDevice isOSAtLeastMajor:4 minor:0 bug:0] ||
        ![MFMessageComposeViewController canSendText]) return;
    NSString *recipient = [[url absoluteString] substringFromIndex:[@"sms:" length]];
    NSUInteger query = [recipient rangeOfString:@"?"].location;
    NSDictionary *parameters = nil;
    if (query != NSNotFound) {
        NSString *full = recipient;
        recipient = [full substringToIndex:query];
        NSString *queryString = [full substringFromIndex:query + 1];
        parameters = [GADNetworkUtilities dictionaryFromQueryString:queryString withLowercaseKeys:YES];
    }
    MFMessageComposeViewController *composer = [[MFMessageComposeViewController alloc] init];
    [composer setMessageComposeDelegate:self];
    [composer setRecipients:[recipient componentsSeparatedByString:@","]];
    [composer setBody:[parameters objectForKey:@"body"]];
    [composer setModalTransitionStyle:UIModalTransitionStyleCoverVertical];
    [self presentComposerController:composer];
    [composer release];
    [self didOpenExternalApp];
}

- (void)openPublisherToolbar:(NSString *)unit withAdContent:(id)content
{
    if (!unit && [slot_ adUnitID]) unit = [slot_ adUnitID];
    GADPublisherToolbarController *toolbar = [[[GADPublisherToolbarController alloc] initWithAdContent:content adUnitID:unit] autorelease];
    UIViewController *presented = nil;
    if ([viewController_ respondsToSelector:@selector(presentedViewController)])
        presented = [viewController_ presentedViewController];
    else if ([viewController_ respondsToSelector:@selector(modalViewController)])
        presented = [viewController_ modalViewController];
    if (presented) {
        if ([viewController_ respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
            [viewController_ dismissViewControllerAnimated:YES completion:^{
                [toolbar presentFromViewController:[self viewController]];
            }];
            return;
        }
        [viewController_ dismissModalViewControllerAnimated:NO];
    }
    [toolbar presentFromViewController:[self viewController]];
}

- (void)mailComposeController:(MFMailComposeViewController *)composer didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    if ([viewController_ respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        [viewController_ dismissViewControllerAnimated:YES completion:nil];
    else
        [viewController_ dismissModalViewControllerAnimated:YES];
    [viewController_ becomeFirstResponder];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)composer didFinishWithResult:(MessageComposeResult)result
{
    if ([viewController_ respondsToSelector:@selector(dismissViewControllerAnimated:completion:)])
        [viewController_ dismissViewControllerAnimated:YES completion:nil];
    else
        [viewController_ dismissModalViewControllerAnimated:YES];
    [viewController_ becomeFirstResponder];
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)product
{
    [[self viewController] dismissViewControllerAnimated:YES completion:nil];
    [viewController_ becomeFirstResponder];
}

- (BOOL)isInAppStoreSupported
{
    return NSClassFromString(@"SKStoreProductViewController") != Nil;
}
@end

extern NSString *const kGADGMSGHandlerParamNotification;
extern NSString *const kGADGMSGURLActionClick;
extern NSString *const kGADGMSGURLActionOpen;
extern NSString *const kGADGMSGURLParamURL;
extern NSString *const kGADGMSGURLParamCustomClose;
extern NSString *const kGADGMSGURLParamCustomCloseValueTrue;

@interface GADNotification : NSObject
- (NSDictionary *)parameters;
@end

@interface GADActionRouter : NSObject
- (id)initWithReceiver:(id)receiver;
- (void)addSelector:(SEL)selector name:(NSString *)name;
- (NSUInteger)postNotificationName:(NSString *)name arguments:(NSDictionary *)arguments;
@end

@interface GADGMSGHandler : NSObject
- (void)addSelector:(SEL)selector forGMSGActionName:(NSString *)name;
@end

@interface GADOpenerGMSGHandler : GADGMSGHandler {
    GADOpener *_gadOpener;
    GADActionRouter *_subParamActionRouter;
}
@property(nonatomic, retain) GADOpener *gadOpener;
@property(nonatomic, retain) GADActionRouter *subParamActionRouter;
@end

@implementation GADOpenerGMSGHandler
@synthesize gadOpener = _gadOpener, subParamActionRouter = _subParamActionRouter;

- (id)initWithOpener:(GADOpener *)opener
{
    self = [super init];
    if (self) {
        _gadOpener = [opener retain];
        _subParamActionRouter = [[GADActionRouter alloc] initWithReceiver:self];
        [self addSelector:@selector(didReceiveClickNotification:) forGMSGActionName:kGADGMSGURLActionClick];
        [self addSelector:@selector(didReceiveOpenNotification:) forGMSGActionName:kGADGMSGURLActionOpen];
        [_subParamActionRouter addSelector:@selector(actionOpenInAppStore:) name:@"in_app_store"];
        [_subParamActionRouter addSelector:@selector(actionOpenInAppPurchase:) name:@"in_app_purchase"];
        [_subParamActionRouter addSelector:@selector(actionOpenBrowser:) name:@"browser"];
        [_subParamActionRouter addSelector:@selector(actionOpenWebApp:) name:@"webapp"];
        [_subParamActionRouter addSelector:@selector(actionExpand:) name:@"expand"];
        [_subParamActionRouter addSelector:@selector(actionOpenBrowser:) name:@"video"];
        [_subParamActionRouter addSelector:@selector(actionOpenApp:) name:@"call"];
        [_subParamActionRouter addSelector:@selector(actionOpenApp:) name:@"app"];
    }
    return self;
}

- (void)dealloc
{
    [_gadOpener release];
    [_subParamActionRouter release];
    [super dealloc];
}

- (void)didReceiveClickNotification:(NSDictionary *)args
{
    GADNotification *note = [args objectForKey:kGADGMSGHandlerParamNotification];
    NSURL *url = [NSURL URLWithString:[[note parameters] objectForKey:kGADGMSGURLParamURL]];
    url = [[[[self gadOpener] slot] slotStats] updateStatsAndReturnSpamClickURL:url];
    [[GADClickTrackerCollection sharedInstance] trackURL:url];
}

- (void)didReceiveOpenNotification:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    NSString *action = [params objectForKey:@"a"];
    if (![[self subParamActionRouter] postNotificationName:action arguments:args]) [self actionOpenApp:args];
}

- (void)actionOpenInAppStore:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    NSString *product = [params objectForKey:@"product_id"];
    NSString *text = [params objectForKey:@"u"];
    NSURL *url = [text length] ? [NSURL URLWithString:text] : nil;
    if ([[self gadOpener] isInAppStoreSupported])
        [[self gadOpener] openInAppStore:product fallbackURLString:url];
    else
        [[self gadOpener] openApp:url];
}

- (void)actionOpenInAppPurchase:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    NSString *product = [params objectForKey:@"product_id"];
    if (product) {
        NSInteger quantity = [[params objectForKey:@"quantity"] integerValue];
        if ([GADInAppPurchase quantityIsValid:quantity]) [[self gadOpener] openInAppPurchase:product quantity:quantity];
    }
}

- (void)actionOpenBrowser:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    NSURL *url = [self urlFromParams:params];
    if (url) [[self gadOpener] openBrowserToURL:url supportedOrientations:[self orientationFromParams:params]];
}

- (void)actionOpenWebApp:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    NSString *html = [params objectForKey:@"html"];
    NSURL *url = [self urlFromParams:params];
    if (url) {
        [[self gadOpener] openWebApp:url supportedOrientations:[self orientationFromParams:params]
                    usingCustomClose:[self shouldUseCustomClose:params]];
    } else if (html) {
        [[self gadOpener] openWebAppWithHTML:html supportedOrientations:[self orientationFromParams:params]
                            usingCustomClose:[self shouldUseCustomClose:params]];
    }
}

- (void)actionExpand:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    [[self gadOpener] expandToWebAppWithSupportedOrientations:[self orientationFromParams:params]
                                            usingCustomClose:[self shouldUseCustomClose:params]];
}

- (void)actionOpenApp:(NSDictionary *)args
{
    NSDictionary *params = [[args objectForKey:kGADGMSGHandlerParamNotification] parameters];
    NSURL *url = [self urlFromParams:params];
    if (url) [[self gadOpener] openApp:url];
}

- (NSURL *)urlFromParams:(NSDictionary *)params
{
    NSString *url = [params objectForKey:@"u"];
    return url ? [NSURL URLWithString:url] : nil;
}

- (GADOrientation)orientationFromParams:(NSDictionary *)params
{
    NSString *value = [params objectForKey:@"o"];
    if (!value) return GADOrientationAny;
    if ([value isEqualToString:@"p"]) return GADOrientationPortrait;
    if (![value isEqualToString:@"l"]) return GADOrientationAny;
    return GADOrientationLandscape;
}

- (BOOL)shouldUseCustomClose:(NSDictionary *)params
{
    return [[params objectForKey:kGADGMSGURLParamCustomClose] isEqualToString:kGADGMSGURLParamCustomCloseValueTrue];
}
@end

@implementation GADBrowserController
@synthesize URLToLoad = _URLToLoad, referringURLToLoad = _referringURLToLoad;
@synthesize webViewDelegate = _webViewDelegate, webView = _webView, toolbar = _toolbar;
@synthesize flexibleSpaceButton = _flexibleSpaceButton, backButton = _backButton, backButtonDisabled = _backButtonDisabled;
@synthesize forwardButton = _forwardButton, forwardButtonDisabled = _forwardButtonDisabled, reloadButton = _reloadButton;
@synthesize safariButton = _safariButton, doneButton = _doneButton, spinnerContainingButton = _spinnerContainingButton;
@synthesize spinner = _spinner;

- (void)dealloc
{
    [_webView setDelegate:nil];
    [_webViewDelegate release];
    [_webView release];
    [_URLToLoad release];
    [_referringURLToLoad release];
    [_toolbar release];
    [_flexibleSpaceButton release];
    [_backButton release];
    [_backButtonDisabled release];
    [_forwardButton release];
    [_forwardButtonDisabled release];
    [_reloadButton release];
    [_safariButton release];
    [_doneButton release];
    [_spinnerContainingButton release];
    [_spinner release];
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[self view] setBackgroundColor:[UIColor whiteColor]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self webView]) return;


    CGFloat toolbarHeight;
    UIViewAutoresizing webMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        toolbarHeight = 44;
    } else if ([[GADDevice currentDevice] isOrientationLandscape]) {
        toolbarHeight = 30;
        webMask |= UIViewAutoresizingFlexibleBottomMargin;
    } else {
        toolbarHeight = 44;
    }
    CGSize bounds = [[self view] bounds].size;
    CGFloat webHeight = bounds.height - toolbarHeight + 1;
    [self setWebView:[[[GADBrowserWebView alloc] initWithFrame:CGRectMake(0, 0, bounds.width, webHeight)] autorelease]];
    [[self webView] setViewController:self];
    [[self webView] setShowDebug:NO];
    [[self webView] setAutoresizingMask:webMask];
    [[self view] addSubview:[self webView]];
    [[self webView] setDataDetectorTypes:UIDataDetectorTypeAll];
    [self setWebViewDelegate:[[[GADBrowserWebViewDelegate alloc] init] autorelease]];
    [self setSlot:[self slot]];
    [[self webView] setDelegate:[self webViewDelegate]];

    if ([self URLToLoad]) {
        [self load:[self URLToLoad] referringURL:[self referringURLToLoad]];
        [self setURLToLoad:nil];
        [self setReferringURLToLoad:nil];
    }

    [self setToolbar:[[[UIToolbar alloc] initWithFrame:CGRectMake(0, webHeight, bounds.width, toolbarHeight)] autorelease]];
    [[self toolbar] setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin];
    [[self toolbar] setAutoresizesSubviews:YES];
    [[self toolbar] setTintColor:[UIColor blackColor]];
    [[self view] addSubview:[self toolbar]];
    [self createToolbarButtons];
    [self refreshToolbar];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    [super didRotateFromInterfaceOrientation:orientation];
    [[self webView] didRotateToOrientation:[self interfaceOrientation]];
}

- (UIBarButtonItem *)buttonWithImage:(UIImage *)image name:(NSString *)name width:(int)width enabled:(BOOL)enabled action:(SEL)action
{
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:action];
    [button setWidth:width];
    [button setEnabled:enabled];
    [button setIsAccessibilityElement:YES];
    [button setAccessibilityLabel:name];
    return [button autorelease];
}

- (void)createToolbarButtons
{
    [self setFlexibleSpaceButton:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                target:nil action:NULL] autorelease]];
    [self setBackButton:[self buttonWithImage:[[GADIntrinsicImages sharedInstance] browserBackButton]
                                         name:@"Back" width:27 enabled:NO action:@selector(back)]];
    [self setForwardButton:[self buttonWithImage:[[GADIntrinsicImages sharedInstance] browserForwardButton]
                                            name:@"Forward" width:27 enabled:NO action:@selector(forward)]];
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [spinner setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin];
    [spinner setFrame:CGRectMake(0, 0, 20, 20)];
    [self setSpinner:[spinner autorelease]];
    [self setSpinnerContainingButton:[[[UIBarButtonItem alloc] initWithCustomView:[self spinner]] autorelease]];
    [[self spinnerContainingButton] setWidth:20];
    [[self spinnerContainingButton] setEnabled:YES];
    [[self spinnerContainingButton] setIsAccessibilityElement:YES];
    [[self spinnerContainingButton] setAccessibilityLabel:@"Spinner"];
    [self setReloadButton:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                         target:self action:@selector(reload)] autorelease]];
    [[self reloadButton] setWidth:27];
    [[self reloadButton] setEnabled:YES];
    [[self reloadButton] setIsAccessibilityElement:YES];
    [[self reloadButton] setAccessibilityLabel:@"Reload"];
    [self setSafariButton:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                         target:self action:@selector(openInSafari)] autorelease]];
    [[self safariButton] setWidth:27];
    [[self safariButton] setEnabled:NO];
    [[self safariButton] setIsAccessibilityElement:YES];
    [[self safariButton] setAccessibilityLabel:@"View in Safari"];
    [self setDoneButton:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                       target:self action:@selector(relinquishScreen)] autorelease]];
    [[self doneButton] setEnabled:YES];
    [[self doneButton] setStyle:UIBarButtonItemStyleDone];
    [[self doneButton] setIsAccessibilityElement:YES];
    [[self doneButton] setAccessibilityLabel:@"Done"];
}

- (void)refreshToolbar
{
    [[self backButton] setEnabled:[[self webView] canGoBack]];
    [[self forwardButton] setEnabled:[[self webView] canGoForward]];
    UIBarButtonItem *loadingButton;
    if ([[self webView] isLoading]) {
        loadingButton = [self spinnerContainingButton];
        [[self spinner] startAnimating];
        [[self safariButton] setEnabled:NO];
    } else {
        loadingButton = [self reloadButton];
        [[self spinner] stopAnimating];
        [[self safariButton] setEnabled:YES];
    }
    [[self toolbar] setItems:@[[self backButton], [self flexibleSpaceButton], [self forwardButton],
        [self flexibleSpaceButton], loadingButton, [self flexibleSpaceButton], [self safariButton],
        [self flexibleSpaceButton], [self doneButton]]];
}

- (void)load:(NSURL *)url
{
    [self load:url referringURL:nil];
}

- (void)load:(NSURL *)url referringURL:(NSURL *)referrer
{
    if (!url) return;
    if ([self webView]) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        if (referrer) [request setValue:[referrer host] forHTTPHeaderField:@"Referer"];
        [[self webView] loadRequest:request];
    } else {
        [self setURLToLoad:url];
        [self setReferringURLToLoad:referrer];
    }
}

- (void)back
{
    if ([[self webView] canGoBack]) [[self webView] goBack];
}

- (void)forward
{
    if ([[self webView] canGoForward]) [[self webView] goForward];
}

- (void)stop
{
    [[self webView] stopLoading];
}

- (void)reload
{
    [[self webView] reload];
}

- (void)openInSafari
{
    NSURL *url = [[[self webView] request] URL];
    GADOpener *opener = [[[GADOpener alloc] init] autorelease];
    [opener setDelegateManager:[self delegateManager]];
    [opener openApp:url];
    [[[self slot] slotStats] setBreakOutToSafari];
}
@end
