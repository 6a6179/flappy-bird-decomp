#import <UIKit/UIKit.h>

@interface GADSlot : NSObject
@end

@interface GADSearchSlot : GADSlot
@end

@implementation GADSearchSlot
- (NSString *)jsBuildAdURL
{
    return @"http://www.gstatic.com/safa/sdk-core-v40.js";
}
@end

@interface GADURL : NSObject
@end

@implementation GADURL
+ (NSURL *)URLWithString:(NSString *)string
{
    if (!string)
        return nil;
    return [NSURL URLWithString:string];
}
@end

@interface GADWebView : UIWebView
@property(nonatomic, assign) UIViewController *viewController;
@end

@interface GADBrowserController : UIViewController
@end

@interface GADBrowserWebView : GADWebView
@end

@implementation GADBrowserWebView
- (void)setViewController:(UIViewController *)controller
{
    if ([controller isKindOfClass:[GADBrowserController class]])
        [super setViewController:controller];
}

- (GADBrowserController *)gadBrowserController
{
    if ([self.viewController isKindOfClass:[GADBrowserController class]])
        return (GADBrowserController *)self.viewController;
    return nil;
}
@end
