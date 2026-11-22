/* Recovered engine and sprite routines. Addresses in comments are ARMv7 VAs.
 * Field and function names describe observed use. Gaps preserve the 32-bit ABI. */

#include "native.h"

/* 0xd8ac */
void tween_init(Tween *tween)
{
    tween->finished = 1;
    tween->value = 0.0f;
}

/* 0xe790. The engine advances tweens in 60 ticks per second. */
void tween_start(Tween *tween, float start, float end, int curve, float seconds)
{
    tween->start = start;
    tween->end = end;
    tween->distance = end - start;
    tween->duration_ticks = (int)(seconds * 60.0f);
    tween->step = 1.0f / tween->duration_ticks;
    tween->tick = 0;
    tween->curve = curve;
    tween->finished = 0;
    tween->value = start;
}

/* 0x10118, 0x10120. At 0xdba0 this flag gates timers and object updates. */
void engine_pause(AtlasEngine *engine) { engine->paused = 1; }
void engine_resume(AtlasEngine *engine) { engine->paused = 0; }

/* 0xe754 */
void engine_schedule(AtlasEngine *engine, int event, int argument, int delay)
{
    engine->event[engine->queue_write] = event;
    engine->argument[engine->queue_write] = argument;
    engine->delay[engine->queue_write] = delay;
    if (++engine->queue_write > 49)
        engine->queue_write = 0;
}

/* 0xe874 */
void engine_output(AtlasEngine *engine, int type, int value)
{
    engine->output_type[engine->output_count] = type;
    engine->output_value[engine->output_count] = value;
    ++engine->output_count;
}

/* 0xe8a4 */
void engine_output_score(AtlasEngine *engine, int score)
{
    engine->output_type[engine->output_count] = 0;
    engine->output_value[engine->output_count] = score;
    ++engine->output_count;
    if (engine->best_score < score)
        engine->best_score = score;
}

/* 0xe8e4 */
void engine_set_touches(AtlasEngine *engine, const int *x, const int *y, int count)
{
    engine->touch_count = count > 10 ? 10 : count;
    for (int i = 0; i < engine->touch_count; ++i) {
        engine->touch_x[i] = x[i];
        engine->touch_y[i] = y[i];
    }
}

/* 0xf4f0. Even a just-finished sequence fetches frames[index] on this tick. */
void animation_tick(Animation *animation)
{
    if (animation->stopped)
        return;

    animation->elapsed += 15;
    if (animation->elapsed < animation->interval)
        return;

    animation->elapsed = 0;
    if (++animation->index >= animation->count) {
        if (animation->repeat)
            animation->index = 0;
        else
            animation->stopped = 1;
    }
    animation->frame = animation->frames[animation->index];
}

/* 0xf608 */
void sprite_place(void *object, int x, int y)
{
    AnimatedSprite *sprite = object;
    sprite->x = x;
    sprite->y = y;
    sprite->rotation = 0;
    sprite->active = 1;
    sprite->visible = 1;
    sprite->flip_x = 0;
    sprite->flip_y = 0;
    sprite->alpha = 1.0f;
}

static inline void rewind_animation(Animation *animation)
{
    animation->elapsed = 0;
    animation->index = 0;
    animation->frame = animation->frames[0];
}

/* 0xf684 */
void sprite_select_animation(AnimatedSprite *sprite, int slot, int restart)
{
    Animation *animation = sprite->animations[slot];
    if (restart == 1)
        rewind_animation(animation);
    if (!animation->repeat && animation->stopped)
        rewind_animation(animation);
    animation->stopped = 0;
    sprite->animation = animation;
}

/* 0xf748 */
void button_place(Button *button, int x, int y)
{
    button->x = x;
    button->y = y;
    button->object.active = 1;
    button->object.visible = 1;
    button->down = button->pressed = button->released = button->touched = 0;
}

/* 0xe3cc. Quads are batched in bottom-left, bottom-right, top-right,
 * top-left order. */
