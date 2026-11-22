// Recovered from the Objective-C metadata, selector references and call sites in the supplied Flap executable.
// The declarations below give Clang the original 32-bit message signatures without an iOS SDK.
#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#import <iAd/iAd.h>
#else
typedef signed char BOOL;
typedef struct CGPoint { float x, y; } CGPoint;
typedef struct CGSize { float width, height; } CGSize;
typedef struct CGRect { CGPoint origin; CGSize size; } CGRect;

__attribute__((objc_root_class))
@interface NSObject {
    Class isa;
}
+ (id)alloc;
+ (Class)class;
- (id)init;
- (oneway void)release;
- (void)dealloc;
@end
@interface UIResponder : NSObject @end
@interface UIScreen : NSObject
+ (UIScreen *)mainScreen;
- (CGRect)bounds;
@end
@interface UIView : UIResponder
- (id)initWithFrame:(CGRect)frame;
- (void)addSubview:(UIView *)view;
@end
@interface UIViewController : UIResponder
@property(nonatomic, retain) UIView *view;
@end
@interface UIWindow : UIView
@property(nonatomic, retain) UIViewController *rootViewController;
- (void)makeKeyAndVisible;
@end
@protocol UIApplicationDelegate @end
@protocol ADBannerViewDelegate @end
@class UIApplication, NSDictionary, NSString;
extern NSString *NSStringFromClass(Class cls);
extern int UIApplicationMain(int argc, char **argv, NSString *principal, NSString *delegate);
#endif

@interface dot_EAGLView : UIView
+ (dot_EAGLView *)instance;
- (void)setup;
- (void)start;
- (void)stop;
@end

@interface dot_AppDelegate : UIResponder <UIApplicationDelegate, ADBannerViewDelegate>
@property(nonatomic, retain) UIWindow *window;
@end

// armv7 0x9e90, armv7s 0xa020
int main(int argc, char **argv) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, (id)0, NSStringFromClass([dot_AppDelegate class]));
    }
}

@implementation dot_AppDelegate
@synthesize window = _window;

- (void)dealloc {
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[UIViewController alloc] init];
    dot_EAGLView *view = [[dot_EAGLView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController.view = view;
    [self.window addSubview:self.window.rootViewController.view];
    [view setup];
    [[dot_EAGLView instance] start];
    [self.window makeKeyAndVisible];
    return 1;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    [[dot_EAGLView instance] stop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[dot_EAGLView instance] stop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[dot_EAGLView instance] start];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[dot_EAGLView instance] stop];
}
@end
