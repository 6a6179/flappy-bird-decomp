#ifndef GAD_GESTURE_SIGNALS_H
#define GAD_GESTURE_SIGNALS_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>

void gad_gig(CFStringRef identifier);
bool gad_gmrs(CFMutableStringRef output);
bool gad_gmcs(CFStringRef input, CFMutableStringRef output);

#endif
