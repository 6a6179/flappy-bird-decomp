#import <Foundation/Foundation.h>

// Externally shared strings from the Google Mobile Ads 6.8.0 SDK.

// GADAdMobExtras
NSString *const kGADAdMobExtrasKeyActivationOverlayURL = @"_activationOverlayUrl";
NSString *const kGADAdMobExtrasKeyAd = @"_ad";
NSString *const kGADAdMobExtrasKeyRequestURL = @"_requestUrl";
NSString *const kGADAdMobExtrasKeyOrientation = @"_orientation";

// GADGMSGHandler
NSString *const kGADGMSGHandlerParamWebView = @"webView";
NSString *const kGADGMSGHandlerParamNotification = @"note";

// GADGMSGURLConstants
NSString *const kGADGMSGURLActionAppEvent = @"appEvent";
NSString *const kGADGMSGURLActionCanOpenURLs = @"canOpenURLs";
NSString *const kGADGMSGURLActionClick = @"click";
NSString *const kGADGMSGURLActionClose = @"close";
NSString *const kGADGMSGURLActionCustomClose = @"customClose";
NSString *const kGADGMSGURLActionHTTPTrack = @"httpTrack";
NSString *const kGADGMSGURLActionLog = @"log";
NSString *const kGADGMSGURLActionOpen = @"open";
NSString *const kGADGMSGURLActionTouch = @"touch";
NSString *const kGADGMSGURLActionVibrate = @"vibrate";
NSString *const kGADGMSGURLParamURL = @"u";
NSString *const kGADGMSGURLParamMessage = @"string";
NSString *const kGADGMSGURLParamTouchDuration = @"td";
NSString *const kGADGMSGURLParamTouchX = @"tx";
NSString *const kGADGMSGURLParamTouchY = @"ty";
NSString *const kGADGMSGURLParamURLs = @"urls";
NSString *const kGADGMSGURLParamURLsSeperator = @",";
NSString *const kGADGMSGURLParamCustomClose = @"custom_close";
NSString *const kGADGMSGURLParamCustomCloseValueTrue = @"1";

// GADPublisherToolbarConstants
NSString *const kGADHelperJavaScriptURL = @"https://media.admob.com/toolbar/sdk-publisher-toolbar.js";
NSString *const kGADClearCredentialsNotificationName = @"clearCredentials";
NSString *const kGADLoadAuthenticationURINotficationName = @"loadAuthenticationUri";
NSString *const kGADLogNotificationName = @"log";
NSString *const kGADShowJSWebViewNotificationName = @"showJavaScriptWebView";
NSString *const kGADStoreCredentialsNotificationName = @"storeCredentials";
NSString *const kGADInitializeToolbarFunction = @"AFMA_initializeToolbar";
NSString *const kGADDecodeImpressionFunction = @"AFMA_decodeImpression";
NSString *const kGADPublisherToolbarCustomURL = @"publisherToolbar://junk.com";
NSString *const kGADToolbarCredentialsFileName = @"GoogleAdsSDKToolbarCredentials";

// GADRequestError
NSString *const kGADErrorDomain = @"com.google.ads";

