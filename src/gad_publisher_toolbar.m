#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

extern NSString *const kGADClearCredentialsNotificationName;
extern NSString *const kGADDecodeImpressionFunction;
extern NSString *const kGADHelperJavaScriptURL;
extern NSString *const kGADInitializeToolbarFunction;
extern NSString *const kGADLoadAuthenticationURINotficationName;
extern NSString *const kGADLogNotificationName;
extern NSString *const kGADShowJSWebViewNotificationName;
extern NSString *const kGADStoreCredentialsNotificationName;
extern NSString *const kGADToolbarCredentialsFileName;

@interface GADMacros : NSObject
+ (NSString *)dictionaryToJSONString:(NSDictionary *)dictionary;
@end

@interface GADNotification : NSObject
+ (BOOL)isNotificationURL:(NSURL *)url;
+ (GADNotification *)notificationFromURL:(NSURL *)url;
- (NSString *)name;
- (NSDictionary *)parameters;
@end

@interface GADCachedFile : NSObject
- (id)initWithDelegate:(id)delegate URL:(NSURL *)url;
- (NSString *)contentAsString;
@end

@interface GADViewController : UIViewController
- (void)relinquishScreen;
@end

@interface GADPublisherToolbarCredentials : NSObject {
    NSDictionary *_credentials;
}
@property(nonatomic, copy) NSDictionary *credentials;
- (void)clearCredentials;
- (void)storeCredentials:(NSDictionary *)credentials;
@end

static struct {
    NSLock *lock;
    dispatch_once_t once;
} gadToolbarCredentials;

@implementation GADPublisherToolbarCredentials
@dynamic credentials;

+ (BOOL)hasToolbarCredentials
{
    return [[NSUserDefaults standardUserDefaults] dictionaryForKey:kGADToolbarCredentialsFileName] != nil;
}

+ (NSLock *)credentialsLock
{
    dispatch_once(&gadToolbarCredentials.once, ^{
        gadToolbarCredentials.lock = [[NSLock alloc] init];
    });
    return gadToolbarCredentials.lock;
}

- (id)init
{
    self = [super init];
    if (self)
        _credentials = [[[NSUserDefaults standardUserDefaults] dictionaryForKey:kGADToolbarCredentialsFileName] copy];
    return self;
}

- (void)clearCredentials
{
    [[GADPublisherToolbarCredentials credentialsLock] lock];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:kGADToolbarCredentialsFileName];
    [defaults synchronize];
    self.credentials = nil;
    [[GADPublisherToolbarCredentials credentialsLock] unlock];
}

- (void)storeCredentials:(NSDictionary *)credentials
{
    [[GADPublisherToolbarCredentials credentialsLock] lock];
    self.credentials = credentials;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:credentials forKey:kGADToolbarCredentialsFileName];
    [defaults synchronize];
    [[GADPublisherToolbarCredentials credentialsLock] unlock];
}
@end

@interface GADPublisherToolbarController : GADViewController <UIWebViewDelegate> {
    GADPublisherToolbarCredentials *_credentials;
    UIWebView *_oauthWebView;
    UIWebView *_jsWebView;
    UIActivityIndicatorView *_spinnyWheel;
    GADCachedFile *_helperJS;
    NSString *_adUnitID;
    NSString *_adContent;
}
@property(nonatomic, retain) GADPublisherToolbarCredentials *credentials;
@property(nonatomic, retain) UIWebView *oauthWebView;
@property(nonatomic, retain) UIWebView *jsWebView;
@property(nonatomic, retain) UIActivityIndicatorView *spinnyWheel;
@property(nonatomic, retain) GADCachedFile *helperJS;
@property(nonatomic, copy) NSString *adUnitID;
@property(nonatomic, copy) NSString *adContent;
@end

@implementation GADPublisherToolbarController
@dynamic credentials, oauthWebView, jsWebView, spinnyWheel, helperJS, adUnitID, adContent;

- (id)initWithAdContent:(NSString *)adContent adUnitID:(NSString *)adUnitID
{
    self = [super init];
    if (self) {
        _credentials = [[GADPublisherToolbarCredentials alloc] init];
        _adContent = [adContent copy];
        _adUnitID = [adUnitID copy];
        NSURL *url = [NSURL URLWithString:kGADHelperJavaScriptURL];
        _helperJS = [[GADCachedFile alloc] initWithDelegate:self URL:url];
        _jsWebView = [[UIWebView alloc] init];
        _spinnyWheel = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    }
    return self;
}

- (void)configureSpinny
{
    self.spinnyWheel.center = self.view.center;
    self.view.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.spinnyWheel];
    [self.spinnyWheel startAnimating];
}

