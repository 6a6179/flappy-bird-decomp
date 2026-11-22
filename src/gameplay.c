// Source reconstruction from the native game code. Function comments give armv7
// virtual addresses. Engine calls and global addresses are labeled by their use.
#include "gameplay.h"
#include "scene.h"

extern int rand(void);

// 0x108a8. Sprite colors have weights 6:2:2.
void bird_reset(Bird *bird) {
    sprite_place(&bird->sprite, 80, 246);
    bird->angle = 0;
    bird->velocity = 0;
    bird->gravity = 1;
    bird->angular_acceleration = 0.4f;
    bird->hit = 0;
    bird->hovering = 1;
    bird->phase = 0;
    sprite_select_animation(&bird->sprite, 1, 1);
    int roll = rand() % 10;
    if (roll <= 5)
        bird->color = 0;
    else if (roll <= 7)
        bird->color = 1;
    else
        bird->color = 2;
}

// 0x11194
void bird_flap(Bird *bird) {
    if (bird->hovering)
        bird->hovering = 0;
    if (bird->sprite.y < 0 || bird->hit)
        return;
    sprite_select_animation(&bird->sprite, 0, 1);
    bird->velocity = -5;
    bird->gravity = 0.3f;
    bird->angular_velocity = -10;
    bird->angular_acceleration = 0.4f;
    engine_schedule(flap_game, EventWingSound, 0, 5);
}

// 0x1134c. One physics step per call. The vertical position is an integer.
void bird_update(void *object, float elapsed) {
    Bird *bird = object;
    sprite_update_animation(&bird->sprite, elapsed);
    if (!bird->hovering) {
        bird->bob_y = 0;
        bird->velocity += bird->gravity;
        if (bird->velocity > 8)
            bird->velocity = 8;
        bird->sprite.y = (int)((float)bird->sprite.y + bird->velocity);
        if (bird->sprite.y > GroundY - bird->sprite.height) {
            bird->sprite.y = GroundY - bird->sprite.height;
            bird->velocity = 0;
            bird->gravity = 0;
        }
        bird->angle += bird->angular_velocity;
        bird->angular_velocity += bird->angular_acceleration;
        if (bird->angle < -20)
            bird->angle = -20;
        else if (bird->angle > 90)
            bird->angle = 90;
    } else {
        bird->phase += 8;
        if (bird->phase == 360)
            bird->phase = 0;
        bird->bob_y = 4 * flap_sine_table[bird->phase];
    }
}

// 0x11434
void bird_draw(void *object, AtlasEngine *engine) {
    Bird *bird = object;
    if (!bird->sprite.visible)
        return;
    int base = 3 * bird->color;
    Region *image = bird->sprite.frames[base + 1];
    if (bird->sprite.animation && !bird->sprite.animation->stopped)
        image = bird->sprite.frames[base + bird->sprite.animation->frame];
    draw_rotated(engine, image, bird->sprite.x - bird->sprite.inset_x,
                 (int)((float)(bird->sprite.y - bird->sprite.inset_y) + bird->bob_y), 1, (int)bird->angle);
}

// 0x11104. Touches within a 20-unit margin of the pause button never flap.
void game_touch_begin(AtlasEngine *engine, int x, int y) {
    Game *game = (Game *)engine;
    if (game->title_screen)
        return;
    Button *pause = game->pause;
    if (x >= pause->x - 20 && x <= pause->x + pause->width + 20 &&
        y >= pause->y - 20 && y <= pause->y + pause->height + 20)
        return;
    Bird *bird = game->bird;
    if (!bird->hovering) {
        if (game->speed > 0)
            bird_flap(bird);
    } else if (game->ready->object.active && game->ready->stage == READY_WAITING_FOR_TAP) {
        ReadyOverlay *ready = game->ready;
        ready->stage = READY_FADING_OUT;
        tween_start(ready->tween, 1, 0, EASE_LINEAR, 0.5f);
        bird = game->bird;
        bird->hovering = 0;
        bird_flap(bird);
    }
}

