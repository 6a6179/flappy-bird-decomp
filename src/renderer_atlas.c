#include "renderer.h"

extern Size strlen(const char *);
extern char *strcpy(char *, const char *);
extern void *malloc(Size);

static int atlas_next_id;

/* 0xcd18 / 0xcec0. An animation names a contiguous run of atlas images.
 * The engine counts every prefix match and returns the first slot. */
Region **find_frames(AtlasEngine *engine, const char *prefix, int *count)
{
    *count = 0;
    int first = -1, matches = 0;
    Region **atlas = engine->atlas;
    for (int i = 0; i < 512; ++i) {
        Region *region = atlas[i];
        if (region) {
            unsigned j;
            Size prefix_length = strlen(prefix);
            for (j = 0; j < prefix_length; ++j)
                if (prefix[j] != region->name[j])
                    break;
            if (j == strlen(prefix)) {
                *count = ++matches;
                if (first < 0)
                    first = i;
            }
        }
    }
    return first >= 0 ? atlas + first : 0;
}

/* 0xd8b8 / 0xda5c */
Region *find_sprite(AtlasEngine *engine, const char *prefix)
{
    Region **atlas = engine->atlas;
    for (int i = 0; i < 512; ++i) {
        Region *region = atlas[i];
        if (region) {
            unsigned j;
            Size prefix_length = strlen(prefix);
            for (j = 0; j < prefix_length; ++j)
                if (prefix[j] != region->name[j])
                    break;
            if (j == strlen(prefix))
                return region;
        }
    }
    return 0;
}

/* 0xcf3c / 0xd0e0 */
Region *init_region(Region *region, const char *name, int width, int height,
                    float u0, float v0, float u1, float v1)
{
    region->name = malloc(strlen(name) + 1);
    strcpy(region->name, name);
    region->name[strlen(name)] = 0;
    region->width = width;
    region->height = height;
    region->u0 = u0;
    region->v0 = v0;
    region->u1 = u1;
    region->v1 = v1;
    region->id = atlas_next_id;
    ++atlas_next_id;
    return region;
}
