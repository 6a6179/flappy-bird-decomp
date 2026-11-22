#include "scene.h"
#include "view_commands.h"

static const SpriteVTable ready_vtable;
static const SpriteVTable game_over_vtable;

static Tween *new_tween(void)
{
    Tween *tween = game_new(sizeof(*tween));
    tween_init(tween);
    return tween;
}

// 0x102ec / 0x10384
ReadyOverlay *init_ready_overlay(ReadyOverlay *overlay)
{
    overlay->object.active = 0;
    overlay->object.visible = 0;
    overlay->object.methods = &ready_vtable.calls;
    overlay->ready = find_sprite(flap_game, "text_ready");
    overlay->tutorial = find_sprite(flap_game, "tutorial");
    overlay->tween = new_tween();
    return overlay;
}

// 0x10350 / 0x103e8
void update_ready_overlay(void *object, float dt)
{
    ReadyOverlay *overlay = object;
    (void)dt;
    advance_tween(overlay->tween);
    switch (overlay->stage) {
    case READY_FADING_IN:
        if (overlay->tween->finished)
            overlay->stage = READY_WAITING_FOR_TAP;
        break;
    case READY_WAITING_FOR_TAP:
        break;
    case READY_FADING_OUT:
        if (overlay->tween->finished) {
            overlay->object.active = 1;
            overlay->object.visible = 0;
        }
        break;
    }
}

// 0x1038c / 0x1041c
void draw_ready_overlay(void *object, AtlasEngine *renderer)
{
    ReadyOverlay *overlay = object;
    draw_region(renderer, overlay->ready, (ScreenWidth - overlay->ready->width) >> 1, 146, overlay->tween->value);
    draw_region(renderer, overlay->tutorial, (ScreenWidth - overlay->tutorial->width) >> 1, 220, overlay->tween->value);
}

// 0x103dc / 0x10468
GameOverOverlay *init_game_over_overlay(GameOverOverlay *overlay)
{
    overlay->object.active = 0;
    overlay->object.visible = 0;
    overlay->object.methods = &game_over_vtable.calls;
    overlay->title = find_sprite(flap_game, "text_game_over");
    overlay->tween = new_tween();
    return overlay;
}

// 0x10430 / 0x104bc
void show_game_over(GameOverOverlay *overlay)
{
    overlay->object.active = overlay->object.visible = 1;
    tween_start(overlay->tween, 0, 1, EASE_QUINT_OUT, 1.0f);
    overlay->offset_y = -1;
    overlay->velocity = -2;
    overlay->gravity = 0.25f;
    overlay->stage = GAME_OVER_FADING_IN;
    engine_output(flap_game, PlaySwoosh, 0);
}

// 0x10488 / 0x10510
void update_game_over(void *object, float dt)
{
    GameOverOverlay *overlay = object;
    (void)dt;
    advance_tween(overlay->tween);
    if (overlay->offset_y < 0) {
        overlay->offset_y = (int)(overlay->offset_y + overlay->velocity);
        overlay->velocity += overlay->gravity;
    } else {
        overlay->offset_y = 0;
    }
    switch (overlay->stage) {
    case GAME_OVER_FADING_IN:
        if (overlay->tween->finished) {
            overlay->stage = GAME_OVER_SHOWING_PANEL;
            show_score_panel(flap_game->panel, flap_game->score, flap_game->best_score,
                             10, 20, 30, 40);
            engine_output(flap_game, PlaySwoosh, 0);
        }
        break;
    case GAME_OVER_SHOWING_PANEL: {
        const ScorePanel *panel = flap_game->panel;
        if (panel->stage == PANEL_FINISHED)
            overlay->stage = GAME_OVER_FINISHED;
        break;
    }
    case GAME_OVER_FINISHED:
        break;
    }
}

// 0x10540 / 0x105c8
void draw_game_over(void *object, AtlasEngine *renderer)
{
    GameOverOverlay *overlay = object;
    draw_region(renderer, overlay->title, (ScreenWidth - overlay->title->width) >> 1, 130 + overlay->offset_y,
                    overlay->tween->value);
}

// 0x1034c / 0x103e4
void *destroy_ready(void *object)
{
    return object;
}

// 0x10348 / 0x103e0
void delete_ready(void *object)
{
    game_delete(object);
}

static const SpriteVTable ready_vtable = {
    0, 0, {update_ready_overlay, draw_ready_overlay, destroy_ready, delete_ready}
};

// 0x1042c / 0x104b8
void *destroy_game_over(void *object)
{
    return object;
}

// 0x10428 / 0x104b4
void delete_game_over(void *object)
{
    game_delete(object);
}

static const SpriteVTable game_over_vtable = {
    0, 0, {update_game_over, draw_game_over, destroy_game_over, delete_game_over}
};
