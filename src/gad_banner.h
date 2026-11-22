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
@end
@interface GADBannerWebViewDelegate : NSObject <UIWebViewDelegate>
- (id)initWithSlot:(id)slot;
- (id)opener;
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
@interface GADDelegateManager : NSObject @end
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
@interface GADAdBanner : GADAd
- (GADAdSize)size;
- (double)refreshInterval;
@end
@interface GADAdFetcher : NSObject
- (void)cancel;
- (void)fetchRemainingContentForAd:(GADAd *)ad headers:(NSDictionary *)headers
        delegate:(id)delegate request:(id)request error:(NSError **)error;
@end
extern NSString *const GADOfflineBufferCount;
extern NSString *const GADOnlineBufferCount;
extern NSString *const GADOfflineAdRequestCount;
extern NSString *const GADTimingPRL;
extern NSString *const GADTimingPRNL;
extern NSString *const GADParamUnitID;
extern NSString *const GADParamFormat;
extern NSString *const GADParamSizes;
extern NSString *const GADParamFrame;
extern NSString *const GADParamBounds;
extern NSString *const GADParamSmartWidth;
extern NSString *const GADParamSmartHeight;
extern NSString *const GADParamRequestID;
extern NSString *const GADParamPosition;
extern NSString *const GADParamSwipeable;
extern NSString *const GADParamToolbar;
extern NSString *const GADParamLoadAndDisplay;
extern NSString *const GADParamManualImpression;
extern const GADAdSize kGADAdSizeInvalid;
extern BOOL GADAdSizeIsFullWidth(GADAdSize size);
extern BOOL GADAdSizeIsAutoHeight(GADAdSize size);
extern NSString *const GADTimingPTime;
extern NSString *const GADOrientationKey;
extern NSString *const GADRequestURLKey;
extern NSString *const GADActivationOverlayURLKey;

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
