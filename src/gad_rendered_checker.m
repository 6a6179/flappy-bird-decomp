#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@protocol GADMWebViewRenderedCheckerDelegate
- (void)webView:(UIWebView *)webView isRendered:(BOOL)rendered;
@end

@interface GADMWebViewRenderedChecker : NSObject {
    UIWebView *webView_;
    id<GADMWebViewRenderedCheckerDelegate> delegate_;
}
@property(nonatomic, assign) UIWebView *webView;
@property(nonatomic, assign) id<GADMWebViewRenderedCheckerDelegate> delegate;
@end

@implementation GADMWebViewRenderedChecker
@synthesize webView = webView_, delegate = delegate_;

- (id)initWithWebView:(UIWebView *)webView delegate:(id<GADMWebViewRenderedCheckerDelegate>)delegate
{
    self = [super init];
    if (self) {
        webView_ = webView;
        delegate_ = delegate;
    }
    return self;
}

- (void)checkIsContentRenderedInWebView
{
    if (![self webView] || ![self delegate]) return;
    UIGraphicsBeginImageContext([[self webView] frame].size);
    [[[self webView] layer] renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGFloat fraction = [self percentOfImage:image ofColor:[[self webView] backgroundColor]];
    [[self delegate] webView:[self webView] isRendered:fraction < 0.9];
}

- (float)percentOfImage:(UIImage *)image ofColor:(UIColor *)color
{
    const CGFloat *rgba = CGColorGetComponents([color CGColor]);
    UIColor *background = [UIColor colorWithRed:rgba[0] green:rgba[1] blue:rgba[2] alpha:rgba[3]];
    CGImageRef bitmap = [image CGImage];
    size_t width = CGImageGetWidth(bitmap), height = CGImageGetHeight(bitmap);
    size_t bytesPerRow = width * 4, byteCount = bytesPerRow * height;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    unsigned char *pixels = calloc(byteCount, 1);
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, bytesPerRow, space,
                                                 kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), bitmap);
    CGContextRelease(context);

    NSUInteger matching = 0, other = 0;
    for (size_t index = 0; index < byteCount; index += 4) {
        NSUInteger red = pixels[index], green = pixels[index + 1];
        NSUInteger blue = pixels[index + 2], alpha = pixels[index + 3];
        UIColor *pixel = [UIColor colorWithRed:red / 255.0f green:green / 255.0f
                                          blue:blue / 255.0f alpha:alpha / 255.0f];
        if ([background isEqual:pixel]) matching++;
        else other++;
    }
    free(pixels);
    return (float)matching / (matching + other);
}
@end
