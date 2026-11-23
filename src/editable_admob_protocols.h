// Objective-C protocols implemented or queried by the bundled Google Mobile Ads SDK.
#ifndef FLAP_EDITABLE_ADMOB_PROTOCOLS_H
#define FLAP_EDITABLE_ADMOB_PROTOCOLS_H

#import <UIKit/UIKit.h>

typedef struct GADAdSize {
    CGSize size;
    NSUInteger flags;
} GADAdSize;

@class ADBannerView, ADInterstitialAd, CTTelephonyNetworkInfo, DFPBannerView, DFPExtras, DFPInterstitial;
@class DFPSwipeableBannerView, GADAbsoluteTime, GADActionRouter, GADActivationView, GADActivationViewDelegate;
@class GADAd, GADAdBanner, GADAdFetcher, GADAdInterstitial, GADAdMobExtras, GADAdType, GADAdURLStash;
@class GADAppEventGMSGHandler, GADApplication, GADBadAdUtil, GADBannerView, GADBannerWebViewDelegate;
@class GADBrowserController, GADBrowserWebView, GADBrowserWebViewDelegate, GADCachedFile;
@class GADCachedURLResponse, GADClickTracker, GADClickTrackerCollection, GADCustomEventExtras;
@class GADCustomEventRequest, GADDefaultGMSGHandler, GADDelegateManager, GADDevice, GADGMSGHandler;
@class GADGestureIdUtil, GADGestureUtil, GADImpressionTicketGestureRecognizer;
@class GADImpressionTicketGestureRecognizerPrivate, GADInAppPurchase, GADInterstitial;
@class GADInterstitialAppController, GADIntrinsicImages, GADJavaScriptController, GADLocation, GADMAdManager;
@class GADMAdNetworkAdapter, GADMAdNetworkConfig, GADMAdNetworkConnector, GADMAdNetworkConnectorBanner;
@class GADMAdNetworkConnectorInterstitial, GADMAdSizeUtilities, GADMAdapterCustomEvents;
@class GADMAdapterGoogleAdMobAds, GADMAdapterHTML, GADMAdapterIAd, GADMConfig, GADMNSURLConnectionFactory;
@class GADMRAIDInterceptor, GADMToGADGlue, GADMUtilities, GADMWebViewRenderedChecker, GADMacros;
@class GADNetworkChecker, GADNetworkUtilities, GADNotification, GADNotificationCenter, GADOpener;
@class GADOpenerGMSGHandler, GADPublisherToolbarController, GADPublisherToolbarCredentials, GADRequest;
@class GADRequestError, GADRequestPrivate, GADSearchBannerView, GADSearchRequest, GADSearchRequestPrivate;
@class GADSearchSlot, GADSession, GADSharedStatistics, GADSlot, GADSlotStatistics, GADStatisticDictionary;
@class GADStatistics, GADStatisticsCore, GADTiming, GADTimingManager, GADUIWebViewGestureDelgate, GADURL;
@class GADURLConnection, GADViewController, GADViewUtilities, GADWebAppGMSGHandler, GADWebAppViewController;
@class GADWebAppWebViewDelegate, GADWebView, GADWebViewDelegate, GAD_GTMStringEncoding, GAD_SBJSON, NSArray;
@class NSData, NSDate, NSDictionary, NSError, NSLock, NSMutableArray, NSMutableData, NSMutableDictionary;
@class NSMutableSet, NSNotification, NSNumber, NSObject, NSRecursiveLock, NSString, NSTimer, NSURL;
@class NSURLConnection, NSURLRequest, NSURLResponse, NSUserDefaults, UIActivityIndicatorView, UIAlertView;
@class UIBarButtonItem, UIButton, UIColor, UIImage, UIImageView, UIToolbar, UIView, UIViewController;
@class UIWebView, UIWindow;

