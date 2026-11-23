// Method bodies recovered from the 32-bit Objective-C runtime metadata and ARM code.
// Interfaces declare only the fields and methods used in this reconstruction.
// The match verifier resolves field offsets against the corresponding original class.

typedef signed char BOOL;

typedef struct CGPoint { float x, y; } CGPoint;
typedef struct CGSize { float width, height; } CGSize;
typedef struct CGRect { CGPoint origin; CGSize size; } CGRect;
typedef struct GADAdSize { CGSize size; unsigned int flags; } GADAdSize;
struct _NSZone;

#define nil ((id)0)

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
@end

// Signatures used by the recovered message-forwarding methods.
@interface NSObject (AdMessages)
+ (id)alloc;
+ (id)allocWithZone:(struct _NSZone *)zone;
+ (Class)class;
+ (id)currentDevice;
+ (id)defaultCenter;
+ (void)disableCanInitWithRequest;
+ (void)enableCanInitWithRequest;
+ (id)errorWithCode:(int)code customMessage:(id)customMessage;
+ (id)errorWithCode:(int)code request:(id)request;
+ (id)errorWithCode:(int)code request:(id)request HTTPStatusCode:(int)statusCode;
+ (id)errorWithCode:(int)code request:(id)request HTTPStatusCode:(int)statusCode customMessage:(id)customMessage;
+ (signed char)isGMSG:(id)url;
+ (id)memoryCache;
+ (id)numberWithBool:(signed char)value;
+ (id)numberWithInt:(int)value;
+ (void)remove:(id)key;
+ (id)requestPrivateWithRequest:(id)request;
+ (id)sdkVersion;
+ (void)setBannerImplementationPath:(id)value;
+ (void)setExpandedBannerImplementationPath:(id)value;
+ (void)setInterstitialImplementationPath:(id)value;
+ (id)sharedApplication;
+ (id)sharedFactory;
+ (id)sharedInstance;
+ (id)stringEncodingWithString:(id)alphabet;
- (id)URL;
- (id)absoluteString;
- (id)actionRouter;
- (void)activateReloadTimer;
- (id)adManager;
- (id)adNetworkClassName;
- (id)adNetworkExtrasFor:(Class)extrasClass;
- (void)adRequestFailedFromConnector:(id)connector withError:(id)error;
- (void)adRequestReturnsFromConnector:(id)connector withInterstitial:(id)interstitial;
- (void)adRequestReturnsFromConnector:(id)connector withView:(id)view;
- (id)adSizeDelegate;
- (id)adTimer;
- (id)adUnitID;
- (id)adapter;
- (void)adapter:(id)adapter clickDidOccurInBanner:(id)banner;
- (void)adapter:(id)adapter didFailAd:(id)error;
- (void)adapter:(id)adapter didFailInterstitial:(id)error;
- (void)adapter:(id)adapter didReceiveAdView:(id)adView;
- (void)adapter:(id)adapter didReceiveInterstitial:(id)interstitial;
- (void)adapterDidDismissFullScreenModal:(id)adapter;
- (void)adapterDidDismissInterstitial:(id)adapter;
- (id)adapterDurationsParameter;
- (id)adapterExitCodesParameter;
- (void)adapterWillDismissFullScreenModal:(id)adapter;
- (void)adapterWillDismissInterstitial:(id)adapter;
- (void)adapterWillLeaveApplication:(id)adapter;
- (void)adapterWillPresentFullScreenModal:(id)adapter;
- (void)adapterWillPresentInterstitial:(id)adapter;
- (void)addDecodeSynonyms:(id)synonyms;
- (void)addObject:(id)object;
- (void)addSelector:(SEL)selector name:(id)name;
- (void)addTiming:(id)timing;
- (int)addValue:(int)value numberForKey:(id)key;
- (id)allKeys;
- (id)allValues;
- (signed char)allowFileAccess;
- (id)appEventDelegate;
- (void)askAdapterToStopBeingDelegate;
- (id)autorelease;
- (id)banner;
- (id)bannerDelegate;
- (void)beginFetchWithCacheBuster:(signed char)useCacheBuster;
- (id)birthday;
- (void)cachedFile:(id)cachedFile downloadDidFail:(id)error;
- (void)cancel;
- (void)cancelPendingActions;
- (void)cancelPendingAndFutureActions;
- (id)category;
- (id)childDirectedTreatment;
- (void)cleanUpConnection;
- (void)configureSpinny;
- (void)configureWebView:(id)webView;
- (id)connection;
- (id)connector;
- (void)createWebViewToolbar;
- (id)credentials;
- (id)customEventBanner;
- (id)customEventInterstitial;
- (void)deactivateReloadTimer;
- (void)dealloc;
- (id)delegate;
- (id)delegateManager;
- (void)didFailToReceiveAdWithError:(id)error;
- (void)didLeaveApplication;
- (signed char)didNetworkRefresh;
- (signed char)didNetworkReturn;
- (void)didOpen;
- (void)didOpenInApplication;
- (void)didReceiveAd;
- (void)didRotateFromInterfaceOrientation:(int)interfaceOrientation;
- (void)didRotateToOrientation:(int)didRotateToOrientation;
- (unsigned int)distanceMoved;
- (void)end;
- (void)endTimingAdapterWithExitCode:(int)exitCode;
- (void)failedToDownloadJavaScriptWithError:(id)error;
- (void)forceRotateToOrientation:(int)forceRotateToOrientation;
- (int)gender;
- (int)gestureState;
- (id)gmsgHandlers;
- (signed char)hasAutoRefreshed;
- (id)helperJS;
- (void)hideStatusBar;
- (id)host;
- (id)httpDestinationURL;
- (id)inAppPurchaseDelegate;
- (id)init;
- (id)initForInterstitial;
- (id)initWithCategory:(id)category;
- (id)initWithDelegate:(id)delegate;
- (id)initWithDescription:(id)description;
- (id)initWithDictionary:(id)dictionary;
- (id)initWithNotificationURL:(id)notificationURL;
- (id)initWithString:(id)string;
- (id)initWithView:(id)view;
- (id)initWithWebView:(id)webView forInterstitial:(id)interstitial;
- (int)interfaceOrientation;
- (id)interstitial;
- (id)interstitialDelegate;
- (void)invalidate;
- (signed char)isATestDevice;
- (signed char)isBannerAnimationOK:(int)animation;
- (signed char)isEqualToString:(id)isEqualToString;
- (id)jsWebView;
- (id)keywords;
- (void)load:(id)url referringURL:(id)referringURL;
- (void)loadAdHTMLFromURL:(id)url usingActivationOverlayURL:(id)usingActivationOverlayURL;
- (void)loadHTMLString:(id)hTMLString baseURL:(id)baseURL;
- (void)loadJavaScript;
- (void)loadPrivateRequest:(id)privateRequest autoRefresh:(signed char)autoRefresh;
- (void)loadRequest:(id)request;
- (id)location;
- (void)makeAdRequest;
- (signed char)manualImpressionsEnabled;
- (void)markAdCompletedTime;
- (void)markAdStartTime;
- (void)mediatedAdNetworkAutoRefreshed;
- (id)mediatedAdView;
- (id)mediatedInterstitial;
- (id)mediationManager;
- (id)model;
- (id)networkConfig;
- (id)networkExtrasAdditionalParameters;
- (id)objectForKey:(id)key;
- (void)openApp:(id)openApp;
- (void)postJSNotification:(id)postJSNotification userInfo:(id)userInfo webView:(id)webView;
- (void)postNotificationFromURL:(id)url object:(id)object;
- (void)presentFromRootViewController:(id)rootViewController;
- (id)privateRequest;
- (id)publisherID;
- (id)publisherId;
- (id)receivedConnector;
- (void)registerAdNetworkExtras:(id)extras;
- (void)release;
- (void)relinquishScreen;
- (void)reload;
- (void)removeAllObjects;
- (void)removeFromSuperview;
- (void)removeObjectForKey:(id)key;
- (void)removeSelfAsDelegate;
- (void)removeTimingForCategory:(id)category;
- (id)addTimingWithCategory:(id)category;
- (id)numberForKey:(id)key;
- (void)setExplicitEnd:(signed char)explicitEnd;
- (unsigned int)unsignedIntegerValue;
- (void)reportBadAd:(id)reportBadAd;
- (void)reportClickFromConnector:(id)connector isRefresh:(signed char)isRefresh;
- (void)reportImpressionFromConnector:(id)connector isRefresh:(signed char)isRefresh;
- (id)request;
- (id)requestPrivate;
- (id)requestingConnector;
- (void)reset;
- (void)resetReloadTimer;
- (void)resetTimingAdapters;
- (void)restoreWindowAndRelease;
- (id)retain;
- (id)rootViewController;
- (void)runEarlyActivities;
- (void)saveDataToFile;
- (void)savePersistentStatistics;
- (void)savePersistentTimings;
- (void)sendInterstitialError:(id)error;
- (void)setAdManager:(id)value;
- (void)setAdSizeDelegate:(id)value;
- (void)setAdType:(id)adType andReloadRequest:(signed char)andReloadRequest;
- (void)setAdUnitID:(id)value;
- (void)setAdView:(id)value;
- (void)setAdditionalParameters:(id)value;
- (void)setAllowFileAccess:(signed char)value;
- (void)setAppEventDelegate:(id)value;
- (void)setBannerDelegate:(id)value;
- (void)setBreakOutToSafari;
- (void)setChildDirectedTreatment:(id)value;
- (void)setClickBackgroundedApp;
- (void)setConnection:(id)value;
- (void)setDelegate:(id)value;
- (void)setDelegateManager:(id)value;
- (void)setDestinationURL:(id)value;
- (void)setDidNetworkRefresh:(signed char)set;
- (void)setDidNetworkReturn:(signed char)set;
- (void)setDidReceiveLoadEvent:(signed char)set;
- (void)setDistanceMoved:(unsigned int)value;
- (void)setDoPad:(signed char)value;
- (void)setGadmDelegate:(id)value;
- (void)setGestureState:(int)value;
- (void)setHtmlWindowWithOrientation:(int)htmlWindowWithOrientation andFireEvent:(signed char)andFireEvent;
- (void)setInAppPurchaseDelegate:(id)value;
- (void)setInterstitial:(id)value;
- (void)setInterstitialDelegate:(id)value;
- (void)setIsInProgress:(signed char)value;
- (void)setLocation:(id)value;
- (void)setManualImpressionsEnabled:(signed char)value;
- (void)setMediatedInterstitial:(id)value;
- (void)setNumber:(id)number forKey:(id)key;
- (void)setObject:(id)object forKey:(id)key;
- (void)setObject:(id)object forKey:(id)key matchingClass:(Class)matchingClass;
- (void)setPaddingChar:(signed char)value;
- (void)setPendingOnShow:(signed char)value;
- (void)setReceivedData:(id)value;
- (void)setResponse:(id)value;
- (void)setRootViewController:(id)value;
- (void)setSDKInterstitialDelegate:(id)value;
- (void)setSlot:(id)value;
- (void)setSourceURL:(id)value;
- (void)setState:(int)value;
- (void)setStatusBarWasHidden:(signed char)value;
- (void)setSwipeDelegate:(id)value;
- (void)setURL:(id)url forView:(id)view;
- (void)setViewController:(id)value;
- (void)setViewForAdUsingView:(id)value;
- (void)setWebView:(id)value;
- (id)slot;
- (id)slotStats;
- (void)start;
- (void)startTimingAdapter;
- (void)startTimingNamed:(id)timingNamed withExplicitEnd:(signed char)explicitEnd;
- (signed char)statusBarWasHidden;
- (void)stop;
- (void)stopBeingDelegate;
- (void)stopLoading;
- (void)stopNetworkChecking;
- (id)swipeDelegate;
- (id)systemVersion;
- (id)timer;
- (id)timingForCategory:(id)category;
- (void)touchesCancelled:(id)touchesCancelled withEvent:(id)event;
- (void)trackURL:(id)trackURL;
- (id)userBirthday;
- (int)userGender;
- (id)userKeywords;
- (void)validate;
- (id)valueForKey:(id)key;
- (id)vars;
- (id)viewControllerForPresentingModalView;
- (void)viewDidAppear:(signed char)view;
- (id)webView;
- (id)webViewDelegate;
- (void)willDismissScreen;
- (void)willLeaveApplication;
@end

