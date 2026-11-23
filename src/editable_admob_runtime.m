// The implementations supply the original method bodies in separate translation units.
// Keep private superclass ivars out of subclass declarations, as in the original SDK.
#import "editable_admob_protocols.h"
#import <iAd/iAd.h>
#import <MessageUI/MessageUI.h>
#import <StoreKit/StoreKit.h>
#import <SystemConfiguration/SCNetworkReachability.h>

#pragma clang diagnostic ignored "-Wprotocol"
#pragma clang diagnostic ignored "-Wobjc-property-implementation"

// Several properties have hand-written accessors and no backing ivar.
#define SDK_CLASS __attribute__((objc_requires_property_definitions))
#define SDK_HIDDEN_CLASS SDK_CLASS __attribute__((visibility("hidden")))

SDK_HIDDEN_CLASS
@interface GADAbsoluteTime : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADActionRouter : NSObject
@property (nonatomic, assign) id receiver;
@property (nonatomic, readonly) NSMutableDictionary *cachedActions;
@end

SDK_HIDDEN_CLASS
@interface GADActivationView : UIWebView <GADOpenerDelegate>
@end

SDK_HIDDEN_CLASS
@interface GADActivationViewDelegate : NSObject <UIWebViewDelegate>
@property (nonatomic, assign) GADSlot *slot;
@end

SDK_HIDDEN_CLASS
@interface GADAd : NSObject
@property (nonatomic, copy) NSURL *adBaseURL;
@property (nonatomic, copy) NSString *adHTML;
@property (nonatomic, copy) NSURL *adURL;
@property (nonatomic, copy) NSURL *activationOverlayBaseURL;
@property (nonatomic, copy) NSString *activationOverlayHTML;
@property (nonatomic, copy) NSURL *activationOverlayURL;
@property (nonatomic, copy) NSArray *clickURLs;
@property (nonatomic, copy) NSArray *impressionURLs;
@property (nonatomic, copy) NSArray *manualImpressionURLs;
@property (nonatomic) GADAdSize size;
@property (nonatomic) int supportedOrientations;
@property (nonatomic, getter=isActivationAndScrollEnabled) BOOL activationAndScrollEnabled;
@property (nonatomic, copy) NSString *debugDialog;
@end

SDK_HIDDEN_CLASS
@interface GADAdFetcher : NSObject <GADURLConnectionDelegate>
@property (nonatomic, retain) NSRecursiveLock *recursiveLock;
@property (nonatomic, retain) GADRequestPrivate *request;
@property (nonatomic, assign) id<GADAdFetcherDelegate> delegate;
@property (nonatomic, retain) GADTiming *timer;
@property (nonatomic, retain) GADURLConnection *adConnection;
@property (nonatomic, retain) GADURLConnection *activationOverlayConnection;
@property (nonatomic, copy) NSString *activationOverlayHTML;
@property (nonatomic, copy) NSURL *activationOverlayBaseURL;
@property (nonatomic) BOOL shouldLoadActivationOverlay;
@property (nonatomic, copy) NSString *adResponse;
@property (nonatomic, copy) NSURL *adBaseURL;
@property (nonatomic) BOOL adConnectionHasCompleted;
@property (nonatomic) BOOL activationOverlayConnectionHasCompleted;
@property (nonatomic) BOOL *wasDeallocated;
@end

SDK_HIDDEN_CLASS
@interface GADAdMobExtras : NSObject <GADAdNetworkExtras>
@property (nonatomic, copy) NSDictionary *additionalParameters;
@end

SDK_HIDDEN_CLASS
@interface GADAdType : NSObject
@property (nonatomic, readonly) BOOL isInterstitial;
@property (nonatomic) GADAdSize adSize;
@end

SDK_HIDDEN_CLASS
@interface GADAdURLStash : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADApplication : NSObject
@property (nonatomic, retain) GADSession *currentSession;
@property (nonatomic) BOOL appFinishedLaunching;
@end

SDK_HIDDEN_CLASS
@interface GADBadAdUtil : NSObject <GADURLConnectionDelegate>
@property (nonatomic, retain) GADURLConnection *connection;
@end

SDK_HIDDEN_CLASS
@interface GADBannerView : UIView
@property (nonatomic, copy) NSString *adUnitID;
@property (nonatomic, assign) UIViewController *rootViewController;
@property (nonatomic) GADAdSize adSize;
@property (nonatomic, assign) NSObject<GADBannerViewDelegate> *delegate;
@property (nonatomic, readonly) BOOL hasAutoRefreshed;
@property (nonatomic, readonly) UIView *mediatedAdView;
@property (nonatomic, readonly) NSString *adNetworkClassName;
@property (nonatomic, readonly) GADWebView *webView;
@property (nonatomic, retain) GADSlot *slot;
@end

SDK_HIDDEN_CLASS
@interface GADCachedFile : NSObject
@property (nonatomic, assign) id<GADCachedFileDelegate> delegate;
@property (nonatomic, retain) NSDictionary *userInfo;
@property (nonatomic, retain) NSURL *sourceURL;
@property (nonatomic, readonly) NSData *contentAsData;
@property (nonatomic, readonly) NSString *contentAsString;
@property (nonatomic, readonly) UIImage *contentAsImage;
@property (nonatomic, readonly) NSString *filePath;
@property (nonatomic, readonly) BOOL fileExists;
@property (nonatomic, readonly) NSString *fileModificationDate;
@property (nonatomic, retain) NSURL *httpDestinationURL;
@property (nonatomic, readonly) int httpStatusCode;
@property (nonatomic, readonly) NSDictionary *httpHeaders;
@end

SDK_HIDDEN_CLASS
@interface GADCachedURLResponse : NSCachedURLResponse <NSCoding>
@property (nonatomic, retain) NSDate *expireDate;
@property (nonatomic, retain) NSURL *destinationURL;
@end

SDK_HIDDEN_CLASS
@interface GADClickTracker : NSObject <GADCachedFileDelegate>
@property (nonatomic, assign) id<GADClickTrackerDelegate> delegate;
@property (nonatomic, readonly) BOOL hasTracked;
@property (nonatomic, readonly) NSURL *trackingURL;
@end

SDK_HIDDEN_CLASS
@interface GADClickTrackerCollection : NSObject <GADClickTrackerDelegate>
@end

SDK_HIDDEN_CLASS
@interface GADCustomEventExtras : NSObject <GADAdNetworkExtras>
@property (nonatomic, retain) NSMutableDictionary *extras;
@end

SDK_HIDDEN_CLASS
@interface GADCustomEventRequest : NSObject
@property (nonatomic, readonly) int userGender;
@property (nonatomic, readonly) NSDate *userBirthday;
@property (nonatomic, readonly) BOOL userHasLocation;
@property (nonatomic, readonly) float userLatitude;
@property (nonatomic, readonly) float userLongitude;
@property (nonatomic, readonly) float userLocationAccuracyInMeters;
@property (nonatomic, readonly) NSString *userLocationDescription;
@property (nonatomic, readonly) NSArray *userKeywords;
@property (nonatomic, readonly) NSDictionary *additionalParameters;
@property (nonatomic, readonly) BOOL isTesting;
@end

SDK_HIDDEN_CLASS
@interface GADDelegateManager : NSObject
@property (nonatomic, assign) id<GADBannerViewDelegate> bannerDelegate;
@property (nonatomic, assign) GADBannerView *adView;
@property (nonatomic, assign) id<GADInterstitialDelegate> interstitialDelegate;
@property (nonatomic, assign) GADInterstitial *interstitial;
@property (nonatomic, assign) id<GADInterstitialDelegate> SDKInterstitialDelegate;
@property (nonatomic, assign) id<GADAppEventDelegate> appEventDelegate;
@property (nonatomic, assign) id<GADSwipeableBannerViewDelegate> swipeDelegate;
@property (nonatomic, assign) id<GADInAppPurchaseDelegate> inAppPurchaseDelegate;
@end

SDK_HIDDEN_CLASS
@interface GADDevice : NSObject <GADDeviceSpecifications>
@property (nonatomic, retain) NSUserDefaults *userDefaults;
@property (nonatomic, retain) CTTelephonyNetworkInfo *telephonyNetworkInfo;
@property (nonatomic, copy) NSString *cachedAdvertisingID;
@property (nonatomic, copy) NSString *cachedMD5AdvertisingID;
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

SDK_HIDDEN_CLASS
@interface GADGMSGHandler : NSObject
@property (nonatomic, retain) GADActionRouter *actionRouter;
@end

