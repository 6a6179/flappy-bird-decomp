#import <Foundation/Foundation.h>

@interface GAD_SBJSON : NSObject
- (id)objectWithString:(NSString *)string error:(NSError **)error;
- (NSString *)stringWithObject:(id)object error:(NSError **)error;
@end
@interface NSDictionary (GADJSON)
- (NSString *)gad_JSONStringPretty:(BOOL)pretty sortKeys:(BOOL)sort error:(NSError **)error;
@end
@protocol GADLogChecker
- (void)message:(NSString *)message;
@end

NSArray *GADStringArrayToURLArray(NSArray *strings)
{
    NSMutableArray *urls = nil;
    for (NSString *string in strings) {
        NSURL *url = [NSURL URLWithString:string];
        if (url) {
            if (!urls)
                urls = [[[NSMutableArray alloc] init] autorelease];
            [urls addObject:url];
        }
    }
    return urls;
}

@interface GADMacros : NSObject
@end

static id<GADLogChecker> logChecker_;

@implementation GADMacros

+ (NSString *)dictionaryToJSONString:(NSDictionary *)dictionary
{
    NSError *error = nil;
    NSString *json = [dictionary gad_JSONStringPretty:NO sortKeys:NO error:&error];
    return !json && error ? @"" : json;
}

+ (NSString *)jsonifyArray:(NSArray *)array
{
    if (!array)
        return nil;
    NSError *error = nil;
    GAD_SBJSON *parser = [[GAD_SBJSON alloc] init];
    NSString *result = [parser stringWithObject:array error:&error];
    if (error)
        result = @"";
    [parser release];
    return result;
}

+ (NSDictionary *)readJsonIntoDictionary:(NSString *)json
{
    if (!json)
        return nil;
    NSError *error = nil;
    GAD_SBJSON *parser = [[GAD_SBJSON alloc] init];
    id value = [parser objectWithString:json error:&error];
    NSDictionary *dictionary = nil;
    if (!error && [value isKindOfClass:[NSDictionary class]])
        dictionary = value;
    [parser release];
    return dictionary;
}

+ (NSArray *)readJsonIntoArray:(NSString *)json
{
    if (!json)
        return nil;
    NSError *error = nil;
    GAD_SBJSON *parser = [[GAD_SBJSON alloc] init];
    id value = [parser objectWithString:json error:&error];
    NSArray *array = nil;
    if (!error && [value isKindOfClass:[NSArray class]])
        array = value;
    [parser release];
    return array;
}

+ (void)pubLog:(NSString *)message
{
    if (logChecker_)
        [logChecker_ message:message];
    NSLog(@"<Google> %@", message);
}

+ (void)setLogChecker:(id<GADLogChecker>)checker
{
    logChecker_ = checker;
}

@end
