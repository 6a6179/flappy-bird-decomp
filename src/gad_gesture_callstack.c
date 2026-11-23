#include <CoreFoundation/CoreFoundation.h>
#include <stdbool.h>

CFStringRef CopyParentMethodFromCallStack(CFStringRef trace)
{
    if (!trace)
        return NULL;

    const int symbolColumn = 3;
    CFArrayRef fields = NULL;
    CFArrayRef lines = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, trace, CFSTR("\n"));
    if (!lines)
        return NULL;

    CFStringRef result = CFSTR("INVALID");
    CFIndex lineCount = CFArrayGetCount(lines);
    bool foundDelegate = false;
    CFStringRef delegateMethod = CFSTR("-[GADBannerWebViewDelegate webView:shouldStartLoadWithRequest:navigationType:]");
    for (CFIndex line = 0; line < lineCount; ++line) {
        CFStringRef frame = CFArrayGetValueAtIndex(lines, line);
        if (fields)
            CFRelease(fields);
        fields = CFStringCreateArrayBySeparatingStrings(kCFAllocatorDefault, frame, CFSTR(" "));
        if (!fields)
            continue;

        CFIndex fieldCount = CFArrayGetCount(fields);
        if (fieldCount > symbolColumn) {
            CFIndex field = 0;
            int nonempty = 0;
            while (field < fieldCount && nonempty < symbolColumn + 1) {
                CFStringRef token = CFArrayGetValueAtIndex(fields, field);
                if (CFStringGetLength(token) > 0)
                    ++nonempty;
                ++field;
            }
            if (nonempty != symbolColumn + 1)
                continue;

            CFStringRef token = CFArrayGetValueAtIndex(fields, field - 1);
            if (CFStringHasPrefix(token, CFSTR("-[")) || CFStringHasPrefix(token, CFSTR("+["))) {
                CFMutableStringRef method = CFStringCreateMutableCopy(kCFAllocatorDefault, 0, token);
                if (!foundDelegate) {
                    while (field < fieldCount) {
                        token = CFArrayGetValueAtIndex(fields, field);
                        if (CFStringGetLength(token) > 0) {
                            CFStringAppendFormat(method, NULL, CFSTR(" %@"), token);
                            if (CFStringHasSuffix(token, CFSTR("]")))
                                break;
                        }
                        ++field;
                    }
                }
                if (foundDelegate) {
                    result = CFStringCreateWithSubstring(kCFAllocatorDefault, method,
                                                         CFRangeMake(2, CFStringGetLength(method) - 2));
                    CFRelease(method);
                    break;
                }
                if (CFStringCompare(method, delegateMethod, 0) == kCFCompareEqualTo)
                    foundDelegate = true;
                CFRelease(method);
            } else if (CFStringHasSuffix(token, CFSTR("()")) && foundDelegate) {
                result = CFStringCreateCopy(kCFAllocatorDefault, token);
                break;
            }
        }
    }

    if (fields)
        CFRelease(fields);
    CFRelease(lines);
    return result;
}