void append_quad(AtlasEngine *renderer, int left, int top, int right, int bottom,
                 float u0, float v0, float u1, float v1, float opacity)
{
    int n = renderer->quads;
    short *xy = renderer->positions;
    xy[8 * n] = left;
    xy[8 * n + 1] = bottom;
    xy[8 * n + 2] = right;
    xy[8 * n + 3] = bottom;
    xy[8 * n + 4] = right;
    xy[8 * n + 5] = top;
    xy[8 * n + 6] = left;
    xy[8 * n + 7] = top;

    float *uv = renderer->texcoords;
    uv[8 * n] = u0;
    uv[8 * n + 1] = v1;
    uv[8 * n + 2] = u1;
    uv[8 * n + 3] = v1;
    uv[8 * n + 4] = u1;
    uv[8 * n + 5] = v0;
    uv[8 * n + 6] = u0;
    uv[8 * n + 7] = v0;

    float *alpha = renderer->alpha;
    alpha[4 * n] = opacity;
    alpha[4 * n + 1] = opacity;
    alpha[4 * n + 2] = opacity;
    alpha[4 * n + 3] = opacity;
    ++renderer->quads;
}

/* 0xceec */
void draw_region(AtlasEngine *renderer, const Region *region, int x, int y,
                 float opacity)
{
    append_quad(renderer, x, y, x + region->width, y + region->height,
                region->u0, region->v0, region->u1, region->v1, opacity);
}

/* 0xe510 */
void draw_region_scaled(AtlasEngine *renderer, int id, int x, int y,
                        float scale_x, float scale_y, float opacity)
{
    const Region *region = renderer->atlas[id];
    append_quad(renderer, x, y, (int)(x + region->width * scale_x),
                (int)(y + region->height * scale_y),
                region->u0, region->v0, region->u1, region->v1, opacity);
}

/* 0xcda4 */
void font_place(DigitFont *font, int x, int y, int alignment, double opacity)
{
    font->alignment = alignment;
    font->x = x;
    font->y = y;
    font->opacity = opacity;
}

/* 0xf75c. The original engine object is global. */
AtlasEngine *flap_game = 0;
void button_update(void *object, float elapsed)
{
    Button *button = object;
    (void)elapsed;
    AtlasEngine *engine = flap_game;
    int count = engine->touch_count;
    button->touched = 0;
    for (int i = 0; i < count; ++i) {
        if (engine->touch_x[i] > button->x && engine->touch_x[i] < button->x + button->width &&
            engine->touch_y[i] > button->y && engine->touch_y[i] < button->y + button->height) {
            button->touched = 1;
            break;
        }
    }
    button->pressed = button->released = 0;
    if (button->touched != button->down) {
        if (button->down) {
            button->released = 1;
            button->down = 0;
        } else {
            button->pressed = 1;
            button->down = 1;
        }
    }
}

/* 0xd938, 0xe7e0, 0xe838. A transition or flash starts only when its
 * previous tween has finished. advance_tween consumes the first tick here. */

void start_transition(AtlasEngine *engine, int mode, int event, float seconds)
{
    Tween *fade = engine->fade;
    if (!fade->finished)
        return;
    if (mode == 1)
        tween_start(fade, 0, 1, 5, seconds);
    else
        tween_start(fade, 1, 0, 5, seconds);
    advance_tween(fade);
    engine->fade_event = event;
}

void screen_flash(AtlasEngine *engine, float seconds)
{
    Tween *flash = engine->flash;
    if (flash->finished) {
        tween_start(flash, 1, 0, 11, seconds);
        advance_tween(flash);
    }
}

void screen_shake(AtlasEngine *engine, int distance, float seconds)
{
    engine->shake_distance = (int)(distance / engine->display_scale);
    engine->shake_ticks = (int)(seconds * 60.0f);
}