SDK_CLASS
@interface GADGestureIdUtil : NSObject
@property (nonatomic, retain) NSUserDefaults *userDefaults;
@end

SDK_CLASS
@interface GADGestureUtil : UIViewController
@end

SDK_HIDDEN_CLASS
@interface GADImpressionTicketGestureRecognizer : UIGestureRecognizer
@property (nonatomic) int gestureState;
@property (nonatomic) unsigned int distanceMoved;
@property (nonatomic, retain) GADImpressionTicketGestureRecognizerPrivate *vars;
@end

SDK_HIDDEN_CLASS
@interface GADImpressionTicketGestureRecognizerPrivate : NSObject
@property (nonatomic) int gestureState;
@property (nonatomic) unsigned int distanceMoved;
@end

SDK_HIDDEN_CLASS
@interface GADInAppPurchase : NSObject
@property (nonatomic, copy) NSString *productID;
@property (nonatomic) unsigned int quantity;
@end

SDK_HIDDEN_CLASS
@interface GADInterstitial : NSObject
@property (nonatomic, copy) NSString *adUnitID;
@property (nonatomic, assign) NSObject<GADInterstitialDelegate> *delegate;
@property (nonatomic, readonly) BOOL isReady;
@property (nonatomic) BOOL hasBeenUsed;
@property (nonatomic, readonly) NSString *adNetworkClassName;
@property (nonatomic, retain) GADRequest *request;
@property (nonatomic, retain) GADWebAppViewController *viewController;
@property (nonatomic, retain) GADSlot *slot;
@end

SDK_HIDDEN_CLASS
@interface GADInterstitialAppController : UIViewController <GADInterstitialDelegate>
@property (nonatomic, retain) UIViewController *originalRootViewController;
@end

SDK_HIDDEN_CLASS
@interface GADIntrinsicImages : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADJavaScriptController : NSObject <GADCachedFileDelegate>
@property (nonatomic) BOOL shouldCheckOreoID;
@property (nonatomic, retain) GADCachedFile *buildAdJS;
@property (nonatomic, retain) UIWebView *buildAdWebView;
@end

SDK_HIDDEN_CLASS
@interface GADLocation : NSObject <NSCopying>
@property (nonatomic, readonly) BOOL isPreciseLocation;
@property (nonatomic, readonly) float latitude;
@property (nonatomic, readonly) float longitude;
@property (nonatomic, readonly) float accuracy;
@property (nonatomic, readonly) NSString *description;
@property (nonatomic, readonly) NSDictionary *dictionaryRepresentation;
@property (nonatomic) double timestamp;
@end

SDK_HIDDEN_CLASS
@interface GADMAdManager : NSObject
@property (nonatomic, assign) id<GADMDelegate> delegate;
@property (nonatomic, retain) GADMConfig *config;
@property (nonatomic, retain) GADAdType *adType;
@property (nonatomic, retain) GADMAdNetworkConnector *requestingConnector;
@property (nonatomic, retain) GADMAdNetworkConnector *receivedConnector;
@property (nonatomic, retain) NSDate *lastRequestTime;
@property (nonatomic) BOOL requestInProgress;
@property (nonatomic, assign) NSTimer *adNetworkTimeoutTimer;
@end

SDK_HIDDEN_CLASS
@interface GADMAdNetworkAdapter : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADMAdNetworkConfig : NSObject
@property (nonatomic, copy) NSString *networkID;
@property (nonatomic, readonly) NSString *publisherID;
@property (nonatomic, copy) NSDictionary *credentials;
@property (nonatomic, copy) NSDictionary *extras;
@property (nonatomic, copy) NSDictionary *ad;
@property (nonatomic, copy) NSArray *adapterList;
@property (nonatomic) Class adapterClass;
@property (nonatomic, copy) NSString *allocationID;
@property (nonatomic, copy) NSArray *impressionURLs;
@end

SDK_HIDDEN_CLASS
@interface GADMAdNetworkConnector : NSObject <GADMAdNetworkConnector, GADMAdNetworkConnectorCOPPAField>
@property (nonatomic, assign) id<GADMDelegate> gadmDelegate;
@property (nonatomic, assign) GADMAdManager *adManager;
@property (nonatomic, retain) GADMConfig *mediationConfig;
@property (nonatomic, retain) GADMAdNetworkConfig *networkConfig;
@property (nonatomic, retain) id<GADMAdNetworkAdapter> adapter;
@property (nonatomic) BOOL didNetworkRefresh;
@end

SDK_HIDDEN_CLASS
@interface GADMAdSizeUtilities : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADMAdapterCustomEvents : NSObject <GADMAdNetworkAdapter, GADCustomEventBannerDelegate, GADCustomEventInterstitialDelegate>
@property (nonatomic, assign) id<GADMAdNetworkConnector> connector;
@property (nonatomic, retain) id<GADCustomEventBanner> customEventBanner;
@property (nonatomic, retain) id<GADCustomEventInterstitial> customEventInterstitial;
@property (nonatomic, readonly) UIViewController *viewControllerForPresentingModalView;
@end

SDK_HIDDEN_CLASS
@interface GADMAdapterGoogleAdMobAds : NSObject <GADMAdNetworkAdapter, GADBannerViewDelegate, GADInterstitialDelegate>
@property (nonatomic, retain) GADBannerView *banner;
@property (nonatomic, retain) GADInterstitial *interstitial;
@property (nonatomic, assign) id<GADMAdNetworkConnector, GADMAdNetworkConnectorCOPPAField> connector;
@end

SDK_CLASS
@interface GADMAdapterHTML : NSObject <GADMAdNetworkAdapter, GADMWebViewRenderedCheckerDelegate, UIWebViewDelegate>
@property (nonatomic, assign) id<GADMAdNetworkConnector> connector;
@property (nonatomic, retain) UIWebView *webView;
@property (nonatomic, retain) NSURL *passbackUrl;
@end

SDK_CLASS
@interface GADMAdapterIAd : NSObject <GADMAdNetworkAdapter, ADBannerViewDelegate, ADInterstitialAdDelegate>
@property (nonatomic, assign) id<GADMAdNetworkConnector> connector;
@property (nonatomic, retain) ADBannerView *adView;
@property (nonatomic, retain) ADInterstitialAd *interstitialAd;
@property (nonatomic) GADAdSize adSize;
@property (nonatomic) BOOL useIOS6API;
@end

SDK_HIDDEN_CLASS
@interface GADMConfig : NSObject
@property (nonatomic, copy) NSArray *adNetworkConfigs;
@property (nonatomic) double refreshInterval;
@property (nonatomic) int bannerAnimationType;
@property (nonatomic) double adNetworkTimeout;
@property (nonatomic, copy) NSArray *impressionURLs;
@property (nonatomic, copy) NSArray *clickURLs;
@property (nonatomic, copy) NSArray *noFillURLs;
@property (nonatomic, copy) NSString *qdata;
@property (nonatomic, retain) GADAdType *adType;
@property (nonatomic, copy) NSString *appKey;
@end

SDK_HIDDEN_CLASS
@interface GADMNSURLConnectionFactory : NSObject <GADMConnectionFactory>
@end

SDK_HIDDEN_CLASS
@interface GADMRAIDInterceptor : NSURLProtocol
@property (nonatomic, copy) NSString *mraidLocationToLoad;
@end

SDK_HIDDEN_CLASS
@interface GADMToGADGlue : NSObject <GADMDelegate>
@property (nonatomic, assign) GADSlot *slot;
@property (nonatomic, assign) id mediatedInterstitial;
@property (nonatomic, retain) GADMAdManager *mediationManager;
@property (nonatomic, retain) GADMConfig *mediationConfig;
@end

SDK_HIDDEN_CLASS
@interface GADMUtilities : NSObject
@end

SDK_CLASS
@interface GADMWebViewRenderedChecker : NSObject
@property (nonatomic, assign) UIWebView *webView;
@property (nonatomic, assign) id<GADMWebViewRenderedCheckerDelegate> delegate;
@end

SDK_HIDDEN_CLASS
@interface GADMacros : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADNetworkChecker : NSObject
@property (getter=isEnabled) BOOL enabled;
@property unsigned int networkType;
@property (nonatomic) SCNetworkReachabilityRef networkReachabilityRef;
@property (nonatomic, retain) NSRecursiveLock *lock;
@end

SDK_HIDDEN_CLASS
@interface GADNetworkUtilities : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADNotification : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSDictionary *parameters;
@end

SDK_HIDDEN_CLASS
@interface GADNotificationCenter : NSNotificationCenter
@end

