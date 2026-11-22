// Recovered sprite, tween, input and rendering entry points used by the game.
#ifndef FLAPPY_NATIVE_H
#define FLAPPY_NATIVE_H

#include "game_objects.h"

extern AtlasEngine *flap_game;
extern unsigned flap_random_z, flap_random_w;
extern float *flap_sine_table;
extern void *game_new(Size size) __asm__("__Znwm");
extern void game_delete(void *object) __asm__("__ZdlPv");
extern const SpriteVTable sprite_vtable, button_vtable;

void append_quad(AtlasEngine *, int left, int top, int right, int bottom,
                 float u0, float v0, float u1, float v1, float opacity);
void draw_region(AtlasEngine *, const Region *, int x, int y, float opacity);
void draw_region_scaled(AtlasEngine *, int id, int x, int y,
                        float scale_x, float scale_y, float opacity);
void draw_rotated(AtlasEngine *, const Region *, int x, int y, float opacity, int angle);
void font_place(DigitFont *, int x, int y, int alignment, double opacity);
void tween_init(Tween *);
void tween_start(Tween *, float start, float end, int curve, float seconds);
void advance_tween(Tween *);
void engine_schedule(AtlasEngine *, int event, int argument, int delay);
void engine_output(AtlasEngine *, int type, int value);
void engine_output_score(AtlasEngine *, int score);
void engine_pause(AtlasEngine *);
void engine_resume(AtlasEngine *);
void engine_set_touches(AtlasEngine *, const int *x, const int *y, int count);
void start_transition(AtlasEngine *, int mode, int event, float seconds);
void screen_flash(AtlasEngine *, float seconds);
void screen_shake(AtlasEngine *, int distance, float seconds);
void animation_tick(Animation *);
AnimatedSprite *sprite_construct(AnimatedSprite *);
void sprite_place(void *object, int x, int y);
void sprite_select_animation(AnimatedSprite *, int slot, int restart);
void sprite_update_animation(void *object, float elapsed);
void sprite_draw(void *object, AtlasEngine *);
void sprite_set_frames(AnimatedSprite *, const char *prefix, int width, int height,
                       int inset_x, int inset_y);
void sprite_add_animation(AnimatedSprite *, int slot, const char *name, const int *frames,
                          int count, int frames_per_second, int loop);
void *destroy_animated_sprite(void *object);
void button_place(Button *, int x, int y);
void button_set_image(Button *, const char *name);
void button_update(void *object, float elapsed);
void button_draw(void *object, AtlasEngine *);

#endif