/* 0xf5ac */
void sprite_set_frames(AnimatedSprite *sprite, const char *prefix, int width, int height,
                       int inset_x, int inset_y)
{
    sprite->frames = find_frames(flap_game, prefix, &sprite->image_count);
    if (!width || !height) {
        sprite->width = sprite->frames[0]->width;
        sprite->height = sprite->frames[0]->height;
    } else {
        sprite->width = width;
        sprite->height = height;
    }
    if (!inset_x || !inset_y) {
        sprite->inset_x = (sprite->frames[0]->width - sprite->width) >> 1;
        sprite->inset_y = (sprite->frames[0]->height - sprite->height) >> 1;
    } else {
        sprite->inset_x = inset_x;
        sprite->inset_y = inset_y;
    }
}

/* 0xf6b8. The movement timestep is passed by the virtual update interface.
 * Animation uses its own fixed increment. */
void sprite_update_animation(void *object, float elapsed)
{
    AnimatedSprite *sprite = object;
    (void)elapsed;
    if (sprite->active && sprite->animation)
        animation_tick(sprite->animation);
}

/* 0xf6cc */
void sprite_draw(void *object, AtlasEngine *renderer)
{
    AnimatedSprite *sprite = object;
    if (sprite->visible) {
        Region **frame = sprite->frames;
        if (sprite->animation)
            frame += sprite->animation->frame;
        draw_region_scaled(renderer, (*frame)->id,
                           sprite->x - sprite->inset_x, sprite->y - sprite->inset_y,
                           1.0f, 1.0f, sprite->alpha);
    }
}

/* 0xf724, 0xf7dc */
void button_set_image(Button *button, const char *name)
{
    Region *image = find_sprite(flap_game, name);
    button->image = image;
    button->width = image->width;
    button->height = image->height;
}

void button_draw(void *object, AtlasEngine *renderer)
{
    Button *button = object;
    if (button->down)
        draw_region_scaled(renderer, button->image->id, button->x, button->y + 2, 1.0f, 1.0f, 1.0f);
    else
        draw_region_scaled(renderer, button->image->id, button->x, button->y, 1.0f, 1.0f, 1.0f);
}

/* 0x10014. The positive bound really is strict: 360 is preserved. */
float *flap_sine_table = 0;
float *flap_cosine_table = 0;
static inline int normalize_degrees(int angle)
{
    while (angle > 360)
        angle -= 360;
    while (angle < 0)
        angle += 360;
    return angle;
}

void rotate_point(int *x, int *y, float center_x, float center_y, int angle)
{
    int index = (int)(float)normalize_degrees(angle);
    float dy = *y - center_y;
    float dx = *x - center_x;
    float s = flap_sine_table[index];
    float c = flap_cosine_table[index];
    *x = (int)(dx * c - dy * s + center_x);
    *y = (int)(dx * s + dy * c + center_y);
}

/* 0xe5a0 */
void draw_rotated(AtlasEngine *renderer, const Region *region, int x, int y,
                  float opacity, int angle)
{
    int px = x, py = y + region->height;
    float center_x = x + (region->width >> 1);
    float center_y = y + (region->height >> 1);
    rotate_point(&px, &py, center_x, center_y, angle);
    renderer->positions[8 * renderer->quads] = px;
    renderer->positions[8 * renderer->quads + 1] = py;

    px = x + region->width;
    py = y + region->height;
    rotate_point(&px, &py, center_x, center_y, angle);
    renderer->positions[8 * renderer->quads + 2] = px;
    renderer->positions[8 * renderer->quads + 3] = py;

    px = x + region->width;
    py = y;
    rotate_point(&px, &py, center_x, center_y, angle);
    renderer->positions[8 * renderer->quads + 4] = px;
    renderer->positions[8 * renderer->quads + 5] = py;

    px = x;
    py = y;
    rotate_point(&px, &py, center_x, center_y, angle);
    int n = renderer->quads;
    renderer->positions[8 * n + 6] = px;
    renderer->positions[8 * n + 7] = py;
    float *uv = renderer->texcoords;
    uv[8 * n] = region->u0;
    uv[8 * n + 1] = region->v1;
    uv[8 * n + 2] = region->u1;
    uv[8 * n + 3] = region->v1;
    uv[8 * n + 4] = region->u1;
    uv[8 * n + 5] = region->v0;
    uv[8 * n + 6] = region->u0;
    uv[8 * n + 7] = region->v0;
    float *alpha = renderer->alpha;
    alpha[4 * n] = opacity;
    alpha[4 * n + 1] = opacity;
    alpha[4 * n + 2] = opacity;
    alpha[4 * n + 3] = opacity;
    ++renderer->quads;
}