@class GADAdMobExtras;
@class GADAdType;
@interface GADAdURLStash : NSObject
@end

@class GADApplication;
@class GADBadAdUtil;
@class GADClickTracker;
@class GADCustomEventExtras;
@class GADDevice;
@class GADGMSGHandler;
@class GADInterstitial;
@class GADLocation;
@class GADMRAIDInterceptor;
@class GADNotification;
@class GADNotificationCenter;
@class GADOpener;
@class GADRequest;
@class GADRequestError;
@class GADRequestPrivate;
@class GADSearchRequestPrivate;
@interface GADSearchSlot : NSObject
@end

@class GADSlot;
@class GADURLConnection;
@interface NSArray : NSObject
@end

@interface NSDate : NSObject
@end

@interface NSDictionary : NSObject
@end

@interface NSNumber : NSObject
@end

@interface NSString : NSObject
@end

@interface UIDevice : NSObject
@end


@interface GADMAdapterIAd : NSObject {
    id connector_;
    id adView_;
    id interstitialAd_;
    signed char useIOS6API_;
}
@property (nonatomic, retain) id adView;
@property (nonatomic, retain) id interstitialAd;
@end

@interface GADSearchRequest : NSObject {
    id backgroundColor;
    id gradientFrom;
    id gradientTo;
    id headerColor;
    id descriptionTextColor;
    id anchorTextColor;
    int headerTextSize;
    id borderColor;
    int borderType;
    int borderThickness;
    int callButtonColor;
    id query;
    id fontFamily;
    id customChannels;
}
@property (nonatomic, copy) id query;
@property (nonatomic, retain) id headerColor;
@property (nonatomic, retain) id descriptionTextColor;
@property (nonatomic, retain) id anchorTextColor;
@property (nonatomic, copy) id fontFamily;
@property (nonatomic, retain) id borderColor;
@property (nonatomic, copy) id customChannels;
@end

@interface GADSearchRequestPrivate : GADSearchRequest {
    id backgroundColor_;
    id gradientFrom_;
    id gradientTo_;
    id headerColor_;
    id descriptionTextColor_;
    id anchorTextColor_;
    int headerTextSize_;
    id borderColor_;
    int borderType_;
    int borderThickness_;
    int callButtonColor_;
    id query_;
    id fontFamily_;
    id channels_;
}
@property (nonatomic, retain) id headerColor;
@property (nonatomic, retain) id descriptionTextColor;
@property (nonatomic, retain) id anchorTextColor;
@property (nonatomic, retain) id borderColor;
@property (nonatomic, copy) id query;
@property (nonatomic, copy) id fontFamily;
@property (nonatomic, copy) id customChannels;
@end

@interface GADRequest : NSObject {
    int _gender;
    id _birthday;
    id _keywords;
    signed char _testing;
    id _mediationExtras;
    id _testDevices;
}
@property (nonatomic, copy) id mediationExtras;
@property (nonatomic, copy) id testDevices;
@property (nonatomic, retain) id birthday;
@property (nonatomic, retain) id keywords;
@end

@interface GADDevice : NSObject
+ (id)currentDevice;
@end

@interface GADRequestPrivate : GADRequest {
    id _location;
    id _childDirectedTreatment;
    id _networkExtrasMap;
}
@property (nonatomic, retain) id location;
@property (nonatomic, retain) id childDirectedTreatment;
@property (nonatomic, retain) id networkExtrasMap;
@end

@interface GADClickTracker : NSObject {
    id delegate_;
    signed char hasTracked_;
    id tracker_;
}
@end

@interface UIViewController : NSObject
@end

@interface GADViewController : UIViewController {
    int _supportedOrientations;
    signed char _viewDidAppear;
    id _slot;
    signed char _statusBarWasHidden;
    signed char _publisherIdleTimerDisabled;
    signed char _appClosing;
    signed char _interactingWithParent;
    signed char _wasPresentedFromViewController;
}
@property (nonatomic, retain) id slot;
@end

@interface GADBrowserController : GADViewController {
    id _URLToLoad;
    id _referringURLToLoad;
    id _webViewDelegate;
    id _webView;
    id _toolbar;
    id _flexibleSpaceButton;
    id _backButton;
    id _backButtonDisabled;
    id _forwardButton;
    id _forwardButtonDisabled;
    id _reloadButton;
    id _safariButton;
    id _doneButton;
    id _spinnerContainingButton;
    id _spinner;
}
@property (nonatomic, retain) id URLToLoad;
@property (nonatomic, retain) id referringURLToLoad;
@property (nonatomic, retain) id webViewDelegate;
@property (nonatomic, retain) id webView;
@property (nonatomic, retain) id toolbar;
@property (nonatomic, retain) id flexibleSpaceButton;
@property (nonatomic, retain) id backButton;
@property (nonatomic, retain) id backButtonDisabled;
@property (nonatomic, retain) id forwardButton;
@property (nonatomic, retain) id forwardButtonDisabled;
@property (nonatomic, retain) id reloadButton;
@property (nonatomic, retain) id safariButton;
@property (nonatomic, retain) id doneButton;
@property (nonatomic, retain) id spinnerContainingButton;
@property (nonatomic, retain) id spinner;
@end

@interface GADWebAppViewController : GADViewController {
    signed char _useCustomClose;
    id _webView;
    signed char _viewHasAppeared;
    signed char _isExpandable;
    signed char _isCollapsing;
    id _bannerScreenshot;
    id _URLToLoad;
    id _HTMLToLoad;
    id _HTMLBaseURLToLoad;
    id _webViewDelegate;
    id _closeButton;
    id _interstitial;
}
@property (nonatomic, retain) id webView;
@property (nonatomic, retain) id bannerScreenshot;
@property (nonatomic, retain) id URLToLoad;
@property (nonatomic, retain) id HTMLToLoad;
@property (nonatomic, retain) id HTMLBaseURLToLoad;
@property (nonatomic, retain) id webViewDelegate;
@property (nonatomic, retain) id closeButton;
@end

@interface GADOpener : NSObject {
    id delegateManager_;
    id viewController_;
    id referringURL_;
    id webView_;
    id slot_;
    signed char didOpenAnotherApplication_;
    id delegate_;
}
@property (nonatomic, retain) id delegateManager;
@property (nonatomic, retain) id referringURL;
@end

@interface GADWebViewDelegate : NSObject {
    id opener_;
    signed char hasLoadedAtLeastOnce_;
    signed char allowFileAccess;
    id _gmsgHandlers;
    id _openerGMSGHandler;
}
@property (nonatomic, retain) id opener;
@property (nonatomic, retain) id openerGMSGHandler;
@end

@interface GADWebAppWebViewDelegate : GADWebViewDelegate {
    signed char _pendingOnShow;
    id _webAppViewController;
    signed char _calledOnShow;
}
@end

@interface GADBannerWebViewDelegate : GADWebViewDelegate {
    id _slot;
}
@end

@interface GADNotification : NSObject {
    id name_;
    id parameters_;
}
@property (nonatomic, retain) id name;
@property (nonatomic, retain) id parameters;
@end

@interface GADStatistics : NSObject {
    id _timingMgr;
    id _statistics;
}
@end

@interface GADSharedStatistics : GADStatistics {
    unsigned long long _sequenceNumber;
}
@end

@interface GADStatisticsCore : NSObject {
    id _userDefaults;
    id _transientStats;
    id _lock;
    id _identifier;
    id _statistics;
}
@property (nonatomic, retain) id userDefaults;
@property (nonatomic, retain) id transientStats;
@property (nonatomic, retain) id lock;
@end

@interface GADInterstitial : NSObject {
    id _request;
    signed char _hasBeenUsed;
    id _viewController;
    id _slot;
}
@property (nonatomic, retain) id request;
@property (nonatomic, retain) id viewController;
@property (nonatomic, retain) id slot;
@end

@interface UIView : NSObject
@end

@interface GADBannerView : UIView {
    id _slot;
}
@property (nonatomic, retain) id slot;
@end

@interface GADSlot : NSObject {
    id _rootViewController;
    id _adSizeDelegate;
    signed char _hasAutoRefreshed;
    signed char _manualImpressionsEnabled;
    id _adType;
    double _timeLastLoaded;
    signed char _isMRAID;
    signed char _isMediating;
    int _supportedOrientations;
    id _webView;
    id _slotStats;
    signed char _calledLoadAndDisplayRequest;
    id _webViewDelegate;
    id _activationView;
    id _activationViewDelegate;
    id _adFetcher;
    double _reloadInterval;
    id _reloadTimer;
    id _adView;
    id _interstitial;
    CGSize _newAdSize;
    id _adMediationGlue;
    signed char _shouldShowActivationOverlay;
    id _adTimer;
    id _delegateManager;
    id _requestPrivate;
    id _requestId;
    id _adDebugDialog;
}
@property (nonatomic, copy) id requestPrivate;
@property (nonatomic, retain) id webView;
@property (nonatomic, retain) id slotStats;
@property (nonatomic, retain) id webViewDelegate;
@property (nonatomic, retain) id activationView;
@property (nonatomic, retain) id activationViewDelegate;
@property (nonatomic, retain) id adFetcher;
@property (nonatomic, retain) id reloadTimer;
@property (nonatomic, copy) id requestId;
@property (nonatomic, retain) id adMediationGlue;
@property (nonatomic, copy) id adDebugDialog;
@property (nonatomic, retain) id adTimer;
@end

@interface GADApplication : NSObject {
    id _currentSession;
    signed char _appFinishedLaunching;
}
@property (nonatomic, retain) id currentSession;
@end

@interface GADLocation : NSObject {
    float latitude_;
    float longitude_;
    float accuracy_;
    double timestamp_;
    id dictionaryRepresentation_;
    id description_;
}
@end