SDK_HIDDEN_CLASS
@interface GADOpener : NSObject <MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate, SKStoreProductViewControllerDelegate>
@property (nonatomic, retain) GADDelegateManager *delegateManager;
@property (nonatomic, assign) UIViewController *viewController;
@property (nonatomic, retain) NSURL *referringURL;
@property (nonatomic, assign) GADWebView *webView;
@property (nonatomic, assign) GADSlot *slot;
@property (nonatomic) BOOL didOpenAnotherApplication;
@property (nonatomic, assign) id<GADOpenerDelegate> delegate;
@end

SDK_HIDDEN_CLASS
@interface GADPublisherToolbarCredentials : NSObject
@property (nonatomic, copy) NSDictionary *credentials;
@end

SDK_HIDDEN_CLASS
@interface GADRequest : NSObject <NSCopying>
@property (nonatomic, copy) NSDictionary *mediationExtras;
@property (nonatomic, copy) NSArray *testDevices;
@property (nonatomic) int gender;
@property (nonatomic, retain) NSDate *birthday;
@property (nonatomic, retain) NSMutableArray *keywords;
@property (nonatomic, copy) NSDictionary *additionalParameters;
@property (nonatomic, getter=isTesting) BOOL testing;
@end

SDK_HIDDEN_CLASS
@interface GADRequestError : NSError
@end

SDK_HIDDEN_CLASS
@interface GADSearchRequest : NSObject
@property (nonatomic, copy) NSString *query;
@property (nonatomic, readonly) UIColor *backgroundColor;
@property (nonatomic, readonly) UIColor *gradientFrom;
@property (nonatomic, readonly) UIColor *gradientTo;
@property (nonatomic, retain) UIColor *headerColor;
@property (nonatomic, retain) UIColor *descriptionTextColor;
@property (nonatomic, retain) UIColor *anchorTextColor;
@property (nonatomic, copy) NSString *fontFamily;
@property (nonatomic) int headerTextSize;
@property (nonatomic, retain) UIColor *borderColor;
@property (nonatomic) int borderType;
@property (nonatomic) int borderThickness;
@property (nonatomic, copy) NSString *customChannels;
@property (nonatomic) int callButtonColor;
@end

SDK_HIDDEN_CLASS
@interface GADSession : NSObject
@property (nonatomic) unsigned long long sessionID;
@end

SDK_HIDDEN_CLASS
@interface GADSlot : NSObject <GADJavaScriptControllerDelegate, GADAdFetcherDelegate>
@property (nonatomic) int state;
@property (nonatomic, copy) NSString *adUnitID;
@property (nonatomic, assign) UIViewController *rootViewController;
@property (nonatomic, assign) NSObject<GADAdSizeDelegate> *adSizeDelegate;
@property (nonatomic, readonly) BOOL hasAutoRefreshed;
@property (nonatomic, readonly) UIView *mediatedAdView;
@property (nonatomic, readonly) NSString *adNetworkClassName;
@property (nonatomic) BOOL manualImpressionsEnabled;
@property (nonatomic, retain) GADDelegateManager *delegateManager;
@property (nonatomic, retain) GADAdType *adType;
@property (nonatomic, copy) GADRequestPrivate *requestPrivate;
@property (nonatomic) double timeLastLoaded;
@property (nonatomic) BOOL isMRAID;
@property (nonatomic) BOOL isMediating;
@property (nonatomic) int supportedOrientations;
@property (nonatomic, retain) GADWebView *webView;
@property (nonatomic, retain) GADSlotStatistics *slotStats;
@property (nonatomic) BOOL calledLoadAndDisplayRequest;
@property (nonatomic, retain) GADBannerWebViewDelegate *webViewDelegate;
@property (nonatomic, retain) GADActivationView *activationView;
@property (nonatomic, retain) GADActivationViewDelegate *activationViewDelegate;
@property (nonatomic, retain) GADAdFetcher *adFetcher;
@property (nonatomic) double reloadInterval;
@property (nonatomic, retain) NSTimer *reloadTimer;
@property (nonatomic, copy) NSString *requestId;
@property (nonatomic, readonly) GADBannerView *adView;
@property (nonatomic, assign) GADInterstitial *interstitial;
@property (nonatomic) CGSize newAdSize;
@property (nonatomic, retain) GADMToGADGlue *adMediationGlue;
@property (nonatomic, copy) NSString *adDebugDialog;
@property (nonatomic) BOOL shouldShowActivationOverlay;
@property (nonatomic, retain) GADTiming *adTimer;
@end

SDK_HIDDEN_CLASS
@interface GADStatisticDictionary : NSObject
@property (nonatomic, assign) id<GADStatisticDictionaryDelegate> delegate;
@property (nonatomic) BOOL *wasDeallocated;
@property (nonatomic) struct dispatch_queue_s *queue;
@property (nonatomic) BOOL allowDictionaryModification;
@property (nonatomic) BOOL hasEnqueuedNotificationBlock;
@end

SDK_HIDDEN_CLASS
@interface GADStatistics : NSObject {
    GADStatisticsCore *_statistics;
    GADTimingManager *_timingMgr;
}
@end

SDK_HIDDEN_CLASS
@interface GADStatisticsCore : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, retain) NSUserDefaults *userDefaults;
@property (nonatomic, retain) NSArray *transientStats;
@property (nonatomic, copy) NSString *userDefaultsKey;
@property (nonatomic, retain) NSLock *lock;
@end

SDK_HIDDEN_CLASS
@interface GADTiming : NSObject <NSCopying>
@property (nonatomic, copy) NSString *category;
@property (nonatomic) BOOL explicitEnd;
@property (nonatomic) double startTimestamp;
@property (nonatomic) double endTimestamp;
@property (nonatomic, retain) NSLock *timeIntervalLock;
@end

SDK_HIDDEN_CLASS
@interface GADTimingManager : NSObject
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, readonly) NSArray *timings;
@property (nonatomic, readonly) NSArray *categories;
@property (nonatomic, retain) NSUserDefaults *userDefaults;
@property (nonatomic, retain) NSArray *transientTimings;
@property (nonatomic, readonly) NSString *userDefaultsKey;
@end

SDK_HIDDEN_CLASS
@interface GADUIWebViewGestureDelgate : NSObject <UIGestureRecognizerDelegate>
@end

SDK_HIDDEN_CLASS
@interface GADURL : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADURLConnection : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic) BOOL isInProgress;
@property (nonatomic, copy) NSURL *sourceURL;
@property (nonatomic, copy) NSURL *destinationURL;
@property (nonatomic) BOOL allowCache;
@property (nonatomic, assign) id<GADURLConnectionDelegate> delegate;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSURLResponse *response;
@property (nonatomic, retain) NSMutableData *receivedData;
@end

SDK_HIDDEN_CLASS
@interface GADViewController : UIViewController
@property (nonatomic, retain) GADDelegateManager *delegateManager;
@property (nonatomic) int supportedOrientations;
@property (nonatomic, readonly) UIViewController *parent;
@property (nonatomic) BOOL viewDidAppear;
@property (nonatomic, retain) GADSlot *slot;
@property (nonatomic) BOOL statusBarWasHidden;
@property (nonatomic) BOOL publisherIdleTimerDisabled;
@property (nonatomic) BOOL appClosing;
@property (nonatomic) BOOL interactingWithParent;
@property (nonatomic) BOOL wasPresentedFromViewController;
@end

SDK_HIDDEN_CLASS
@interface GADViewUtilities : NSObject
@end

SDK_HIDDEN_CLASS
@interface GADWebView : UIWebView <UIAlertViewDelegate>
@property (nonatomic, assign) UIViewController *viewController;
@property (nonatomic) BOOL touched;
@property (nonatomic, copy) NSString *adDebugDialog;
@property (nonatomic) BOOL showDebug;
@property (nonatomic) BOOL didReceiveLoadEvent;
@property (nonatomic) int orientation;
@property (nonatomic, retain) GADUIWebViewGestureDelgate *gestureDelegate;
@property (nonatomic, retain) GADImpressionTicketGestureRecognizer *gesture;
@property (nonatomic, retain) UIAlertView *alertView;
@property (nonatomic) BOOL savedState;
@property (nonatomic) CGRect savedFrame;
@property (nonatomic, retain) UIView *savedSuperview;
@property (nonatomic, retain) NSObject<UIWebViewDelegate> *savedDelegate;
@property (nonatomic, readonly) NSURL *url;
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, assign) UIViewController *viewControllerBeforeExpanded;
@end