/* Degree lookup tables and easing curves. The initializer at 0xe920
 * allocates each curve as a separate array of 100 single-precision values. */
float *quad_in = 0, *quad_out = 0, *quad_in_out = 0;
float *cubic_in = 0, *cubic_out = 0, *cubic_in_out = 0;
float *quart_in = 0, *quart_out = 0, *quart_in_out = 0;
float *quint_in = 0, *quint_out = 0, *quint_in_out = 0;
float *elastic_in = 0, *elastic_out = 0, *elastic_in_out = 0;
float *back_in = 0, *back_out = 0, *back_in_out = 0;
float *bounce_in = 0, *bounce_out = 0, *bounce_in_out = 0;

#define SAMPLE(table) ((table)[(int)(tween->progress * 100.0f)])

/* 0xe148. Cases 1 and 7 share a quartic curve. Cases 16–18 use the
 * elastic tables, even though the initializer also computes back curves. */
void advance_tween(Tween *tween)
{
    if (tween->finished)
        return;
    ++tween->tick;
    tween->progress = tween->step * tween->tick;
    switch (tween->curve) {
    case 1: case 7: tween->progress = SAMPLE(quart_in); break;
    case 2: tween->progress = SAMPLE(quad_out); break;
    case 3: tween->progress = SAMPLE(quad_in_out); break;
    case 4: tween->progress = SAMPLE(cubic_in); break;
    case 5: tween->progress = SAMPLE(cubic_out); break;
    case 6: tween->progress = SAMPLE(cubic_in_out); break;
    case 8: tween->progress = SAMPLE(quart_out); break;
    case 9: tween->progress = SAMPLE(quart_in_out); break;
    case 10: tween->progress = SAMPLE(quint_in); break;
    case 11: tween->progress = SAMPLE(quint_out); break;
    case 12: tween->progress = SAMPLE(quint_in_out); break;
    case 13: case 16: tween->progress = SAMPLE(elastic_in); break;
    case 14: case 17: tween->progress = SAMPLE(elastic_out); break;
    case 15: case 18: tween->progress = SAMPLE(elastic_in_out); break;
    case 19: tween->progress = SAMPLE(bounce_in); break;
    case 20: tween->progress = SAMPLE(bounce_out); break;
    case 21: tween->progress = SAMPLE(bounce_in_out); break;
    }
    tween->value = tween->progress * tween->distance + tween->start;
    if (tween->tick == tween->duration_ticks) {
        tween->finished = 1;
        tween->value = tween->end;
        tween->progress = 1.0f;
    }
}
#undef SAMPLE

/* 0xef00 */
double ease_quint_in_out(double t)
{
    if (t < 0.5)
        return 16 * t * t * t * t * t;
    double u = 2 * t - 2;
    return 0.5 * u * u * u * u * u + 1;
}

extern double exp2(double);
static const double half_wave = 20.420352248333657;
static const double pi = 3.141592653589793;

/* 0xef60. The original uses integer subscripts into the degree sine table,
 * including the negative subscript produced by the second branch. */
double ease_elastic_in_out(double t)
{
    double u = t * 2;
    if (t < 0.5)
        return 0.5 * flap_sine_table[(int)(half_wave * u)] * exp2(10 * (u - 1));
    u -= 1;
    return 0.5 * (flap_sine_table[(int)(-half_wave * (u + 1))] * exp2(-10 * u) + 2);
}

/* 0xf048 */
double ease_back_in_out(double t)
{
    double u = t * 2;
    if (t < 0.5)
        return 0.5 * (u * u * u - u * flap_sine_table[(int)(u * pi)]);
    u = 1 - (u - 1);
    return 0.5 * (1 - (u * u * u - u * flap_sine_table[(int)(u * pi)])) + 0.5;
}