@interface GADDelegateManager : NSObject {
    id _bannerDelegate;
    id _adView;
    id _interstitialDelegate;
    id _interstitial;
    id _SDKInterstitialDelegate;
    id _appEventDelegate;
    id _swipeDelegate;
    id _inAppPurchaseDelegate;
}
@end

@interface GADInterstitialAppController : UIViewController {
    id originalRootViewController_;
    id interstitial_;
    id timeout_;
    id storedUserViews_;
    id imageView_;
}
@property (nonatomic, retain) id originalRootViewController;
@end

@interface GADMAdManager : NSObject {
    id _delegate;
    id _config;
    id _adType;
    id _requestingConnector;
    id _receivedConnector;
    id _lastRequestTime;
    signed char _requestInProgress;
    id _adNetworkTimeoutTimer;
    id _adNetworkConfigQueue;
}
@property (nonatomic, retain) id config;
@property (nonatomic, retain) id adType;
@property (nonatomic, retain) id requestingConnector;
@property (nonatomic, retain) id receivedConnector;
@property (nonatomic, retain) id lastRequestTime;
@end

@interface GADMAdNetworkConfig : NSObject {
    Class _adapterClass;
    id _networkID;
    id _credentials;
    id _extras;
    id _ad;
    id _adapterList;
    id _allocationID;
    id _impressionURLs;
}
@property (nonatomic, copy) id networkID;
@property (nonatomic, copy) id credentials;
@property (nonatomic, copy) id extras;
@property (nonatomic, copy) id ad;
@property (nonatomic, copy) id adapterList;
@property (nonatomic, copy) id allocationID;
@property (nonatomic, copy) id impressionURLs;
@end

@interface GADMToGADGlue : NSObject {
    id _slot;
    id _mediatedInterstitial;
    id _mediationManager;
    id _mediationConfig;
}
@property (nonatomic, retain) id mediationManager;
@property (nonatomic, retain) id mediationConfig;
@end

@interface GADStatisticDictionary : NSObject {
    id _delegate;
    BOOL *_wasDeallocated;
    signed char _allowDictionaryModification;
    signed char _hasEnqueuedNotificationBlock;
}
@end

@interface GADMConfig : NSObject {
    double _refreshInterval;
    int _bannerAnimationType;
    double _adNetworkTimeout;
    id _adType;
    id _adNetworkConfigs;
    id _impressionURLs;
    id _clickURLs;
    id _noFillURLs;
    id _qdata;
    id _appKey;
}
@property (nonatomic, copy) id adNetworkConfigs;
@property (nonatomic, copy) id impressionURLs;
@property (nonatomic, copy) id clickURLs;
@property (nonatomic, copy) id noFillURLs;
@property (nonatomic, copy) id qdata;
@property (nonatomic, retain) id adType;
@property (nonatomic, copy) id appKey;
@end

@interface GADMAdNetworkConnector : NSObject {
    id _strippedCredentials;
    id _gadmDelegate;
    id _adManager;
    id _mediationConfig;
    id _networkConfig;
    id _adapter;
    signed char _didNetworkRefresh;
}
@property (nonatomic, retain) id mediationConfig;
@property (nonatomic, retain) id networkConfig;
@property (nonatomic, retain) id adapter;
@end

@interface GADMAdapterGoogleAdMobAds : NSObject {
    id _banner;
    id _interstitial;
    id _connector;
}
@property (nonatomic, retain) id banner;
@property (nonatomic, retain) id interstitial;
@end

@interface GADAdFetcher : NSObject {
    id _recursiveLock;
    id _request;
    id _delegate;
    id _timer;
    id _adConnection;
    id _activationOverlayConnection;
    signed char _shouldLoadActivationOverlay;
    signed char _adConnectionHasCompleted;
    signed char _activationOverlayConnectionHasCompleted;
    BOOL *_wasDeallocated;
    id _activationOverlayHTML;
    id _activationOverlayBaseURL;
    id _adResponse;
    id _adBaseURL;
}
@property (nonatomic, retain) id recursiveLock;
@property (nonatomic, retain) id request;
@property (nonatomic, retain) id timer;
@property (nonatomic, retain) id adConnection;
@property (nonatomic, retain) id activationOverlayConnection;
@property (nonatomic, copy) id activationOverlayHTML;
@property (nonatomic, copy) id activationOverlayBaseURL;
@property (nonatomic, copy) id adResponse;
@property (nonatomic, copy) id adBaseURL;
@end

@interface GADURLConnection : NSObject
@end

@interface UIGestureRecognizer : NSObject
@end

@interface GADImpressionTicketGestureRecognizer : UIGestureRecognizer {
    id _vars;
}
@property (nonatomic, retain) id vars;
@end

@interface NSURLProtocol : NSObject
@end

@interface GADMRAIDInterceptor : NSURLProtocol {
    id _mraidLocationToLoad;
}
@property (nonatomic, copy) id mraidLocationToLoad;
@end

@interface GADSession : NSObject {
    unsigned long long _sessionID;
}
@end

@interface GADMAdapterCustomEvents : NSObject {
    id _connector;
    id _customEventBanner;
    id _customEventInterstitial;
}
@property (nonatomic, retain) id customEventBanner;
@property (nonatomic, retain) id customEventInterstitial;
@end

@interface GADCustomEventRequest : NSObject {
    int userGender_;
    id userBirthday_;
    signed char userHasLocation_;
    float userLongitude_;
    float userLatitude_;
    float userLocationAccuracyInMeters_;
    id userLocationDescription_;
    id userKeywords_;
    id additionalParameters_;
    signed char isTesting_;
}
@end

@interface GADUIWebViewGestureDelgate : NSObject
@end

@interface GADCustomEventExtras : NSObject {
    id extras_;
}
@property (nonatomic, retain) id extras;
@end

@interface GADAd : NSObject {
    GADAdSize _size;
    int _supportedOrientations;
    signed char _activationAndScrollEnabled;
    id _adBaseURL;
    id _adHTML;
    id _adURL;
    id _activationOverlayBaseURL;
    id _activationOverlayHTML;
    id _activationOverlayURL;
    id _clickURLs;
    id _impressionURLs;
    id _manualImpressionURLs;
    id _debugDialog;
}
@property (nonatomic, copy) id adBaseURL;
@property (nonatomic, copy) id adHTML;
@property (nonatomic, copy) id adURL;
@property (nonatomic, copy) id activationOverlayBaseURL;
@property (nonatomic, copy) id activationOverlayHTML;
@property (nonatomic, copy) id activationOverlayURL;
@property (nonatomic, copy) id clickURLs;
@property (nonatomic, copy) id impressionURLs;
@property (nonatomic, copy) id manualImpressionURLs;
@property (nonatomic, copy) id debugDialog;
@end

@interface GADAdInterstitial : GADAd {
    double _interstitialTimeout;
}
@end

@interface GADAdType : NSObject {
    signed char _isInterstitial;
    GADAdSize _adSize;
}
@end

@interface GADImpressionTicketGestureRecognizerPrivate : NSObject {
    int gestureState_;
    unsigned int distanceMoved_;
}
@end

@interface GADMAdNetworkConnectorBanner : GADMAdNetworkConnector {
    signed char _didNetworkReturn;
}
@end

@interface GADMAdNetworkConnectorInterstitial : GADMAdNetworkConnector {
    signed char _calledWillDismissInterstitial;
}
@end

@interface DFPBannerView : GADBannerView {
    id validAdSizes_;
}
@property (nonatomic, retain) id validAdSizes;
@end

@interface GADAdBanner : GADAd {
    double _refreshInterval;
}
@end

@interface GADBadAdUtil : NSObject {
    id connection_;
}
@property (nonatomic, retain) id connection;
@end

@interface GADActivationViewDelegate : NSObject {
    id slot_;
}
@end

@interface GADJavaScriptController : NSObject {
    signed char _shouldCheckOreoID;
    id _buildAdJS;
    id _buildAdWebView;
}
@property (nonatomic, retain) id buildAdJS;
@property (nonatomic, retain) id buildAdWebView;
@end

@interface UIWebView : NSObject
@end

@interface GADWebView : UIWebView {
    id _viewController;
    signed char _touched;
    signed char _showDebug;
    signed char _didReceiveLoadEvent;
    int _orientation;
    id _gestureDelegate;
    id _gesture;
    id _alertView;
    signed char _savedState;
    CGRect _savedFrame;
    id _savedSuperview;
    id _savedDelegate;
    id _url;
    id _URL;
    id _viewControllerBeforeExpanded;
    id _adDebugDialog;
}
@property (nonatomic, copy) id adDebugDialog;
@property (nonatomic, retain) id gestureDelegate;
@property (nonatomic, retain) id gesture;
@property (nonatomic, retain) id alertView;
@property (nonatomic, retain) id savedSuperview;
@property (nonatomic, retain) id savedDelegate;
@property (nonatomic, retain) id URL;
@end

@interface GADPublisherToolbarController : GADViewController {
    id _credentials;
    id _oauthWebView;
    id _jsWebView;
    id _spinnyWheel;
    id _helperJS;
    id _adUnitID;
    id _adContent;
}
@property (nonatomic, retain) id credentials;
@property (nonatomic, retain) id oauthWebView;
@property (nonatomic, retain) id jsWebView;
@property (nonatomic, retain) id spinnyWheel;
@property (nonatomic, retain) id helperJS;
@property (nonatomic, copy) id adUnitID;
@property (nonatomic, copy) id adContent;
@end

@interface GADInAppPurchase : NSObject {
    unsigned int _quantity;
    id _productID;
}
@property (nonatomic, copy) id productID;
@end

@interface GADGMSGHandler : NSObject {
    id _actionRouter;
}
@property (nonatomic, retain) id actionRouter;
@end

@interface GADAppEventGMSGHandler : GADGMSGHandler {
    id _slot;
}
@end

@interface GADOpenerGMSGHandler : GADGMSGHandler {
    id _gadOpener;
    id _subParamActionRouter;
}
@property (nonatomic, retain) id gadOpener;
@property (nonatomic, retain) id subParamActionRouter;
@end

@interface GADActionRouter : NSObject {
    id _receiver;
}
@end

@interface GADMWebViewRenderedChecker : NSObject {
    id webView_;
    id delegate_;
}
@end

@interface GADMAdapterHTML : NSObject {
    id webView_;
    id passbackUrl_;
    id connector_;
}
@property (nonatomic, retain) id webView;
@property (nonatomic, retain) id passbackUrl;
@end

@interface GADAdMobExtras : NSObject {
    id _additionalParameters;
}
@property (nonatomic, copy) id additionalParameters;
@end

@interface DFPExtras : GADAdMobExtras {
    id _publisherProvidedID;
}
@property (nonatomic, copy) id publisherProvidedID;
@end

@interface GADPublisherToolbarCredentials : NSObject {
    id _credentials;
}
@property (nonatomic, copy) id credentials;
@end

@interface NSError : NSObject
@end

