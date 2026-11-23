// Recreate the C++ specializations whose coalesced section starts after the score panel.
#define _Bool bool
extern "C" {
#include "scene.h"
void *malloc(Size size);
AtlasEngine *flap_game;
extern const SpriteVTable number_vtable;
AnimatedSprite *init_sparkle(AnimatedSprite *);
}

struct FloatingNumber {
    Sprite object;
    Region **digits;
    int width, height;
    bool draw_marker;
    int lifetime, value, places, velocity, acceleration, tick;
    int x, y, number_offset;
    int reserved;
};

static inline void initialize_item(FloatingNumber *number)
{
    number->object.active = false;
    number->object.visible = false;
    number->object.methods = &number_vtable.calls;
    number->width = 12;
    number->height = 14;
    int frames;
    number->digits = find_frames(flap_game, "number_context", &frames);
}

static inline void initialize_item(AnimatedSprite *sparkle)
{
    init_sparkle(sparkle);
}

template <class Item>
void initialize_pool(SpritePool *pool, int count)
{
    pool->count = count;
    pool->items = static_cast<void **>(malloc(sizeof(*pool->items) * count));
    if (count > 0) {
        int i = 0;
        do {
            Item *item = static_cast<Item *>(game_new(sizeof(*item)));
            initialize_item(item);
            pool->items[i++] = item;
        } while (i < pool->count);
    }
    pool->next = 0;
}

template void initialize_pool<FloatingNumber>(SpritePool *, int);
template void initialize_pool<AnimatedSprite>(SpritePool *, int);

// In the engine this vtable was defined alongside the number initialization code.
extern "C" const SpriteVTable number_vtable = {};