// Register shifts in the generator are signed; the multiply and add wrap at 32 bits.
static int next_pipe_y(void) {
    flap_random_z = 36969u * (flap_random_z & 65535u) + ((int)flap_random_z >> 16);
    flap_random_w = 18000u * (flap_random_w & 65535u) + ((int)flap_random_w >> 16);
    unsigned sample = (flap_random_z << 16) + flap_random_w;
    if ((int)sample < 0)
        sample = 0u - sample;
    return 180 + (int)sample % 180;
}

static void scroll_pipes(Game *game) {
    game->pipe_x[0] -= game->speed;
    game->pipe_x[1] -= game->speed;
    game->pipe_x[2] -= game->speed;

    int first = game->pipe_x[0];
    int bird_x = game->bird->sprite.x;
    if (game->speed > 0 && game->warmup <= 0 && (first == bird_x || first == bird_x - 1)) {
        ++game->engine.score;
        engine_output(&game->engine, PlayPoint, 0);
    }
    Region *pipe = game->pipe_up;
    if (game->pipe_x[0] >= -pipe->width)
        return;
    game->pipe_x[0] = game->pipe_x[1];
    game->pipe_y[0] = game->pipe_y[1];
    game->pipe_x[1] = game->pipe_x[2];
    game->pipe_y[1] = game->pipe_y[2];
    game->pipe_x[2] = game->pipe_x[1] + game->pipe_spacing + pipe->width;
    game->pipe_y[2] = next_pipe_y();
    if (game->warmup > 0 && --game->warmup == 0) {
        game->pipe_x[1] = -pipe->width;
        game->pipe_x[0] = -pipe->width;
    }
}

static inline __attribute__((always_inline)) void collide(Game *game, _Bool pipe_hit, _Bool set_hit_flag) {
    screen_flash(&game->engine, 1);
    screen_shake(&game->engine, 4, 0.5f);
    if (set_hit_flag)
        game->bird->hit = 1;
    game->speed = 0;
    engine_output(&game->engine, PlayHit, 0);
    if (pipe_hit)
        engine_schedule(&game->engine, EventDieSound, 0, 500);
    engine_schedule(&game->engine, EventGameOver, (int)(__INTPTR_TYPE__)game->engine.panel, 1000);
}

// These empty compiler constraints reproduce Xcode 5.0.2 register allocation
// in the original frame loop. Editable builds use the ordinary C expressions.
#ifdef FLAP_MATCH_FRAME
#define FRAME_REGISTER(name) __asm__(name)
#define FRAME_UPPER_PIPE(image) __asm__ volatile ("" : : "r"(image))
#define FRAME_PIPE_EDGE(left, bird_y) __asm__ volatile ("" : "+r"(left) : "r"(bird_y))
#define FRAME_OPACITY() __asm__ volatile ("" : : : "r5")
#else
#define FRAME_REGISTER(name)
#define FRAME_UPPER_PIPE(image) ((void)0)
#define FRAME_PIPE_EDGE(left, bird_y) ((void)0)
#define FRAME_OPACITY() ((void)0)
#endif

static inline __attribute__((always_inline)) void check_pipe_pair(Game *game, int i) {
    AnimatedSprite *bird = &game->bird->sprite;
    int y = game->pipe_y[i];
    int bird_x = bird->x;
    int left = game->pipe_x[i];
    int bird_right = bird_x + bird->width;
    int height = game->pipe_down->height;

    if (bird_right < left)
        return;
    register Region *upper FRAME_REGISTER("r5") = game->pipe_down;
    if (bird_x <= left + upper->width) {
        FRAME_UPPER_PIPE(upper);
        register int bird_y FRAME_REGISTER("r6") = bird->y;
        if (bird_y + bird->height >= y - PipeGap - height &&
            bird_y <= y - PipeGap) {
            // The first upper pipe leaves the bird's hit flag alone.
            collide(game, 1, i != 0);
            return;
        }
        FRAME_PIPE_EDGE(left, bird_y);
        if (bird_right < left)
            return;
    }
    if (bird_x <= left + game->pipe_up->width &&
        bird->y + bird->height >= y && bird->y <= y + game->pipe_up->height)
        collide(game, 1, 1);
}

