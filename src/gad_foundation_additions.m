#import <Foundation/Foundation.h>
#import <CoreGraphics/CGBase.h>
#import <CommonCrypto/CommonDigest.h>
#include <string.h>

@implementation NSError (GADInternalErrorAdditions)

+ (NSError *)gad_errorWithCode:(NSInteger)code description:(NSString *)description
{
    NSDictionary *info = nil;
    if (description)
        info = @{NSLocalizedDescriptionKey:description, NSLocalizedFailureReasonErrorKey:description};
    return [self errorWithDomain:@"com.google.ads.private" code:code userInfo:info];
}

+ (NSString *)gad_localizedDescriptionForErrorCode:(NSInteger)code
{
    return code == 1 ? @"File could not be read." : nil;
}

@end

@implementation NSDecimalNumber (GADValueAdditions)

+ (NSDecimalNumber *)gad_negativeOne
{
    return [NSDecimalNumber decimalNumberWithMantissa:1 exponent:0 isNegative:YES];
}

@end

@implementation NSString (GADStringNumberAdditions)

+ (NSString *)gad_shortStringWithCGFloat:(CGFloat)value
{
    NSString *string = [NSString stringWithFormat:@"%f", value];
    if (![string length])
        return nil;
    NSInteger index = [string length] - 1;
    while (index >= 0) {
        unichar character = [string characterAtIndex:index];
        if (character != '0') {
            if (character == '.')
                --index;
            break;
        }
        --index;
    }
    return [string substringToIndex:index + 1];
}

- (NSString *)gad_MD5String
{
    const char *text = [self UTF8String];
    if (!text)
        return nil;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(text, (CC_LONG)strlen(text), digest);
    return [NSString gad_stringWithMD5Bytes:digest];
}

+ (NSString *)gad_stringWithMD5Bytes:(unsigned char *)digest
{
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
        digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]];
}

@end

@interface GAD_SBJSON : NSObject
- (void)setHumanReadable:(BOOL)pretty;
- (void)setSortKeys:(BOOL)sort;
- (NSString *)stringWithObject:(id)object error:(NSError **)error;
@end

@implementation NSDictionary (GADJSONAdditions)

- (NSString *)gad_JSONStringPretty:(BOOL)pretty sortKeys:(BOOL)sort error:(NSError **)error
{
    GAD_SBJSON *json = [[[GAD_SBJSON alloc] init] autorelease];
    [json setHumanReadable:pretty];
    [json setSortKeys:sort];
    return [json stringWithObject:self error:error];
}

@end
