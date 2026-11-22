// Flappy Bird (bundle version 1.2), inferred names and the field layout of the 32-bit iOS slices.
#ifndef FLAP_GAMEPLAY_H
#define FLAP_GAMEPLAY_H

#include "game_objects.h"
#include "view_commands.h"

typedef struct Game Game;

enum GameEvent {
    EventGameOver = 2, EventDieSound, EventWingSound, EventStartRound,
    EventTitleScreen, EventCopyright
};

enum { GroundY = 400, PipeGap = 96 };

typedef struct {
    AnimatedSprite sprite;
    float angle, angular_velocity, angular_acceleration;
    float reserved_6c;
    float velocity, gravity;
    _Bool hit, hovering;
    int phase;
    float bob_y;
    int color;
} Bird;

struct Game {
    AtlasEngine engine;
    _Bool title_screen, reported_score;
    Bird *bird;
    Button *play, *ok, *pause, *resume, *menu, *scores, *share, *rate;
    FrameSet *numbers;
    Region *background, *day, *night, *forest, *land, *pipe_up, *pipe_down;
    Region *title, *copyright;
    int land_x, pipe_y[3], pipe_x[3], pipe_spacing, warmup;
    ReadyOverlay *ready;
    GameOverOverlay *game_over;
    DigitFont *score_font;
    int speed;
};

// Verify the offsets used by the executable wherever ARM pointers are 32 bits.
#if __SIZEOF_POINTER__ == 4
_Static_assert(__builtin_offsetof(Bird, sprite.x) == 0x30, "Bird.x");
_Static_assert(__builtin_offsetof(Bird, velocity) == 0x70, "Bird.velocity");
_Static_assert(__builtin_offsetof(Bird, color) == 0x84, "Bird.color");
_Static_assert(__builtin_offsetof(Game, engine.score) == 0x538, "Game.score");
_Static_assert(__builtin_offsetof(Game, bird) == 0x554, "Game.bird");
_Static_assert(__builtin_offsetof(Game, speed) == 0x5d0, "Game.speed");
_Static_assert(__builtin_offsetof(Button, released) == 0x1e, "Button.released");
#endif

void bird_reset(Bird *bird);
void bird_flap(Bird *bird);
void bird_update(void *object, float elapsed);
void bird_draw(void *object, AtlasEngine *engine);
void game_frame(AtlasEngine *engine, float elapsed);
void game_reset(Game *game);
void game_handle_event(AtlasEngine *engine, int event, int argument);
Game *viewGameConstruct(Game *, int best, int plays, char *atlas, int length);
void game_touch_end(AtlasEngine *engine, int old_x, int old_y, int x, int y);
void game_touch_begin(AtlasEngine *engine, int x, int y);

#endif