/* 0xf100 */
double ease_bounce_out(double t)
{
    if (t < 4.0 / 11)
        return 121 * t * t / 16;
    if (t < 8.0 / 11)
        return 363.0 / 40 * t * t - 99.0 / 10 * t + 17.0 / 5;
    if (t < 0.9)
        return 4356.0 / 361 * t * t - 35442.0 / 1805 * t + 16061.0 / 1805;
    return 54.0 / 5 * t * t - 513.0 / 25 * t + 268.0 / 25;
}

/* 0xf218 */
double ease_bounce_in_out(double t)
{
    if (t < 0.5)
        return 0.5 * (1 - ease_bounce_out(1 - t * 2));
    return 0.5 * ease_bounce_out(t * 2 - 1) + 0.5;
}

extern void *malloc(unsigned long);
extern float sinf(float);
extern float cosf(float);

/* 0xe920 */
void *init_math_tables(void *self)
{
    float *sines = flap_sine_table = malloc(360 * sizeof(float));
    float *cosines = flap_cosine_table = malloc(360 * sizeof(float));
    for (int i = 0; i < 360; ++i) {
        float radians = (float)(i * 3.1415926 / 180.0);
        sines[i] = sinf(radians);
        cosines[i] = cosf(radians);
    }

    /* All arrays have distinct allocations, retained locally while filling them. */
#define ALLOCATE_CURVE(name) float *name##_values = name = malloc(100 * sizeof(float))
    ALLOCATE_CURVE(quad_in);
    ALLOCATE_CURVE(quad_out);
    ALLOCATE_CURVE(quad_in_out);
    ALLOCATE_CURVE(cubic_in);
    ALLOCATE_CURVE(cubic_out);
    ALLOCATE_CURVE(cubic_in_out);
    ALLOCATE_CURVE(quart_in);
    ALLOCATE_CURVE(quart_out);
    ALLOCATE_CURVE(quart_in_out);
    ALLOCATE_CURVE(quint_in);
    ALLOCATE_CURVE(quint_out);
    ALLOCATE_CURVE(quint_in_out);
    ALLOCATE_CURVE(elastic_in);
    ALLOCATE_CURVE(elastic_out);
    ALLOCATE_CURVE(elastic_in_out);
    ALLOCATE_CURVE(back_in);
    ALLOCATE_CURVE(back_out);
    ALLOCATE_CURVE(back_in_out);
    ALLOCATE_CURVE(bounce_in);
    ALLOCATE_CURVE(bounce_out);
    ALLOCATE_CURVE(bounce_in_out);
#undef ALLOCATE_CURVE

    for (int i = 0; i < 100; ++i) {
        double t = i / 100.0;
        quad_in_values[i] = t * t;
        quad_out_values[i] = -(t * (t - 2));
        quad_in_out_values[i] = t < 0.5 ? 2 * t * t : -2 * t * t + 4 * t - 1;

        cubic_in_values[i] = t * t * t;
        double u = t - 1;
        cubic_out_values[i] = u * u * u + 1;
        double cubic_eased;
        if (t < 0.5) {
            cubic_eased = 4 * t * t * t;
        } else {
            double v = 2 * t - 2;
            cubic_eased = 0.5 * v * v * v + 1;
        }
        cubic_in_out_values[i] = cubic_eased;

        quart_in_values[i] = t * t * t * t;
        double v = 1 - t;
        quart_out_values[i] = u * u * u * v + 1;
        quart_in_out_values[i] = t < 0.5 ? 8 * t * t * t * t : -8 * u * u * u * u + 1;

        quint_in_values[i] = t * t * t * t * t;
        quint_out_values[i] = u * u * u * u * u + 1;
        quint_in_out_values[i] = ease_quint_in_out(t);
        elastic_in_values[i] = sines[(int)(t * half_wave)] * exp2(10 * u);
        elastic_out_values[i] = sines[(int)((t + 1) * -half_wave)] * exp2(-10 * t) + 1;
        elastic_in_out_values[i] = ease_elastic_in_out(t);
        back_in_values[i] = t*t*t - t * sines[(int)(t * pi)];
        back_out_values[i] = 1 - (v*v*v - v * sines[(int)(v * pi)]);
        back_in_out_values[i] = ease_back_in_out(t);
        bounce_in_values[i] = 1 - ease_bounce_out(v);
        bounce_out_values[i] = ease_bounce_out(t);
        bounce_in_out_values[i] = ease_bounce_in_out(t);
    }
    return self;
}

