/* Shared 32-bit ABI for the engine's atlas, font and OpenGL code. */
#ifndef FLAPPY_RENDERER_H
#define FLAPPY_RENDERER_H

typedef unsigned long Size;
enum { EngineEventSlots = 50 };
typedef struct {
    int id;
    char *name;
    int width, height;
    float u0, v0, u1, v1;
} Region;

typedef struct FrameSet FrameSet;
typedef struct AtlasEngine AtlasEngine;
typedef struct {
    AtlasEngine *(*destroy)(AtlasEngine *);
    void (*delete_object)(AtlasEngine *);
    void (*frame)(AtlasEngine *, float);
    void (*begin)(AtlasEngine *, int, int);
    void (*end)(AtlasEngine *, int, int, int, int);
    void (*move)(AtlasEngine *, int, int, int, int);
    void (*load)(AtlasEngine *);
    void (*event)(AtlasEngine *, int, int);
    void (*score)(AtlasEngine *, int);
    void (*pause)(AtlasEngine *);
    void (*resume)(AtlasEngine *);
} EngineMethods;
typedef struct {
    unsigned program;
    int position, texcoord, sampler, matrix, alpha;
} ShaderProgram;
typedef struct {
    unsigned framebuffer, texture;
} RenderTarget;
struct AtlasEngine {
    const EngineMethods *methods;
    unsigned renderbuffer, screen_framebuffer;
    RenderTarget scene_target, upscale_target;
    ShaderProgram sprites, blit;
    unsigned short *indices;
    short *positions;
    float *texcoords, *alpha;
    int quads;
    float projection[3][16];
    Region **atlas;
    int field_124;
    int delay[EngineEventSlots], event[EngineEventSlots], argument[EngineEventSlots];
    int queue_write;
    struct Tween *fade;
    int fade_event;
    struct Tween *flash;
    int shake_x, shake_y, shake_distance, shake_ticks;
    float display_scale;
    int texture_scale;
    struct SpritePool *numbers, *sparkles;
    Region *black, *white;
    int mode;
    unsigned char paused;
    char reserved3bd[3];
    int screen_width, screen_height, display_width, display_height;
    int scaled_width, scaled_height;
    float upscale_u, upscale_v, scene_u, scene_v;
    int origin_x, origin_y;
    int touch_x[10], touch_y[10];
    int touch_count, output_count;
    int output_type[20];
    double output_value[20];
    int score;
    int best_score, games_played;
    FrameSet *score_digits;
    struct ScorePanel *panel;
    unsigned atlas_texture;
};

typedef struct {
    Region *glyph[256];
    int advance[256];
    int height, overlap, alignment, x, y;
    char text[256];
    double opacity;
} DigitFont;

struct FrameSet {
    Region **frames;
    int width, height;
};
#define CHECK_ENGINE_OFFSET(member, offset) \
    _Static_assert(__builtin_offsetof(AtlasEngine, member) == (offset), #member)
CHECK_ENGINE_OFFSET(sprites, 0x1c);
CHECK_ENGINE_OFFSET(indices, 0x4c);
CHECK_ENGINE_OFFSET(atlas, 0x120);
CHECK_ENGINE_OFFSET(fade, 0x384);
CHECK_ENGINE_OFFSET(numbers, 0x3a8);
CHECK_ENGINE_OFFSET(scene_u, 0x3e0);
CHECK_ENGINE_OFFSET(touch_x, 0x3f0);
CHECK_ENGINE_OFFSET(output_count, 0x444);
CHECK_ENGINE_OFFSET(output_type, 0x448);
CHECK_ENGINE_OFFSET(atlas_texture, 0x54c);
#undef CHECK_ENGINE_OFFSET

AtlasEngine *engine_construct(AtlasEngine *, int best, int plays, char *atlas, int length);
AtlasEngine *engine_destroy(AtlasEngine *);
FrameSet *init_frameset(FrameSet *, const char *prefix);
DigitFont *init_font(DigitFont *, const char *prefix, int overlap);
DigitFont *destroy_font(DigitFont *);
void draw_text(DigitFont *, AtlasEngine *, const char *format, ...);

Region **find_frames(AtlasEngine *, const char *prefix, int *count);
Region *find_sprite(AtlasEngine *, const char *prefix);
Region *init_region(Region *, const char *, int, int, float, float, float, float);

#endif
