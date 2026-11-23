#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <math.h>

@interface GADDevice : NSObject
- (CGFloat)screenDensity;
@end
@interface GAD_GTMStringEncoding : NSObject
+ (id)rfc4648Base64StringEncoding;
- (NSData *)decode:(NSString *)string;
@end
@interface GADIntrinsicImages : NSObject
- (GADDevice *)currentDevice;
@end

struct {
    dispatch_once_t once;
    GADIntrinsicImages *instance;
    UIImage *back, *forward, *close;
} GADIntrinsicImageCache = {0};

@implementation GADIntrinsicImages

+ (id)sharedInstance
{
    dispatch_once(&GADIntrinsicImageCache.once, ^{
        GADIntrinsicImageCache.instance = [[GADIntrinsicImages alloc] init];
    });
    return GADIntrinsicImageCache.instance;
}

- (UIImage *)createImageFromEncoding:(NSString *)encoding
{
    NSData *data = [[GAD_GTMStringEncoding rfc4648Base64StringEncoding] decode:encoding];
    UIImage *image = [UIImage imageWithData:data];
    if ([image respondsToSelector:@selector(initWithCGImage:scale:orientation:)]) {
        if ([[self currentDevice] respondsToSelector:@selector(screenDensity)])
            return [UIImage imageWithCGImage:[image CGImage] scale:[[self currentDevice] screenDensity]
                                 orientation:UIImageOrientationUp];
        return [UIImage imageWithCGImage:[image CGImage]];
    }
    CGSize size = [image size];
    CGFloat width = roundf(size.width * 0.5f);
    CGFloat height = roundf(size.height * 0.5f);
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    [image drawInRect:CGRectMake(0, 0, width, height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resized;
}

- (NSString *)chooseImage:(NSString *)image orDoubleDensityImage:(NSString *)retinaImage
{
    if (![[self currentDevice] respondsToSelector:@selector(screenDensity)])
        return nil;
    return [[self currentDevice] screenDensity] == 1.0f ? image : retinaImage;
}

- (UIImage *)browserBackButton
{
    if (!GADIntrinsicImageCache.back) {
        NSString *standard =
            @"iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAABjklEQVRIx9WWMUvDQBTHa5JBP0QFEZWSpVvXggE3v0XGgoKL"
            "k/0GGbtEB9FJCXQtEfIJFJyEDv0GxZYWa5Pe8/80V44QHZJrsQ/+yd1B3i/vf3fJVYiosi5VNhaGMKCtlcIYAFlK31wJLAOx"
            "oQfbtnflS2iBpZYZ3G42m9toXzmOMw+fQur1egc83m63jVKwHMtOoTff92k2m2GIpt1u96g0TJ0LxD702Gq1aDAYMGTOl09E"
            "KVhqmZkmsNC+bDQakyiKOP+ChRDcSZKkGCzHshPotdPp0Hg85twx/ZD4Vg6mQKrQveu61O/3JUSkEBmlK+NVdlav10dhGErL"
            "EoYIISgTxWByf9RqNd/zPBoOh1nL8qJwZd8wzMu1zARInFONPhuhHUDOAXlXEiargklVoVslcSyT64SxnZbSP4aeM1DtlfFD"
            "ptK+gEYZa7XBpJRfxwd/2e+WZQkR64blWetALxIK2FQn7C9rJwwMguBQNyzHWtrDVrlJV+9yv+o+g2StNdZxujJ+A232Ue5f"
            "wb4AWkJre3r4X5oAAAAASUVORK5CYII=";
        NSString *retina =
            @"iVBORw0KGgoAAAANSUhEUgAAADYAAAA2CAYAAACMRWrdAAAB4ElEQVRo3u3ZP2vCUByF4RcEwamSySng5BoolDq5OvkZCoVA"
            "JydXV3EWCoWsTq5OfoNCIJOTk2tLiyAILp4uBqS0WGuMN5d74LeGPHBI7h8kYeNYiXIwB3MwB3OwzGBpzn6B42kAM8C3BVYB"
            "BsAWkC2wDrAE1Gg0NJvNNBwO74sMqwNTQJVKRYPBQNvtVpIKCysDfWADqNPpaLlc6jBFhLWBBaB6va7pdKqfUhgY4AMTQOVy"
            "Wf1+X5vNRr/FeNi+dj1gDajdbmuxWOhYjIYBLWAOyPd9TSYT/TVGwoAaME5r1+v1tF6vdUqMggEloAusALVaLc3nc/0nxsCA"
            "JpAAqtVqGo/HOidXhwEeEAEqlUrqdrtarVY6N1eFAWFau2azqSRJlFWuAgMCIAbkeZ6iKFLWyRt2A4z2q2+FYZhJ7a4NewDe"
            "AAVBoDiOdcnkCqtWq5+j0Uh5JDeYpIfdbveunJIrTNKHdbD9F/FG0rN1sIP/WCDp1UZYOo+XqqcJa8WL1NOk1X2m9TRxP5ZJ"
            "PU3dQXuSXmyEpXMrKbYRlk54aj2LdK54Uj0Ld2D613oW9uz+WD0LfSmxr2dkHezgmXeSEutgB89+kpSeNVhzo/m9nvnATB8H"
            "czAHczAHczAHM3C+ADF7yq5qJ9TZAAAAAElFTkSuQmCC";
        NSString *encoding = [self chooseImage:standard orDoubleDensityImage:retina];
        GADIntrinsicImageCache.back = [self createImageFromEncoding:encoding];
        [GADIntrinsicImageCache.back retain];
    }
    return GADIntrinsicImageCache.back;
}

- (UIImage *)browserForwardButton
{
    if (!GADIntrinsicImageCache.forward) {
        NSString *standard =
            @"iVBORw0KGgoAAAANSUhEUgAAABsAAAAbCAYAAACN1PRVAAABkUlEQVRIx93WsWrCQBgHcKsZ7EMolNIWyeKWNdBAt76FY6CF"
            "Lp3qGzi6pB1KO7UIrpJCnqCFToUMvoFUUWo15vN/aQ4+itbEXBx68Ofu0OSX++4iFoiosKvsDPoTQ9tDirljaCU21gSsHJM3"
            "1XW9ivETonNUKdZsNqOy9Xq9I/fFJcuyZkBuTNMsx2AxS2lXYt1u9wT9ZDqdkuM4QvlAzrOWdi32jUY/bdbv98m2baE8I4er"
            "9jYTFgRBhC0Wi1B0Ip7nkWEYYyDX+K4mwaSl3YihhQDjIc1HoxG1222hvCNnaUqbCJNSjIr53Pd9ajQaQnlEKspWRqyFYSjR"
            "QPiu61K9Xh8CvEDKSrFfq4xKOxgMqNVqUa1Wc/j7qgxjq5zLOfbzNr6XciyQnwH9BHqJ4b7qMkYHhM3vkVwOCEdekVN2vbau"
            "fGmxgKFD5AqRL3KJjbOtDPvBV/NA9FVl1yj7uZow5A2x0pQsMdbpdI5jZLxtyTZi7GkrOMp36A+2LVkSTIY//VYlS4NJMP8/"
            "PHnl/2JLfTVrez6f4koAAAAASUVORK5CYII=";
        NSString *retina =
            @"iVBORw0KGgoAAAANSUhEUgAAADYAAAA2CAYAAACMRWrdAAABxUlEQVRo3u3ZMWuDUBQF4IAgODU4OQlOroFCqZOrk7+hUBA6"
            "OWV1DZmFQsHVydXJf1AQnJycXFtahIDgktv7ihcCLbRJFt/lHTiYKbwPDkbiCgBWHMsSpWAKpmAKpmBXwTA2tsK6qz9y9cGu"
            "/J5LYOLDhN1hDRaw/X5/X1UVuK4LM7DHhixgeIVpmmC324FhGAQssY70MErf9xCGIeFGbILVpYdRyrIEx3EI2GEDFjCRcRwh"
            "SRLQdZ2AhbjZSA+jdF0HQRAQ7oDdinlKD6MURQG2bROwxfosYCKHwwG22+3pPHOsJT2M0rYt+L5PuAEbYzXpYZQ8z8GyLAI2"
            "WI8FTGQYBojjGDRNI2CGNaWHUZqmAc/zTucZsYBRsiwD0zQJWGM3LGA0zyiKCCeaYm+kh1HquobNZkO4N+wDCxglTVNYr9ef"
            "7GAix+PxHS/8YJgPjrBnLJ+bB+YVy+d2P8/uETj9QNPsgMsj1ensgMND8G+z4wB7wZr/OpgksBp7e9bBFg4Ts4suOtiCYf+e"
            "nSyws2e3dNj37Fj8d3+STMyOzUsJTIO9k/41EtaeQQP2ic0bzRn2Y3YcYNJUwRRMwRRMwRRMwRbYL2Mwyq7vtDnQAAAAAElF"
            "TkSuQmCC";
        NSString *encoding = [self chooseImage:standard orDoubleDensityImage:retina];
        GADIntrinsicImageCache.forward = [self createImageFromEncoding:encoding];
        [GADIntrinsicImageCache.forward retain];
    }
    return GADIntrinsicImageCache.forward;
}

- (UIImage *)closeButton
{
    if (!GADIntrinsicImageCache.close) {
        NSString *standard =
            @"iVBORw0KGgoAAAANSUhEUgAAABkAAAAZCAYAAADE6YVjAAADf0lEQVRIx7VWTUgbQRiNUWiiiSJKo8GDtNeCBw/W2rQSQbAB"
            "UfHn4qn24j33UkHwIL0qASEhxdBLQRDSo4LanowH/0igN9tDg8UoKrub+fq9cWZZFkOopAuP+WZ2Zt58P/N2PUTkuQdeRr1r"
            "LMBoVgi43tWpNfft5blv0Ln5M8YiY/v29vY3owTc3NwUeWyXsXxyctLvOlxVkga0l5eXj7ldM03TODw8pJWVFRobG6OhoSEJ"
            "2Kurq3R0dERMKJj4y8LCQo/Dq4okDap9wfhZKBRoYmKCZ3hMhsUQLpTxDnMwlw/0Z2Nj4y2P1buJ3CECgZFOp7G5gc26urqo"
            "s7OTgsHgHQJ3LcbwThGa6+vrJISgZDIZ577fSWTHUYXolyIww+EwAWxTU1MT+f1+aQOwMQYbczo6OmBbICqVSgZ7N8f9R04S"
            "7cUa3IYHWNjW1iY36e7ulq3X6yWfzycB2/muvb3dJjo9PSUuhjzbL7UDdhUhySoHQnsQiUTo7OyMcEL0Q6GQBGyM4R3maI/Q"
            "Tk5Olq+vrykejye4H3KSLKKKECYVZ3lKbKKfVCplhwu2fjBHe6TWlg8ODmhvb+8H22/gjSbZRpnCXSRUxxundT6JRELC+Wgv"
            "sQZrYWMvDhkK58PIyEizvMm4aOPj4zJUqBwkVsfdeWr3o73DXKzBWvT5HolisUixWOwz95+ApBm3eHDwtSQJBAJyIhKs469P"
            "jxIFtFc6T5gLW6+NRqOCqxVkW9zvdZAM1pxkdHT0O/efy3BBi/5HuIaHh20SYBdahMqoReJ5LwFdY3urr6+vV5Ms17CEaX9/"
            "n7LZLLQtMzMz81SSQK6hpjW6jOLq6opmZ2cvuP9+amqqxZZmyHU+n7d164GyQsfHx2JnZwd2jg8Q49ZrC+TS0lKPZVkX6U9S"
            "IK0HCCRlMhlxfn5OnIcSe/xxYGAg7JQVSbS5uTlXLpdJKbGl41xF6m0CwzBofn4e35+vr/iBF+6PVh0PNjBBnGNqQk0hdurj"
            "JPRmbiAHCBE8UATfeP9pbhsrfX5B5OeF73hhgYuBcrmc/vwKXDIANsoUVYQkIwcIkfJgurW1taXajwSIfIwI5BpqCrHD5cIt"
            "BmDjHqBMVRXlkAMVokai6n8rdp7wPYBcQ00hdtAiSIW6ydClDMoUVYQk6xz8C4lNJuUaagqxg0wwcJNx0eQ9qLC5xl/JL2N6"
            "nHl7YAAAAABJRU5ErkJggg==";
        NSString *retina =
            @"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";
        NSString *encoding = [self chooseImage:standard orDoubleDensityImage:retina];
        GADIntrinsicImageCache.close = [self createImageFromEncoding:encoding];
        [GADIntrinsicImageCache.close retain];
    }
    return GADIntrinsicImageCache.close;
}

+ (UIImage *)screenshotOfView:(UIView *)view
{
    UIGraphicsBeginImageContext([view bounds].size);
    [[view layer] renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@end

@interface GADViewUtilities : NSObject @end

@implementation GADViewUtilities

+ (NSDictionary *)positionOf:(UIView *)view in:(UIScreen *)screen
{
    CGRect display = [screen applicationFrame];
    if (![view superview] || ![view window])
        return nil;
    CGRect local = [[view superview] convertRect:[view frame] toView:nil];
    CGRect frame = [[view window] convertRect:local toWindow:nil];
    BOOL visible = YES;
    if ([view isHidden] || frame.origin.x + [view frame].size.width <= 0 ||
        frame.origin.y + [view frame].size.height <= 0 ||
        frame.origin.x > display.size.width || frame.origin.y > display.size.height)
        visible = NO;
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:frame.origin.x], @"x",
        [NSNumber numberWithFloat:frame.origin.y], @"y",
        [NSNumber numberWithFloat:frame.size.width], @"width",
        [NSNumber numberWithFloat:frame.size.height], @"height",
        [NSNumber numberWithBool:visible], @"visible", nil];
}

@end
