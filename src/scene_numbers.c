#include "scene.h"

extern void *malloc(Size size);

#ifdef FLAP_SCENE_REFERENCE_OBJECT
AtlasEngine *flap_game;
#endif

typedef struct {
    Sprite object;
    Region **digits;
    int width, height;
    _Bool draw_marker;
    int lifetime, value, places, velocity, acceleration, tick;
    int x, y, number_offset;
    int reserved;
} FloatingNumber;

static const SpriteVTable number_vtable;

// 0xf814 / 0xf8b0
void delete_floating_number(void *number)
{
    game_delete(number);
}

// 0xf818 / 0xf8b4
void *destroy_floating_number(void *number)
{
    return number;
}

// 0xf81c / 0xf8b8. The number_context atlas has a narrow glyph for 1.
void draw_context_number(FloatingNumber *number, AtlasEngine *renderer, int value, int right, int y,
                         _Bool zero_fill, int places)
{
    int x = right - number->width;
    _Bool show_zero = 1;
    while (places > 0) {
        if (value > 0 || show_zero) {
            int digit = value % 10;
            draw_region_scaled(renderer, number->digits[digit]->id, x, y, 1, 1, 1);
            value /= 10;
            if (digit == 1)
                x -= 4;
            else
                x -= number->width - 2;
            show_zero = zero_fill;
        }
        --places;
    }
}

// 0xf8a4 / 0xf940
void update_floating_number(void *object, float dt)
{
    (void)dt;
    FloatingNumber *number = object;
    if (!number->object.active || number->lifetime <= 0)
        return;
    --number->lifetime;
    if (number->velocity <= 1) {
        number->y += number->velocity;
        if (++number->tick == 4) {
            number->tick = 0;
            number->velocity += number->acceleration;
        }
    }
    if (number->lifetime <= 0)
        number->object.active = number->object.visible = 0;
}

// 0xf8e0 / 0xf97c
void draw_floating_number(void *object, AtlasEngine *renderer)
{
    FloatingNumber *number = object;
    if (!number->object.visible)
        return;
    if (number->draw_marker)
        draw_region_scaled(renderer, number->digits[10]->id, number->x, number->y, 1, 1, 1);
    draw_context_number(number, renderer, number->value, number->x + number->number_offset, number->y, 0, number->places);
}

// 0xf930 / 0xf9cc. Score and best on the panel use a fixed glyph advance.
void draw_number(FrameSet *font, AtlasEngine *renderer, int value, int right, int y, _Bool zero_fill,
                 int places)
{
    int x = right - font->width;
    _Bool show_zero = 1;
    while (places > 0) {
        if (value > 0 || show_zero) {
            int digit = value % 10;
            draw_region_scaled(renderer, font->frames[digit]->id, x, y, 1, 1, 1);
            value /= 10;
            x -= font->width;
            show_zero = zero_fill;
        }
        --places;
    }
}

static inline void init_floating_number(FloatingNumber *number)
{
    number->object.active = 0;
    number->object.visible = 0;
    number->object.methods = &number_vtable.calls;
    number->width = 12;
    number->height = 14;
    int frames;
    number->digits = find_frames(flap_game, "number_context", &frames);
}

// 0xff4c / 0xffe4
void init_number_pool(SpritePool *pool, int count)
{
    pool->count = count;
    pool->items = malloc(sizeof(*pool->items) * count);
    if (count > 0) {
        int i = 0;
        do {
            FloatingNumber *number = game_new(sizeof(*number));
            init_floating_number(number);
            pool->items[i++] = number;
        } while (i < pool->count);
    }
    pool->next = 0;
}

static const SpriteVTable number_vtable = {
    0, 0, {update_floating_number, draw_floating_number, destroy_floating_number,
           delete_floating_number}
};
