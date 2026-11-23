#ifndef GAD_VIEW_GEOMETRY_H
#define GAD_VIEW_GEOMETRY_H

#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>

typedef struct {
    int x, y, width, height;
    char className[128];
} GADViewGeometry;

bool GADReadSignalInteger(CFDictionaryRef dictionary, CFStringRef key, int *value);
bool GADReadSignalString(CFDictionaryRef dictionary, CFStringRef key,
                         char *value, CFIndex capacity);
int GADViewIntersectionArea(GADViewGeometry view, GADViewGeometry target);

#endif
