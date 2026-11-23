#import <UIKit/UIKit.h>

typedef struct { CGSize size; NSUInteger flags; } GADAdSize;
extern BOOL IsGADAdSizeValid(GADAdSize size);
extern BOOL GADAdSizeIsStandardFixed(GADAdSize size);
extern BOOL GADAdSizeEqualToSize(GADAdSize first, GADAdSize second);
extern NSString *NSStringFromGADAdSize(GADAdSize size);

@interface GADAdType : NSObject
- (BOOL)isInterstitial;
- (GADAdSize)adSize;
@end

@interface GADMConfig : NSObject
- (GADAdType *)adType;
@end

@interface GADMAdManager : NSObject
- (void)setDelegate:(id)delegate;
- (void)mediateForAdType:(GADAdType *)type config:(GADMConfig *)config;
- (BOOL)changeAdTypeTo:(GADAdType *)type;
- (void)presentInterstitialFromRootViewController:(UIViewController *)controller;
@end

@interface GADRequestError : NSError
+ (id)errorWithCode:(NSInteger)code customMessage:(NSString *)message;
@end

@interface GADMacros : NSObject
+ (void)pubLog:(NSString *)message;
@end

@interface GADSlot : NSObject
- (GADAdType *)adType;
- (void)didFailToReceiveAdWithError:(NSError *)error;
- (id)delegateManager;
@end

@interface GADDelegateManager : NSObject
- (void)willPresentScreen;
- (void)didDismissScreen;
@end

@interface GADMToGADGlue : NSObject {
    GADSlot *_slot;
    id _mediatedInterstitial;
    GADMAdManager *_mediationManager;
    GADMConfig *_mediationConfig;
}
@property (nonatomic, readonly) GADSlot *slot;
@property (nonatomic, retain) GADMAdManager *mediationManager;
@property (nonatomic, retain) GADMConfig *mediationConfig;
- (BOOL)hasConsistentMediationConfigForAdType:(GADAdType *)type;
@end

@implementation GADMToGADGlue
@dynamic slot, mediationManager, mediationConfig;

- (id)init
{
    if ((self = [super init])) {
        _mediationManager = [[GADMAdManager alloc] init];
        [_mediationManager setDelegate:self];
    }
    return self;
}

- (void)requestAdWithType:(GADAdType *)type mediationConfig:(GADMConfig *)config
{
    self.mediationConfig = config;
    if ([self hasConsistentMediationConfigForAdType:type])
        [self.mediationManager mediateForAdType:type config:config];
}

- (BOOL)changeAdTypeTo:(GADAdType *)type
{
    if ([[self.slot adType] isInterstitial] || [type isInterstitial])
        return NO;
    return [self.mediationManager changeAdTypeTo:type];
}

- (void)presentInterstitialFromRootViewController:(UIViewController *)controller
{
    if ([[self.slot adType] isInterstitial])
        [self.mediationManager presentInterstitialFromRootViewController:controller];
}

- (BOOL)hasConsistentMediationConfigForAdType:(GADAdType *)type
{
    GADAdType *configured = [self.mediationConfig adType];
    if (!type) {
        NSString *message = [NSString stringWithFormat:@"Invalid requested GADAdType: %@.", type];
        NSError *error = [GADRequestError errorWithCode:0 customMessage:message];
        [self.slot didFailToReceiveAdWithError:error];
    }
    if (!configured) {
        NSString *message = [NSString stringWithFormat:@"Invalid mediation configuration GADAdType: %@.", configured];
        NSError *error = [GADRequestError errorWithCode:7 customMessage:message];
        [self.slot didFailToReceiveAdWithError:error];
    }

    if ([type isInterstitial] && ![configured isInterstitial]) {
        NSString *message = [NSString stringWithFormat:@"Unable to request an interstitial when mediation configuration was for %@.", NSStringFromGADAdSize([configured adSize])];
        NSError *error = [GADRequestError errorWithCode:10 customMessage:message];
        [self.slot didFailToReceiveAdWithError:error];
        return NO;
    } else if (![type isInterstitial] && [configured isInterstitial]) {
        NSString *message = [NSString stringWithFormat:@"Unable to request %@ when mediation configuration was for an interstitial.", NSStringFromGADAdSize([type adSize])];
        NSError *error = [GADRequestError errorWithCode:10 customMessage:message];
        [self.slot didFailToReceiveAdWithError:error];
        return NO;
    } else if (![type isInterstitial]) {
        if (!IsGADAdSizeValid([type adSize])) {
            NSString *message = [NSString stringWithFormat:@"Unable to request ad with invalid size: %@.", NSStringFromGADAdSize([type adSize])];
            NSError *error = [GADRequestError errorWithCode:10 customMessage:message];
            [self.slot didFailToReceiveAdWithError:error];
            return NO;
        } else if (GADAdSizeIsStandardFixed([configured adSize]) && GADAdSizeIsStandardFixed([type adSize]) &&
                   !GADAdSizeEqualToSize([type adSize], [configured adSize])) {
            [GADMacros pubLog:[NSString stringWithFormat:@"Warning (banner size mismatch): Attempting to request %@ but mediation configuration was for %@.",
                               NSStringFromGADAdSize([type adSize]), NSStringFromGADAdSize([configured adSize])]];
        }
    }
    return YES;
}

- (void)gadmWillPresentFullScreenModal
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kAdModalViewControllerWillPresentFullScreen" object:nil];
    [[self.slot delegateManager] willPresentScreen];
}

- (void)gadmDidDismissFullScreenModal
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kAdModalViewControllerDidDismissFullScreen" object:nil];
    [[self.slot delegateManager] didDismissScreen];
}

- (void)gadmWillPresentInterstitial
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kAdModalViewControllerWillPresentFullScreen" object:nil];
    [[self.slot delegateManager] willPresentScreen];
}

- (void)gadmDidDismissInterstitial
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kAdModalViewControllerDidDismissFullScreen" object:nil];
    [[self.slot delegateManager] didDismissScreen];
}
@end
