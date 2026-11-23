#pragma once

#import <UIKit/UIKit.h>
#include <string.h>

// The original SDK uses three 32-bit words for a logical size, including the
// flags that distinguish fixed and smart banners.
typedef struct GADAdSize { CGSize size; unsigned int flags; } GADAdSize;

extern GADAdSize GADAdSizeFromCGSize(CGSize size);
extern BOOL GADAdSizeEqualToSize(GADAdSize first, GADAdSize second);
extern CGSize CGSizeFromGADAdSize(GADAdSize size);
extern BOOL IsGADAdSizeValid(GADAdSize size);
extern NSString *NSStringFromGADAdSize(GADAdSize size);

@interface GADAdType : NSObject
+ (id)interstitialAdType;
+ (id)bannerAdTypeForSize:(GADAdSize)size;
- (GADAdSize)adSize;
- (BOOL)isInterstitial;
- (BOOL)isValid;
@end

@interface GADRequestError : NSObject
+ (id)errorWithCode:(int)code customMessage:(NSString *)reason;
+ (id)errorWithCode:(int)code request:(id)request;
@end
@interface GADMacros : NSObject
+ (NSDictionary *)readJsonIntoDictionary:(id)text;
+ (void)pubLog:(NSString *)message;
@end
@interface GADMAdapterGoogleAdMobAds : NSObject @end
@interface GADPublisherToolbarCredentials : NSObject
+ (BOOL)hasToolbarCredentials;
@end
@interface GADViewUtilities : NSObject
+ (id)positionOf:(UIView *)view in:(UIScreen *)screen;
@end
@interface GADApplication : NSObject
+ (id)sharedApplication;
- (BOOL)isAppActive;
@end
@interface GADDevice : NSObject
+ (BOOL)osIsSupported;
+ (BOOL)isOSAtLeastMajor:(int)major minor:(int)minor bug:(int)patch;
@end

@interface GADWebView : UIWebView
- (void)setAdDebugDialog:(NSString *)dialog;
- (void)setTouched:(BOOL)touched;
- (BOOL)touched;
- (UIViewController *)viewController;
@end
@class GADSlot;

@interface GADOpener : NSObject
- (void)setSlot:(GADSlot *)slot;
- (void)setDelegate:(id)delegate;
- (void)setDelegateManager:(id)manager;
- (void)setViewController:(UIViewController *)controller;
- (void)setReferringURL:(NSURL *)url;
- (void)openBrowserToURL:(NSURL *)url supportedOrientations:(int)orientations;
@end
@interface GADWebViewDelegate : NSObject <UIWebViewDelegate>
- (GADOpener *)opener;
- (void)addGMSGHandler:(id)handler;
@end
@interface GADBannerWebViewDelegate : GADWebViewDelegate {
    GADSlot *_slot;
}
- (id)initWithSlot:(GADSlot *)slot;
@end
@interface GADMConfig : NSObject
- (id)initWithAppKey:(NSString *)key configDict:(NSDictionary *)config error:(NSError **)error;
- (GADAdType *)adType;
- (void)setAdType:(GADAdType *)type;
- (double)refreshInterval;
@end
@interface GADSlotStatistics : NSObject
- (void)startTimingNamed:(NSString *)name withExplicitEnd:(BOOL)explicitEnd;
- (void)setIdentifier:(NSString *)identifier;
- (void)endTimingNamed:(NSString *)name;
- (NSURL *)updateStatsAndReturnSpamClickURL:(NSURL *)url;
@end
@interface GADMToGADGlue : NSObject
- (void)setSlot:(id)slot;
- (BOOL)changeAdTypeTo:(id)type;
- (void)requestAdWithType:(id)type mediationConfig:(GADMConfig *)config;
@end
@interface GADTiming : NSObject
+ (double)counter;
- (id)initWithCategory:(NSString *)category;
@end
@interface GADDelegateManager : NSObject
- (void)didReceiveAd;
@end
@interface GADActivationView : UIWebView @end
@interface GADActivationViewDelegate : NSObject <UIWebViewDelegate>
- (void)setSlot:(id)slot;
@end
@interface GADSharedStatistics : NSObject
+ (id)sharedInstance;
- (id)timingNamed:(NSString *)name;
- (void)startTimingNamed:(NSString *)name withExplicitEnd:(BOOL)explicitEnd;
- (void)incrementAdRequestCount;
- (void)incrementParameterCount:(NSString *)name;
- (void)resetParameterCount:(NSString *)name;
@end
@interface GADRequestPrivate : NSObject
- (NSDictionary *)networkExtrasAdditionalParameters;
@end
@interface GADMRAIDInterceptor : NSObject
+ (void)allow;
@end
@interface GADJavaScriptController : NSObject
+ (id)sharedInstance;
- (void)executeJavaScriptFileFromURL:(NSString *)url withDelegate:(id)delegate;
@end
@interface GADAd : NSObject
- (id)initWithDictionary:(NSDictionary *)dictionary;
+ (id)adWithDictionary:(NSDictionary *)data;
- (void)setAdURL:(NSURL *)url;
- (void)setActivationOverlayURL:(NSURL *)url;
- (NSArray *)clickURLs;
- (NSArray *)impressionURLs;
- (NSArray *)manualImpressionURLs;
- (int)supportedOrientations;
- (NSString *)debugDialog;
@end
@interface GADAdInterstitial : GADAd @end
@interface GADAdBanner : GADAd {
    double _refreshInterval;
}
- (GADAdSize)size;
- (double)refreshInterval;
@end
@interface GADAdFetcher : NSObject
- (void)cancel;
- (void)fetchRemainingContentForAd:(GADAd *)ad headers:(NSDictionary *)headers
        delegate:(id)delegate request:(id)request error:(NSError **)error;
