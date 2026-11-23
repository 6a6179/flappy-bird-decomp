#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

@interface GADAdType : NSObject
- (BOOL)isInterstitial;
@end

@interface GADSlot : NSObject
- (GADAdType *)adType;
- (void)setIsMRAID:(BOOL)isMRAID;
- (id)delegateManager;
- (id)adView;
- (id)interstitial;
@end

extern NSString *const kGADGMSGHandlerParamNotification;
extern NSString *const kGADGMSGHandlerParamWebView;
extern NSString *const kGADGMSGURLActionAppEvent;
extern NSString *const kGADGMSGURLActionCanOpenURLs;
extern NSString *const kGADGMSGURLActionClose;
extern NSString *const kGADGMSGURLActionCustomClose;
extern NSString *const kGADGMSGURLActionHTTPTrack;
extern NSString *const kGADGMSGURLActionLog;
extern NSString *const kGADGMSGURLActionTouch;
extern NSString *const kGADGMSGURLActionVibrate;
extern NSString *const kGADGMSGURLParamCustomClose;
extern NSString *const kGADGMSGURLParamCustomCloseValueTrue;
extern NSString *const kGADGMSGURLParamMessage;
extern NSString *const kGADGMSGURLParamTouchDuration;
extern NSString *const kGADGMSGURLParamTouchX;
extern NSString *const kGADGMSGURLParamTouchY;
extern NSString *const kGADGMSGURLParamURL;
extern NSString *const kGADGMSGURLParamURLs;
extern NSString *const kGADGMSGURLParamURLsSeperator;

extern void gad_htg(int x, int y, int duration);

@interface GADActionRouter : NSObject
- (id)initWithReceiver:(id)receiver;
- (NSUInteger)postNotificationName:(NSString *)name arguments:(NSDictionary *)arguments;
@end

@interface GADNotification : NSObject
+ (id)notificationFromURL:(NSURL *)url;
- (NSString *)name;
- (NSDictionary *)parameters;
@end

@interface GADGMSGHandler : NSObject {
    GADActionRouter *_actionRouter;
}
- (GADActionRouter *)actionRouter;
- (void)addSelector:(SEL)selector forGMSGActionName:(NSString *)name;
@end

@implementation GADGMSGHandler

+ (BOOL)isGMSG:(NSURL *)url
{
    return [[[url scheme] lowercaseString] isEqualToString:@"gmsg"];
}

- (id)init
{
    self = [super init];
    if (self)
        _actionRouter = [[GADActionRouter alloc] initWithReceiver:self];
    return self;
}

- (BOOL)handleRequest:(NSURLRequest *)request webView:(UIWebView *)webView
{
    NSURL *url = [request URL];
    if (![GADGMSGHandler isGMSG:url])
        return NO;
    GADNotification *note = [GADNotification notificationFromURL:url];
    NSMutableDictionary *arguments = [[[NSMutableDictionary alloc] init] autorelease];
    if (webView)
        [arguments setObject:webView forKey:@"webView"];
    if (note)
        [arguments setObject:note forKey:@"note"];
    return [[self actionRouter] postNotificationName:[note name] arguments:arguments] != 0;
}

@end

@interface GADClickTrackerCollection : NSObject
+ (id)sharedInstance;
- (void)trackURL:(NSURL *)url;
@end

@interface GADDevice : NSObject
+ (id)currentDevice;
- (NSDictionary *)canOpenURLs:(NSArray *)urls;
@end

@interface GADNotificationCenter : NSNotificationCenter
- (void)postJSNotification:(NSString *)name userInfo:(NSDictionary *)userInfo webView:(UIWebView *)webView;
@end

@interface GADWebView : UIWebView
- (UIViewController *)viewController;
@end

@interface GADViewController : UIViewController
- (void)relinquishScreen;
@end

@interface GADWebAppViewController : GADViewController
- (void)setUseCustomClose:(BOOL)useCustomClose;
@end

@interface GADDefaultGMSGHandler : GADGMSGHandler
@end

@implementation GADDefaultGMSGHandler

+ (NSInteger)integerForKey:(NSString *)key fromDictionary:(NSDictionary *)dictionary withDefaultValue:(NSInteger)value
{
    id object = [dictionary objectForKey:key];
    return [object respondsToSelector:@selector(integerValue)] ? [object integerValue] : value;
}

- (id)init
{
    self = [super init];
    if (self) {
        [self addSelector:@selector(didReceiveTrackHTTPNotification:) forGMSGActionName:kGADGMSGURLActionHTTPTrack];
        [self addSelector:@selector(didReceiveLogNotification:) forGMSGActionName:kGADGMSGURLActionLog];
        [self addSelector:@selector(didReceiveTouchNotification:) forGMSGActionName:kGADGMSGURLActionTouch];
        [self addSelector:@selector(didReceiveVibrateNotification:) forGMSGActionName:kGADGMSGURLActionVibrate];
        [self addSelector:@selector(didReceiveCanOpenURLsNotification:) forGMSGActionName:kGADGMSGURLActionCanOpenURLs];
        [self addSelector:@selector(didReceiveCloseNotification:) forGMSGActionName:kGADGMSGURLActionClose];
    }
    return self;
}

