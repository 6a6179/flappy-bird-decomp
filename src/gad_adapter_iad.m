#import <UIKit/UIKit.h>
#import <iAd/iAd.h>

typedef struct GADAdSize { CGSize size; NSUInteger flags; } GADAdSize;
extern CGSize CGSizeFromGADAdSize(GADAdSize size);
extern NSString *NSStringFromGADAdSize(GADAdSize size);
extern NSString *const kGADErrorDomain;

@interface NSObject (GADMIAdConnector)
- (void)adapter:(id)adapter didReceiveAdView:(UIView *)view;
- (void)adapter:(id)adapter didReceiveInterstitial:(id)interstitial;
- (void)adapter:(id)adapter didFailAd:(NSError *)error;
- (void)adapter:(id)adapter didFailInterstitial:(NSError *)error;
- (void)adapter:(id)adapter clickDidOccurInBanner:(UIView *)view;
- (void)adapterWillPresentInterstitial:(id)adapter;
- (void)adapterWillPresentFullScreenModal:(id)adapter;
- (void)adapterDidDismissFullScreenModal:(id)adapter;
- (void)adapterDidDismissInterstitial:(id)adapter;
- (void)adapterWillLeaveApplication:(id)adapter;
@end

@interface GADMAdapterIAd : NSObject <ADBannerViewDelegate, ADInterstitialAdDelegate> {
    id connector_;
    ADBannerView *adView_;
    ADInterstitialAd *interstitialAd_;
    BOOL useIOS6API_;
    GADAdSize adSize_;
}
@property(nonatomic) GADAdSize adSize;
- (BOOL)useIOS6API;
- (ADBannerView *)adView;
- (void)setAdView:(ADBannerView *)view;
@end

@implementation GADMAdapterIAd
@synthesize adSize = adSize_;

+ (NSString *)adapterVersion
{
    NSString *date = [NSString stringWithCString:"Oct  4 2012" encoding:NSASCIIStringEncoding];
    return [date stringByReplacingOccurrencesOfString:@" " withString:@""];
}

- (id)initWithGADMAdNetworkConnector:(id)connector
{
    if ((self = [super init])) {
        connector_ = connector;
        useIOS6API_ = [ADBannerView instancesRespondToSelector:@selector(initWithAdType:)];
    }
    return self;
}

- (BOOL)validPhoneSize:(GADAdSize)adSize
{
    CGSize size = CGSizeFromGADAdSize(adSize);
    return CGSizeEqualToSize(size, CGSizeMake(320, 50)) ||
           CGSizeEqualToSize(size, CGSizeMake(480, 32)) ||
           CGSizeEqualToSize(size, CGSizeMake(568, 32));
}

- (BOOL)validTabletSize:(GADAdSize)adSize
{
    CGSize size = CGSizeFromGADAdSize(adSize);
    return CGSizeEqualToSize(size, CGSizeMake(768, 66)) ||
           CGSizeEqualToSize(size, CGSizeMake(1024, 66)) ||
           CGSizeEqualToSize(size, CGSizeMake(768, 90)) ||
           CGSizeEqualToSize(size, CGSizeMake(1024, 90)) ||
           (CGSizeEqualToSize(size, CGSizeMake(300, 250)) && [self useIOS6API]);
}

- (BOOL)usePortraitIdentifier
{
    CGSize portraitPhoneSize = CGSizeMake(320, 50);
    CGSize portraitTabletSize = CGSizeMake(768, 66);
    CGSize admobPortraitTabletSize = CGSizeMake(768, 90);

    CGSize cgSize = CGSizeFromGADAdSize([self adSize]);
    return CGSizeEqualToSize(cgSize, portraitPhoneSize) ||
           CGSizeEqualToSize(cgSize, portraitTabletSize) ||
           CGSizeEqualToSize(cgSize, admobPortraitTabletSize);
}