@end
extern NSString *const kGADParameterBufferedAdsShownOfflineCount;
extern NSString *const kGADParameterBufferedAdsShownOnlineCount;
extern NSString *const kGADParameterOfflineAdRequestsCount;
extern NSString *const kGADParameterPriorRequestLatency;
extern NSString *const kGADParameterPriorPreClickLatency;
extern NSString *const kGADParameterPriorRequestNetworkLatency;
extern NSString *const kGADParameterAdSlotID;
extern NSString *const kGADParameterAdFormat;
extern NSString *const kGADParameterXFPValidAdSizes;
extern NSString *const kGADParameterAdFrame;
extern NSString *const kGADParameterAdBounds;
extern NSString *const kGADParameterSmartWidth;
extern NSString *const kGADParameterSmartHeight;
extern NSString *const kGADParameterRequestId;
extern NSString *const kGADParameterAdPositionData;
extern NSString *const kGADParameterSwipeable;
extern NSString *const kGADParameterDebugPublisherToolbar;
extern NSString *const kGADParameterCalledLoadAndDisplayRequest;
extern NSString *const kGADParameterEnableManualImpressions;
extern const GADAdSize kGADAdSizeInvalid;
extern BOOL GADAdSizeIsFullWidth(GADAdSize size);
extern BOOL GADAdSizeIsAutoHeight(GADAdSize size);
extern NSString *const kGADParameterTimeSinceFirstRequest;
extern NSString *const kGADAdMobExtrasKeyOrientation;
extern NSString *const kGADAdMobExtrasKeyRequestURL;
extern NSString *const kGADAdMobExtrasKeyActivationOverlayURL;

@class GADBannerView;
@interface GADSlot : NSObject {
    GADBannerView *_adView;
    id _rootViewController, _delegateManager, _adType, _adTimer, _requestPrivate;
    id _activationViewDelegate, _requestId;
    GADBannerWebViewDelegate *_webViewDelegate;
    GADAdFetcher *_adFetcher;
    GADMToGADGlue *_adMediationGlue;
    GADSlotStatistics *_slotStats;
    NSString *_adUnitID, *_adDebugDialog;
    NSMutableSet *_pendingClickURLs, *_pendingTrackingURLs, *_pendingManualTrackingURLs;
    NSTimer *_reloadTimer;
    GADWebView *_webView;
    GADActivationView *_activationView;
    BOOL _hasAutoRefreshed, _isMRAID, _shouldShowActivationOverlay;
    int _state, _supportedOrientations;
    CGSize _newAdSize;
}
- (id)initWithFrame:(CGRect)frame;
- (id)initWithView:(GADBannerView *)view;
- (CGSize)newAdSize;
- (void)setSupportedOrientations:(int)orientation;
- (void)setAdDebugDialog:(NSString *)dialog;
- (NSString *)adDebugDialog;
- (void)setViewForAdUsingView:(UIView *)view;
- (id)adSizeDelegate;
- (UIView *)activationView;
- (id)requestId;
- (BOOL)calledLoadAndDisplayRequest;
- (void)setCalledLoadAndDisplayRequest:(BOOL)flag;
- (BOOL)manualImpressionsEnabled;
- (id)adView;
@property(nonatomic, copy) NSString *adUnitID;
- (GADSlotStatistics *)slotStats;
- (GADAdType *)adType;
- (void)setAdType:(id)type andReloadRequest:(BOOL)reload;
- (GADAdFetcher *)adFetcher;
- (void)setAdFetcher:(id)fetcher;
- (id)adMediationGlue;
- (BOOL)isMediating;
- (void)loadRequest:(id)request;
- (void)loadPrivateRequest:(id)request autoRefresh:(BOOL)refresh;
- (id)requestPrivate;
- (void)setRequestPrivate:(GADRequestPrivate *)request;
- (void)notifyAdRequestHasStarted;
- (void)notifyAdRequestHasCompleted;
- (void)setTimeLastLoaded:(double)time;
- (double)timeLastLoaded;
- (int)supportedOrientations;
- (void)setReloadInterval:(double)interval;
- (double)reloadInterval;
- (GADWebView *)webView;
- (void)showAd:(NSString *)html withBaseURL:(NSURL *)url;
- (void)processMediationResponse:(id)response;
@property(nonatomic, retain) id delegateManager;
@end

@interface GADSlot (State)
- (void)setState:(int)state;
- (int)state;
@end

@interface GADBannerView : UIView {
    GADSlot *_slot;
}
@property(nonatomic, retain) GADSlot *slot;
- (id)rootViewController;
- (void)setRootViewController:(id)controller;
@end

@interface DFPBannerView : GADBannerView @end
@interface DFPSwipeableBannerView : DFPBannerView @end
@interface GADClickTrackerCollection : NSObject
+ (id)sharedInstance;
- (void)trackURLs:(NSArray *)urls;
@end

@interface NSObject (AdMobSlotMessages)
- (NSMutableDictionary *)parameters;
- (void)adView:(id)view willChangeAdSizeTo:(GADAdSize)size;
- (void)didFailToReceiveAdWithError:(id)error;
- (void)setIdentifier:(NSString *)identifier;
- (id)mediationManager;
- (id)receivedConnector;
- (id)networkConfig;
- (Class)adapterClass;
- (void)presentInterstitialFromRootViewController:(UIViewController *)controller;
- (void)cancelPendingAndFutureActions;
@end
