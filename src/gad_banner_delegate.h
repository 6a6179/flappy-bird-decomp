#pragma once

@class GADBannerView, GADRequestError;

@protocol GADBannerViewDelegate <NSObject>
@optional
- (void)adViewDidReceiveAd:(GADBannerView *)adView;
- (void)adView:(GADBannerView *)adView didFailToReceiveAdWithError:(GADRequestError *)error;
- (void)adViewWillPresentScreen:(GADBannerView *)adView;
- (void)adViewWillDismissScreen:(GADBannerView *)adView;
- (void)adViewDidDismissScreen:(GADBannerView *)adView;
- (void)adViewWillLeaveApplication:(GADBannerView *)adView;
@end