SDK_HIDDEN_CLASS
@interface GADWebViewDelegate : NSObject <UIWebViewDelegate> {
    BOOL hasLoadedAtLeastOnce_;
}
@property (nonatomic, retain) GADOpener *opener;
@property (nonatomic, readonly) BOOL hasLoadedAtLeastOnce;
@property (nonatomic) BOOL allowFileAccess;
@property (nonatomic, readonly) NSMutableArray *gmsgHandlers;
@property (nonatomic, retain) GADOpenerGMSGHandler *openerGMSGHandler;
@end

SDK_HIDDEN_CLASS
@interface GAD_GTMStringEncoding : NSObject
@end

SDK_HIDDEN_CLASS
@interface GAD_SBJSON : NSObject
@property BOOL humanReadable;
@property BOOL sortKeys;
@property unsigned int maxDepth;
@end

SDK_HIDDEN_CLASS
@interface DFPBannerView : GADBannerView
@property (nonatomic, assign) NSObject<GADAppEventDelegate> *appEventDelegate;
@property (nonatomic, assign) NSObject<GADAdSizeDelegate> *adSizeDelegate;
@property (nonatomic, retain) NSArray *validAdSizes;
@property (nonatomic) BOOL enableManualImpressions;
@end

SDK_HIDDEN_CLASS
@interface DFPExtras : GADAdMobExtras
@property (nonatomic, copy) NSString *publisherProvidedID;
@end

SDK_HIDDEN_CLASS
@interface DFPInterstitial : GADInterstitial
@property (nonatomic, assign) NSObject<GADAppEventDelegate> *appEventDelegate;
@end

SDK_HIDDEN_CLASS
@interface GADAdBanner : GADAd
@property (nonatomic) double refreshInterval;
@end

SDK_HIDDEN_CLASS
@interface GADAdInterstitial : GADAd
@property (nonatomic) double interstitialTimeout;
@end

SDK_HIDDEN_CLASS
@interface GADAppEventGMSGHandler : GADGMSGHandler
@property (nonatomic, assign) GADSlot *slot;
@end

SDK_HIDDEN_CLASS
@interface GADBannerWebViewDelegate : GADWebViewDelegate
@property (nonatomic, readonly) GADSlot *slot;
@end

SDK_HIDDEN_CLASS
@interface GADBrowserController : GADViewController
@property (nonatomic, retain) NSURL *URLToLoad;
@property (nonatomic, retain) NSURL *referringURLToLoad;
@property (nonatomic, retain) GADWebViewDelegate *webViewDelegate;
@property (nonatomic, retain) GADWebView *webView;
@property (nonatomic, retain) UIToolbar *toolbar;
@property (nonatomic, retain) UIBarButtonItem *flexibleSpaceButton;
@property (nonatomic, retain) UIBarButtonItem *backButton;
@property (nonatomic, retain) UIBarButtonItem *backButtonDisabled;
@property (nonatomic, retain) UIBarButtonItem *forwardButton;
@property (nonatomic, retain) UIBarButtonItem *forwardButtonDisabled;
@property (nonatomic, retain) UIBarButtonItem *reloadButton;
@property (nonatomic, retain) UIBarButtonItem *safariButton;
@property (nonatomic, retain) UIBarButtonItem *doneButton;
@property (nonatomic, retain) UIBarButtonItem *spinnerContainingButton;
@property (nonatomic, retain) UIActivityIndicatorView *spinner;
@end

SDK_HIDDEN_CLASS
@interface GADBrowserWebView : GADWebView
@end

SDK_HIDDEN_CLASS
@interface GADBrowserWebViewDelegate : GADWebViewDelegate
@end

SDK_HIDDEN_CLASS
@interface GADDefaultGMSGHandler : GADGMSGHandler
@end

SDK_HIDDEN_CLASS
@interface GADMAdNetworkConnectorBanner : GADMAdNetworkConnector
@property (nonatomic) BOOL didNetworkReturn;
@end

SDK_HIDDEN_CLASS
@interface GADMAdNetworkConnectorInterstitial : GADMAdNetworkConnector
@property (nonatomic) BOOL calledWillDismissInterstitial;
@end

SDK_HIDDEN_CLASS
@interface GADOpenerGMSGHandler : GADGMSGHandler
@property (nonatomic, retain) GADOpener *gadOpener;
@property (nonatomic, retain) GADActionRouter *subParamActionRouter;
@end

SDK_HIDDEN_CLASS
@interface GADPublisherToolbarController : GADViewController <UIWebViewDelegate, GADCachedFileDelegate>
@property (nonatomic, retain) GADPublisherToolbarCredentials *credentials;
@property (nonatomic, retain) UIWebView *oauthWebView;
@property (nonatomic, retain) UIWebView *jsWebView;
@property (nonatomic, retain) UIActivityIndicatorView *spinnyWheel;
@property (nonatomic, retain) GADCachedFile *helperJS;
@property (nonatomic, copy) NSString *adUnitID;
@property (nonatomic, copy) NSString *adContent;
@end

SDK_HIDDEN_CLASS
@interface GADRequestPrivate : GADRequest
@property (nonatomic, retain) GADLocation *location;
@property (nonatomic, retain) NSNumber *childDirectedTreatment;
@property (nonatomic, retain) NSMutableDictionary *networkExtrasMap;
@end

SDK_HIDDEN_CLASS
@interface GADSearchBannerView : GADBannerView
@end

SDK_HIDDEN_CLASS
@interface GADSearchRequestPrivate : GADSearchRequest
@end

SDK_HIDDEN_CLASS
@interface GADSearchSlot : GADSlot
@end

SDK_HIDDEN_CLASS
@interface GADSharedStatistics : GADStatistics
@property (nonatomic) int adRequestCount;
@property (nonatomic) unsigned long long sequenceNumber;
@end

SDK_HIDDEN_CLASS
@interface GADSlotStatistics : GADStatistics
@property (nonatomic, copy) NSString *identifier;
@end

SDK_HIDDEN_CLASS
@interface GADWebAppGMSGHandler : GADGMSGHandler
@end

SDK_HIDDEN_CLASS
@interface GADWebAppViewController : GADViewController
@property (nonatomic) BOOL allowFileAccess;
@property (nonatomic) BOOL useCustomClose;
@property (nonatomic, retain) GADWebView *webView;
@property (nonatomic) BOOL viewHasAppeared;
@property (nonatomic) BOOL isExpandable;
@property (nonatomic) BOOL isCollapsing;
@property (nonatomic, retain) UIImageView *bannerScreenshot;
@property (nonatomic, retain) NSURL *URLToLoad;
@property (nonatomic, retain) NSString *HTMLToLoad;
@property (nonatomic, retain) NSURL *HTMLBaseURLToLoad;
@property (nonatomic, retain) GADWebAppWebViewDelegate *webViewDelegate;
@property (nonatomic, retain) UIButton *closeButton;
@property (nonatomic, assign) GADInterstitial *interstitial;
@end

SDK_HIDDEN_CLASS
@interface GADWebAppWebViewDelegate : GADWebViewDelegate
@property (nonatomic) BOOL pendingOnShow;
@property (nonatomic, assign) GADWebAppViewController *webAppViewController;
@property (nonatomic) BOOL calledOnShow;
@end

SDK_HIDDEN_CLASS
@interface DFPSwipeableBannerView : DFPBannerView
@property (nonatomic, assign) NSObject<GADSwipeableBannerViewDelegate> *swipeDelegate;
@end

@implementation DFPSwipeableBannerView
@end

@implementation DFPBannerView {
    NSArray *validAdSizes_;
}
@synthesize validAdSizes = validAdSizes_;
@end

@implementation DFPExtras {
    NSString *_publisherProvidedID;
}
@synthesize publisherProvidedID = _publisherProvidedID;
@end

@implementation DFPInterstitial
@end

@implementation GADAdBanner {
    double _refreshInterval;
}
@synthesize refreshInterval = _refreshInterval;
@end

@implementation GADAdInterstitial {
    double _interstitialTimeout;
}
@synthesize interstitialTimeout = _interstitialTimeout;
@end

@implementation GADAppEventGMSGHandler {
    GADSlot *_slot;
}
@synthesize slot = _slot;
@end

@implementation GADBannerWebViewDelegate {
    GADSlot *_slot;
}
@synthesize slot = _slot;
@end