static void check_collisions(Game *game) {
    Bird *bird = game->bird;
    if (bird->sprite.y >= GroundY - bird->sprite.height && game->speed > 0)
        collide(game, 0, 0);
    if (!game->bird->hit && game->warmup <= 0 && game->speed > 0) {
        check_pipe_pair(game, 0);
        check_pipe_pair(game, 1);
    }
}

static inline void update_sprite(Sprite *sprite, float elapsed) {
    sprite->methods->update(sprite, elapsed);
}

static inline void draw_sprite(Sprite *sprite, Game *game) {
    sprite->methods->draw(sprite, &game->engine);
}

static inline __attribute__((always_inline)) void draw_pipe_pair(Game *game, int i) {
    draw_region(&game->engine, game->pipe_up, game->pipe_x[i], game->pipe_y[i], 1);
    draw_region(&game->engine, game->pipe_down, game->pipe_x[i],
                game->pipe_y[i] - PipeGap - game->pipe_down->height, 1);
}

static void draw_course(Game *game, float elapsed) {
    check_collisions(game);
    // Collision callbacks can update the controller before it draws the pipes.
    const volatile int *warmup = &game->warmup;
    if (*warmup <= 0) {
        draw_pipe_pair(game, 0);
        FRAME_OPACITY();
        draw_pipe_pair(game, 1);
        if (game->pipe_x[2] < ScreenWidth)
            draw_pipe_pair(game, 2);
    }
    ScorePanel *panel = game->engine.panel;
    if (panel->object.active && panel->stage == PANEL_FINISHED && !game->play->object.active) {
        button_place(game->play, (272 - game->play->width - game->scores->width) >> 1, 340);
        button_place(game->scores, game->play->x + game->play->width + 16, 340);
    }
    if (game->game_over->object.active) {
        update_sprite(&game->game_over->object, elapsed);
        draw_sprite(&game->game_over->object, game);
    } else {
        font_place(game->score_font, 144, 100, 6, 1.0);
        draw_text(game->score_font, &game->engine, "%u", (unsigned)game->engine.score);
    }
}

static inline __attribute__((always_inline)) void draw_bird_and_land(Game *game) {
    Bird *bird = game->bird;
    bird->sprite.object.methods->draw(bird, &game->engine);
    draw_region(&game->engine, game->land, game->land_x, ScreenHeight - game->land->height, 1);
}

// 0x10b18. The original updates state while drawing each frame.
void game_frame(AtlasEngine *engine, float elapsed) {
    Game *game = (Game *)engine;
    draw_region(&game->engine, game->background, 0, 0, 1);
    game->land_x -= game->speed;
    if (game->land_x < -23)
        game->land_x = 0;
    if (!game->bird->hovering)
        scroll_pipes(game);
    game->bird->sprite.object.methods->update(game->bird, elapsed);
    if (!game->title_screen) {
        draw_course(game, elapsed);
        draw_bird_and_land(game);
    } else {
        draw_region(&game->engine, game->title, (ScreenWidth - game->title->width) >> 1, 150, 1);
        FRAME_OPACITY();
        game->bird->sprite.x = (ScreenWidth - game->bird->sprite.width) >> 1;
        game->bird->sprite.y = game->title->height + 170;
        draw_bird_and_land(game);
    }
    if (game->ready->object.active) {
        update_sprite(&game->ready->object, elapsed);
        draw_sprite(&game->ready->object, game);
    }
    if (game->title_screen) {
        draw_region(&game->engine, game->copyright, (ScreenWidth - game->copyright->width) >> 1,
                   432 - game->copyright->height, 1);
    }
    if (!game->play->object.active)
        return;
    update_sprite(&game->play->object, elapsed);
    draw_sprite(&game->play->object, game);
    update_sprite(&game->scores->object, elapsed);
    draw_sprite(&game->scores->object, game);
    if (game->play->released) {
        start_transition(&game->engine, 1, EventStartRound, 0.5f);
        engine_output(&game->engine, PlaySwoosh, 0);
    }
    if (game->scores->released) {
        engine_output(&game->engine, ShowLeaderboard, 0);
        engine_output(&game->engine, PlaySwoosh, 0);
    }
    if (game->rate->object.active) {
        update_sprite(&game->rate->object, elapsed);
        draw_sprite(&game->rate->object, game);
        if (game->rate->released)
            engine_output(&game->engine, OpenAppStore, 0);
    }
}

