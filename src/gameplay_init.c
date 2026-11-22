// Object construction and virtual dispatch tables reconstructed from __DATA,__const.
// The two initial words of each table are the offset-to-top and RTTI slots.
#include "gameplay.h"
#include "scene.h"

extern int rand(void);

typedef struct {
    void *(*destroy)(void *);
    void (*delete_object)(void *);
} FontMethods;

typedef struct {
    const FontMethods *methods;
    DigitFont font;
    int field_920, field_924;
} GameFont;

// 0x105b0 and 0x1059c
AtlasEngine *game_destroy(AtlasEngine *engine) { return engine_destroy(engine); }
void game_delete_object(AtlasEngine *engine) {
    engine_destroy(engine);
    game_delete(engine);
}

// 0x105cc and 0x105b4
void *game_font_destroy(void *object) {
    GameFont *font = object;
    destroy_font(&font->font);
    return object;
}
void game_font_delete(void *object) {
    GameFont *font = object;
    destroy_font(&font->font);
    game_delete(object);
}

const struct {
    int offset;
    void *type_info;
    FontMethods calls;
} game_font_vtable = {0, 0, {game_font_destroy, game_font_delete}};

// 0x11348 and 0x11334
void *bird_destroy(void *bird) { return destroy_animated_sprite(bird); }
void bird_delete(void *bird) {
    destroy_animated_sprite(bird);
    game_delete(bird);
}

const SpriteVTable bird_vtable = {0, 0, {bird_update, bird_draw, bird_destroy, bird_delete, sprite_place}};

static const int bird_frames[12] = {0, 1, 2, 1, 0, 1, 2, 1, 0, 1, 2, 1};

// 0x11234. The same sequence is copied into both animation slots.
Bird *bird_construct(Bird *bird) {
    sprite_construct(&bird->sprite);
    bird->sprite.object.methods = &bird_vtable.calls;
    sprite_set_frames(&bird->sprite, "bird", 20, 20, 14, 14);
    int frames[12];
    __builtin_memcpy(frames, bird_frames, sizeof(frames));
    sprite_add_animation(&bird->sprite, 0, "flap", frames, 12, 30, 0);
    sprite_add_animation(&bird->sprite, 1, "auto", frames, 12, 10, 1);
    bird->hovering = 1;
    bird->color = rand() % 3;
    return bird;
}

static inline void new_button(Button **slot, const char *image) {
    Button *button = game_new(sizeof(*button));
    button->object.active = 0;
    button->object.visible = 0;
    button->object.methods = &button_vtable.calls;
    *slot = button;
    button_set_image(button, image);
}

// 0x105dc
void game_load_assets(AtlasEngine *engine) {
    Game *game = (Game *)engine;
    GameFont *font = game_new(sizeof(*font));
    init_font(&font->font, "font", 4);
    font->methods = &game_font_vtable.calls;
    font->field_920 = font->field_924 = 0;
    game->score_font = font ? &font->font : 0;
    new_button(&game->play, "button_play");
    new_button(&game->scores, "button_score");
    new_button(&game->ok, "button_ok");
    new_button(&game->menu, "button_menu");
    new_button(&game->pause, "button_pause");
    new_button(&game->resume, "button_resume");
    new_button(&game->share, "button_share");
    new_button(&game->rate, "button_rate");
    FrameSet *numbers = game_new(sizeof(*numbers));
    init_frameset(numbers, "number_score");
    game->numbers = numbers;
    game->day = find_sprite(engine, "bg_day");
    game->night = find_sprite(engine, "bg_night");
    game->forest = find_sprite(engine, "bg_forest");
    game->land = find_sprite(engine, "land");
    game->pipe_up = find_sprite(engine, "pipe_up");
    game->pipe_down = find_sprite(engine, "pipe_down");
    game->title = find_sprite(engine, "title");
    game->copyright = find_sprite(engine, "brand_copyright");
    Region *pipe = game->pipe_up;
    game->pipe_spacing = (ScreenWidth - 3 * pipe->width / 2) / 2;
    game->pipe_x[0] = game->pipe_spacing - (pipe->width >> 1);
    game->pipe_y[0] = 274;
    game->pipe_x[1] = game->pipe_x[0] + game->pipe_spacing + pipe->width;
    game->pipe_y[1] = 274;
    game->pipe_x[2] = game->pipe_x[1] + game->pipe_spacing + pipe->width;
    game->pipe_y[2] = 274;
    Bird *bird = game_new(sizeof(Bird));
    bird_construct(bird);
    game->bird = bird;
    bird_reset(bird);
    ReadyOverlay *ready = game_new(sizeof(ReadyOverlay));
    init_ready_overlay(ready);
    game->ready = ready;
    GameOverOverlay *over = game_new(sizeof(*over));
    init_game_over_overlay(over);
    game->game_over = over;
    game->title_screen = 1;
    engine_schedule(engine, EventTitleScreen, (int)(__INTPTR_TYPE__)game, 1);
}

// Game callbacks at 0x11230, 0x110fc and 0x11100.
void game_touch_move(AtlasEngine *engine, int old_x, int old_y, int x, int y) {
    (void)engine; (void)old_x; (void)old_y; (void)x; (void)y;
}
void game_suspend(AtlasEngine *engine) { (void)engine; }
void game_resume(AtlasEngine *engine) { (void)engine; }

const struct {
    int offset;
    void *type_info;
    EngineMethods calls;
} game_vtable = {0, 0, {game_destroy, game_delete_object, game_frame, game_touch_begin, game_touch_end,
                        game_touch_move, game_load_assets, game_handle_event, engine_output_score,
                        game_suspend, game_resume}};

// 0x10574
Game *viewGameConstruct(Game *game, int best, int plays, char *atlas, int length) {
    engine_construct(&game->engine, best, plays, atlas, length);
    game->engine.methods = &game_vtable.calls;
    return game;
}
