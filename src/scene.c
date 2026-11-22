#include "scene.h"

extern void *malloc(Size size);

static const SpriteVTable sparkle_vtable;
static const SpriteVTable medal_vtable;
static const SpriteVTable panel_vtable;

// The original compiled the engine and these widgets in one translation unit;
// direct references to their data differ from imports through non-lazy pointers.
// The standalone match build recreates this visibility for this object.
#ifdef FLAP_SCENE_REFERENCE_OBJECT
AtlasEngine *flap_game;
unsigned flap_random_z, flap_random_w;
#endif

static Tween *new_tween(void)
{
    Tween *tween = game_new(sizeof(*tween));
    tween->finished = 1;
    tween->value = 0;
    return tween;
}

// 0xf9ac / 0xfa48
AnimatedSprite *init_sparkle(AnimatedSprite *sparkle)
{
    sparkle->object.active = 0;
    sparkle->object.visible = 0;
    sparkle->alpha = 1;
    sparkle->animation = 0;
    sparkle->active = 0;
    sparkle->visible = 0;
    sparkle->object.methods = &sparkle_vtable.calls;
    sparkle->frames = find_frames(flap_game, "blink", &sparkle->image_count);
    sparkle->width = 10;
    sparkle->height = 10;
    sparkle->inset_x = 4;
    sparkle->inset_y = 4;

    Animation *animation = game_new(sizeof(*animation));
    __builtin_memcpy(animation->name, "blink", 6);
    animation->count = 5;
    animation->frames = malloc(5 * sizeof(int));
    static const int order[] = {0, 1, 2, 1, 0};
    __builtin_memcpy(animation->frames, order, sizeof(order));
    animation->interval = 100;
    animation->repeat = 0;
    animation->slot = 0;
    sparkle->animations[0] = animation;
    return sparkle;
}

// 0xfa74 / 0xfb10
void show_sparkle(void *object, int x, int y)
{
    AnimatedSprite *sparkle = object;
    sparkle->x = x;
    sparkle->y = y;
    sparkle->rotation = 0;
    sparkle->active = 1;
    sparkle->visible = 1;
    sparkle->flip_x = 0;
    sparkle->flip_y = 0;
    sparkle->alpha = 1;
    sprite_select_animation(sparkle, 0, 1);
}

// 0xfa9c / 0xfb38
void update_sparkle(void *object, float dt)
{
    AnimatedSprite *sparkle = object;
    (void)dt;
    if (sparkle->active && sparkle->animation)
        animation_tick(sparkle->animation);
    if (sparkle->animation->stopped)
        sparkle->active = sparkle->visible = 0;
}

static int sparkle_random(int span)
{
    // The high halves are signed (ASR). Shift the result as unsigned to retain
    // the low 32 bits of the original multiply-with-carry combination.
    flap_random_z = 36969 * (unsigned)(flap_random_z & 65535) + ((int)flap_random_z >> 16);
    flap_random_w = 18000 * (unsigned)(flap_random_w & 65535) + ((int)flap_random_w >> 16);
    int value = (int)(((unsigned)flap_random_z << 16) + flap_random_w);
    int positive = value < 0 ? (int)(0u - (unsigned)value) : value;
    return positive % span;
}

// 0xfad0 / 0xfb6c
void update_medal(void *object, float dt)
{
    Medal *medal = object;
    (void)dt;
    if (!medal->object.active || medal->until_sparkle <= 0 || --medal->until_sparkle > 0)
        return;
    medal->until_sparkle = 30;
    AtlasEngine *engine = flap_game;
    int x = medal->x + sparkle_random(medal->width + 6) - 3;
    int y = medal->y + sparkle_random(medal->height + 6) - 3;
    SpritePool *pool = engine->sparkles;
    AnimatedSprite *sparkle = pool->items[pool->next++];
    if (pool->next == pool->count)
        pool->next = 0;
    sparkle->object.methods->place(sparkle, x, y);
}

// 0xfbbc / 0xfc64
void draw_medal(void *object, AtlasEngine *renderer)
{
    Medal *medal = object;
    if (medal->object.visible)
        draw_region_scaled(renderer, medal->frames[medal->frame]->id, medal->x, medal->y, 1, 1, 1);
}

static inline Medal *init_medal(Medal *medal)
{
    medal->object.active = 0;
    medal->object.visible = 0;
    medal->object.methods = &medal_vtable.calls;
    int count = 0;
    medal->frames = find_frames(flap_game, "medals", &count);
    return medal;
}