@interface GADRequestError : NSError
@end

@interface GADIntrinsicImages : NSObject
@end

@interface NSNotificationCenter : NSObject
@end

@interface GADNotificationCenter : NSNotificationCenter
@end

@interface GADSearchBannerView : GADBannerView
@end

@interface GADClickTrackerCollection : NSObject {
    id trackers_;
}
@end

@interface DFPInterstitial : GADInterstitial
@end

@interface GADSlotStatistics : GADStatistics
@end

@interface GADActivationView : UIWebView
@end

@interface DFPSwipeableBannerView : DFPBannerView
@end

@implementation GADMAdapterIAd

@synthesize adView = adView_;
@synthesize interstitialAd = interstitialAd_;

+ (Class)networkExtrasClass
{
    return 0;
}

- (void)interstitialAdActionDidFinish:(id)interstitialAdAction
{
}

- (id)connector
{
    return connector_;
}

- (void)setConnector:(id)value
{
    connector_ = value;
}

- (signed char)useIOS6API
{
    return useIOS6API_;
}

- (void)setUseIOS6API:(signed char)value
{
    useIOS6API_ = value;
}

@end

extern id NSAllocateObject(Class cls, unsigned int extraBytes, struct _NSZone *zone);

@implementation GADSearchRequest

@synthesize query = query;
@synthesize headerColor = headerColor;
@synthesize descriptionTextColor = descriptionTextColor;
@synthesize anchorTextColor = anchorTextColor;
@synthesize fontFamily = fontFamily;
@synthesize borderColor = borderColor;
@synthesize customChannels = customChannels;

- (void)setBackgroundSolid:(id)color
{
}

- (void)setBackgroundGradientFrom:(id)backgroundGradientFrom toColor:(id)color
{
}

- (id)backgroundColor
{
    return backgroundColor;
}

- (id)gradientFrom
{
    return gradientFrom;
}

- (id)gradientTo
{
    return gradientTo;
}

- (int)headerTextSize
{
    return headerTextSize;
}

- (void)setHeaderTextSize:(int)value
{
    headerTextSize = value;
}

- (int)borderType
{
    return borderType;
}

- (void)setBorderType:(int)value
{
    borderType = value;
}

- (int)borderThickness
{
    return borderThickness;
}

- (void)setBorderThickness:(int)value
{
    borderThickness = value;
}

- (int)callButtonColor
{
    return callButtonColor;
}

- (void)setCallButtonColor:(int)value
{
    callButtonColor = value;
}

+ (id)alloc
{
    return [GADSearchRequestPrivate allocWithZone:0];
}

+ (id)allocWithZone:(struct _NSZone *)zone
{
    return NSAllocateObject([GADSearchRequestPrivate class], 0, zone);
}

@end

@implementation GADSearchRequestPrivate

@synthesize headerColor = headerColor_;
@synthesize descriptionTextColor = descriptionTextColor_;
@synthesize anchorTextColor = anchorTextColor_;
@synthesize borderColor = borderColor_;
@synthesize query = query_;
@synthesize fontFamily = fontFamily_;
@synthesize customChannels = channels_;

- (void)setBackgroundSolid:(id)color
{
    backgroundColor_ = [color retain];
    gradientFrom_ = nil;
    gradientTo_ = nil;
}

- (void)setBackgroundGradientFrom:(id)from toColor:(id)to
{
    if (from && to) {
        backgroundColor_ = nil;
        gradientFrom_ = [from retain];
        gradientTo_ = [to retain];
    }
}

- (id)backgroundColor
{
    return backgroundColor_;
}

- (id)gradientFrom
{
    return gradientFrom_;
}

- (id)gradientTo
{
    return gradientTo_;
}

- (int)headerTextSize
{
    return headerTextSize_;
}

- (void)setHeaderTextSize:(int)value
{
    headerTextSize_ = value;
}

- (int)borderType
{
    return borderType_;
}

- (void)setBorderType:(int)value
{
    borderType_ = value;
}

- (int)borderThickness
{
    return borderThickness_;
}

- (void)setBorderThickness:(int)value
{
    borderThickness_ = value;
}

- (int)callButtonColor
{
    return callButtonColor_;
}

- (void)setCallButtonColor:(int)value
{
    callButtonColor_ = value;
}

- (void)dealloc
{
    [query_ release];
    [backgroundColor_ release];
    [gradientFrom_ release];
    [gradientTo_ release];
    [headerColor_ release];
    [descriptionTextColor_ release];
    [anchorTextColor_ release];
    [fontFamily_ release];
    [borderColor_ release];
    [channels_ release];
    [super dealloc];
}

@end

@implementation GADClickTracker

- (id)delegate
{
    return delegate_;
}

- (void)setDelegate:(id)value
{
    delegate_ = value;
}

- (signed char)hasTracked
{
    return hasTracked_;
}

- (id)trackingURL
{
    return [tracker_ httpDestinationURL];
}

- (void)dealloc
{
    [self reset];
    [super dealloc];
}

@end

@implementation GADWebViewDelegate

@synthesize opener = opener_;
@synthesize openerGMSGHandler = _openerGMSGHandler;

- (void)webViewDidStartLoad:(id)webView
{
}

- (void)loadedFirstPage:(id)loadedFirstPage
{
}

- (signed char)hasLoadedAtLeastOnce
{
    return hasLoadedAtLeastOnce_;
}

- (signed char)allowFileAccess
{
    return allowFileAccess;
}

- (void)setAllowFileAccess:(signed char)value
{
    allowFileAccess = value;
}

- (id)gmsgHandlers
{
    return _gmsgHandlers;
}

- (void)addGMSGHandler:(id)gMSGHandler
{
    [[self gmsgHandlers] addObject:gMSGHandler];
}

- (void)dealloc
{
    [_gmsgHandlers release];
    [_openerGMSGHandler release];
    [opener_ setViewController:nil];
    [opener_ setSlot:nil];
    [opener_ setWebView:nil];
    [opener_ release];
    [super dealloc];
}

@end

@implementation GADWebAppWebViewDelegate

- (signed char)pendingOnShow
{
    return _pendingOnShow;
}

- (id)webAppViewController
{
    return _webAppViewController;
}

- (void)setWebAppViewController:(id)value
{
    _webAppViewController = value;
}

- (signed char)calledOnShow
{
    return _calledOnShow;
}

@end

@implementation GADBannerWebViewDelegate

- (id)slot
{
    return _slot;
}

@end

@implementation GADStatistics

- (void)startTimingNamed:(id)name withExplicitEnd:(signed char)explicitEnd
{
    [_timingMgr removeTimingForCategory:name];
    id timing = [_timingMgr addTimingWithCategory:name];
    [timing setExplicitEnd:explicitEnd];
    [timing start];
}

- (unsigned int)valueForParameter:(id)name
{
    return [[_statistics numberForKey:name] unsignedIntegerValue];
}

+ (id)allTimingNames
{
    return nil;
}

+ (id)allCounterNames
{
    return nil;
}

- (id)parameters
{
    return nil;
}

- (id)timingNamed:(id)timingNamed
{
    return [_timingMgr timingForCategory:timingNamed];
}

- (void)endTimingNamed:(id)timingNamed
{
    [[_timingMgr timingForCategory:timingNamed] end];
}

- (void)removeTimingNamed:(id)timingNamed
{
    [_timingMgr removeTimingForCategory:timingNamed];
}

- (void)incrementParameterCount:(id)incrementParameterCount
{
    [_statistics addValue:1 numberForKey:incrementParameterCount];
}

- (void)resetParameterCount:(id)resetParameterCount
{
    [_statistics setNumber:[NSNumber numberWithInt:0] forKey:resetParameterCount];
}

- (void)setFlagWithParameterName:(id)value
{
    [_statistics setNumber:[NSNumber numberWithInt:1] forKey:value];
}

- (void)resetFlagWithParameterName:(id)parameterName
{
    [_statistics removeObjectForKey:parameterName];
}

@end

@implementation GADSharedStatistics

- (unsigned long long)sequenceNumber
{
    return _sequenceNumber;
}

- (void)setSequenceNumber:(unsigned long long)value
{
    _sequenceNumber = value;
}

@end

@implementation GADStatisticsCore

@synthesize userDefaults = _userDefaults;
@synthesize transientStats = _transientStats;
@synthesize lock = _lock;

- (void)synchronize
{
    [self savePersistentStatistics];
}

- (void)setString:(id)string forKey:(id)key
{
    [self setObject:string forKey:key matchingClass:[NSString class]];
}

- (void)setNumber:(id)number forKey:(id)key
{
    [self setObject:number forKey:key matchingClass:[NSNumber class]];
}

- (void)setDate:(id)date forKey:(id)key
{
    [self setObject:date forKey:key matchingClass:[NSDate class]];
}

- (void)setArray:(id)array forKey:(id)key
{
    [self setObject:array forKey:key matchingClass:[NSArray class]];
}

- (void)setDictionary:(id)dictionary forKey:(id)key
{
    [self setObject:dictionary forKey:key matchingClass:[NSDictionary class]];
}

- (id)stringForKey:(id)key
{
    return [_statistics objectForKey:key];
}

- (id)numberForKey:(id)key
{
    return [_statistics objectForKey:key];
}

- (id)dateForKey:(id)key
{
    return [_statistics objectForKey:key];
}

- (id)arrayForKey:(id)key
{
    return [_statistics objectForKey:key];
}

- (id)dictionaryForKey:(id)key
{
    return [_statistics objectForKey:key];
}

- (void)removeObjectForKey:(id)key
{
    [_statistics removeObjectForKey:key];
}

- (void)removeAllObjects
{
    [_statistics removeAllObjects];
}

@end

@implementation GADInterstitial

@synthesize request = _request;
@synthesize viewController = _viewController;
@synthesize slot = _slot;

- (id)privateRequest
{
    return _request;
}

- (signed char)hasBeenUsed
{
    return _hasBeenUsed;
}

- (void)setHasBeenUsed:(signed char)value
{
    _hasBeenUsed = value;
}

- (void)cancel
{
    [[self slot] cancelPendingAndFutureActions];
}

- (void)setAdUnitID:(id)value
{
    [[self slot] setAdUnitID:value];
}

- (id)adUnitID
{
    return [[self slot] adUnitID];
}

- (void)setDelegate:(id)value
{
    [[[self slot] delegateManager] setInterstitialDelegate:value];
    [[[self slot] delegateManager] setInterstitial:self];
}

- (id)delegate
{
    return [[[self slot] delegateManager] interstitialDelegate];
}

- (void)setInAppPurchaseDelegate:(id)value
{
    [[[self slot] delegateManager] setInAppPurchaseDelegate:value];
}

- (id)inAppPurchaseDelegate
{
    return [[[self slot] delegateManager] inAppPurchaseDelegate];
}

- (void)sendInterstitialUsageError
{
    [self sendInterstitialError:[GADRequestError errorWithCode:6 request:[self privateRequest]]];
}

- (id)adNetworkClassName
{
    return [[self slot] adNetworkClassName];
}