- (void)createWebViewToolbar
{
    CGSize size = self.view.bounds.size;
    CGRect frame = CGRectMake(0, size.height - 30, size.width, 30);
    UIToolbar *toolbar = [[[UIToolbar alloc] initWithFrame:frame] autorelease];
    toolbar.tintColor = [UIColor blackColor];
    UIBarButtonItem *done = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                target:self action:@selector(relinquishScreen)] autorelease];
    done.enabled = YES;
    done.style = UIBarButtonItemStyleDone;
    done.isAccessibilityElement = YES;
    done.accessibilityLabel = @"Done";
    toolbar.items = @[done];
    [self.view addSubview:toolbar];
}

- (void)configureWebView:(UIWebView *)webView
{
    CGSize size = self.view.bounds.size;
    webView.frame = CGRectMake(0, 0, size.width, size.height - 30);
    webView.hidden = YES;
    webView.delegate = self;
    [self.view addSubview:webView];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)type
{
    if (![GADNotification isNotificationURL:request.URL])
        return YES;
    GADNotification *notification = [GADNotification notificationFromURL:request.URL];
    NSString *name = [notification name];
    if ([name isEqualToString:kGADLoadAuthenticationURINotficationName]) {
        [self loadAuthenticationUri:[[notification parameters] objectForKey:@"authenticationUri"]];
    } else if ([name isEqualToString:kGADShowJSWebViewNotificationName]) {
        [self.spinnyWheel stopAnimating];
        self.jsWebView.hidden = NO;
    } else if ([name isEqualToString:kGADLogNotificationName]) {
        return NO;
    } else if ([name isEqualToString:kGADClearCredentialsNotificationName]) {
        [self.credentials clearCredentials];
    } else if ([name isEqualToString:kGADStoreCredentialsNotificationName]) {
        [self.credentials storeCredentials:[notification parameters]];
    }
    return NO;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (webView == self.oauthWebView) {
        NSString *title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
        if ([title hasPrefix:@"Success"]) {
            self.oauthWebView.hidden = YES;
            [self.spinnyWheel startAnimating];
            [self decodeImpression:title];
        }
    } else if (webView == self.jsWebView) {
        [self launchToolbar];
    }
}

- (void)cachedFileDownloadDidEnd:(GADCachedFile *)file
{
    NSMutableString *html = [NSMutableString string];
    [html appendString:@"<html><head><script>"];
    [html appendString:[self.helperJS contentAsString]];
    [html appendString:@"</script>"];
    [html appendString:@"</head><body></body></html>"];
    [self.jsWebView loadHTMLString:html baseURL:nil];
}

- (void)callJavaScriptMethod:(NSString *)method withArgument:(NSString *)argument wrappedAsString:(BOOL)quote
{
    NSString *script = [NSString stringWithFormat:@"%@(", method];
    if (argument) {
        if (quote) {
            argument = [argument stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
            argument = [NSString stringWithFormat:@"'%@'", argument];
        }
        script = [script stringByAppendingString:argument];
    }
    script = [script stringByAppendingString:@");"];
    [self.jsWebView stringByEvaluatingJavaScriptFromString:script];
}

- (void)launchToolbar
{
    NSMutableDictionary *arguments = [[[NSMutableDictionary alloc] init] autorelease];
    if (self.adUnitID)
        [arguments setObject:self.adUnitID forKey:@"adUnitID"];
    if (self.credentials.credentials && [self.credentials.credentials count])
        [arguments setObject:self.credentials.credentials forKey:@"credentials"];
    if (self.adContent)
        [arguments setObject:self.adContent forKey:@"adContent"];
    NSString *json = [GADMacros dictionaryToJSONString:arguments];
    [self callJavaScriptMethod:kGADInitializeToolbarFunction withArgument:json wrappedAsString:NO];
}

- (void)loadAuthenticationUri:(NSString *)uri
{
    if (!self.oauthWebView) {
        self.oauthWebView = [[[UIWebView alloc] init] autorelease];
        [self configureWebView:self.oauthWebView];
    }
    self.jsWebView.hidden = YES;
    self.oauthWebView.hidden = NO;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:uri]];
    [self.oauthWebView loadRequest:request];
}

- (void)decodeImpression:(NSString *)title
{
    NSMutableDictionary *arguments = [[[NSMutableDictionary alloc] init] autorelease];
    if (self.adContent)
        [arguments setObject:self.adContent forKey:@"adContent"];
    if (title)
        [arguments setObject:title forKey:@"authenticationPageTitle"];
    NSString *json = [GADMacros dictionaryToJSONString:arguments];
    [self callJavaScriptMethod:kGADDecodeImpressionFunction withArgument:json wrappedAsString:NO];
}
@end