@implementation GADBrowserController {
    NSURL *_URLToLoad;
    NSURL *_referringURLToLoad;
    GADWebViewDelegate *_webViewDelegate;
    GADWebView *_webView;
    UIToolbar *_toolbar;
    UIBarButtonItem *_flexibleSpaceButton;
    UIBarButtonItem *_backButton;
    UIBarButtonItem *_backButtonDisabled;
    UIBarButtonItem *_forwardButton;
    UIBarButtonItem *_forwardButtonDisabled;
    UIBarButtonItem *_reloadButton;
    UIBarButtonItem *_safariButton;
    UIBarButtonItem *_doneButton;
    UIBarButtonItem *_spinnerContainingButton;
    UIActivityIndicatorView *_spinner;
}
@synthesize URLToLoad = _URLToLoad;
@synthesize referringURLToLoad = _referringURLToLoad;
@synthesize webViewDelegate = _webViewDelegate;
@synthesize webView = _webView;
@synthesize toolbar = _toolbar;
@synthesize flexibleSpaceButton = _flexibleSpaceButton;
@synthesize backButton = _backButton;
@synthesize backButtonDisabled = _backButtonDisabled;
@synthesize forwardButton = _forwardButton;
@synthesize forwardButtonDisabled = _forwardButtonDisabled;
@synthesize reloadButton = _reloadButton;
@synthesize safariButton = _safariButton;
@synthesize doneButton = _doneButton;
@synthesize spinnerContainingButton = _spinnerContainingButton;
@synthesize spinner = _spinner;
@end

@implementation GADBrowserWebView
@end

@implementation GADBrowserWebViewDelegate
@end

@implementation GADDefaultGMSGHandler
@end

@implementation GADMAdNetworkConnectorBanner {
    BOOL _didNetworkReturn;
}
@synthesize didNetworkReturn = _didNetworkReturn;
@end

@implementation GADMAdNetworkConnectorInterstitial {
    BOOL _calledWillDismissInterstitial;
}
@synthesize calledWillDismissInterstitial = _calledWillDismissInterstitial;
@end

@implementation GADOpenerGMSGHandler {
    GADOpener *_gadOpener;
    GADActionRouter *_subParamActionRouter;
}
@synthesize gadOpener = _gadOpener;
@synthesize subParamActionRouter = _subParamActionRouter;
@end

@implementation GADPublisherToolbarController {
    GADPublisherToolbarCredentials *_credentials;
    UIWebView *_oauthWebView;
    UIWebView *_jsWebView;
    UIActivityIndicatorView *_spinnyWheel;
    GADCachedFile *_helperJS;
    NSString *_adUnitID;
    NSString *_adContent;
}
@synthesize credentials = _credentials;
@synthesize oauthWebView = _oauthWebView;
@synthesize jsWebView = _jsWebView;
@synthesize spinnyWheel = _spinnyWheel;
@synthesize helperJS = _helperJS;
@synthesize adUnitID = _adUnitID;
@synthesize adContent = _adContent;
@end

@implementation GADRequestPrivate {
    GADLocation *_location;
    NSNumber *_childDirectedTreatment;
    NSMutableDictionary *_networkExtrasMap;
}
@synthesize location = _location;
@synthesize childDirectedTreatment = _childDirectedTreatment;
@synthesize networkExtrasMap = _networkExtrasMap;
@end

@implementation GADSearchBannerView
@end

@implementation GADSearchRequestPrivate {
    NSString *query_;
    UIColor *backgroundColor_;
    UIColor *gradientFrom_;
    UIColor *gradientTo_;
    UIColor *headerColor_;
    UIColor *descriptionTextColor_;
    UIColor *anchorTextColor_;
    NSString *fontFamily_;
    int headerTextSize_;
    UIColor *borderColor_;
    int borderType_;
    int borderThickness_;
    NSString *channels_;
    int callButtonColor_;
}
@end

@implementation GADSearchSlot
@end

@implementation GADSharedStatistics {
    unsigned long long _sequenceNumber;
}
@synthesize sequenceNumber = _sequenceNumber;
@end

@implementation GADSlotStatistics {
    NSString *_identifier;
}
@synthesize identifier = _identifier;
@end

@implementation GADWebAppGMSGHandler
@end

@implementation GADWebAppViewController {
    BOOL _useCustomClose;
    BOOL _viewHasAppeared;
    BOOL _isExpandable;
    BOOL _isCollapsing;
    GADWebView *_webView;
    UIImageView *_bannerScreenshot;
    NSURL *_URLToLoad;
    NSString *_HTMLToLoad;
    NSURL *_HTMLBaseURLToLoad;
    GADWebAppWebViewDelegate *_webViewDelegate;
    UIButton *_closeButton;
    GADInterstitial *_interstitial;
}
@synthesize useCustomClose = _useCustomClose;
@synthesize webView = _webView;
@synthesize viewHasAppeared = _viewHasAppeared;
@synthesize isExpandable = _isExpandable;
@synthesize isCollapsing = _isCollapsing;
@synthesize bannerScreenshot = _bannerScreenshot;
@synthesize URLToLoad = _URLToLoad;
@synthesize HTMLToLoad = _HTMLToLoad;
@synthesize HTMLBaseURLToLoad = _HTMLBaseURLToLoad;
@synthesize webViewDelegate = _webViewDelegate;
@synthesize closeButton = _closeButton;
@synthesize interstitial = _interstitial;
@end

@implementation GADWebAppWebViewDelegate {
    BOOL _pendingOnShow;
    BOOL _calledOnShow;
    GADWebAppViewController *_webAppViewController;
}
@synthesize pendingOnShow = _pendingOnShow;
@synthesize webAppViewController = _webAppViewController;
@synthesize calledOnShow = _calledOnShow;
@end

@implementation GADAbsoluteTime
@end

@implementation GADActionRouter {
    id _receiver;
    NSMutableDictionary *_cachedActions;
}
@synthesize receiver = _receiver;
@synthesize cachedActions = _cachedActions;
@end

@implementation GADActivationView
@end

@implementation GADActivationViewDelegate {
    GADSlot *slot_;
}
@synthesize slot = slot_;
@end

@implementation GADAd {
    BOOL _activationAndScrollEnabled;
    NSURL *_adBaseURL;
    NSString *_adHTML;
    NSURL *_adURL;
    NSURL *_activationOverlayBaseURL;
    NSString *_activationOverlayHTML;
    NSURL *_activationOverlayURL;
    NSArray *_clickURLs;
    NSArray *_impressionURLs;
    NSArray *_manualImpressionURLs;
    int _supportedOrientations;
    NSString *_debugDialog;
    GADAdSize _size;
}
@synthesize adBaseURL = _adBaseURL;
@synthesize adHTML = _adHTML;
@synthesize adURL = _adURL;
@synthesize activationOverlayBaseURL = _activationOverlayBaseURL;
@synthesize activationOverlayHTML = _activationOverlayHTML;
@synthesize activationOverlayURL = _activationOverlayURL;
@synthesize clickURLs = _clickURLs;
@synthesize impressionURLs = _impressionURLs;
@synthesize manualImpressionURLs = _manualImpressionURLs;
@synthesize size = _size;
@synthesize supportedOrientations = _supportedOrientations;
@synthesize activationAndScrollEnabled = _activationAndScrollEnabled;
@synthesize debugDialog = _debugDialog;
@end

@implementation GADAdFetcher {
    long _startOncePredicate;
    long _notifyOncePredicate;
    BOOL _shouldLoadActivationOverlay;
    BOOL _adConnectionHasCompleted;
    BOOL _activationOverlayConnectionHasCompleted;
    NSRecursiveLock *_recursiveLock;
    GADRequestPrivate *_request;
    id<GADAdFetcherDelegate> _delegate;
    GADTiming *_timer;
    GADURLConnection *_adConnection;
    GADURLConnection *_activationOverlayConnection;
    NSString *_activationOverlayHTML;
    NSURL *_activationOverlayBaseURL;
    NSString *_adResponse;
    NSURL *_adBaseURL;
    BOOL *_wasDeallocated;
}
@synthesize recursiveLock = _recursiveLock;
@synthesize request = _request;
@synthesize delegate = _delegate;
@synthesize timer = _timer;
@synthesize adConnection = _adConnection;
@synthesize activationOverlayConnection = _activationOverlayConnection;
@synthesize activationOverlayHTML = _activationOverlayHTML;
@synthesize activationOverlayBaseURL = _activationOverlayBaseURL;
@synthesize shouldLoadActivationOverlay = _shouldLoadActivationOverlay;
@synthesize adResponse = _adResponse;
@synthesize adBaseURL = _adBaseURL;
@synthesize adConnectionHasCompleted = _adConnectionHasCompleted;
@synthesize activationOverlayConnectionHasCompleted = _activationOverlayConnectionHasCompleted;
@synthesize wasDeallocated = _wasDeallocated;
@end

@implementation GADAdMobExtras {
    NSDictionary *_additionalParameters;
}
@synthesize additionalParameters = _additionalParameters;
@end