// GADRequestParameters
NSString *const kGADParameterSDKVersion = @"js";
NSString *const kGADParameteriPadCompatibilityMode = @"ios_ipadc";
NSString *const kGADParameteriTunesMetadata = @"ios_metadata";
NSString *const kGADParameterBaseSdkVersion = @"ios_base_sdk";
NSString *const kGADParameterApplicationName = @"app_name";
NSString *const kGADParameterCalledLoadAndDisplayRequest = @"cladr";
NSString *const kGADParameterDebugPublisherToolbar = @"dpt";
NSString *const kGADParameterMediationAdapters = @"adapters";
NSString *const kGADParameterJailbroken = @"ios_jb";
NSString *const kGADParameterNetworkType = @"net";
NSString *const kGADParameterDeviceModel = @"platform";
NSString *const kGADParameterDeviceSubmodel = @"submodel";
NSString *const kGADParameterLocale = @"hl";
NSString *const kGADParameterAudioOutput = @"u_audio";
NSString *const kGADParameterScreenOrientation = @"u_so";
NSString *const kGADParameterScreenDensity = @"u_sd";
NSString *const kGADParameterSmartWidth = @"smart_w";
NSString *const kGADParameterSmartHeight = @"smart_h";
NSString *const kGADParameterScreenWidth = @"u_w";
NSString *const kGADParameterScreenHeight = @"u_h";
NSString *const kGADParameterCapabilitiesBookstore = @"cap_bs";
NSString *const kGADParameteriOSRadio = @"ios_radio";
NSString *const kGADParameterAdSlotID = @"slotname";
NSString *const kGADParameterAdFormat = @"format";
NSString *const kGADParameterXFPValidAdSizes = @"sz";
NSString *const kGADParameterAdFrame = @"ad_frame";
NSString *const kGADParameterAdBounds = @"ad_bounds";
NSString *const kGADParameterAdPositionData = @"ad_pos";
NSString *const kGADParameterAnalyticsJoinId = @"analytics_join_id";
NSString *const kGADParameterRequestId = @"request_id";
NSString *const kGADParameterSwipeable = @"swipeable";
NSString *const kGADParameterTestMode = @"adtest";
NSString *const kGADParameterTesting = @"testing";
NSString *const kGADParameterExtraParams = @"extras";
NSString *const kGADParameterGender = @"cust_gender";
NSString *const kGADParameterBirthday = @"cust_age";
NSString *const kGADParameterLocation = @"uule";
NSString *const kGADParameterKeywords = @"kw";
NSString *const kGADParameterMediationExtrasParams = @"mediation_extras";
NSString *const kGADParameterEnableManualImpressions = @"d_imp_hdr";
NSString *const kGADParameterTagForChildDirectedTreatment = @"tag_for_child_directed_treatment";
NSString *const kGADParameterPriorRequestLatency = @"prl";
NSString *const kGADParameterPriorClickLatency = @"pcl";
NSString *const kGADParameterPriorPreClickLatency = @"ppcl";
NSString *const kGADParameterPriorLandingPageLoad = @"plpl";
NSString *const kGADParameterPriorLandingPageDuration = @"plpd";
NSString *const kGADParameterPriorClickBreakOut = @"pcbo";
NSString *const kGADParameterTotalAdRequests = @"preqs";
NSString *const kGADParameterTimeSinceFirstRequest = @"ptime";
NSString *const kGADParameterAppOpenInterstitialTimedOut = @"aoi_timedout";
NSString *const kGADParameterAppOpenInterstitialNoFill = @"aoi_nofill";
NSString *const kGADParameterPriorClickBackgroundedApp = @"pclb";
NSString *const kGADParameterPriorLandingPageNavCount = @"plpnc";
NSString *const kGADParameterPriorLandingPageSSLNavCount = @"plpsnc";
NSString *const kGADParameterPriorImpressionTicketString = @"pit";
NSString *const kGADParameterPriorClickCount = @"pcc";
NSString *const kGADParameterOfflineAdRequestsCount = @"oar";
NSString *const kGADParameterBufferedAdsShownOnlineCount = @"bas_on";
NSString *const kGADParameterBufferedAdsShownOfflineCount = @"bas_off";
NSString *const kGADParameterPriorRequestNetworkLatency = @"prnl";
NSString *const kGADParameterSessionID = @"session_id";
NSString *const kGADParameterSequenceNumber = @"seq_num";
NSString *const kGADSearchParameterQuery = @"q";
NSString *const kGADSearchParameterBackgroundColor = @"bgcolor";
NSString *const kGADSearchParameterBackgroundGradientFrom = @"gradientfrom";
NSString *const kGADSearchParameterBackgroundGradientTo = @"gradientto";
NSString *const kGADSearchParameterHeaderColor = @"hcolor";
NSString *const kGADSearchParameterDescriptionTextColor = @"dcolor";
NSString *const kGADSearchParameterAnchorTextColor = @"acolor";
NSString *const kGADSearchParameterFontFamily = @"font";
NSString *const kGADSearchParameterFontSize = @"headersize";
NSString *const kGADSearchParameterBorderColor = @"bcolor";
NSString *const kGADSearchParameterBorderType = @"btype";
NSString *const kGADSearchParameterBorderThickness = @"bthick";
NSString *const kGADSearchParameterChannel = @"channel";
NSString *const kGADSearchParameterCallButtonColor = @"callbuttoncolor";
NSString *const kGADDFPParameterPublisherProvidedID = @"ppid";

// GADWebViewDelegate
NSString *const kGADWebViewDelegateDidReceiveWebAction = @"didReceiveWebAction";
NSString *const kGADWebViewDelegateWebViewDidFinishLoad = @"webViewDidFinishLoad";
NSString *const kGADWebViewDelegateWebViewDidFailLoad = @"webViewDidFailLoad";