- (void)didReceiveTrackHTTPNotification:(NSDictionary *)arguments
{
    GADNotification *note = [arguments objectForKey:kGADGMSGHandlerParamNotification];
    NSURL *url = [NSURL URLWithString:[[note parameters] objectForKey:kGADGMSGURLParamURL]];
    [[GADClickTrackerCollection sharedInstance] trackURL:url];
}

- (void)didReceiveLogNotification:(NSDictionary *)arguments
{
    GADNotification *note = [arguments objectForKey:kGADGMSGHandlerParamNotification];
    NSLog(@"%@", [[note parameters] objectForKey:kGADGMSGURLParamMessage]);
}

- (void)didReceiveTouchNotification:(NSDictionary *)arguments
{
    GADNotification *note = [arguments objectForKey:kGADGMSGHandlerParamNotification];
    NSInteger x = [GADDefaultGMSGHandler integerForKey:kGADGMSGURLParamTouchX
                                       fromDictionary:[note parameters] withDefaultValue:-1];
    NSInteger y = [GADDefaultGMSGHandler integerForKey:kGADGMSGURLParamTouchY
                                       fromDictionary:[note parameters] withDefaultValue:-1];
    NSInteger duration = [GADDefaultGMSGHandler integerForKey:kGADGMSGURLParamTouchDuration
                                              fromDictionary:[note parameters] withDefaultValue:-1];
    gad_htg(x, y, duration);
}

- (void)didReceiveVibrateNotification:(NSDictionary *)arguments
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

- (void)didReceiveCanOpenURLsNotification:(NSDictionary *)arguments
{
    GADNotification *note = [arguments objectForKey:kGADGMSGHandlerParamNotification];
    GADWebView *view = [arguments objectForKey:kGADGMSGHandlerParamWebView];
    NSString *list = [[note parameters] objectForKey:kGADGMSGURLParamURLs];
    NSArray *urls = [list componentsSeparatedByString:kGADGMSGURLParamURLsSeperator];
    NSDictionary *openable = [[GADDevice currentDevice] canOpenURLs:urls];
    [(GADNotificationCenter *)[GADNotificationCenter defaultCenter]
        postJSNotification:@"openableURLs" userInfo:openable webView:view];
}

- (void)didReceiveCloseNotification:(NSDictionary *)arguments
{
    GADWebView *view = [arguments objectForKey:kGADGMSGHandlerParamWebView];
    [view viewController];
    if ([[view viewController] isKindOfClass:[GADViewController class]])
        [(GADViewController *)[view viewController] relinquishScreen];
}

@end

@interface GADAppEventGMSGHandler : GADGMSGHandler {
    GADSlot *_slot;
}
- (GADSlot *)slot;
@end

@protocol GADAppEventDelegate
- (void)adView:(id)view didReceiveAppEvent:(NSString *)event withInfo:(NSString *)info;
- (void)interstitial:(id)interstitial didReceiveAppEvent:(NSString *)event withInfo:(NSString *)info;
@end

@implementation GADAppEventGMSGHandler

- (id)initWithSlot:(GADSlot *)slot
{
    self = [super init];
    if (self) {
        _slot = slot;
        [self addSelector:@selector(didReceiveAppEventNotification:) forGMSGActionName:kGADGMSGURLActionAppEvent];
    }
    return self;
}

- (void)didReceiveAppEventNotification:(NSDictionary *)arguments
{
    GADNotification *note = [arguments objectForKey:kGADGMSGHandlerParamNotification];
    NSDictionary *parameters = [note parameters];
    NSString *name = [parameters valueForKey:@"name"];
    NSString *info = [parameters valueForKey:@"info"];
    if (name) {
        if ([[[self slot] adType] isInterstitial]) {
            [[[self slot] delegateManager] interstitial:[[self slot] interstitial] didReceiveAppEvent:name withInfo:info];
        } else {
            [[[self slot] delegateManager] adView:[[self slot] adView] didReceiveAppEvent:name withInfo:info];
        }
    }
}

@end

@interface GADWebAppGMSGHandler : GADGMSGHandler
@end

@implementation GADWebAppGMSGHandler

- (id)init
{
    self = [super init];
    if (self)
        [self addSelector:@selector(didReceiveCustomCloseNotification:) forGMSGActionName:kGADGMSGURLActionCustomClose];
    return self;
}

- (void)didReceiveCustomCloseNotification:(NSDictionary *)arguments
{
    GADWebView *view = [arguments objectForKey:kGADGMSGHandlerParamWebView];
    if ([[view viewController] isKindOfClass:[GADWebAppViewController class]]) {
        GADWebAppViewController *controller = (GADWebAppViewController *)[view viewController];
        GADNotification *note = [arguments objectForKey:kGADGMSGHandlerParamNotification];
        NSString *value = [[note parameters] objectForKey:kGADGMSGURLParamCustomClose];
        [controller setUseCustomClose:[value isEqualToString:kGADGMSGURLParamCustomCloseValueTrue]];
    }
}

@end
