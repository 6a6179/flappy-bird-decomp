#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

@interface GADActivationView : UIWebView
@end

@implementation GADActivationView
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        if ([self respondsToSelector:@selector(scrollView)]) {
            self.scrollView.scrollEnabled = NO;
            self.scrollView.scrollsToTop = NO;
        }
        self.clipsToBounds = YES;
        self.scalesPageToFit = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}
@end

@interface GADNotification : NSObject
+ (BOOL)isNotificationURL:(NSURL *)url;
+ (GADNotification *)notificationFromURL:(NSURL *)url;
- (NSString *)name;
- (NSDictionary *)parameters;
@end

@interface GADDelegateManager : NSObject
- (void)didActivateAd;
- (void)didDeactivatedAd;
@end

@interface GADSlot : NSObject
- (GADDelegateManager *)delegateManager;
- (GADActivationView *)activationView;
@end

@interface GADActivationViewDelegate : NSObject <UIWebViewDelegate>
- (GADSlot *)slot;
@end

@implementation GADActivationViewDelegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)type
{
    if (![GADNotification isNotificationURL:[request URL]])
        return YES;
    GADNotification *notification = [GADNotification notificationFromURL:[request URL]];
    if (![[notification name] isEqualToString:@"setNativeActivationOverlay"] ||
        ![webView isKindOfClass:[GADActivationView class]])
        return NO;
    NSString *active = [[notification parameters] objectForKey:@"a"];
    if ([active isEqualToString:@"1"])
        [[[self slot] delegateManager] didActivateAd];
    else if ([active isEqualToString:@"0"])
        [[[self slot] delegateManager] didDeactivatedAd];

    NSString *width = [[notification parameters] objectForKey:@"w"];
    NSString *height = [[notification parameters] objectForKey:@"h"];
    NSString *x = [[notification parameters] objectForKey:@"x"];
    NSString *y = [[notification parameters] objectForKey:@"y"];
    if (width || height || x || y) {
        CGRect frame = webView.frame;
        if (width) frame.size.width = [width intValue];
        if (height) frame.size.height = [height intValue];
        if (x) frame.origin.x = [x intValue];
        if (y) frame.origin.y = [y intValue];
        [self setActivationOverlayFrameOnNextRunLoop:frame];
    } else {
        [self setActivationOverlayFrameOnNextRunLoop:webView.superview.bounds];
    }
    return NO;
}

- (void)setActivationOverlayFrameOnNextRunLoop:(CGRect)frame
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0), dispatch_get_main_queue(), ^{
        [[self slot] activationView].frame = frame;
    });
}
@end
