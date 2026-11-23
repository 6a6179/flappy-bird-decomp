#include <mach-o/dyld.h>
#include <sys/stat.h>

typedef struct {
    const char *name;
    uintptr_t start;
    uintptr_t end;
} GADImageRange;

static int GADCompareImageRanges(const void *left, const void *right)
{
    const GADImageRange *a = left;
    const GADImageRange *b = right;
    if (a && b) {
        int delta = (int)(a->start - b->start);
        if (delta > 0)
            return 1;
        if (delta == 0)
            return 0;
        if (delta < 0)
            return -1;
    }
    return 0;
}

int FindSwizzling(const char *imageName)
{
    int imageCount = _dyld_image_count();
    if (imageCount <= 0 || !imageName)
        return -1;
    GADImageRange *images = malloc(imageCount * sizeof(*images));
    if (!images)
        return -1;
    uintptr_t lastAddress = (uintptr_t)-1;
    int count = 0;
    for (int i = 0; i < imageCount; ++i) {
        const char *name = _dyld_get_image_name(i);
        const struct mach_header *header = _dyld_get_image_header(i);
        if (!name || !header)
            continue;
        images[count].name = name;
        images[count].start = (uintptr_t)header;
        images[count].end = lastAddress;
        ++count;
    }
    qsort(images, count, sizeof(*images), GADCompareImageRanges);
    GADImageRange target = {0};
    for (int i = 0; i < count - 1; ++i) {
        images[i].end = images[i + 1].start;
        if (strstr(images[i].name, imageName)) {
            target = images[i];
            break;
        }
    }
    int flags = 0;
    if (target.name) {
        for (int i = 0; i < 12; ++i) {
            GADGestureMethod method = gestureMethods[i];
            uintptr_t imp = (uintptr_t)GADGestureInstanceImplementation(method.className, method.selectorName);
            if (imp >= target.start && imp < target.end)
                flags |= method.flag;
        }
    }
    free(images);
    return flags;
}

static const char *jailbreakPath = "655094cdb3395f5389941a9b03f725681467421bb1a010";

int CheckJailBreakStatus(void)
{
    int status = -1;
    struct stat info;
    char *name = DECODE_GESTURE_NAME(jailbreakPath);
    if (stat(name, &info) == 0)
        status = 1;
    else
        status = 0;
    GADClearGestureString(name);
    return status;
}
