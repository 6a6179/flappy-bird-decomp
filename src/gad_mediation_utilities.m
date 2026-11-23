#import <Foundation/Foundation.h>

@interface GADRequest : NSObject
+ (NSString *)sdkVersion;
@end
@interface GADMUtilities : NSObject
@end

@implementation GADMUtilities

+ (void)replace:(NSString *)placeholder with:(NSString *)value inString:(NSMutableString *)string
{
    if (value)
        [string replaceOccurrencesOfString:placeholder withString:value options:NSLiteralSearch
                                     range:NSMakeRange(0, [string length])];
}

+ (NSURL *)mediationUrlFrom:(NSString *)url adLocationId:(NSString *)location
           adNetworkRefresh:(BOOL)refresh allocationId:(NSString *)allocation adNetworkId:(NSString *)network
                      qData:(NSString *)data sessionId:(NSString *)session sequenceNum:(NSString *)sequence
                  exitCodes:(NSString *)codes durations:(NSString *)durations
{
    NSMutableString *expanded = [url mutableCopy];
    [GADMUtilities replace:@"@gw_adlocid@" with:location inString:expanded];
    [GADMUtilities replace:@"@gw_qdata@" with:data inString:expanded];
    [GADMUtilities replace:@"@gw_sdkver@" with:[GADRequest sdkVersion] inString:expanded];
    [GADMUtilities replace:@"@gw_sessid@" with:session inString:expanded];
    [GADMUtilities replace:@"@gw_seqnum@" with:sequence inString:expanded];
    [GADMUtilities replace:@"@gw_devid@" with:@"" inString:expanded];
    [GADMUtilities replace:@"@gw_adnetrefresh@" with:refresh ? @"1" : @"0" inString:expanded];
    [GADMUtilities replace:@"@gw_adnetid@" with:network inString:expanded];
    [GADMUtilities replace:@"@gw_allocid@" with:allocation inString:expanded];
    [GADMUtilities replace:@"@gw_aec@" with:codes inString:expanded];
    [GADMUtilities replace:@"@gw_adt@" with:durations inString:expanded];
    return [NSURL URLWithString:[expanded autorelease]];
}

@end