@end

@implementation GADBannerView

@synthesize slot = _slot;

- (void)setAdUnitID:(id)value
{
    [[self slot] setAdUnitID:value];
}

- (id)adUnitID
{
    return [[self slot] adUnitID];
}

- (void)setDelegate:(id)value
{
    [[[self slot] delegateManager] setBannerDelegate:value];
    [[[self slot] delegateManager] setAdView:self];
}

- (id)delegate
{
    return [[[self slot] delegateManager] bannerDelegate];
}

- (void)setInAppPurchaseDelegate:(id)value
{
    [[[self slot] delegateManager] setInAppPurchaseDelegate:value];
}

- (id)inAppPurchaseDelegate
{
    return [[[self slot] delegateManager] inAppPurchaseDelegate];
}

- (void)setRootViewController:(id)value
{
    [[self slot] setRootViewController:value];
    [[[self slot] webView] setViewController:value];
}

- (id)rootViewController
{
    return [[self slot] rootViewController];
}

- (id)webView
{
    return [[self slot] webView];
}

- (signed char)hasAutoRefreshed
{
    return [[self slot] hasAutoRefreshed];
}

- (id)mediatedAdView
{
    return [[self slot] mediatedAdView];
}

- (id)adNetworkClassName
{
    return [[self slot] adNetworkClassName];
}

@end

@implementation GADSlot

@synthesize requestPrivate = _requestPrivate;
@synthesize webView = _webView;
@synthesize slotStats = _slotStats;
@synthesize webViewDelegate = _webViewDelegate;
@synthesize activationView = _activationView;
@synthesize activationViewDelegate = _activationViewDelegate;
@synthesize adFetcher = _adFetcher;
@synthesize reloadTimer = _reloadTimer;
@synthesize requestId = _requestId;
@synthesize adMediationGlue = _adMediationGlue;
@synthesize adDebugDialog = _adDebugDialog;
@synthesize adTimer = _adTimer;

- (id)rootViewController
{
    return _rootViewController;
}

- (id)adSizeDelegate
{
    return _adSizeDelegate;
}

- (void)setAdSizeDelegate:(id)value
{
    _adSizeDelegate = value;
}

- (signed char)hasAutoRefreshed
{
    return _hasAutoRefreshed;
}

- (signed char)manualImpressionsEnabled
{
    return _manualImpressionsEnabled;
}

- (void)setManualImpressionsEnabled:(signed char)value
{
    _manualImpressionsEnabled = value;
}

- (id)adType
{
    return _adType;
}

- (double)timeLastLoaded
{
    return _timeLastLoaded;
}

- (void)setTimeLastLoaded:(double)value
{
    _timeLastLoaded = value;
}

- (signed char)isMRAID
{
    return _isMRAID;
}

- (void)setIsMRAID:(signed char)value
{
    _isMRAID = value;
}

- (signed char)isMediating
{
    return _isMediating;
}

- (void)setIsMediating:(signed char)value
{
    _isMediating = value;
}

- (int)supportedOrientations
{
    return _supportedOrientations;
}

- (void)setSupportedOrientations:(int)value
{
    _supportedOrientations = value;
}

- (signed char)calledLoadAndDisplayRequest
{
    return _calledLoadAndDisplayRequest;
}

- (void)setCalledLoadAndDisplayRequest:(signed char)value
{
    _calledLoadAndDisplayRequest = value;
}

- (double)reloadInterval
{
    return _reloadInterval;
}

- (void)setReloadInterval:(double)value
{
    _reloadInterval = value;
}

- (id)adView
{
    return _adView;
}

- (id)interstitial
{
    return _interstitial;
}

- (void)setInterstitial:(id)value
{
    _interstitial = value;
}

- (CGSize)newAdSize
{
    return _newAdSize;
}

- (signed char)shouldShowActivationOverlay
{
    return _shouldShowActivationOverlay;
}

- (void)setShouldShowActivationOverlay:(signed char)set
{
    _shouldShowActivationOverlay = set;
}

- (id)mediatedInterstitial
{
    return [_adMediationGlue mediatedInterstitial];
}

- (void)setAdType:(id)value
{
    [self setAdType:value andReloadRequest:1];
}

+ (void)initialize
{
    if ([GADSlot class] != self) {
        return;
    }
    [[GADApplication sharedApplication] runEarlyActivities];
}

- (void)deactivateReloadTimer
{
    [self resetReloadTimer];
}

- (void)appDidBecomeInactive:(id)app
{
    [self deactivateReloadTimer];
}

- (void)appDidBecomeActive:(id)app
{
    [self activateReloadTimer];
}

- (void)adWillPresentFullScreen:(id)ad
{
    [self deactivateReloadTimer];
}

- (void)adDidRelinquishFullScreen:(id)ad
{
    [self activateReloadTimer];
}

- (void)loadHTMLFromURL:(id)url
{
    [self loadAdHTMLFromURL:url usingActivationOverlayURL:nil];
}

- (void)loadRequest:(id)request
{
    [self loadPrivateRequest:[GADRequestPrivate requestPrivateWithRequest:request] autoRefresh:0];
}

- (void)handleActivationOverlayResponse:(id)response withBaseURL:(id)baseURL
{
    [_activationView loadHTMLString:response baseURL:baseURL];
}

- (void)didFailToReceiveAdWithError:(id)error
{
    [self setState:7];
    [self activateReloadTimer];
    [[self delegateManager] didFailToReceiveAdWithError:error];
}

- (void)markAdStartTime
{
    [[self adTimer] start];
}

- (void)notifyAdRequestHasStarted
{
    [self markAdStartTime];
    [GADMRAIDInterceptor enableCanInitWithRequest];
}

- (void)markAdCompletedTime
{
    [[self adTimer] end];
}

- (void)notifyAdRequestHasCompleted
{
    [self markAdCompletedTime];
    [GADMRAIDInterceptor disableCanInitWithRequest];
}

@end

@implementation GADDelegateManager

- (id)bannerDelegate
{
    return _bannerDelegate;
}

- (void)setBannerDelegate:(id)value
{
    _bannerDelegate = value;
}

- (id)adView
{
    return _adView;
}

- (void)setAdView:(id)value
{
    _adView = value;
}

- (id)interstitialDelegate
{
    return _interstitialDelegate;
}

- (void)setInterstitialDelegate:(id)value
{
    _interstitialDelegate = value;
}

- (id)interstitial
{
    return _interstitial;
}

- (void)setInterstitial:(id)value
{
    _interstitial = value;
}

- (id)SDKInterstitialDelegate
{
    return _SDKInterstitialDelegate;
}

- (void)setSDKInterstitialDelegate:(id)value
{
    _SDKInterstitialDelegate = value;
}

- (id)appEventDelegate
{
    return _appEventDelegate;
}

- (void)setAppEventDelegate:(id)value
{
    _appEventDelegate = value;
}

- (id)swipeDelegate
{
    return _swipeDelegate;
}

- (void)setSwipeDelegate:(id)value
{
    _swipeDelegate = value;
}

- (id)inAppPurchaseDelegate
{
    return _inAppPurchaseDelegate;
}

- (void)setInAppPurchaseDelegate:(id)value
{
    _inAppPurchaseDelegate = value;
}

@end

@implementation GADInterstitialAppController

@synthesize originalRootViewController = originalRootViewController_;

- (signed char)shouldAutorotate
{
    return 1;
}

- (unsigned int)supportedInterfaceOrientations
{
    return 2;
}

- (void)dealloc
{
    [originalRootViewController_ release];
    [interstitial_ release];
    [timeout_ invalidate];
    [timeout_ release];
    [storedUserViews_ release];
    [imageView_ removeFromSuperview];
    [imageView_ release];
    [super dealloc];
}

- (void)removeSelfAsDelegate
{
    [[[interstitial_ slot] delegateManager] setSDKInterstitialDelegate:nil];
}

- (void)interstitialDidReceiveAd:(id)interstitial
{
    [timeout_ invalidate];
    [interstitial_ presentFromRootViewController:self];
}

- (void)interstitialWillDismissScreen:(id)interstitial
{
    [self removeSelfAsDelegate];
    [self restoreWindowAndRelease];
}

@end

@implementation GADMAdManager

@synthesize config = _config;
@synthesize adType = _adType;
@synthesize requestingConnector = _requestingConnector;
@synthesize receivedConnector = _receivedConnector;
@synthesize lastRequestTime = _lastRequestTime;

- (id)delegate
{
    return _delegate;
}

- (signed char)requestInProgress
{
    return _requestInProgress;
}

- (void)setRequestInProgress:(signed char)value
{
    _requestInProgress = value;
}

- (id)adNetworkTimeoutTimer
{
    return _adNetworkTimeoutTimer;
}

- (void)setAdNetworkTimeoutTimer:(id)value
{
    _adNetworkTimeoutTimer = value;
}

- (void)dealloc
{
    [_adType release];
    [_config release];
    [_adNetworkConfigQueue release];
    [_lastRequestTime release];
    [_requestingConnector setGadmDelegate:nil];
    [_requestingConnector setAdManager:nil];
    [_requestingConnector release];
    [_receivedConnector setAdManager:nil];
    [_receivedConnector setGadmDelegate:nil];
    [_receivedConnector release];
    [super dealloc];
}

- (void)requestNextAdNetwork
{
    [self makeAdRequest];
}

- (void)cancel
{
    [self cancelPendingActions];
    [[self requestingConnector] askAdapterToStopBeingDelegate];
    [[self requestingConnector] setGadmDelegate:nil];
    [[self requestingConnector] setAdManager:nil];
    [[self receivedConnector] askAdapterToStopBeingDelegate];
    [[self receivedConnector] setGadmDelegate:nil];
    [[self receivedConnector] setAdManager:nil];
}

@end

@implementation GADMAdNetworkConfig

@synthesize networkID = _networkID;
@synthesize credentials = _credentials;
@synthesize extras = _extras;
@synthesize ad = _ad;
@synthesize adapterList = _adapterList;
@synthesize allocationID = _allocationID;
@synthesize impressionURLs = _impressionURLs;

- (Class)adapterClass
{
    return _adapterClass;
}

- (void)setAdapterClass:(Class)value
{
    _adapterClass = value;
}

- (id)publisherID
{
    return [[self credentials] objectForKey:@"pubid"];
}

- (void)dealloc
{
    [_networkID release];
    [_credentials release];
    [_extras release];
    [_ad release];
    [_adapterList release];
    [_allocationID release];
    [_impressionURLs release];
    [super dealloc];
}

@end

@implementation GADMToGADGlue

@synthesize mediationManager = _mediationManager;
@synthesize mediationConfig = _mediationConfig;

- (id)slot
{
    return _slot;
}

- (void)setSlot:(id)value
{
    _slot = value;
}

- (id)mediatedInterstitial
{
    return _mediatedInterstitial;
}

- (void)setMediatedInterstitial:(id)value
{
    _mediatedInterstitial = value;
}

