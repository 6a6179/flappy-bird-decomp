#import "gad_banner.h"

// These two methods access the externally defined ivar through its nonlazy
// pointer slot. They were compiled separately from the primary class.
@implementation GADSlot (State)

- (int)state
{
    return _state;
}

- (void)setState:(int)newState
{
    int previousState = _state;
    if (previousState == newState)
        return;
    if (previousState == 0 && newState == 2)
        [self notifyAdRequestHasStarted];
    else if (newState == 6 || newState == 7 || newState == 1)
        [self notifyAdRequestHasCompleted];
    _state = newState;
    if (_state == 6) {
        [[self webView] setTouched:NO];
        [self setTimeLastLoaded:[GADTiming counter]];
    }
    if (_state == 5)
        [[self slotStats] endTimingNamed:GADTimingPRNL];
}

@end