@implementation GADAdType {
    BOOL _isInterstitial;
    GADAdSize _adSize;
}
@synthesize isInterstitial = _isInterstitial;
@synthesize adSize = _adSize;
@end

@implementation GADAdURLStash
@end

@implementation GADApplication {
    BOOL _appFinishedLaunching;
    GADSession *_currentSession;
}
@synthesize currentSession = _currentSession;
@synthesize appFinishedLaunching = _appFinishedLaunching;
@end

@implementation GADBadAdUtil {
    GADURLConnection *connection_;
}
@synthesize connection = connection_;
@end

@implementation GADBannerView {
    GADSlot *_slot;
}
@synthesize slot = _slot;
@end

@implementation GADCachedFile {
    id<GADCachedFileDelegate> delegate_;
    NSURL *sourceURL_;
    NSString *filePath_;
    NSURLConnection *connection_;
    NSMutableData *receivedData_;
    NSString *receivedModificationDate_;
    NSURL *httpDestinationURL_;
    int httpStatusCode_;
    NSDictionary *httpHeaders_;
    NSDictionary *userInfo_;
}
@synthesize delegate = delegate_;
@synthesize userInfo = userInfo_;
@synthesize sourceURL = sourceURL_;
@synthesize httpDestinationURL = httpDestinationURL_;
@synthesize httpStatusCode = httpStatusCode_;
@synthesize httpHeaders = httpHeaders_;
@end

@implementation GADCachedURLResponse {
    NSDate *expireDate_;
    NSURL *destinationURL_;
}
@synthesize expireDate = expireDate_;
@synthesize destinationURL = destinationURL_;
@end

@implementation GADClickTracker {
    id<GADClickTrackerDelegate> delegate_;
    GADCachedFile *tracker_;
    BOOL hasTracked_;
    unsigned int backgroundTaskID_;
}
@synthesize delegate = delegate_;
@synthesize hasTracked = hasTracked_;
@end

@implementation GADClickTrackerCollection {
    NSMutableSet *trackers_;
}
@end

@implementation GADCustomEventExtras {
    NSMutableDictionary *extras_;
}
@synthesize extras = extras_;
@end

@implementation GADCustomEventRequest {
    BOOL userHasLocation_;
    BOOL isTesting_;
    int userGender_;
    NSDate *userBirthday_;
    float userLongitude_;
    float userLatitude_;
    float userLocationAccuracyInMeters_;
    NSString *userLocationDescription_;
    NSArray *userKeywords_;
    NSDictionary *additionalParameters_;
}
@synthesize userGender = userGender_;
@synthesize userBirthday = userBirthday_;
@synthesize userHasLocation = userHasLocation_;
@synthesize userLatitude = userLatitude_;
@synthesize userLongitude = userLongitude_;
@synthesize userLocationAccuracyInMeters = userLocationAccuracyInMeters_;
@synthesize userLocationDescription = userLocationDescription_;
@synthesize userKeywords = userKeywords_;
@synthesize additionalParameters = additionalParameters_;
@synthesize isTesting = isTesting_;
@end

@implementation GADDelegateManager {
    id<GADBannerViewDelegate> _bannerDelegate;
    GADBannerView *_adView;
    id<GADInterstitialDelegate> _interstitialDelegate;
    GADInterstitial *_interstitial;
    id<GADInterstitialDelegate> _SDKInterstitialDelegate;
    id<GADAppEventDelegate> _appEventDelegate;
    id<GADSwipeableBannerViewDelegate> _swipeDelegate;
    id<GADInAppPurchaseDelegate> _inAppPurchaseDelegate;
}
@synthesize bannerDelegate = _bannerDelegate;
@synthesize adView = _adView;
@synthesize interstitialDelegate = _interstitialDelegate;
@synthesize interstitial = _interstitial;
@synthesize SDKInterstitialDelegate = _SDKInterstitialDelegate;
@synthesize appEventDelegate = _appEventDelegate;
@synthesize swipeDelegate = _swipeDelegate;
@synthesize inAppPurchaseDelegate = _inAppPurchaseDelegate;
@end

@implementation GADDevice {
    NSUserDefaults *_userDefaults;
    CTTelephonyNetworkInfo *_telephonyNetworkInfo;
    NSString *_cachedAdvertisingID;
    NSString *_cachedMD5AdvertisingID;
}
@synthesize userDefaults = _userDefaults;
@synthesize telephonyNetworkInfo = _telephonyNetworkInfo;
@synthesize cachedAdvertisingID = _cachedAdvertisingID;
@synthesize cachedMD5AdvertisingID = _cachedMD5AdvertisingID;
@end

@implementation GADGMSGHandler {
    GADActionRouter *_actionRouter;
}
@synthesize actionRouter = _actionRouter;
@end

@implementation GADGestureIdUtil {
    NSUserDefaults *userDefaults_;
}
@synthesize userDefaults = userDefaults_;
@end

@implementation GADGestureUtil
@end

@implementation GADImpressionTicketGestureRecognizer {
    GADImpressionTicketGestureRecognizerPrivate *_vars;
}
@synthesize vars = _vars;
@end

@implementation GADImpressionTicketGestureRecognizerPrivate {
    int gestureState_;
    unsigned int distanceMoved_;
}
@synthesize gestureState = gestureState_;
@synthesize distanceMoved = distanceMoved_;
@end

@implementation GADInAppPurchase {
    NSString *_productID;
    unsigned int _quantity;
}
@synthesize productID = _productID;
@synthesize quantity = _quantity;
@end

@implementation GADInterstitial {
    BOOL _hasBeenUsed;
    GADRequest *_request;
    GADWebAppViewController *_viewController;
    GADSlot *_slot;
}
@synthesize hasBeenUsed = _hasBeenUsed;
@synthesize request = _request;
@synthesize viewController = _viewController;
@synthesize slot = _slot;
@end

@implementation GADInterstitialAppController {
    GADInterstitial *interstitial_;
    UIWindow *window_;
    NSArray *storedUserViews_;
    UIImageView *imageView_;
    NSTimer *timeout_;
    BOOL hideStatusBar_;
    UIViewController *originalRootViewController_;
}
@synthesize originalRootViewController = originalRootViewController_;
@end

@implementation GADIntrinsicImages
@end

@implementation GADJavaScriptController {
    GADWebViewDelegate *buildAdWebViewDelegate_;
    NSMutableArray *pendingDelegates_;
    NSMutableDictionary *delegates_;
    NSMutableArray *pendingJavaScriptCommands_;
    unsigned int requestId_;
    BOOL _shouldCheckOreoID;
    GADCachedFile *_buildAdJS;
    UIWebView *_buildAdWebView;
}
@synthesize shouldCheckOreoID = _shouldCheckOreoID;
@synthesize buildAdJS = _buildAdJS;
@synthesize buildAdWebView = _buildAdWebView;
@end

@implementation GADLocation {
    float latitude_;
    float longitude_;
    float accuracy_;
    NSString *description_;
    double timestamp_;
    NSDictionary *dictionaryRepresentation_;
}
@synthesize latitude = latitude_;
@synthesize longitude = longitude_;
@synthesize accuracy = accuracy_;
@synthesize dictionaryRepresentation = dictionaryRepresentation_;
@synthesize timestamp = timestamp_;
@end

@implementation GADMAdManager {
    NSMutableArray *_adNetworkConfigQueue;
    GADMAdNetworkConnector *_lastConnectorNotifiedForAClick;
    BOOL _requestInProgress;
    id<GADMDelegate> _delegate;
    GADMConfig *_config;
    GADAdType *_adType;
    GADMAdNetworkConnector *_requestingConnector;
    GADMAdNetworkConnector *_receivedConnector;
    NSDate *_lastRequestTime;
    NSTimer *_adNetworkTimeoutTimer;
}
@synthesize delegate = _delegate;
@synthesize config = _config;
@synthesize adType = _adType;
@synthesize requestingConnector = _requestingConnector;
@synthesize receivedConnector = _receivedConnector;
@synthesize lastRequestTime = _lastRequestTime;
@synthesize requestInProgress = _requestInProgress;
@synthesize adNetworkTimeoutTimer = _adNetworkTimeoutTimer;
@end

@implementation GADMAdNetworkAdapter
@end

