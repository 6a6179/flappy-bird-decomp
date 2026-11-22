// Score, medal, and game-over widgets used by the frame driver and gameplay.
#ifndef FLAPPY_SCENE_H
#define FLAPPY_SCENE_H

#include "native.h"

extern const SpriteVTable number_pool_vtable, sparkle_pool_vtable;
void init_number_pool(SpritePool *, int count);
void init_sparkle_pool(SpritePool *, int count);
ScorePanel *init_score_panel(ScorePanel *);
void show_score_panel(ScorePanel *, int score, int best, int bronze, int silver,
                      int gold, int platinum);
void update_score_panel(void *object, float elapsed);
void draw_score_panel(void *object, AtlasEngine *);
ReadyOverlay *init_ready_overlay(ReadyOverlay *);
GameOverOverlay *init_game_over_overlay(GameOverOverlay *);
void show_game_over(GameOverOverlay *);
void draw_number(FrameSet *, AtlasEngine *, int value, int right, int y,
                 _Bool zero_fill, int places);

#endif