- (void)cancel
{
    [[self mediationManager] setDelegate:nil];
    [[self mediationManager] cancel];
}

- (void)dealloc
{
    [_mediationManager setDelegate:nil];
    [_mediationManager cancelPendingActions];
    [_mediationManager release];
    [_mediationConfig release];
    [super dealloc];
}

- (id)viewControllerForPresentingModalView
{
    return [[self slot] rootViewController];
}

- (void)gadmDidReceiveAd:(id)gadm
{
    [[self slot] setViewForAdUsingView:gadm];
    [[self slot] setState:6];
    [[[self slot] delegateManager] didReceiveAd];
}

- (void)gadmDidFailToReceiveAdWithError:(id)gadm
{
    [[self slot] setState:7];
    [[[self slot] delegateManager] didFailToReceiveAdWithError:gadm];
}

- (void)gadmDidReceiveInterstitial:(id)gadm
{
    [self setMediatedInterstitial:gadm];
    [[self slot] setState:6];
    [[[self slot] delegateManager] didReceiveAd];
}

- (void)gadmWillDismissFullScreenModal
{
    [[[self slot] delegateManager] willDismissScreen];
}

- (void)gadmWillDismissInterstitial
{
    [[[self slot] delegateManager] willDismissScreen];
}

- (void)gadmWillLeaveApplication
{
    [[[self slot] delegateManager] willLeaveApplication];
    [[[self slot] slotStats] setClickBackgroundedApp];
}

- (void)gadmBannerAdRefreshFailedWithError:(id)error
{
    [[self slot] mediatedAdNetworkAutoRefreshed];
    [[[self slot] delegateManager] didFailToReceiveAdWithError:error];
}

- (signed char)gadmTestMode
{
    return [[[self slot] requestPrivate] isATestDevice];
}

- (int)userGender
{
    return [[[self slot] requestPrivate] gender];
}

- (id)userBirthday
{
    return [[[self slot] requestPrivate] birthday];
}

- (id)userLocation
{
    return [[[self slot] requestPrivate] location];
}

- (id)userKeywords
{
    return [[[self slot] requestPrivate] keywords];
}

- (id)childDirectedTreatment
{
    return [[[self slot] requestPrivate] childDirectedTreatment];
}

- (id)networkExtrasFor:(Class)networkExtrasFor
{
    return [[[self slot] requestPrivate] adNetworkExtrasFor:networkExtrasFor];
}

- (void)startTimingAdapter
{
    [[[self slot] slotStats] startTimingAdapter];
}

- (void)resetTimingAdapters
{
    [[[self slot] slotStats] resetTimingAdapters];
}

- (void)endTimingAdapterWithExitCode:(int)exitCode
{
    [[[self slot] slotStats] endTimingAdapterWithExitCode:exitCode];
}

- (id)adapterDurationsParameter
{
    return [[[self slot] slotStats] adapterDurationsParameter];
}

- (id)adapterExitCodesParameter
{
    return [[[self slot] slotStats] adapterExitCodesParameter];
}

@end

@implementation GADStatisticDictionary

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)value
{
    _delegate = value;
}

- (BOOL *)wasDeallocated
{
    return _wasDeallocated;
}

- (void)setWasDeallocated:(BOOL *)value
{
    _wasDeallocated = value;
}

- (signed char)allowDictionaryModification
{
    return _allowDictionaryModification;
}

- (void)setAllowDictionaryModification:(signed char)value
{
    _allowDictionaryModification = value;
}

- (signed char)hasEnqueuedNotificationBlock
{
    return _hasEnqueuedNotificationBlock;
}

- (void)setHasEnqueuedNotificationBlock:(signed char)value
{
    _hasEnqueuedNotificationBlock = value;
}

- (id)init
{
    return [self initWithDelegate:nil];
}

- (id)objectForKeyedSubscript:(id)keyedSubscript
{
    return [self objectForKey:keyedSubscript];
}

@end

@implementation GADMConfig

@synthesize adNetworkConfigs = _adNetworkConfigs;
@synthesize impressionURLs = _impressionURLs;
@synthesize clickURLs = _clickURLs;
@synthesize noFillURLs = _noFillURLs;
@synthesize qdata = _qdata;
@synthesize adType = _adType;
@synthesize appKey = _appKey;

- (double)refreshInterval
{
    return _refreshInterval;
}

- (int)bannerAnimationType
{
    return _bannerAnimationType;
}

- (void)setBannerAnimationType:(int)value
{
    _bannerAnimationType = value;
}

- (double)adNetworkTimeout
{
    return _adNetworkTimeout;
}

- (void)setAdNetworkTimeout:(double)value
{
    _adNetworkTimeout = value;
}

- (void)dealloc
{
    [_adType release];
    [_appKey release];
    [_adNetworkConfigs release];
    [_impressionURLs release];
    [_clickURLs release];
    [_noFillURLs release];
    [_qdata release];
    [super dealloc];
}

@end

@implementation GADMAdNetworkConnector

@synthesize mediationConfig = _mediationConfig;
@synthesize networkConfig = _networkConfig;
@synthesize adapter = _adapter;

- (id)credentials
{
    return _strippedCredentials;
}

- (void)adapter:(id)adapter didReceiveAdView:(id)adView
{
}

- (void)adapter:(id)adapter didFailAd:(id)error
{
}

- (void)adapter:(id)adapter didReceiveInterstitial:(id)interstitial
{
}

- (void)adapter:(id)adapter didFailInterstitial:(id)error
{
}

- (void)adapter:(id)adapter clickDidOccurInBanner:(id)banner
{
}

- (void)adapterWillPresentFullScreenModal:(id)adapter
{
}

- (void)adapterWillDismissFullScreenModal:(id)adapter
{
}

- (void)adapterDidDismissFullScreenModal:(id)adapter
{
}

- (void)adapterWillPresentInterstitial:(id)adapter
{
}

- (void)adapterWillDismissInterstitial:(id)adapter
{
}

- (void)adapterDidDismissInterstitial:(id)adapter
{
}

- (void)adapterWillLeaveApplication:(id)adapter
{
}

- (id)gadmDelegate
{
    return _gadmDelegate;
}

- (void)setGadmDelegate:(id)value
{
    _gadmDelegate = value;
}

- (id)adManager
{
    return _adManager;
}

- (void)setAdManager:(id)value
{
    _adManager = value;
}

- (signed char)didNetworkRefresh
{
    return _didNetworkRefresh;
}

- (void)setDidNetworkRefresh:(signed char)set
{
    _didNetworkRefresh = set;
}

- (void)askAdapterToStopBeingDelegate
{
    [[self adapter] stopBeingDelegate];
}

- (signed char)askAdapterIsBannerAnimationOK:(int)askAdapterIsBannerAnimationOK
{
    return [[self adapter] isBannerAnimationOK:askAdapterIsBannerAnimationOK];
}

- (id)publisherId
{
    return [[self networkConfig] publisherID];
}

- (id)viewControllerForPresentingModalView
{
    return [_gadmDelegate viewControllerForPresentingModalView];
}

- (int)userGender
{
    return [_gadmDelegate userGender];
}

- (id)userBirthday
{
    return [_gadmDelegate userBirthday];
}

- (id)userKeywords
{
    return [_gadmDelegate userKeywords];
}

- (id)childDirectedTreatment
{
    return [_gadmDelegate childDirectedTreatment];
}

@end

@implementation GADMAdapterGoogleAdMobAds

@synthesize banner = _banner;
@synthesize interstitial = _interstitial;

- (signed char)isBannerAnimationOK:(int)animation
{
    return 1;
}

- (id)connector
{
    return _connector;
}

- (void)setConnector:(id)value
{
    _connector = value;
}

- (void)dealloc
{
    [self stopBeingDelegate];
    [_interstitial release];
    [_banner release];
    [super dealloc];
}

+ (id)adapterVersion
{
    return [GADRequest sdkVersion];
}

+ (Class)networkExtrasClass
{
    return [GADAdMobExtras class];
}

- (void)getInterstitial
{
    id request = [self request];
    [self setInterstitial:[[[GADInterstitial alloc] init] autorelease]];
    [[self interstitial] setAdUnitID:[[self connector] publisherId]];
    [[self interstitial] setDelegate:self];
    [[self interstitial] loadRequest:request];
}

- (void)stopBeingDelegate
{
    [[self banner] setDelegate:nil];
    [[self interstitial] setDelegate:nil];
}

- (void)presentInterstitialFromRootViewController:(id)controller
{
    [[self interstitial] presentFromRootViewController:controller];
}

- (void)adViewDidReceiveAd:(id)adView
{
    [[self connector] adapter:self didReceiveAdView:adView];
}

- (void)adView:(id)adView didFailToReceiveAdWithError:(id)error
{
    [[self connector] adapter:self didFailAd:error];
}

- (void)adViewWillPresentScreen:(id)adView
{
    [[self connector] adapter:self clickDidOccurInBanner:adView];
    [[self connector] adapterWillPresentFullScreenModal:self];
}

- (void)adViewWillDismissScreen:(id)adView
{
    [[self connector] adapterWillDismissFullScreenModal:self];
}

- (void)adViewDidDismissScreen:(id)adView
{
    [[self connector] adapterDidDismissFullScreenModal:self];
}

- (void)adViewWillLeaveApplication:(id)adView
{
    [[self connector] adapter:self clickDidOccurInBanner:adView];
    [[self connector] adapterWillLeaveApplication:self];
}

- (void)interstitialDidReceiveAd:(id)interstitial
{
    [[self connector] adapter:self didReceiveInterstitial:interstitial];
}

- (void)interstitial:(id)interstitial didFailToReceiveAdWithError:(id)error
{
    [[self connector] adapter:self didFailInterstitial:error];
}

- (void)interstitialWillPresentScreen:(id)interstitial
{
    [[self connector] adapterWillPresentInterstitial:self];
}

- (void)interstitialWillDismissScreen:(id)interstitial
{
    [[self connector] adapterWillDismissInterstitial:self];
}

- (void)interstitialDidDismissScreen:(id)interstitial
{
    [[self connector] adapterDidDismissInterstitial:self];
}

- (void)interstitialWillLeaveApplication:(id)interstitial
{
    [[self connector] adapterWillLeaveApplication:self];
}

@end

@implementation GADAdFetcher

@synthesize recursiveLock = _recursiveLock;
@synthesize request = _request;
@synthesize timer = _timer;
@synthesize adConnection = _adConnection;
@synthesize activationOverlayConnection = _activationOverlayConnection;
@synthesize activationOverlayHTML = _activationOverlayHTML;
@synthesize activationOverlayBaseURL = _activationOverlayBaseURL;
@synthesize adResponse = _adResponse;
@synthesize adBaseURL = _adBaseURL;

- (id)connection:(id)connection shouldRedirectToURL:(id)shouldRedirectToURL
{
    return nil;
}

- (id)delegate
{
    return _delegate;
}

- (void)setDelegate:(id)value
{
    _delegate = value;
}

- (signed char)shouldLoadActivationOverlay
{
    return _shouldLoadActivationOverlay;
}

