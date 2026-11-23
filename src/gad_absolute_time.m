#import <Foundation/Foundation.h>
#include <mach/mach_time.h>

@interface GADAbsoluteTime : NSObject
@end

@implementation GADAbsoluteTime

+ (NSNumber *)absoluteTimeInMilliseconds
{
    static uint64_t baseTime;
    static double ticksPerMillisecond;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        baseTime = mach_absolute_time();
        mach_timebase_info_data_t timebase = {0};
        mach_timebase_info(&timebase);
        ticksPerMillisecond = ((double)timebase.denom / timebase.numer) * 1000000.0;
    });
    uint64_t milliseconds = (mach_absolute_time() - baseTime) / ticksPerMillisecond;
    return [NSNumber numberWithUnsignedLongLong:milliseconds];
}

@end