@protocol GADAdFetcherDelegate, GADAdNetworkExtras, GADAdSizeDelegate, GADAppEventDelegate;
@protocol GADBannerViewDelegate, GADCachedFileDelegate, GADClickTrackerDelegate, GADCustomEventBanner;
@protocol GADCustomEventBannerDelegate, GADCustomEventInterstitial, GADCustomEventInterstitialDelegate;
@protocol GADDeviceSpecifications, GADInAppPurchaseDelegate, GADInterstitialDelegate;
@protocol GADJavaScriptControllerDelegate, GADMAdNetworkAdapter, GADMAdNetworkConnector;
@protocol GADMAdNetworkConnectorCOPPAField, GADMConnectionFactory, GADMDelegate;
@protocol GADMWebViewRenderedCheckerDelegate, GADOpenerDelegate, GADStatisticDictionaryDelegate;
@protocol GADSwipeableBannerViewDelegate, GADURLConnectionDelegate, UIWebViewDelegate;

@protocol GADAdFetcherDelegate <NSObject>
- (void)addClickTrackingURLs:(NSArray *)values;
- (void)addTrackingURLs:(NSArray *)values;
- (void)addManualTrackingURLs:(NSArray *)values;
- (void)setRequestedOrientation:(int)requestedOrientation;
- (void)setRefreshInterval:(double)refreshInterval;
- (void)setIsMediating:(BOOL)isMediating;
- (BOOL)isMediating;
- (void)setAdDebugDialog:(NSString *)adDebugDialog;
- (void)setNewAdSize:(CGSize)newAdSize;
- (void)handleAdResponse:(NSString *)string withBaseURL:(NSURL *)baseURL;
- (void)handleActivationOverlayResponse:(NSString *)string withBaseURL:(NSURL *)baseURL;
- (void)didFailToReceiveAdWithError:(GADRequestError *)error;
- (void)didDisableScrollingAndActivationOverlay:(BOOL)value;
@end

@protocol GADAdNetworkExtras <NSObject>
@end

#import "gad_banner_delegate.h"

@protocol GADCachedFileDelegate
- (NSError *)cachedFile:(GADCachedFile *)cachedFile shouldRedirectToURL:(NSURL *)shouldRedirectToURL;
- (void)cachedFileDownloadDidEnd:(GADCachedFile *)cachedFile;
- (void)cachedFile:(GADCachedFile *)cachedFile downloadDidFail:(NSError *)downloadDidFail;
@end

@protocol GADClickTrackerDelegate <NSObject>
@optional
- (void)tracker:(GADClickTracker *)tracker didRedirect:(NSURL *)didRedirect;
- (void)tracker:(GADClickTracker *)tracker didFailWithError:(NSError *)error;
@end

@protocol GADCustomEventBanner <NSObject>
- (void)requestBannerAd:(GADAdSize)size parameter:(NSString *)parameter label:(NSString *)label request:(GADCustomEventRequest *)request;
@property (nonatomic, assign) id<GADCustomEventBannerDelegate> delegate;
@end

@protocol GADCustomEventBannerDelegate <NSObject>
- (void)customEventBanner:(id<GADCustomEventBanner>)customEventBanner didReceiveAd:(UIView *)didReceiveAd;
- (void)customEventBanner:(id<GADCustomEventBanner>)customEventBanner didFailAd:(NSError *)error;
- (void)customEventBanner:(id<GADCustomEventBanner>)customEventBanner clickDidOccurInAd:(UIView *)clickDidOccurInAd;
- (void)customEventBannerWillPresentModal:(id<GADCustomEventBanner>)customEventBannerWillPresentModal;
- (void)customEventBannerWillDismissModal:(id<GADCustomEventBanner>)customEventBannerWillDismissModal;
- (void)customEventBannerDidDismissModal:(id<GADCustomEventBanner>)customEventBannerDidDismissModal;
- (void)customEventBannerWillLeaveApplication:(id<GADCustomEventBanner>)customEventBannerWillLeaveApplication;
@property (nonatomic, readonly) UIViewController *viewControllerForPresentingModalView;
@end

@protocol GADCustomEventInterstitial <NSObject>
- (void)requestInterstitialAdWithParameter:(NSString *)string label:(NSString *)label request:(GADCustomEventRequest *)request;
- (void)presentFromRootViewController:(UIViewController *)viewController;
@property (nonatomic, assign) id<GADCustomEventInterstitialDelegate> delegate;
@end

