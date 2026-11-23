#import <Foundation/Foundation.h>
#import <UIKit/UIScreen.h>
#import <UIKit/UIScreenMode.h>
#import <stdlib.h>

typedef struct {
    int width;
    int height;
} GADScreenDimensions;

GADScreenDimensions GetScreenDimensions(void)
{
    GADScreenDimensions dimensions;
    CGSize size = [[[UIScreen mainScreen] currentMode] size];
    dimensions.width = abs((int)size.width);
    dimensions.height = abs((int)size.height);
    return dimensions;
}

static int minutesPerDay = 24 * 60;

int GetTimeZoneUTCOffsetMinutesPlusOneDay(void)
{
    NSTimeZone *local = [NSTimeZone systemTimeZone];
    NSTimeZone *utc = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    int localSeconds = [local secondsFromGMT];
    int utcSeconds = [utc secondsFromGMT];
    int delta = localSeconds - utcSeconds;
    return delta / 60 + minutesPerDay;
}
