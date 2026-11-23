#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

@protocol GADManagedAdDelegate <NSObject>
@optional
- (void)adViewDidReceiveAd:(id)view;
- (void)interstitialDidReceiveAd:(id)interstitial;
- (void)adView:(id)view didFailToReceiveAdWithError:(NSError *)error;
- (void)interstitial:(id)interstitial didFailToReceiveAdWithError:(NSError *)error;
- (void)adView:(id)view didReceiveAppEvent:(NSString *)name withInfo:(NSString *)info;
- (void)interstitial:(id)interstitial didReceiveAppEvent:(NSString *)name withInfo:(NSString *)info;
- (void)adViewDidActivateAd:(id)view;
- (void)adViewDidDeactivateAd:(id)view;
- (void)adViewWillPresentScreen:(id)view;
- (void)interstitialWillPresentScreen:(id)interstitial;
- (void)adViewWillDismissScreen:(id)view;
- (void)interstitialWillDismissScreen:(id)interstitial;
- (void)adViewDidDismissScreen:(id)view;
- (void)interstitialDidDismissScreen:(id)interstitial;
- (void)adViewWillLeaveApplication:(id)view;
- (void)interstitialWillLeaveApplication:(id)interstitial;
- (void)didReceiveInAppPurchase:(id)purchase;
@end

@interface GADDelegateManager : NSObject
- (id<GADManagedAdDelegate>)bannerDelegate;
- (id<GADManagedAdDelegate>)interstitialDelegate;
- (id<GADManagedAdDelegate>)SDKInterstitialDelegate;
- (id<GADManagedAdDelegate>)appEventDelegate;
- (id<GADManagedAdDelegate>)swipeDelegate;
- (id<GADManagedAdDelegate>)inAppPurchaseDelegate;
- (id)adView;
- (id)interstitial;
@end

void GADDelegateManagerDispatchSynchronouslyOnMainThreadWithBlock(dispatch_block_t block)
{
    if ([NSThread isMainThread])
        block();
    else
        dispatch_sync(dispatch_get_main_queue(), ^{
            GADDelegateManagerDispatchSynchronouslyOnMainThreadWithBlock(block);
        });
}

@implementation GADDelegateManager

// Delegates survive until the current autorelease pool drains. The dispatched
// block captures the two ad objects by reference, as in the shipped MRC code.
#define CAPTURE_AD_DELEGATES() \
    id<GADManagedAdDelegate> banner = [[[self bannerDelegate] retain] autorelease]; \
    id<GADManagedAdDelegate> sdk = [[[self SDKInterstitialDelegate] retain] autorelease]; \
    id<GADManagedAdDelegate> publisher = [[[self interstitialDelegate] retain] autorelease]; \
    __block id view = [self adView]; \
    __block id interstitial = [self interstitial]

#define FORWARD_AD_EVENT(bannerEvent, interstitialEvent) \
    CAPTURE_AD_DELEGATES(); \
    GADDelegateManagerDispatchSynchronouslyOnMainThreadWithBlock(^{ \
        if ([banner respondsToSelector:@selector(bannerEvent:)]) \
            [banner bannerEvent:view]; \
        if ([sdk respondsToSelector:@selector(interstitialEvent:)]) \
            [sdk interstitialEvent:interstitial]; \
        if ([publisher respondsToSelector:@selector(interstitialEvent:)]) \
            [publisher interstitialEvent:interstitial]; \
    })

- (void)didReceiveAd
{
    FORWARD_AD_EVENT(adViewDidReceiveAd, interstitialDidReceiveAd);
}

- (void)didFailToReceiveAdWithError:(NSError *)error
{
    CAPTURE_AD_DELEGATES();
    GADDelegateManagerDispatchSynchronouslyOnMainThreadWithBlock(^{
        if ([banner respondsToSelector:@selector(adView:didFailToReceiveAdWithError:)])
            [banner adView:view didFailToReceiveAdWithError:error];
        if ([sdk respondsToSelector:@selector(interstitial:didFailToReceiveAdWithError:)])
            [sdk interstitial:interstitial didFailToReceiveAdWithError:error];
        if ([publisher respondsToSelector:@selector(interstitial:didFailToReceiveAdWithError:)])
            [publisher interstitial:interstitial didFailToReceiveAdWithError:error];
    });
}

- (void)adView:(id)view didReceiveAppEvent:(NSString *)name withInfo:(NSString *)info
{
    id<GADManagedAdDelegate> delegate = [[[self appEventDelegate] retain] autorelease];
    if ([delegate respondsToSelector:@selector(adView:didReceiveAppEvent:withInfo:)])
        [delegate adView:view didReceiveAppEvent:name withInfo:info];
}

- (void)interstitial:(id)interstitial didReceiveAppEvent:(NSString *)name withInfo:(NSString *)info
{
    id<GADManagedAdDelegate> delegate = [[[self appEventDelegate] retain] autorelease];
    if ([delegate respondsToSelector:@selector(interstitial:didReceiveAppEvent:withInfo:)])
        [delegate interstitial:interstitial didReceiveAppEvent:name withInfo:info];
}

- (void)didActivateAd
{
    id<GADManagedAdDelegate> delegate = [[[self swipeDelegate] retain] autorelease];
    if ([delegate respondsToSelector:@selector(adViewDidActivateAd:)])
        [delegate adViewDidActivateAd:[self adView]];
}

- (void)didDeactivatedAd
{
    id<GADManagedAdDelegate> delegate = [[[self swipeDelegate] retain] autorelease];
    if ([delegate respondsToSelector:@selector(adViewDidDeactivateAd:)])
        [delegate adViewDidDeactivateAd:[self adView]];
}

- (void)willPresentScreen
{
    FORWARD_AD_EVENT(adViewWillPresentScreen, interstitialWillPresentScreen);
}

- (void)willDismissScreen
{
    FORWARD_AD_EVENT(adViewWillDismissScreen, interstitialWillDismissScreen);
}

- (void)didDismissScreen
{
    FORWARD_AD_EVENT(adViewDidDismissScreen, interstitialDidDismissScreen);
}

- (void)willLeaveApplication
{
    FORWARD_AD_EVENT(adViewWillLeaveApplication, interstitialWillLeaveApplication);
}

- (void)didReceiveInAppPurchase:(id)purchase
{
    id<GADManagedAdDelegate> delegate = [[[self inAppPurchaseDelegate] retain] autorelease];
    GADDelegateManagerDispatchSynchronouslyOnMainThreadWithBlock(^{
        if ([delegate respondsToSelector:@selector(didReceiveInAppPurchase:)])
            [delegate didReceiveInAppPurchase:purchase];
    });
}
@end
