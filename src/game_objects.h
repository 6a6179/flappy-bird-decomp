// Object layouts shared by the game, its renderer, and its score and title screens.
#ifndef FLAPPY_GAME_OBJECTS_H
#define FLAPPY_GAME_OBJECTS_H

#include "renderer.h"

typedef struct Medal Medal;
typedef struct ScorePanel ScorePanel;

enum { ScreenWidth = 288, ScreenHeight = 512 };
enum { EASE_LINEAR = 0, EASE_QUINT_OUT = 11 };

typedef struct Tween {
    int duration_ticks, tick;
    float step, value, progress, start, end, distance;
    int curve;
    _Bool finished;
} Tween;

typedef enum {
    PANEL_SLIDING_IN, PANEL_COUNTING_SCORE, PANEL_FINISHED
} ScorePanelPhase;

typedef enum {
    READY_FADING_IN, READY_WAITING_FOR_TAP, READY_FADING_OUT
} ReadyPhase;

typedef enum {
    GAME_OVER_FADING_IN, GAME_OVER_SHOWING_PANEL, GAME_OVER_FINISHED
} GameOverPhase;

typedef struct {
    void (*update)(void *object, float elapsed);
    void (*draw)(void *object, AtlasEngine *engine);
    void *(*destroy)(void *object);
    void (*delete_object)(void *object);
    void (*place)(void *object, int x, int y);
} SpriteMethods;

typedef struct Sprite {
    const SpriteMethods *methods;
    _Bool active, visible;
} Sprite;

typedef struct {
    Sprite object;
    Region *image;
    int x, y, width, height;
    _Bool down, pressed, released, touched;
} Button;

typedef struct {
    int index;
    int *frames;
    int elapsed, interval, count, slot, frame;
    _Bool stopped;
    unsigned char repeat;  // sprite_add_animation stores the low byte of its loop argument.
    char reserved_1e[6];
    char name[20];
} Animation;

typedef struct {
    Sprite object;
    Animation *animations[10];
    int x, y;
    int rotation;
    int width, height, inset_x, inset_y;
    float alpha;
    Animation *animation;
    _Bool flip_x, flip_y, active, visible;
    int image_count;
    Region **frames;
} AnimatedSprite;

typedef struct {
    int offset_to_top;
    const void *type_info;
    SpriteMethods calls;
} SpriteVTable;

struct Medal {
    Sprite object;
    Region **frames;
    int x, y, width, height, frame, until_sparkle;
};

struct ScorePanel {
    Sprite object;
    int x, y, width, height, shown_score, best;
    int bronze, silver, gold, platinum;
    ScorePanelPhase stage;
    int score;
    _Bool new_best;
    int final_y;
    Medal *medal;
    Tween *tween;
    Region *new_badge, *background;
    FrameSet *digits;
};

typedef struct {
    Sprite object;
    Tween *tween;
    Region *ready, *tutorial;
    ReadyPhase stage;
} ReadyOverlay;

typedef struct {
    Sprite object;
    Tween *tween;
    Region *title;
    int offset_y;
    float velocity, gravity;
    GameOverPhase stage;
} GameOverOverlay;

typedef struct SpritePool {
    Sprite object;
    void **items;
    int count, next;
} SpritePool;

#if __SIZEOF_POINTER__ == 4
_Static_assert(sizeof(Tween) == 0x28, "Tween");
_Static_assert(sizeof(AnimatedSprite) == 0x60, "AnimatedSprite");
_Static_assert(sizeof(SpritePool) == 0x14, "SpritePool");
_Static_assert(sizeof(ReadyOverlay) == 0x18, "ReadyOverlay");
_Static_assert(sizeof(GameOverOverlay) == 0x20, "GameOverOverlay");
_Static_assert(sizeof(ScorePanel) == 0x54, "ScorePanel");
#endif

#endif