// 0xfbf0 / 0xfc98
ScorePanel *init_score_panel(ScorePanel *panel)
{
    panel->object.active = 0;
    panel->object.visible = 0;
    panel->object.methods = &panel_vtable.calls;
    panel->score = 0;
    panel->shown_score = 0;
    panel->best = 0;
    Region *background = find_sprite(flap_game, "score_panel");
    panel->background = background;
    panel->new_badge = find_sprite(flap_game, "new");
    panel->digits = flap_game->score_digits;
    panel->width = background->width;
    panel->height = background->height;
    panel->final_y = (ScreenHeight - panel->height) >> 1;
    panel->tween = new_tween();

    Medal *medal = game_new(sizeof(*medal));
    panel->medal = init_medal(medal);
    return panel;
}

static void panel_tween(Tween *tween, float from, float to, int easing)
{
    tween->start = from;
    tween->end = to;
    tween->distance = to - from;
    tween->duration_ticks = 30;
    tween->step = 1.0f / 30;
    tween->tick = 0;
    tween->curve = easing;
    tween->finished = 0;
    tween->value = from;
}

// 0xfcc0 / 0xfd68
void show_score_panel(ScorePanel *panel, int score, int best, int bronze, int silver,
                      int gold, int platinum)
{
    panel->score = score;
    panel->best = best;
    panel->shown_score = 0;
    panel->bronze = bronze;
    panel->silver = silver;
    panel->gold = gold;
    panel->platinum = platinum;
    panel->object.active = panel->object.visible = 1;
    panel->new_best = 0;
    panel->x = (ScreenWidth - panel->width) >> 1;
    panel->y = 504;
    panel_tween(panel->tween, 504, (float)panel->final_y, EASE_QUINT_OUT);
    panel->stage = PANEL_SLIDING_IN;
    Medal *medal = panel->medal;
    medal->object.active = 0;
    medal->object.visible = 0;
}

static inline void show_medal(Medal *medal, int frame)
{
    medal->x = 0;
    medal->y = 0;
    medal->width = medal->height = 44;
    medal->frame = frame;
    medal->until_sparkle = 30;
    medal->object.active = medal->object.visible = 1;
}

// 0xfd54 / 0xfdfc
void update_score_panel(void *object, float dt)
{
    ScorePanel *panel = object;
    if (!panel->object.active)
        return;
    if (!panel->tween->finished)
        advance_tween(panel->tween);

    switch (panel->stage) {
    case PANEL_SLIDING_IN:
        panel->y = (int)panel->tween->value;
        if (panel->tween->finished) {
            if (panel->score > 0) {
                panel->stage = PANEL_COUNTING_SCORE;
                panel_tween(panel->tween, 0, (float)panel->score, EASE_LINEAR);
            } else {
                panel->stage = PANEL_FINISHED;
            }
        }
        break;
    case PANEL_COUNTING_SCORE:
        panel->shown_score = (int)panel->tween->value;
        if (!panel->tween->finished)
            return;
        panel->stage = PANEL_FINISHED;
        flap_game->methods->score(flap_game, panel->shown_score);
        if (panel->shown_score > panel->best) {
            panel->best = panel->shown_score;
            panel->new_best = 1;
        }
        if (panel->shown_score >= panel->platinum)
            show_medal(panel->medal, 0);
        else if (panel->shown_score >= panel->gold)
            show_medal(panel->medal, 1);
        else if (panel->shown_score >= panel->silver)
            show_medal(panel->medal, 2);
        else if (panel->shown_score >= panel->bronze)
            show_medal(panel->medal, 3);
        panel->medal->x = panel->x + 32;
        panel->medal->y = panel->y + 44;
        break;
    case PANEL_FINISHED:
        panel->medal->object.methods->update(panel->medal, dt);
        break;
    }
}

// 0xfea4 / 0xff3c
void draw_score_panel(void *object, AtlasEngine *renderer)
{
    ScorePanel *panel = object;
    if (!panel->object.visible)
        return;
    draw_region_scaled(renderer, panel->background->id, panel->x, panel->y, 1, 1, 1);
    draw_number(panel->digits, renderer, panel->shown_score, panel->x + 210, panel->y + 36, 0, 10);
    draw_number(panel->digits, renderer, panel->best, panel->x + 210, panel->y + 78, 0, 10);
    if (panel->new_best)
        draw_region_scaled(renderer, panel->new_badge->id, panel->x + 142, panel->y + 60, 1, 1, 1);
    panel->medal->object.methods->draw(panel->medal, renderer);
}

// 0xffd0 / 0x1006c
void init_sparkle_pool(SpritePool *pool, int count)
{
    pool->count = count;
    pool->items = malloc(sizeof(*pool->items) * count);
    if (count > 0) {
        int i = 0;
        do {
            AnimatedSprite *sparkle = game_new(sizeof(*sparkle));
            init_sparkle(sparkle);
            pool->items[i++] = sparkle;
        } while (i < pool->count);
    }
    pool->next = 0;
}

