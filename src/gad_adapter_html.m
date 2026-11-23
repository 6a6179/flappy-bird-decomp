#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef struct GADAdSize { CGSize size; NSUInteger flags; } GADAdSize;
extern CGSize CGSizeFromGADAdSize(GADAdSize size);
extern NSString *kGADErrorDomain;

@interface GADMWebViewRenderedChecker : NSObject
- (id)initWithWebView:(UIWebView *)webView delegate:(id)delegate;
- (void)setDelegate:(id)delegate;
- (void)setWebView:(UIWebView *)webView;
- (void)checkIsContentRenderedInWebView;
@end

@interface NSObject (GADMHTMLConnector)
- (NSDictionary *)credentials;
- (void)adapter:(id)adapter didFailAd:(NSError *)error;
- (void)adapter:(id)adapter didFailInterstitial:(NSError *)error;
- (void)adapter:(id)adapter didReceiveAdView:(UIView *)view;
@end

@interface GADMAdapterHTML : NSObject <UIWebViewDelegate> {
    id connector_;
    UIWebView *webView_;
    NSURL *passbackUrl_;
    GADMWebViewRenderedChecker *webViewRenderedChecker_;
    NSTimer *checkRenderingTimer_;
    NSUInteger checkRenderingCount_;
}
- (id)connector;
- (UIWebView *)webView;
- (void)setWebView:(UIWebView *)view;
- (NSURL *)passbackUrl;
- (void)setPassbackUrl:(NSURL *)url;
@end

@implementation GADMAdapterHTML
- (id)initWithGADMAdNetworkConnector:(id)connector
{
    if ((self = [super init])) connector_ = connector;
    return self;
}

- (void)dealloc
{
    connector_ = nil;
    [self clearWebView];
    [super dealloc];
}

- (void)clearWebView
{
    [self stopBeingDelegate];
    [webView_ release];
    webView_ = nil;
    [passbackUrl_ release];
    passbackUrl_ = nil;
}

- (void)failInterstitialRequest
{
    [[self connector] adapter:self didFailInterstitial:[self errorWithCode:0 text:@"Interstitials not supported."]];
}

- (void)startRenderingTimer
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(startRenderingTimer) withObject:nil waitUntilDone:YES];
        return;
    }
    webViewRenderedChecker_ = [[[GADMWebViewRenderedChecker alloc] initWithWebView:[self webView] delegate:self] autorelease];
    checkRenderingTimer_ = [NSTimer scheduledTimerWithTimeInterval:0.2 target:webViewRenderedChecker_
                  selector:@selector(checkIsContentRenderedInWebView) userInfo:nil repeats:YES];
}

- (void)stopRenderingTimer
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(stopRenderingTimer) withObject:nil waitUntilDone:YES];
        return;
    }
    if (webViewRenderedChecker_) {
        [webViewRenderedChecker_ setWebView:nil];
        [webViewRenderedChecker_ setDelegate:nil];
        webViewRenderedChecker_ = nil;
    }
    if (checkRenderingTimer_) {
        [checkRenderingTimer_ invalidate];
        checkRenderingTimer_ = nil;
    }
}

- (NSError *)errorWithCode:(NSInteger)code text:(NSString *)text
{
    return [NSError errorWithDomain:kGADErrorDomain code:code userInfo:
            [NSDictionary dictionaryWithObjectsAndKeys:text, NSLocalizedDescriptionKey, nil]];
}

- (void)webView:(UIWebView *)view isRendered:(BOOL)rendered
{
    if ([self webView] != view) return;
    ++checkRenderingCount_;
    if (rendered) {
        [self stopRenderingTimer];
        [[self connector] adapter:self didReceiveAdView:[self webView]];
    } else if (checkRenderingCount_ > 100) {
        [self stopRenderingTimer];
    }
}

+ (NSString *)adapterVersion
{
    return @"1.1";
}

- (void)getBannerWithSize:(GADAdSize)size
{
    [self clearWebView];
    NSString *html = [[[self connector] credentials] objectForKey:@"adxtym_html"];
    NSString *passback = [[[self connector] credentials] objectForKey:@"adxtym_passback_url"];
    if (passback) {
        if ([passback isEqualToString:@""]) {
            [[self connector] adapter:self didFailAd:[self errorWithCode:2 text:@"Empty passback URL in TYM response."]];
            return;
        }
        [self setPassbackUrl:[NSURL URLWithString:passback]];
        if (![self passbackUrl]) {
            [[self connector] adapter:self didFailAd:[self errorWithCode:2 text:@"Invalid passback URL in TYM response."]];
            return;
        }
    }
    if (!html || ![html length]) {
        [[self connector] adapter:self didFailAd:[self errorWithCode:2 text:@"Missing HTML in TYM response."]];
        return;
    }
    [self createWebViewWithSize:size];
    [[self webView] loadHTMLString:html baseURL:[NSURL URLWithString:@"http://adx.g.dpvblfcljck.nft"]];
    [self startRenderingTimer];
}

- (void)createWebViewWithSize:(GADAdSize)adSize
{
    CGSize size = CGSizeFromGADAdSize(adSize);
    [self setWebView:[[[UIWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)] autorelease]];
    [[self webView] setScalesPageToFit:NO];
    [[self webView] setClipsToBounds:YES];
    [[self webView] setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [[self webView] setOpaque:NO];
    [[self webView] setBackgroundColor:[UIColor clearColor]];
    [[self webView] setAllowsInlineMediaPlayback:YES];
    [[self webView] setMediaPlaybackRequiresUserAction:YES];
    [[self webView] setDataDetectorTypes:UIDataDetectorTypeNone];
    [[self webView] setDelegate:self];
}

- (void)getInterstitial
{
    [self failInterstitialRequest];
}

- (void)stopBeingDelegate
{
    [webView_ setDelegate:nil];
    [self stopRenderingTimer];
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)controller
{
    [self failInterstitialRequest];
}

- (NSString *)stripTrailingSlashFromPath:(NSString *)path
{
    if ([path length] && [[path substringFromIndex:[path length] - 1] isEqualToString:@"/"]) {
        return [path substringToIndex:[path length] - 1];
    }
    return path;
}

- (BOOL)isPath:(NSString *)path equivalentToPath:(NSString *)other
{
    return [[self stripTrailingSlashFromPath:path] isEqualToString:[self stripTrailingSlashFromPath:other]];
}

- (BOOL)isPassbackRequest:(NSURLRequest *)request
{
    return [[request.URL scheme] isEqualToString:@"passback"] ||
        ([self passbackUrl] && [[[self passbackUrl] host] isEqualToString:[request.URL host]] &&
            [self isPath:[[self passbackUrl] path] equivalentToPath:[request.URL path]]);
}

- (BOOL)webView:(UIWebView *)view shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)type
{
    if ([self webView] != view || ![request URL]) return NO;
    if (![self isPassbackRequest:request]) return YES;
    [self stopRenderingTimer];
    [[self connector] adapter:self didFailAd:[self errorWithCode:1 text:@"Ad network returned no ad."]];
    return NO;
}
@end
