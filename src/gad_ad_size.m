#import "gad_banner.h"

enum {
    GADSizeCustom = 1,
    GADSizeFullWidth = 2,
    GADSizeSkinny = 4,
    GADSizeLandscape = 8,
    GADSizeAutoHeight = 16,
    GADSizeSmart = GADSizeFullWidth | GADSizeAutoHeight
};

const GADAdSize kGADAdSizeInvalid = {{-1, -1}, 0};
const GADAdSize kGADAdSizeBanner = {{320, 50}, 0};
const GADAdSize kGADAdSizeMediumRectangle = {{300, 250}, 0};
const GADAdSize kGADAdSizeFullBanner = {{468, 60}, 0};
const GADAdSize kGADAdSizeLeaderboard = {{728, 90}, 0};
const GADAdSize kGADAdSizeSkyscraper = {{120, 600}, 0};

const GADAdSize kGADAdSizeSmartBannerPortrait = {{0, 0}, GADSizeSmart};
const GADAdSize kGADAdSizeSmartBannerLandscape = {{0, 0}, GADSizeSmart | GADSizeLandscape};
const GADAdSize kGADAdSizeSmartBannerSkinnyPortrait = {{0, 0}, GADSizeSmart | GADSizeSkinny};
const GADAdSize kGADAdSizeSmartBannerSkinnyLandscape = {{0, 0}, GADSizeSmart | GADSizeSkinny | GADSizeLandscape};

GADAdSize GADAdSizeFromCGSize(CGSize size)
{
    static const GADAdSize *const nonSmartStandardSizes[] = {
        &kGADAdSizeInvalid, &kGADAdSizeBanner, &kGADAdSizeMediumRectangle,
        &kGADAdSizeFullBanner, &kGADAdSizeLeaderboard, &kGADAdSizeSkyscraper
    };
    for (unsigned i = 0; i < sizeof(nonSmartStandardSizes) / sizeof(nonSmartStandardSizes[0]); ++i) {
        const GADAdSize *standard = nonSmartStandardSizes[i];
        if (CGSizeEqualToSize(size, standard->size))
            return *standard;
    }
    return (GADAdSize){{size.width, size.height}, GADSizeCustom};
}

BOOL GADAdSizeEqualToSize(GADAdSize first, GADAdSize second)
{
    return CGSizeEqualToSize(first.size, second.size) && first.flags == second.flags;
}

static inline __attribute__((always_inline)) BOOL isStandardFixedSize(GADAdSize size)
{
    return GADAdSizeEqualToSize(size, kGADAdSizeBanner) ||
           GADAdSizeEqualToSize(size, kGADAdSizeMediumRectangle) ||
           GADAdSizeEqualToSize(size, kGADAdSizeFullBanner) ||
           GADAdSizeEqualToSize(size, kGADAdSizeLeaderboard) ||
           GADAdSizeEqualToSize(size, kGADAdSizeSkyscraper);
}

BOOL GADAdSizeIsStandardFixed(GADAdSize size)
{
    return isStandardFixedSize(size);
}

BOOL GADAdSizeIsStandard(GADAdSize size)
{
    return GADAdSizeIsStandardFixed(size) ||
           GADAdSizeEqualToSize(size, kGADAdSizeSmartBannerSkinnyPortrait) ||
           GADAdSizeEqualToSize(size, kGADAdSizeSmartBannerSkinnyLandscape) ||
           GADAdSizeEqualToSize(size, kGADAdSizeSmartBannerPortrait) ||
           GADAdSizeEqualToSize(size, kGADAdSizeSmartBannerLandscape);
}

BOOL IsGADAdSizeValid(GADAdSize size)
{
    return (size.flags & GADSizeCustom) || GADAdSizeIsStandard(size);
}

BOOL GADAdSizeIsFullWidth(GADAdSize size)
{
    return size.flags & GADSizeFullWidth;
}

BOOL GADAdSizeIsAutoHeight(GADAdSize size)
{
    return size.flags & GADSizeAutoHeight;
}

CGSize CGSizeFromGADAdSizeSmartBanner(GADAdSize size, UIUserInterfaceIdiom idiom, CGSize screen)
{
    if (GADAdSizeIsFullWidth(size)) {
        BOOL landscape = size.flags & GADSizeLandscape;
        CGFloat width = landscape ? screen.height : screen.width;
        if (idiom == UIUserInterfaceIdiomPad) {
            if (size.flags & GADSizeSkinny)
                return CGSizeMake(width, 66);
            return CGSizeMake(width, 90);
        }
        if (idiom == UIUserInterfaceIdiomPhone) {
            if (landscape)
                return CGSizeMake(width, 32);
            return CGSizeMake(width, 50);
        }
    }
    return CGSizeZero;
}

CGSize CGSizeFromGADAdSize(GADAdSize size)
{
    if (isStandardFixedSize(size))
        return size.size;
    if (GADAdSizeIsFullWidth(size)) {
        UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
        CGSize smart = CGSizeFromGADAdSizeSmartBanner(size, idiom, [[UIScreen mainScreen] bounds].size);
        if (GADAdSizeIsAutoHeight(size))
            return smart;
        if (size.flags & GADSizeCustom) {
            smart.height = size.size.height;
            return smart;
        }
    } else if (size.flags & GADSizeCustom) {
        return size.size;
    }
    return CGSizeZero;
}

CGSize GADCGSizeFromString(NSString *string)
{
    NSString *dimensions = [string stringByReplacingOccurrencesOfString:@"x" withString:@","];
    return CGSizeFromString([NSString stringWithFormat:@"{%@}", dimensions]);
}

static struct {
    NSArray *entries;
    dispatch_once_t once;
} gadSizeNames;

NSString *NSStringFromGADAdSize(GADAdSize size)
{
    dispatch_once(&gadSizeNames.once, ^{
#define SIZE_NAME(symbol) @[[NSValue valueWithPointer:&symbol], @#symbol]
        gadSizeNames.entries = @[
            SIZE_NAME(kGADAdSizeBanner), SIZE_NAME(kGADAdSizeMediumRectangle),
            SIZE_NAME(kGADAdSizeFullBanner), SIZE_NAME(kGADAdSizeLeaderboard),
            SIZE_NAME(kGADAdSizeSkyscraper), SIZE_NAME(kGADAdSizeSmartBannerSkinnyPortrait),
            SIZE_NAME(kGADAdSizeSmartBannerSkinnyLandscape), SIZE_NAME(kGADAdSizeSmartBannerPortrait),
            SIZE_NAME(kGADAdSizeSmartBannerLandscape), SIZE_NAME(kGADAdSizeInvalid)
        ];
#undef SIZE_NAME
        [gadSizeNames.entries retain];
    });

    for (NSArray *entry in gadSizeNames.entries) {
        const GADAdSize *standard = NULL;
        [[entry objectAtIndex:0] getValue:&standard];
        if (standard && GADAdSizeEqualToSize(size, *standard))
            return [entry objectAtIndex:1];
    }
    if (GADAdSizeIsFullWidth(size))
        return [NSString stringWithFormat:@"Full width GADAdSize with height: %f", size.size.height];
    if (size.flags & GADSizeCustom)
        return [NSString stringWithFormat:@"Custom GADAdSize: %@", NSStringFromCGSize(size.size)];
    return [NSString stringWithFormat:@"GADAdSize: %@, %lx", NSStringFromCGSize(size.size),
                     (unsigned long)size.flags];
}