@protocol GADCustomEventInterstitialDelegate <NSObject>
- (void)customEventInterstitial:(id<GADCustomEventInterstitial>)customEventInterstitial didReceiveAd:(NSObject *)didReceiveAd;
- (void)customEventInterstitial:(id<GADCustomEventInterstitial>)customEventInterstitial didFailAd:(NSError *)error;
- (void)customEventInterstitialWillPresent:(id<GADCustomEventInterstitial>)customEventInterstitialWillPresent;
- (void)customEventInterstitialWillDismiss:(id<GADCustomEventInterstitial>)customEventInterstitialWillDismiss;
- (void)customEventInterstitialDidDismiss:(id<GADCustomEventInterstitial>)customEventInterstitialDidDismiss;
- (void)customEventInterstitialWillLeaveApplication:(id<GADCustomEventInterstitial>)customEventInterstitialWillLeaveApplication;
@end

@protocol GADDeviceSpecifications <NSObject>
@property (nonatomic, readonly, getter=isJailbroken) BOOL jailbroken;
@property (nonatomic, readonly) NSString *osVersion;
@property (nonatomic, readonly) NSString *deviceIdentifier;
@property (nonatomic, readonly) NSString *deviceModel;
@property (nonatomic, readonly) NSString *deviceSubmodel;
@property (nonatomic, readonly) NSString *locale;
@property (nonatomic, readonly) unsigned int audioRoute;
@property (nonatomic, readonly, getter=isOrientationLandscape) BOOL orientationLandscape;
@property (nonatomic, readonly) float screenDensity;
@property (nonatomic, readonly) CGSize screenSize;
@end

@protocol GADInterstitialDelegate <NSObject>
@optional
- (void)interstitialDidReceiveAd:(GADInterstitial *)interstitial;
- (void)interstitial:(GADInterstitial *)interstitial didFailToReceiveAdWithError:(GADRequestError *)error;
- (void)interstitialWillPresentScreen:(GADInterstitial *)interstitial;
- (void)interstitialWillDismissScreen:(GADInterstitial *)interstitial;
- (void)interstitialDidDismissScreen:(GADInterstitial *)interstitial;
- (void)interstitialWillLeaveApplication:(GADInterstitial *)interstitial;
@end

@protocol GADJavaScriptControllerDelegate
- (NSString *)jsBuildAdURL;
- (NSDictionary *)requestParameters;
- (void)loadAdURL:(NSNotification *)value;
- (void)invalidJavaScriptRequest;
- (void)failedJavaScriptFile;
- (void)setRequestId:(NSString *)requestId;
@end

@protocol GADMAdNetworkAdapter <NSObject>
- (id)initWithGADMAdNetworkConnector:(id<GADMAdNetworkConnector>)gADMAdNetworkConnector;
- (void)getBannerWithSize:(GADAdSize)size;
- (void)getInterstitial;
- (void)stopBeingDelegate;
- (BOOL)isBannerAnimationOK:(int)value;
- (void)presentInterstitialFromRootViewController:(UIViewController *)viewController;
+ (NSString *)adapterVersion;
+ (Class)networkExtrasClass;
@optional
- (void)changeAdSizeTo:(GADAdSize)size;
@end