@implementation GADMAdNetworkConfig {
    NSString *_networkID;
    NSDictionary *_credentials;
    NSDictionary *_extras;
    NSDictionary *_ad;
    NSArray *_adapterList;
    Class _adapterClass;
    NSString *_allocationID;
    NSArray *_impressionURLs;
}
@synthesize networkID = _networkID;
@synthesize credentials = _credentials;
@synthesize extras = _extras;
@synthesize ad = _ad;
@synthesize adapterList = _adapterList;
@synthesize adapterClass = _adapterClass;
@synthesize allocationID = _allocationID;
@synthesize impressionURLs = _impressionURLs;
@end

@implementation GADMAdNetworkConnector {
    NSDictionary *_strippedCredentials;
    BOOL _shareLocation;
    BOOL _didNetworkRefresh;
    id<GADMDelegate> _gadmDelegate;
    GADMAdManager *_adManager;
    GADMConfig *_mediationConfig;
    GADMAdNetworkConfig *_networkConfig;
    id<GADMAdNetworkAdapter> _adapter;
}
@synthesize gadmDelegate = _gadmDelegate;
@synthesize adManager = _adManager;
@synthesize mediationConfig = _mediationConfig;
@synthesize networkConfig = _networkConfig;
@synthesize adapter = _adapter;
@synthesize didNetworkRefresh = _didNetworkRefresh;
@end

@implementation GADMAdSizeUtilities
@end

@implementation GADMAdapterCustomEvents {
    id<GADMAdNetworkConnector> _connector;
    id<GADCustomEventBanner> _customEventBanner;
    id<GADCustomEventInterstitial> _customEventInterstitial;
}
@synthesize connector = _connector;
@synthesize customEventBanner = _customEventBanner;
@synthesize customEventInterstitial = _customEventInterstitial;
@end

@implementation GADMAdapterGoogleAdMobAds {
    GADBannerView *_banner;
    GADInterstitial *_interstitial;
    id<GADMAdNetworkConnector, GADMAdNetworkConnectorCOPPAField> _connector;
}
@synthesize banner = _banner;
@synthesize interstitial = _interstitial;
@synthesize connector = _connector;
@end

@implementation GADMAdapterHTML {
    unsigned int checkRenderingCount_;
    NSTimer *checkRenderingTimer_;
    GADMWebViewRenderedChecker *webViewRenderedChecker_;
    UIWebView *webView_;
    NSURL *passbackUrl_;
    id<GADMAdNetworkConnector> connector_;
}
@synthesize connector = connector_;
@synthesize webView = webView_;
@synthesize passbackUrl = passbackUrl_;
@end

@implementation GADMAdapterIAd {
    id<GADMAdNetworkConnector> connector_;
    ADBannerView *adView_;
    ADInterstitialAd *interstitialAd_;
    GADAdSize adSize_;
    BOOL useIOS6API_;
}
@synthesize connector = connector_;
@synthesize adView = adView_;
@synthesize interstitialAd = interstitialAd_;
@synthesize adSize = adSize_;
@synthesize useIOS6API = useIOS6API_;
@end

@implementation GADMConfig {
    NSArray *_adNetworkConfigs;
    int _bannerAnimationType;
    NSArray *_impressionURLs;
    NSArray *_clickURLs;
    NSArray *_noFillURLs;
    NSString *_qdata;
    GADAdType *_adType;
    NSString *_appKey;
    double _refreshInterval;
    double _adNetworkTimeout;
}
@synthesize adNetworkConfigs = _adNetworkConfigs;
@synthesize refreshInterval = _refreshInterval;
@synthesize bannerAnimationType = _bannerAnimationType;
@synthesize adNetworkTimeout = _adNetworkTimeout;
@synthesize impressionURLs = _impressionURLs;
@synthesize clickURLs = _clickURLs;
@synthesize noFillURLs = _noFillURLs;
@synthesize qdata = _qdata;
@synthesize adType = _adType;
@synthesize appKey = _appKey;
@end

@implementation GADMNSURLConnectionFactory
@end

@implementation GADMRAIDInterceptor {
    NSString *_mraidLocationToLoad;
}
@synthesize mraidLocationToLoad = _mraidLocationToLoad;
@end

@implementation GADMToGADGlue {
    GADSlot *_slot;
    id _mediatedInterstitial;
    GADMAdManager *_mediationManager;
    GADMConfig *_mediationConfig;
}
@synthesize slot = _slot;
@synthesize mediatedInterstitial = _mediatedInterstitial;
@synthesize mediationManager = _mediationManager;
@synthesize mediationConfig = _mediationConfig;
@end

@implementation GADMUtilities
@end

@implementation GADMWebViewRenderedChecker {
    UIWebView *webView_;
    id<GADMWebViewRenderedCheckerDelegate> delegate_;
}
@synthesize webView = webView_;
@synthesize delegate = delegate_;
@end

@implementation GADMacros
@end

@implementation GADNetworkChecker {
    unsigned int _changeCount;
    unsigned int _networkType;
    SCNetworkReachabilityRef _networkReachabilityRef;
    NSRecursiveLock *_lock;
}
@synthesize networkReachabilityRef = _networkReachabilityRef;
@synthesize lock = _lock;
@end

@implementation GADNetworkUtilities
@end

@implementation GADNotification {
    NSString *name_;
    NSDictionary *parameters_;
}
@synthesize name = name_;
@synthesize parameters = parameters_;
@end

@implementation GADNotificationCenter
@end

@implementation GADOpener {
    GADDelegateManager *delegateManager_;
    UIViewController *viewController_;
    NSURL *referringURL_;
    GADWebView *webView_;
    GADSlot *slot_;
    BOOL didOpenAnotherApplication_;
    id<GADOpenerDelegate> delegate_;
}
@synthesize delegateManager = delegateManager_;
@synthesize viewController = viewController_;
@synthesize referringURL = referringURL_;
@synthesize webView = webView_;
@synthesize slot = slot_;
@synthesize didOpenAnotherApplication = didOpenAnotherApplication_;
@synthesize delegate = delegate_;
@end

@implementation GADPublisherToolbarCredentials {
    NSDictionary *_credentials;
}
@synthesize credentials = _credentials;
@end

@implementation GADRequest {
    BOOL _testing;
    NSDictionary *_mediationExtras;
    NSArray *_testDevices;
    int _gender;
    NSDate *_birthday;
    NSMutableArray *_keywords;
}
@synthesize mediationExtras = _mediationExtras;
@synthesize testDevices = _testDevices;
@synthesize gender = _gender;
@synthesize birthday = _birthday;
@synthesize keywords = _keywords;
@synthesize testing = _testing;
@end

@implementation GADRequestError
@end

@implementation GADSearchRequest {
    NSString *query;
    UIColor *backgroundColor;
    UIColor *gradientFrom;
    UIColor *gradientTo;
    UIColor *headerColor;
    UIColor *descriptionTextColor;
    UIColor *anchorTextColor;
    NSString *fontFamily;
    int headerTextSize;
    UIColor *borderColor;
    int borderType;
    int borderThickness;
    NSString *customChannels;
    int callButtonColor;
}
@synthesize query = query;
@synthesize backgroundColor = backgroundColor;
@synthesize gradientFrom = gradientFrom;
@synthesize gradientTo = gradientTo;
@synthesize headerColor = headerColor;
@synthesize descriptionTextColor = descriptionTextColor;
@synthesize anchorTextColor = anchorTextColor;
@synthesize fontFamily = fontFamily;
@synthesize headerTextSize = headerTextSize;
@synthesize borderColor = borderColor;
@synthesize borderType = borderType;
@synthesize borderThickness = borderThickness;
@synthesize customChannels = customChannels;
@synthesize callButtonColor = callButtonColor;
@end

@implementation GADSession {
    unsigned long long _sessionID;
}
@synthesize sessionID = _sessionID;
@end