- (void)getBannerWithSize:(GADAdSize)size
{
    if (!NSClassFromString(@"ADBannerView")) {
        NSString *message = @"iAd Framework not present, are you running on iOS 3.x or below?";
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        NSError *error = [NSError errorWithDomain:kGADErrorDomain code:10 userInfo:info];
        [connector_ adapter:self didFailAd:error];
        return;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && ![self validTabletSize:size]) {
        NSString *message = [NSString stringWithFormat:@"Invalid size (%@) for iAd on tablet.", NSStringFromGADAdSize(size)];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        NSError *error = [NSError errorWithDomain:kGADErrorDomain code:10 userInfo:info];
        [connector_ adapter:self didFailAd:error];
        return;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && ![self validPhoneSize:size]) {
        NSString *message = [NSString stringWithFormat:@"Invalid size (%@) for iAd on phone.", NSStringFromGADAdSize(size)];
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:message, NSLocalizedDescriptionKey, nil];
        NSError *error = [NSError errorWithDomain:kGADErrorDomain code:10 userInfo:info];
        [connector_ adapter:self didFailAd:error];
        return;
    }
    ADBannerView *banner;
    if ([self useIOS6API]) {
        BOOL rectangle = CGSizeEqualToSize(CGSizeFromGADAdSize(size), CGSizeMake(300, 250));
        if (rectangle) {
            banner = [[[ADBannerView alloc] initWithAdType:ADAdTypeMediumRectangle] autorelease];
        } else {
            banner = [[[ADBannerView alloc] initWithAdType:ADAdTypeBanner] autorelease];
            [banner setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
        }
    } else {
        banner = [[[ADBannerView alloc] initWithFrame:CGRectZero] autorelease];
        [banner setRequiredContentSizeIdentifiers:[NSSet setWithObjects:
                ADBannerContentSizeIdentifierPortrait, ADBannerContentSizeIdentifierLandscape, nil]];
    }
    [banner setDelegate:self];
    [self setAdView:banner];
    [self setAdSize:size];
    [self adjustADBannerToAdSize];
}

- (void)getInterstitial
{
    if (!NSClassFromString(@"ADInterstitialAd")) {
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                @"ADInterstitialAd not present, are you running on iOS 4.x or below?", NSLocalizedDescriptionKey, nil];
        NSError *error = [NSError errorWithDomain:kGADErrorDomain code:4 userInfo:info];
        [connector_ adapter:self didFailAd:error];
    } else if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                @"ADInterstitialAd can only be used on an iPad", NSLocalizedDescriptionKey, nil];
        NSError *error = [NSError errorWithDomain:kGADErrorDomain code:10 userInfo:info];
        [connector_ adapter:self didFailInterstitial:error];
    } else {
        interstitialAd_ = [[ADInterstitialAd alloc] init];
        [interstitialAd_ setDelegate:self];
    }
}

- (void)stopBeingDelegate
{
    [adView_ setDelegate:nil];
    [interstitialAd_ setDelegate:nil];
}

- (BOOL)isBannerAnimationOK:(int)animation
{
    return animation != 7;
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)controller
{
    [connector_ adapterWillPresentInterstitial:self];
    [interstitialAd_ presentFromViewController:controller];
}

- (void)changeAdSizeTo:(GADAdSize)size
{
    [self setAdSize:size];
    [self adjustADBannerToAdSize];
}

- (void)adjustADBannerToAdSize
{
    if ([self usePortraitIdentifier]) {
        [[self adView] setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierPortrait];
    } else {
        [[self adView] setCurrentContentSizeIdentifier:ADBannerContentSizeIdentifierLandscape];
    }
}

- (void)dealloc
{
    [self stopBeingDelegate];
    [adView_ release];
    adView_ = nil;
    [interstitialAd_ release];
    interstitialAd_ = nil;
    [super dealloc];
}

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
    [[self adView] setHidden:NO];
    [connector_ adapter:self didReceiveAdView:banner];
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    [[self adView] setHidden:YES];
    [connector_ adapter:self didFailAd:error];
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
    [connector_ adapter:self clickDidOccurInBanner:banner];
    [connector_ adapterWillPresentFullScreenModal:self];
    return YES;
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner
{
    [connector_ adapterDidDismissFullScreenModal:self];
}

- (void)interstitialAdDidLoad:(ADInterstitialAd *)interstitial
{
    [connector_ adapter:self didReceiveInterstitial:interstitial];
}

- (void)interstitialAdDidUnload:(ADInterstitialAd *)interstitial
{
    [connector_ adapterDidDismissInterstitial:self];
    [interstitialAd_ setDelegate:nil];
    [interstitialAd_ release];
    interstitialAd_ = nil;
}

- (void)interstitialAd:(ADInterstitialAd *)interstitial didFailWithError:(NSError *)error
{
    [connector_ adapter:self didFailInterstitial:error];
    [interstitialAd_ setDelegate:nil];
    [interstitialAd_ release];
    interstitialAd_ = nil;
}

- (BOOL)interstitialAdActionShouldBegin:(ADInterstitialAd *)interstitial willLeaveApplication:(BOOL)willLeave
{
    if (willLeave) [connector_ adapterWillLeaveApplication:self];
    return YES;
}
@end