// 0x10128 / 0x101c8
void update_sparkle_pool(void *object, float dt)
{
    SpritePool *pool = object;
    for (int i = 0; i < pool->count; ++i) {
        AnimatedSprite *sparkle = pool->items[i];
        if (sparkle->active)
            sparkle->object.methods->update(sparkle, dt);
    }
}

// 0x10160 / 0x101fc
void draw_sparkle_pool(void *object, AtlasEngine *renderer)
{
    SpritePool *pool = object;
    for (int i = 0; i < pool->count; ++i) {
        AnimatedSprite *sparkle = pool->items[i];
        if (sparkle->visible)
            sparkle->object.methods->draw(sparkle, renderer);
    }
}

// 0x101f0 / 0x1028c
void update_node_pool(void *object, float dt)
{
    SpritePool *pool = object;
    for (int i = 0; i < pool->count; ++i) {
        Sprite *node = pool->items[i];
        if (node->active)
            node->methods->update(node, dt);
    }
}

// 0x10224 / 0x102c0
void draw_node_pool(void *object, AtlasEngine *renderer)
{
    SpritePool *pool = object;
    for (int i = 0; i < pool->count; ++i) {
        Sprite *node = pool->items[i];
        if (node->visible)
            node->methods->draw(node, renderer);
    }
}

// 0xfa6c / 0xfb08
void *destroy_sparkle(void *object)
{
    return destroy_animated_sprite(object);
}

// 0xfa58 / 0xfaf4
void delete_sparkle(void *object)
{
    destroy_animated_sprite(object);
    game_delete(object);
}

static const SpriteVTable sparkle_vtable = {
    0, 0, {update_sparkle, sprite_draw, destroy_sparkle, delete_sparkle, show_sparkle}
};

// 0xfac8 / 0xfb64
void *destroy_medal(void *object)
{
    return object;
}

// 0xfac4 / 0xfb60
void delete_medal(void *object)
{
    game_delete(object);
}

static const SpriteVTable medal_vtable = {
    0, 0, {update_medal, draw_medal, destroy_medal, delete_medal}
};

// 0xfcb8 / 0xfd60
void *destroy_score_panel(void *object)
{
    return object;
}

// 0xfcb4 / 0xfd5c
void delete_panel(void *object)
{
    game_delete(object);
}

static const SpriteVTable panel_vtable = {
    0, 0, {update_score_panel, draw_score_panel, destroy_score_panel, delete_panel}
};

// The pool specializations differ in the activation flags used by their items.
// Both destructors release the items through the deleting-destructor vtable slot.
extern void free(void *ptr);

static inline SpritePool *dispose_pool(SpritePool *pool, const SpriteVTable *vtable)
{
    pool->object.methods = &vtable->calls;
    for (int i = 0; i < pool->count; ++i) {
        Sprite *item = pool->items[i];
        if (item)
            item->methods->delete_object(item);
        pool->items[i] = 0;
    }
    free(pool->items);
    pool->items = 0;
    return pool;
}

// 0x101a8 / 0x10244
SpritePool *dispose_sparkle_pool(SpritePool *pool)
{
    return dispose_pool(pool, &sparkle_pool_vtable);
}

// 0x10190 / 0x1022c
void *destroy_sparkle_pool(void *object)
{
    return dispose_sparkle_pool(object);
}

// 0x10194 / 0x10230
void delete_sparkle_pool(void *object)
{
    dispose_sparkle_pool(object);
    game_delete(object);
}

// 0x1026c / 0x10304
SpritePool *dispose_number_pool(SpritePool *pool)
{
    return dispose_pool(pool, &number_pool_vtable);
}

// 0x10254 / 0x102ec
void *destroy_number_pool(void *object)
{
    return dispose_number_pool(object);
}

// 0x10258 / 0x102f0
void delete_number_pool(void *object)
{
    dispose_number_pool(object);
    game_delete(object);
}

const SpriteVTable sparkle_pool_vtable = {
    0, 0, {update_sparkle_pool, draw_sparkle_pool, destroy_sparkle_pool, delete_sparkle_pool}
};
const SpriteVTable number_pool_vtable = {
    0, 0, {update_node_pool, draw_node_pool, destroy_number_pool, delete_number_pool}
};

// 0x10104 / 0x101a4. Button vtable complete-object destructor.
void *destroy_button(void *object)
{
    return object;
}

// 0x10108 / 0x101a8
void delete_button(void *object)
{
    game_delete(object);
}