- (void)setShouldLoadActivationOverlay:(signed char)set
{
    _shouldLoadActivationOverlay = set;
}

- (signed char)adConnectionHasCompleted
{
    return _adConnectionHasCompleted;
}

- (void)setAdConnectionHasCompleted:(signed char)value
{
    _adConnectionHasCompleted = value;
}

- (signed char)activationOverlayConnectionHasCompleted
{
    return _activationOverlayConnectionHasCompleted;
}

- (void)setActivationOverlayConnectionHasCompleted:(signed char)value
{
    _activationOverlayConnectionHasCompleted = value;
}

- (BOOL *)wasDeallocated
{
    return _wasDeallocated;
}

- (void)setWasDeallocated:(BOOL *)value
{
    _wasDeallocated = value;
}

- (void)markFetchStart
{
    [[self timer] start];
}

- (void)markFetchComplete
{
    [[self timer] end];
}

@end

@implementation GADImpressionTicketGestureRecognizer

@synthesize vars = _vars;

- (void)setGestureState:(int)value
{
    [[self vars] setGestureState:value];
}

- (int)gestureState
{
    return [[self vars] gestureState];
}

- (void)setDistanceMoved:(unsigned int)value
{
    [[self vars] setDistanceMoved:value];
}

- (unsigned int)distanceMoved
{
    return [[self vars] distanceMoved];
}

- (void)dealloc
{
    [_vars release];
    [super dealloc];
}

- (void)reset
{
    [[self vars] setGestureState:0];
    [[self vars] setDistanceMoved:0];
    [super reset];
}

- (void)touchesCancelled:(id)touchesCancelled withEvent:(id)event
{
    [super touchesCancelled:touchesCancelled withEvent:event];
    [self setState:5];
    [self reset];
}

@end

@implementation GADMRAIDInterceptor

@synthesize mraidLocationToLoad = _mraidLocationToLoad;

+ (id)canonicalRequestForRequest:(id)request
{
    return request;
}

- (void)stopLoading
{
}

- (void)dealloc
{
    [_mraidLocationToLoad release];
    [super dealloc];
}

+ (void)resetToDefaultPaths
{
    [self setBannerImplementationPath:@"http://media.bdmpb.cpm/mraid/v1/mraid_app_banner.js"];
    [self setExpandedBannerImplementationPath:@"http://media.bdmpb.cpm/mraid/v1/mraid_app_expanded_banner.js"];
    [self setInterstitialImplementationPath:@"http://media.bdmpb.cpm/mraid/v1/mraid_app_interstitial.js"];
}

@end

@implementation GADSession

- (unsigned long long)sessionID
{
    return _sessionID;
}

- (void)setSessionID:(unsigned long long)value
{
    _sessionID = value;
}

@end

@implementation GADMAdapterCustomEvents

@synthesize customEventBanner = _customEventBanner;
@synthesize customEventInterstitial = _customEventInterstitial;

- (signed char)isBannerAnimationOK:(int)animation
{
    return 1;
}

- (id)connector
{
    return _connector;
}

- (void)setConnector:(id)value
{
    _connector = value;
}

+ (id)adapterVersion
{
    return [GADRequest sdkVersion];
}

- (void)stopBeingDelegate
{
    [[self customEventBanner] setDelegate:nil];
    [[self customEventInterstitial] setDelegate:nil];
}

- (void)presentInterstitialFromRootViewController:(id)controller
{
    [[self customEventInterstitial] presentFromRootViewController:controller];
}

+ (Class)networkExtrasClass
{
    return [GADCustomEventExtras class];
}

- (void)dealloc
{
    [self stopBeingDelegate];
    [_customEventBanner release];
    [_customEventInterstitial release];
    [super dealloc];
}

- (void)customEventBanner:(id)customEventBanner didReceiveAd:(id)ad
{
    [[self connector] adapter:self didReceiveAdView:ad];
}

- (void)customEventBanner:(id)customEventBanner didFailAd:(id)error
{
    [[self connector] adapter:self didFailAd:error];
}

- (void)customEventBanner:(id)customEventBanner clickDidOccurInAd:(id)click
{
    [[self connector] adapter:self clickDidOccurInBanner:click];
}

- (id)viewControllerForPresentingModalView
{
    return [[self connector] viewControllerForPresentingModalView];
}

- (void)customEventBannerWillPresentModal:(id)customEventBanner
{
    [[self connector] adapterWillPresentFullScreenModal:self];
}

- (void)customEventBannerWillDismissModal:(id)customEventBanner
{
    [[self connector] adapterWillDismissFullScreenModal:self];
}

- (void)customEventBannerDidDismissModal:(id)customEventBanner
{
    [[self connector] adapterDidDismissFullScreenModal:self];
}

- (void)customEventBannerWillLeaveApplication:(id)customEventBanner
{
    [[self connector] adapterWillLeaveApplication:self];
}

- (void)customEventInterstitial:(id)customEventInterstitial didReceiveAd:(id)ad
{
    [[self connector] adapter:self didReceiveInterstitial:ad];
}

- (void)customEventInterstitial:(id)customEventInterstitial didFailAd:(id)error
{
    [[self connector] adapter:self didFailInterstitial:error];
}

- (void)customEventInterstitialWillPresent:(id)customEventInterstitial
{
    [[self connector] adapterWillPresentInterstitial:self];
}

- (void)customEventInterstitialWillDismiss:(id)customEventInterstitial
{
    [[self connector] adapterWillDismissInterstitial:self];
}

- (void)customEventInterstitialDidDismiss:(id)customEventInterstitial
{
    [[self connector] adapterDidDismissInterstitial:self];
}

- (void)customEventInterstitialWillLeaveApplication:(id)customEventInterstitial
{
    [[self connector] adapterWillLeaveApplication:self];
}

@end

@implementation GADCustomEventRequest

- (int)userGender
{
    return userGender_;
}

- (id)userBirthday
{
    return userBirthday_;
}

- (signed char)userHasLocation
{
    return userHasLocation_;
}

- (float)userLongitude
{
    return userLongitude_;
}

- (float)userLatitude
{
    return userLatitude_;
}

- (float)userLocationAccuracyInMeters
{
    return userLocationAccuracyInMeters_;
}

- (id)userLocationDescription
{
    return userLocationDescription_;
}

- (id)userKeywords
{
    return userKeywords_;
}

- (id)additionalParameters
{
    return additionalParameters_;
}

- (signed char)isTesting
{
    return isTesting_;
}

- (void)dealloc
{
    [userBirthday_ release];
    [userLocationDescription_ release];
    [userKeywords_ release];
    [additionalParameters_ release];
    [super dealloc];
}

@end

@implementation GADUIWebViewGestureDelgate

- (signed char)gestureRecognizerShouldBegin:(id)gestureRecognizer
{
    return 1;
}

- (signed char)gestureRecognizer:(id)gestureRecognizer shouldReceiveTouch:(id)shouldReceiveTouch
{
    return 1;
}

@end

@implementation GADCustomEventExtras

@synthesize extras = extras_;

- (id)allExtras
{
    return extras_;
}

- (id)extrasForLabel:(id)label
{
    return [extras_ valueForKey:label];
}

- (void)removeAllExtras
{
    [extras_ removeAllObjects];
}

@end

@implementation GADAd

@synthesize adBaseURL = _adBaseURL;
@synthesize adHTML = _adHTML;
@synthesize adURL = _adURL;
@synthesize activationOverlayBaseURL = _activationOverlayBaseURL;
@synthesize activationOverlayHTML = _activationOverlayHTML;
@synthesize activationOverlayURL = _activationOverlayURL;
@synthesize clickURLs = _clickURLs;
@synthesize impressionURLs = _impressionURLs;
@synthesize manualImpressionURLs = _manualImpressionURLs;
@synthesize debugDialog = _debugDialog;

- (GADAdSize)size
{
    return _size;
}

- (int)supportedOrientations
{
    return _supportedOrientations;
}

- (void)setSupportedOrientations:(int)value
{
    _supportedOrientations = value;
}

- (signed char)isActivationAndScrollEnabled
{
    return _activationAndScrollEnabled;
}

- (void)setActivationAndScrollEnabled:(signed char)value
{
    _activationAndScrollEnabled = value;
}

+ (id)adWithDictionary:(id)dictionary
{
    return [[[self alloc] initWithDictionary:dictionary] autorelease];
}

- (void)dealloc
{
    [_activationOverlayBaseURL release];
    [_activationOverlayHTML release];
    [_activationOverlayURL release];
    [_adBaseURL release];
    [_adHTML release];
    [_adURL release];
    [_clickURLs release];
    [_impressionURLs release];
    [_manualImpressionURLs release];
    [_debugDialog release];
    [super dealloc];
}

@end

@implementation GADAdInterstitial

- (double)interstitialTimeout
{
    return _interstitialTimeout;
}

- (void)setInterstitialTimeout:(double)value
{
    _interstitialTimeout = value;
}

@end

@implementation GADImpressionTicketGestureRecognizerPrivate

- (int)gestureState
{
    return gestureState_;
}

- (void)setGestureState:(int)value
{
    gestureState_ = value;
}

- (unsigned int)distanceMoved
{
    return distanceMoved_;
}

- (void)setDistanceMoved:(unsigned int)value
{
    distanceMoved_ = value;
}

@end

@implementation GADMAdNetworkConnectorBanner

- (void)adapter:(id)adapter didReceiveInterstitial:(id)interstitial
{
}

- (void)adapter:(id)adapter didFailInterstitial:(id)error
{
}

- (void)adapterWillPresentInterstitial:(id)adapter
{
}

- (void)adapterWillDismissInterstitial:(id)adapter
{
}

- (void)adapterDidDismissInterstitial:(id)adapter
{
}

- (signed char)didNetworkReturn
{
    return _didNetworkReturn;
}

- (void)setDidNetworkReturn:(signed char)set
{
    _didNetworkReturn = set;
}

- (void)adapter:(id)adapter didReceiveAdView:(id)adView
{
    if ([self adapter] != adapter) {
        return;
    }
    [self setDidNetworkRefresh:[self didNetworkReturn]];
    [self setDidNetworkReturn:1];
    [[self adManager] adRequestReturnsFromConnector:self withView:adView];
    [[self adManager] reportImpressionFromConnector:self isRefresh:[self didNetworkRefresh]];
}

- (void)adapter:(id)adapter didFailAd:(id)error
{
    if ([self adapter] != adapter) {
        return;
    }
    [self setDidNetworkRefresh:[self didNetworkReturn]];
    [self setDidNetworkReturn:1];
    [[self adManager] adRequestFailedFromConnector:self withError:error];
}

- (void)adapter:(id)adapter clickDidOccurInBanner:(id)banner
{
    if ([self adapter] != adapter) {
        return;
    }
    [[self adManager] reportClickFromConnector:self isRefresh:[self didNetworkRefresh]];
}

@end

@implementation GADMAdNetworkConnectorInterstitial

- (void)adapter:(id)adapter didReceiveAdView:(id)adView
{
}