extern void free(void *ptr);

/* 0xf284. The destructor frees all tables first, then clears their globals. */
void *dispose_math_tables(void *self)
{
    free(flap_sine_table);
    free(flap_cosine_table);
    free(quad_in);
    free(quad_out);
    free(quad_in_out);
    free(cubic_in);
    free(cubic_out);
    free(cubic_in_out);
    free(quart_in);
    free(quart_out);
    free(quart_in_out);
    free(quint_in);
    free(quint_out);
    free(quint_in_out);
    free(elastic_in);
    free(elastic_out);
    free(elastic_in_out);
    free(back_in);
    free(back_out);
    free(back_in_out);
    free(bounce_in);
    free(bounce_out);
    free(bounce_in_out);
    flap_sine_table = 0;
    flap_cosine_table = 0;
    quad_in = 0;
    quad_out = 0;
    quad_in_out = 0;
    cubic_in = 0;
    cubic_out = 0;
    cubic_in_out = 0;
    quart_in = 0;
    quart_out = 0;
    quart_in_out = 0;
    quint_in = 0;
    quint_out = 0;
    quint_in_out = 0;
    elastic_in = 0;
    elastic_out = 0;
    elastic_in_out = 0;
    back_in = 0;
    back_out = 0;
    back_in_out = 0;
    bounce_in = 0;
    bounce_out = 0;
    bounce_in_out = 0;
    return self;
}

/* The five base animation methods follow the Itanium ABI's offset and RTTI. */
extern void *memcpy(void *dst, const void *src, unsigned long length);
extern char *strcpy(char *dst, const char *src);

/* 0xf52c */
AnimatedSprite *sprite_construct(AnimatedSprite *sprite)
{
    sprite->object.active = 0;
    sprite->object.visible = 0;
    sprite->object.methods = &sprite_vtable.calls;
    sprite->alpha = 1.0f;
    sprite->animation = 0;
    sprite->active = sprite->visible = 0;
    return sprite;
}

/* 0xf568 */
void *destroy_animated_sprite(void *object)
{
    AnimatedSprite *sprite = object;
    sprite->object.methods = &sprite_vtable.calls;
    for (int i = 0; i < 10; ++i) {
        Animation *animation = sprite->animations[i];
        if (animation) {
            free(animation->frames);
            game_delete(animation);
            sprite->animations[i] = 0;
        }
    }
    return sprite;
}

/* 0xf564, 0xf550 */
static void *sprite_destroy(void *object)
{
    return destroy_animated_sprite(object);
}

static void sprite_delete(void *object)
{
    destroy_animated_sprite(object);
    game_delete(object);
}

const SpriteVTable sprite_vtable = {
    0, 0, {sprite_update_animation, sprite_draw, sprite_destroy, sprite_delete, sprite_place}
};

/* 0xf62c */
void sprite_add_animation(AnimatedSprite *sprite, int slot, const char *name, const int *frames,
                          int count, int frames_per_second, int loop)
{
    Animation *animation = game_new(sizeof(Animation));
    strcpy(animation->name, name);
    animation->count = count;
    animation->frames = malloc(count * sizeof(int));
    memcpy(animation->frames, frames, count * sizeof(int));
    animation->interval = 1000 / frames_per_second;
    animation->repeat = loop;
    animation->slot = slot;
    sprite->animations[slot] = animation;
}

extern void *destroy_button(void *object);
extern void delete_button(void *object);
const SpriteVTable button_vtable = {
    0, 0, {button_update, button_draw, destroy_button, delete_button}
};
