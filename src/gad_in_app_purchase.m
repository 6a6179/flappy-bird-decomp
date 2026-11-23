#import <Foundation/Foundation.h>

@interface GADInAppPurchase : NSObject {
    NSString *_productID;
    NSUInteger _quantity;
}
@end

@implementation GADInAppPurchase
+ (BOOL)quantityIsValid:(NSUInteger)quantity
{
    return quantity > 0 && quantity <= 10;
}

+ (NSString *)stringForStatus:(int)status
{
    switch (status) {
    case 1: return @"success";
    case 2: return @"cancel";
    case 3: return @"invalid product";
    default: return @"error";
    }
}

- (id)init
{
    self = [super init];
    if (self)
        _quantity = 1;
    return self;
}

- (void)setQuantity:(NSUInteger)quantity
{
    _quantity = [[self class] quantityIsValid:quantity] ? quantity : 0;
}
@end