@implementation GADSlot {
    int _state;
    NSMutableSet *_pendingClickURLs;
    NSMutableSet *_pendingTrackingURLs;
    NSMutableSet *_pendingManualTrackingURLs;
    BOOL _hasAutoRefreshed;
    BOOL _manualImpressionsEnabled;
    BOOL _isMRAID;
    BOOL _isMediating;
    BOOL _calledLoadAndDisplayRequest;
    BOOL _shouldShowActivationOverlay;
    NSString *_adUnitID;
    UIViewController *_rootViewController;
    NSObject<GADAdSizeDelegate> *_adSizeDelegate;
    GADDelegateManager *_delegateManager;
    GADAdType *_adType;
    GADRequestPrivate *_requestPrivate;
    int _supportedOrientations;
    GADWebView *_webView;
    GADSlotStatistics *_slotStats;
    GADBannerWebViewDelegate *_webViewDelegate;
    GADActivationView *_activationView;
    GADActivationViewDelegate *_activationViewDelegate;
    GADAdFetcher *_adFetcher;
    NSTimer *_reloadTimer;
    NSString *_requestId;
    GADBannerView *_adView;
    GADInterstitial *_interstitial;
    GADMToGADGlue *_adMediationGlue;
    NSString *_adDebugDialog;
    GADTiming *_adTimer;
    double _timeLastLoaded;
    double _reloadInterval;
    CGSize _newAdSize;
}
@synthesize adUnitID = _adUnitID;
@synthesize rootViewController = _rootViewController;
@synthesize adSizeDelegate = _adSizeDelegate;
@synthesize hasAutoRefreshed = _hasAutoRefreshed;
@synthesize manualImpressionsEnabled = _manualImpressionsEnabled;
@synthesize delegateManager = _delegateManager;
@synthesize adType = _adType;
@synthesize requestPrivate = _requestPrivate;
@synthesize timeLastLoaded = _timeLastLoaded;
@synthesize isMRAID = _isMRAID;
@synthesize isMediating = _isMediating;
@synthesize supportedOrientations = _supportedOrientations;
@synthesize webView = _webView;
@synthesize slotStats = _slotStats;
@synthesize calledLoadAndDisplayRequest = _calledLoadAndDisplayRequest;
@synthesize webViewDelegate = _webViewDelegate;
@synthesize activationView = _activationView;
@synthesize activationViewDelegate = _activationViewDelegate;
@synthesize adFetcher = _adFetcher;
@synthesize reloadInterval = _reloadInterval;
@synthesize reloadTimer = _reloadTimer;
@synthesize requestId = _requestId;
@synthesize adView = _adView;
@synthesize interstitial = _interstitial;
@synthesize newAdSize = _newAdSize;
@synthesize adMediationGlue = _adMediationGlue;
@synthesize adDebugDialog = _adDebugDialog;
@synthesize shouldShowActivationOverlay = _shouldShowActivationOverlay;
@synthesize adTimer = _adTimer;
@end

@implementation GADStatisticDictionary {
    NSMutableDictionary *_statistics;
    BOOL _allowDictionaryModification;
    BOOL _hasEnqueuedNotificationBlock;
    id<GADStatisticDictionaryDelegate> _delegate;
    BOOL *_wasDeallocated;
    struct dispatch_queue_s *_queue;
}
@synthesize delegate = _delegate;
@synthesize wasDeallocated = _wasDeallocated;
@synthesize queue = _queue;
@synthesize allowDictionaryModification = _allowDictionaryModification;
@synthesize hasEnqueuedNotificationBlock = _hasEnqueuedNotificationBlock;
@end

@implementation GADStatistics
@end

@implementation GADStatisticsCore {
    NSMutableDictionary *_statistics;
    NSString *_identifier;
    NSUserDefaults *_userDefaults;
    NSArray *_transientStats;
    NSString *_userDefaultsKey;
    NSLock *_lock;
}
@synthesize identifier = _identifier;
@synthesize userDefaults = _userDefaults;
@synthesize transientStats = _transientStats;
@synthesize userDefaultsKey = _userDefaultsKey;
@synthesize lock = _lock;
@end

@implementation GADTiming {
    NSMutableDictionary *_userData;
    BOOL _explicitEnd;
    NSString *_category;
    NSLock *_timeIntervalLock;
    double _startTimestamp;
    double _endTimestamp;
}
@synthesize category = _category;
@synthesize explicitEnd = _explicitEnd;
@synthesize startTimestamp = _startTimestamp;
@synthesize endTimestamp = _endTimestamp;
@synthesize timeIntervalLock = _timeIntervalLock;
@end

@implementation GADTimingManager {
    NSString *identifier_;
    NSMutableDictionary *timings_;
    NSUserDefaults *userDefaults_;
    NSString *userDefaultsKey_;
    NSArray *transientTimings_;
}
@synthesize identifier = identifier_;
@synthesize userDefaults = userDefaults_;
@synthesize transientTimings = transientTimings_;
@synthesize userDefaultsKey = userDefaultsKey_;
@end

@implementation GADUIWebViewGestureDelgate
@end

@implementation GADURL
@end

@implementation GADURLConnection {
    BOOL _isInProgress;
    BOOL _allowCache;
    NSURL *_sourceURL;
    NSURL *_destinationURL;
    id<GADURLConnectionDelegate> _delegate;
    NSURLConnection *_connection;
    NSURLResponse *_response;
    NSMutableData *_receivedData;
}
@synthesize isInProgress = _isInProgress;
@synthesize sourceURL = _sourceURL;
@synthesize destinationURL = _destinationURL;
@synthesize allowCache = _allowCache;
@synthesize delegate = _delegate;
@synthesize connection = _connection;
@synthesize response = _response;
@synthesize receivedData = _receivedData;
@end

@implementation GADViewController {
    BOOL _viewDidAppear;
    BOOL _statusBarWasHidden;
    BOOL _publisherIdleTimerDisabled;
    BOOL _appClosing;
    BOOL _interactingWithParent;
    BOOL _wasPresentedFromViewController;
    GADDelegateManager *_delegateManager;
    int _supportedOrientations;
    GADSlot *_slot;
}
@synthesize delegateManager = _delegateManager;
@synthesize supportedOrientations = _supportedOrientations;
@synthesize viewDidAppear = _viewDidAppear;
@synthesize slot = _slot;
@synthesize statusBarWasHidden = _statusBarWasHidden;
@synthesize publisherIdleTimerDisabled = _publisherIdleTimerDisabled;
@synthesize appClosing = _appClosing;
@synthesize interactingWithParent = _interactingWithParent;
@synthesize wasPresentedFromViewController = _wasPresentedFromViewController;
@end

@implementation GADViewUtilities
@end

@implementation GADWebView {
    BOOL _touched;
    BOOL _showDebug;
    BOOL _didReceiveLoadEvent;
    BOOL _savedState;
    UIViewController *_viewController;
    NSString *_adDebugDialog;
    int _orientation;
    GADUIWebViewGestureDelgate *_gestureDelegate;
    GADImpressionTicketGestureRecognizer *_gesture;
    UIAlertView *_alertView;
    UIView *_savedSuperview;
    NSObject<UIWebViewDelegate> *_savedDelegate;
    NSURL *_url;
    NSURL *_URL;
    UIViewController *_viewControllerBeforeExpanded;
    CGRect _savedFrame;
}
@synthesize viewController = _viewController;
@synthesize touched = _touched;
@synthesize adDebugDialog = _adDebugDialog;
@synthesize showDebug = _showDebug;
@synthesize didReceiveLoadEvent = _didReceiveLoadEvent;
@synthesize orientation = _orientation;
@synthesize gestureDelegate = _gestureDelegate;
@synthesize gesture = _gesture;
@synthesize alertView = _alertView;
@synthesize savedState = _savedState;
@synthesize savedFrame = _savedFrame;
@synthesize savedSuperview = _savedSuperview;
@synthesize savedDelegate = _savedDelegate;
@synthesize url = _url;
@synthesize URL = _URL;
@synthesize viewControllerBeforeExpanded = _viewControllerBeforeExpanded;
@end

@implementation GADWebViewDelegate {
    BOOL allowFileAccess;
    GADOpener *opener_;
    NSMutableArray *_gmsgHandlers;
    GADOpenerGMSGHandler *_openerGMSGHandler;
}
@synthesize opener = opener_;
@synthesize hasLoadedAtLeastOnce = hasLoadedAtLeastOnce_;
@synthesize allowFileAccess = allowFileAccess;
@synthesize gmsgHandlers = _gmsgHandlers;
@synthesize openerGMSGHandler = _openerGMSGHandler;
@end

@implementation GAD_GTMStringEncoding {
    NSData *charMapData_;
    char *charMap_;
    int reverseCharMap_[128];
    int shift_;
    int mask_;
    BOOL doPad_;
    BOOL paddingChar_;
    int padLen_;
}
@end

@implementation GAD_SBJSON {
    BOOL humanReadable;
    BOOL sortKeys;
    unsigned int maxDepth;
    unsigned int depth;
    const char *c;
}
@synthesize humanReadable = humanReadable;
@synthesize sortKeys = sortKeys;
@synthesize maxDepth = maxDepth;
@end

#undef SDK_HIDDEN_CLASS
#undef SDK_CLASS

// These two protocols are queried dynamically by the custom-event adapter.
// Referencing the literals makes Clang emit their complete protocol metadata.
__attribute__((constructor)) static void registerCustomEventProtocols(void)
{
    (void)@protocol(GADCustomEventBanner);
    (void)@protocol(GADCustomEventInterstitial);
}
