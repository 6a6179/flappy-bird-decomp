#import "gad_banner.h"

@interface GADURL : NSURL
@end

extern NSArray *GADStringArrayToURLArray(NSArray *strings);
extern CGSize GADCGSizeFromString(NSString *string);
extern int GADAdSupportedOrientationsFromString(NSString *string);

@interface GADAd ()
- (NSString *)adHTML;
- (NSString *)activationOverlayHTML;
- (BOOL)isActivationAndScrollEnabled;
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

- (id)init
{
    self = [super init];
    if (self)
        _activationAndScrollEnabled = YES;
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [self init];
    if (self) {
        NSString *overlayHTML = [dictionary objectForKey:@"activation_overlay_html"];
        NSURL *overlayBase = [GADURL URLWithString:[dictionary objectForKey:@"activation_overlay_base_url"]];
        if ([overlayHTML length] && overlayBase) {
            _activationOverlayHTML = [overlayHTML copy];
            _activationOverlayBaseURL = [overlayBase retain];
        } else {
            _activationOverlayURL = [[GADURL URLWithString:[dictionary objectForKey:@"activation_overlay_url"]] retain];
        }

        NSString *adHTML = [dictionary objectForKey:@"ad_html"];
        NSURL *adBase = [GADURL URLWithString:[dictionary objectForKey:@"ad_base_url"]];
        if ([adHTML length] && adBase) {
            _adHTML = [adHTML copy];
            _adBaseURL = [adBase retain];
        } else {
            _adURL = [[GADURL URLWithString:[dictionary objectForKey:@"ad_url"]] retain];
        }

        _impressionURLs = [GADStringArrayToURLArray([dictionary objectForKey:@"impression_urls"]) retain];
        _manualImpressionURLs = [GADStringArrayToURLArray([dictionary objectForKey:@"manual_impression_urls"]) retain];
        _clickURLs = [GADStringArrayToURLArray([dictionary objectForKey:@"click_urls"]) retain];
        NSNumber *disabled = [dictionary objectForKey:@"disable_activation_and_scroll"];
        if ([disabled isKindOfClass:[NSNumber class]])
            _activationAndScrollEnabled = ![disabled boolValue];
        CGSize size = GADCGSizeFromString([dictionary objectForKey:@"ad_size"]);
        _size = GADAdSizeFromCGSize(size);
        int orientation = GADAdSupportedOrientationsFromString([dictionary objectForKey:@"orientation"]);
        _supportedOrientations = orientation == 2 || orientation == 3 ? orientation : 1;
        _debugDialog = [[dictionary objectForKey:@"debug_dialog"] copy];
    }
    return self;
}

- (BOOL)shouldLoadAdHTML
{
    return ![[self adHTML] length];
}

- (BOOL)shouldLoadActivationOverlayHTML
{
    return [self isActivationAndScrollEnabled] && ![[self activationOverlayHTML] length];
}

- (void)setSize:(GADAdSize)size
{
    _size = size;
}
@end

@implementation GADAdInterstitial {
    NSTimeInterval _interstitialTimeout;
}
- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super initWithDictionary:dictionary];
    if (self) {
        NSNumber *timeout = [dictionary objectForKey:@"interstitial_timeout"];
        if ([timeout isKindOfClass:[NSNumber class]])
            _interstitialTimeout = [timeout doubleValue];
    }
    return self;
}
@end
