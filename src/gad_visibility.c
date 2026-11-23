#include "gad_view_geometry.h"
#include <string.h>

extern CFArrayRef GetWalkViews(CFStringRef className);

bool GADReadViewGeometry(CFDictionaryRef dictionary, GADViewGeometry *view)
{
    return GADReadSignalInteger(dictionary, CFSTR("x"), &view->x) &&
           GADReadSignalInteger(dictionary, CFSTR("y"), &view->y) &&
           GADReadSignalInteger(dictionary, CFSTR("w"), &view->width) &&
           GADReadSignalInteger(dictionary, CFSTR("h"), &view->height) &&
           GADReadSignalString(dictionary, CFSTR("ViewName"), view->className,
                               sizeof(view->className));
}

int GetAdVisibility(const char *className)
{
    int result = -1;
    CFStringRef name = CFStringCreateWithCString(kCFAllocatorDefault, className,
                                                  kCFStringEncodingUTF8);
    CFArrayRef views = GetWalkViews(name);
    CFRelease(name);
    if (!views)
        return result;

    CFIndex count = CFArrayGetCount(views);
    GADViewGeometry target = {0};
    bool found = false;
    for (int i = 0; i < count; i++) {
        CFDictionaryRef dictionary = CFArrayGetValueAtIndex(views, i);
        GADViewGeometry view;
        if (!GADReadViewGeometry(dictionary, &view))
            break;
        if (strcmp(view.className, className) == 0 && !found) {
            target = view;
            found = true;
            result = 0;
            continue;
        }
        int overlap = GADViewIntersectionArea(view, target);
        if (found && overlap > 0) {
            result = overlap;
            break;
        }
    }
    return result;
}