// 0x11204. The copyright action checks a vertical band on the title screen.
void game_touch_end(AtlasEngine *engine, int old_x, int old_y, int x, int y) {
    Game *game = (Game *)engine;
    (void)old_x;
    (void)old_y;
    (void)x;
    if (game->title_screen && y >= 482 - game->copyright->height && y <= 482)
        engine_schedule(&game->engine, EventCopyright, 0, 5);
}

static inline void hide_sprite(Sprite *sprite) {
    sprite->active = 0;
    sprite->visible = 0;
}

// 0x10918
void game_reset(Game *game) {
    if (rand() % 10 <= 5)
        game->background = game->day;
    else
        game->background = game->night;
    SpritePool *pool = game->engine.sparkles;
    for (int i = 0; i < pool->count; ++i) {
        AnimatedSprite *sprite = pool->items[i];
        sprite->active = 0;
        sprite->visible = 0;
    }
    button_place(game->play, (272 - game->play->width - game->scores->width) >> 1, 340);
    button_place(game->scores, game->play->x + game->play->width + 16, 340);
    button_place(game->rate, (ScreenWidth - game->rate->width) >> 1, 270);
    game->ready->object.active = 0;
    game->game_over->object.active = 0;
    ScorePanel *panel = game->engine.panel;
    hide_sprite(&panel->object);
    hide_sprite(&game->ok->object);
    hide_sprite(&game->menu->object);
    hide_sprite(&game->pause->object);
    hide_sprite(&game->resume->object);
    hide_sprite(&game->share->object);
    game->title_screen = 1;
    game->land_x = 0;
    bird_reset(game->bird);
    game->speed = 2;
    game->warmup = 1;
    game->engine.score = 0;
}

// 0x10a18. Handles the engine's delayed event numbers.
void game_handle_event(AtlasEngine *engine, int event, int argument) {
    Game *game = (Game *)engine;
    (void)argument;
    switch (event) {
    case EventGameOver:
        game->reported_score = 1;
        engine_output(&game->engine, ReportScore, game->engine.score);
        show_game_over(game->game_over);
        engine_output(&game->engine, RoundEnded, 0);
        break;
    case EventDieSound:
        engine_output(&game->engine, PlayDie, 0);
        break;
    case EventWingSound:
        engine_output(&game->engine, PlayWing, 0);
        break;
    case EventStartRound: {
        game_reset(game);
        game->play->object.active = 0;
        game->scores->object.active = 0;
        game->rate->object.active = 0;
        game->title_screen = 0;
        start_transition(&game->engine, 0, 0, 0.5f);
        game->land_x = 0;
        bird_reset(game->bird);
        game->speed = 2;
        game->warmup = 1;
        game->engine.score = 0;
        ReadyOverlay *ready = game->ready;
        ready->object.active = 1;
        ready->object.visible = 1;
        tween_start(ready->tween, 0, 1, EASE_LINEAR, 0.5f);
        ready->stage = READY_FADING_IN;
        ++game->engine.games_played;
        engine_output(&game->engine, RoundStarted, 0);
        break;
    }
    case EventTitleScreen:
        game_reset(game);
        game->bird->color = 0;
        start_transition(&game->engine, 0, 0, 0.5f);
        engine_output(&game->engine, ConfigureTitle, 0);
        break;
    case EventCopyright:
        engine_output(&game->engine, CopyrightTapped, 0);
        break;
    }
}