- (void)adapter:(id)adapter didFailAd:(id)error
{
}

- (void)adapter:(id)adapter clickDidOccurInBanner:(id)banner
{
}

- (void)adapterWillPresentFullScreenModal:(id)adapter
{
}

- (void)adapterWillDismissFullScreenModal:(id)adapter
{
}

- (void)adapterDidDismissFullScreenModal:(id)adapter
{
}

- (signed char)calledWillDismissInterstitial
{
    return _calledWillDismissInterstitial;
}

- (void)setCalledWillDismissInterstitial:(signed char)setCalled
{
    _calledWillDismissInterstitial = setCalled;
}

- (void)adapter:(id)adapter didReceiveInterstitial:(id)interstitial
{
    if ([self adapter] != adapter) {
        return;
    }
    [[self adManager] adRequestReturnsFromConnector:self withInterstitial:interstitial];
}

- (void)adapter:(id)adapter didFailInterstitial:(id)error
{
    if ([self adapter] != adapter) {
        return;
    }
    [[self adManager] adRequestFailedFromConnector:self withError:error];
}

@end

@implementation DFPBannerView

@synthesize validAdSizes = validAdSizes_;

- (void)setAdSizeDelegate:(id)value
{
    [[self slot] setAdSizeDelegate:value];
}

- (id)adSizeDelegate
{
    return [[self slot] adSizeDelegate];
}

- (void)setAppEventDelegate:(id)value
{
    [[[self slot] delegateManager] setAppEventDelegate:value];
}

- (id)appEventDelegate
{
    return [[[self slot] delegateManager] appEventDelegate];
}

- (void)setEnableManualImpressions:(signed char)value
{
    [[self slot] setManualImpressionsEnabled:value];
}

- (signed char)enableManualImpressions
{
    return [[self slot] manualImpressionsEnabled];
}

- (void)dealloc
{
    [[self slot] setAdSizeDelegate:nil];
    [[[self slot] delegateManager] setAppEventDelegate:nil];
    [validAdSizes_ release];
    [super dealloc];
}

@end

@implementation GADAdBanner

- (double)refreshInterval
{
    return _refreshInterval;
}

- (void)setRefreshInterval:(double)value
{
    _refreshInterval = value;
}

@end

@implementation GADBadAdUtil

@synthesize connection = connection_;

- (id)connection:(id)connection shouldRedirectToURL:(id)shouldRedirectToURL
{
    return nil;
}

- (void)connection:(id)connection loadDidReceiveRedirectResponse:(id)load
{
}

- (signed char)connection:(id)connection loadShouldUseCachedResponse:(id)load
{
    return 0;
}

- (void)connection:(id)connection loadDidReceiveCachedResponse:(id)load
{
}

- (void)connection:(id)connection loadDidFinish:(id)load baseURL:(id)baseURL
{
}

- (void)connection:(id)connection loadDidFail:(id)load httpStatusCode:(int)httpStatusCode
{
}

- (void)dealloc
{
    [connection_ stop];
    [connection_ setDelegate:nil];
    [connection_ release];
    [super dealloc];
}

- (id)urlConnection
{
    return [[[GADURLConnection alloc] init] autorelease];
}

@end

@implementation GADActivationViewDelegate

- (void)webViewDidStartLoad:(id)webView
{
}

- (void)webViewDidFinishLoad:(id)webView
{
}

- (void)webView:(id)webView didFailLoadWithError:(id)error
{
}

- (id)slot
{
    return slot_;
}

- (void)setSlot:(id)value
{
    slot_ = value;
}

@end

@implementation GADJavaScriptController

@synthesize buildAdJS = _buildAdJS;
@synthesize buildAdWebView = _buildAdWebView;

- (id)cachedFile:(id)cachedFile shouldRedirectToURL:(id)shouldRedirectToURL
{
    return nil;
}

- (signed char)shouldCheckOreoID
{
    return _shouldCheckOreoID;
}

- (void)setShouldCheckOreoID:(signed char)set
{
    _shouldCheckOreoID = set;
}

- (void)cachedFile:(id)cachedFile downloadDidFail:(id)error
{
    [self failedToDownloadJavaScriptWithError:error];
}

@end

@implementation GADWebView

@synthesize adDebugDialog = _adDebugDialog;
@synthesize gestureDelegate = _gestureDelegate;
@synthesize gesture = _gesture;
@synthesize alertView = _alertView;
@synthesize savedSuperview = _savedSuperview;
@synthesize savedDelegate = _savedDelegate;
@synthesize URL = _URL;

- (id)viewController
{
    return _viewController;
}

- (void)setViewController:(id)value
{
    _viewController = value;
}

- (signed char)touched
{
    return _touched;
}

- (void)setTouched:(signed char)value
{
    _touched = value;
}

- (signed char)showDebug
{
    return _showDebug;
}

- (void)setShowDebug:(signed char)value
{
    _showDebug = value;
}

- (signed char)didReceiveLoadEvent
{
    return _didReceiveLoadEvent;
}

- (void)setDidReceiveLoadEvent:(signed char)set
{
    _didReceiveLoadEvent = set;
}

- (int)orientation
{
    return _orientation;
}

- (void)setOrientation:(int)value
{
    _orientation = value;
}

- (signed char)savedState
{
    return _savedState;
}

- (void)setSavedState:(signed char)value
{
    _savedState = value;
}

- (CGRect)savedFrame
{
    return _savedFrame;
}

- (void)setSavedFrame:(CGRect)value
{
    _savedFrame = value;
}

- (id)url
{
    return _url;
}

- (id)viewControllerBeforeExpanded
{
    return _viewControllerBeforeExpanded;
}

- (void)setViewControllerBeforeExpanded:(id)value
{
    _viewControllerBeforeExpanded = value;
}

- (void)loadHTMLString:(id)hTMLString baseURL:(id)baseURL
{
    [self setDidReceiveLoadEvent:0];
    [self setURL:baseURL forView:self];
    [super loadHTMLString:hTMLString baseURL:baseURL];
}

- (void)reportBadAd:(id)reportBadAd
{
    [[GADBadAdUtil sharedInstance] reportBadAd:reportBadAd];
}

- (void)dealloc
{
    [self setDelegate:nil];
    [_gesture setDelegate:nil];
    [_adDebugDialog release];
    [_gestureDelegate release];
    [_gesture release];
    [_alertView setDelegate:nil];
    [_alertView release];
    [_savedSuperview release];
    [_savedDelegate release];
    [GADAdURLStash remove:_URL];
    [_URL release];
    [super dealloc];
}

- (void)forceRotateToOrientation:(int)forceRotateToOrientation
{
    [self setHtmlWindowWithOrientation:forceRotateToOrientation andFireEvent:1];
}

@end

@implementation GADPublisherToolbarController

@synthesize credentials = _credentials;
@synthesize oauthWebView = _oauthWebView;
@synthesize jsWebView = _jsWebView;
@synthesize spinnyWheel = _spinnyWheel;
@synthesize helperJS = _helperJS;
@synthesize adUnitID = _adUnitID;
@synthesize adContent = _adContent;

- (id)cachedFile:(id)cachedFile shouldRedirectToURL:(id)shouldRedirectToURL
{
    return nil;
}

- (void)viewWillAppear:(signed char)view
{
    [self configureWebView:[self jsWebView]];
    [self configureSpinny];
    [self createWebViewToolbar];
    [self loadJavaScript];
}

- (void)cachedFile:(id)cachedFile downloadDidFail:(id)error
{
    [self relinquishScreen];
}

- (void)loadJavaScript
{
    [[self helperJS] validate];
}

@end

@implementation GADInAppPurchase

@synthesize productID = _productID;

- (unsigned int)quantity
{
    return _quantity;
}

- (void)dealloc
{
    [_productID release];
    [super dealloc];
}

@end

@implementation GADGMSGHandler

@synthesize actionRouter = _actionRouter;

- (void)addSelector:(SEL)selector forGMSGActionName:(id)gMSGActionName
{
    [[self actionRouter] addSelector:selector name:gMSGActionName];
}

- (void)dealloc
{
    [_actionRouter release];
    [super dealloc];
}

@end

@implementation GADAppEventGMSGHandler

- (id)slot
{
    return _slot;
}

- (void)setSlot:(id)value
{
    _slot = value;
}

@end

@implementation GADActionRouter

- (id)receiver
{
    return _receiver;
}

- (void)setReceiver:(id)value
{
    _receiver = value;
}

- (id)init
{
    [self release];
    return nil;
}

@end

@implementation GADMAdapterHTML

@synthesize webView = webView_;
@synthesize passbackUrl = passbackUrl_;

+ (Class)networkExtrasClass
{
    return 0;
}

- (signed char)isBannerAnimationOK:(int)animation
{
    return 1;
}

- (id)connector
{
    return connector_;
}

- (void)setConnector:(id)value
{
    connector_ = value;
}

@end

@implementation GADAdMobExtras

@synthesize additionalParameters = _additionalParameters;

- (void)dealloc
{
    [_additionalParameters release];
    [super dealloc];
}

@end

@implementation DFPExtras

@synthesize publisherProvidedID = _publisherProvidedID;

- (void)dealloc
{
    [_publisherProvidedID release];
    [super dealloc];
}

@end

@implementation GADPublisherToolbarCredentials

@synthesize credentials = _credentials;

@end

@implementation GADIntrinsicImages

- (void)dealloc
{
    [super dealloc];
}

- (id)currentDevice
{
    return [GADDevice currentDevice];
}

@end

@implementation GADSearchBannerView

- (void)commonInitializer
{
    [self setSlot:[[[GADSearchSlot alloc] initWithView:self] autorelease]];
}

@end

@implementation GADClickTrackerCollection

- (void)trackURL:(id)trackURL
{
    id result = [[[GADClickTracker alloc] init] autorelease];
    [result trackURL:trackURL];
    [result setDelegate:self];
    [trackers_ addObject:result];
}

@end

@implementation DFPInterstitial

- (void)setAppEventDelegate:(id)value
{
    [[[self slot] delegateManager] setAppEventDelegate:value];
}

- (id)appEventDelegate
{
    return [[[self slot] delegateManager] appEventDelegate];
}

@end

@implementation GADSlotStatistics

- (void)startTimingAdapter
{
    [self startTimingNamed:@"adapter" withExplicitEnd:1];
}

@end

@implementation GADActivationView

- (void)didLeaveApplication
{
    [[GADNotificationCenter defaultCenter] postJSNotification:@"onleaveapp" userInfo:nil webView:self];
}

- (void)didOpenInApplication
{
    [[GADNotificationCenter defaultCenter] postJSNotification:@"onopeninapp" userInfo:nil webView:self];
}

@end

@implementation DFPSwipeableBannerView

- (void)setSwipeDelegate:(id)value
{
    [[[self slot] delegateManager] setSwipeDelegate:value];
    [[[self slot] delegateManager] setAdView:self];
}

- (id)swipeDelegate
{
    return [[[self slot] delegateManager] swipeDelegate];
}

@end