@protocol GADMAdNetworkConnector <NSObject>
- (NSString *)publisherId;
- (NSDictionary *)credentials;
- (BOOL)testMode;
- (id<GADAdNetworkExtras>)networkExtras;
- (UIViewController *)viewControllerForPresentingModalView;
- (int)userGender;
- (NSDate *)userBirthday;
- (BOOL)userHasLocation;
- (float)userLatitude;
- (float)userLongitude;
- (float)userLocationAccuracyInMeters;
- (NSString *)userLocationDescription;
- (NSArray *)userKeywords;
- (void)adapter:(id<GADMAdNetworkAdapter>)adapter didReceiveAdView:(UIView *)didReceiveAdView;
- (void)adapter:(id<GADMAdNetworkAdapter>)adapter didFailAd:(NSError *)error;
- (void)adapter:(id<GADMAdNetworkAdapter>)adapter didReceiveInterstitial:(NSObject *)didReceiveInterstitial;
- (void)adapter:(id<GADMAdNetworkAdapter>)adapter didFailInterstitial:(NSError *)didFailInterstitial;
- (void)adapter:(id<GADMAdNetworkAdapter>)adapter clickDidOccurInBanner:(UIView *)view;
- (void)adapterWillPresentFullScreenModal:(id<GADMAdNetworkAdapter>)adapterWillPresentFullScreenModal;
- (void)adapterWillDismissFullScreenModal:(id<GADMAdNetworkAdapter>)adapterWillDismissFullScreenModal;
- (void)adapterDidDismissFullScreenModal:(id<GADMAdNetworkAdapter>)adapterDidDismissFullScreenModal;
- (void)adapterWillPresentInterstitial:(id<GADMAdNetworkAdapter>)adapterWillPresentInterstitial;
- (void)adapterWillDismissInterstitial:(id<GADMAdNetworkAdapter>)adapterWillDismissInterstitial;
- (void)adapterDidDismissInterstitial:(id<GADMAdNetworkAdapter>)adapterDidDismissInterstitial;
- (void)adapterWillLeaveApplication:(id<GADMAdNetworkAdapter>)adapterWillLeaveApplication;
@end

@protocol GADMAdNetworkConnectorCOPPAField
- (NSNumber *)childDirectedTreatment;
@end

@protocol GADMConnectionFactory <NSObject>
- (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate;
- (NSURLConnection *)newConnectionWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)startImmediately;
@end

@protocol GADMDelegate <NSObject>
- (UIViewController *)viewControllerForPresentingModalView;
- (void)gadmDidReceiveAd:(UIView *)view;
- (void)gadmDidReceiveInterstitial:(NSObject *)interstitial;
- (void)gadmDidFailToReceiveAdWithError:(GADRequestError *)error;
- (void)gadmBannerAdRefreshFailedWithError:(GADRequestError *)error;
- (void)gadmWillPresentFullScreenModal;
- (void)gadmWillDismissFullScreenModal;
- (void)gadmDidDismissFullScreenModal;
- (void)gadmWillPresentInterstitial;
- (void)gadmWillDismissInterstitial;
- (void)gadmDidDismissInterstitial;
- (void)gadmWillLeaveApplication;
- (BOOL)gadmTestMode;
- (id<GADAdNetworkExtras>)networkExtrasFor:(Class)value;
- (int)userGender;
- (NSDate *)userBirthday;
- (GADLocation *)userLocation;
- (NSArray *)userKeywords;
- (NSNumber *)childDirectedTreatment;
- (void)startTimingAdapter;
- (void)resetTimingAdapters;
- (void)endTimingAdapterWithExitCode:(int)exitCode;
- (NSString *)adapterDurationsParameter;
- (NSString *)adapterExitCodesParameter;
@end

@protocol GADMWebViewRenderedCheckerDelegate <NSObject>
- (void)webView:(UIWebView *)webView isRendered:(BOOL)rendered;
@end

@protocol GADOpenerDelegate
- (void)didOpenInApplication;
- (void)didLeaveApplication;
@end

@protocol GADURLConnectionDelegate
- (NSError *)connection:(GADURLConnection *)connection shouldRedirectToURL:(NSURL *)shouldRedirectToURL;
- (void)connection:(GADURLConnection *)connection loadDidReceiveRedirectResponse:(NSURLResponse *)loadDidReceiveRedirectResponse;
- (BOOL)connection:(GADURLConnection *)connection loadShouldUseCachedResponse:(NSURLResponse *)loadShouldUseCachedResponse;
- (void)connection:(GADURLConnection *)connection loadDidReceiveCachedResponse:(NSURLResponse *)loadDidReceiveCachedResponse;
- (void)connection:(GADURLConnection *)connection loadDidFinish:(NSString *)loadDidFinish baseURL:(NSURL *)baseURL;
- (void)connection:(GADURLConnection *)connection loadDidFail:(NSError *)loadDidFail httpStatusCode:(int)httpStatusCode;
@end

#endif
