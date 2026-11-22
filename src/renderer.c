/* Original sprite atlas reader and bitmap-font renderer. Address pairs identify
 * the entry in ARMv7 / ARMv7s. The renderer consumes the bundled atlas.txt. */

#include "scene.h"

extern Size strlen(const char *);
extern void *malloc(Size);
extern void *memset(void *, int, Size);
extern int printf(const char *, ...);
extern int sscanf(const char *, const char *, ...);
extern int vsprintf(char *, const char *, __builtin_va_list);

/* Coalesce the direct engine pointer reference with the scene translation unit. */
AtlasEngine *flap_game __attribute__((weak, visibility("hidden")));
/* 0xcc54 / 0xcdfc. Glyphs are numbered with decimal character codes
 * inside their atlas names. A space has the advance of the digit zero. */
DigitFont *init_font(DigitFont *font, const char *prefix, int overlap)
{
    int count, character;
    Region **regions = find_frames(flap_game, prefix, &count);
    memset(font->glyph, 0, sizeof(font->glyph));
    for (int i = 0; i < count; ++i) {
        const char *digits = regions[i]->name + strlen(prefix);
        while (*digits < '0' || *digits > '9')
            ++digits;
        sscanf(digits, "%d", &character);
        font->glyph[character] = regions[i];
        Region *glyph = regions[i];
        font->advance[character] = glyph->width;
        font->height = font->height > glyph->height ? font->height : glyph->height;
        printf("Number: %s %d\r\n", glyph->name, character);
    }
    font->advance[' '] = font->advance['0'];
    font->overlap = overlap;
    return font;
}

/* 0xd908 / 0xdaac */
FrameSet *init_frameset(FrameSet *set, const char *prefix)
{
    int count;
    set->frames = find_frames(flap_game, prefix, &count);
    set->width = set->frames[0]->width;
    set->height = set->frames[0]->height;
    return set;
}

/* 0xcdc0 / 0xcf68. The original mutates the anchor during alignment, then
 * emits one quad per glyph with the adjusted X/Y and the stored opacity. */
void draw_text(DigitFont *font, AtlasEngine *renderer, const char *format, ...)
{
    __builtin_va_list args;
    __builtin_va_start(args, format);
    vsprintf(font->text, format, args);
    __builtin_va_end(args);

    int length = (int)strlen(font->text);
    int width = 0;
    for (int i = 0; i < length; ++i)
        width += font->advance[(int)font->text[i]] - font->overlap;
    width += 2;
    int height = font->height;
    if (font->alignment & 2)
        font->x -= width / 2;
    else if (font->alignment & 1)
        font->x -= width;
    if (font->alignment & 4)
        font->y -= height / 2;
    else if (font->alignment & 8)
        font->y -= height;

    int x = font->x, y = font->y;
    for (int i = 0; i < length; ++i) {
        Region *glyph = font->glyph[(int)font->text[i]];
        if (glyph)
            append_quad(renderer, x, y, x + glyph->width, y + glyph->height,
                        glyph->u0, glyph->v0, glyph->u1, glyph->v1, font->opacity);
        x += font->advance[(int)font->text[i]] - font->overlap;
    }
}

/* 0xcda0 / 0xcf48. The font borrows its glyphs from the engine. */
DigitFont *destroy_font(DigitFont *font)
{
    return font;
}

extern void free(void *);
extern int puts(const char *);
extern void glDeleteTextures(int, const unsigned *);
extern void glDeleteBuffers(int, const unsigned *);
extern void glDeleteProgram(unsigned);

/* The first two vtable words are the 32-bit Itanium ABI header. */
typedef struct { int offset; void *type_info; EngineMethods calls; } EngineTable;
static const EngineTable engine_vtable;

/* 0xcfb8 / 0xd158. Builds the indexed quad batch and parses atlas.txt
 * records. The final two columns of the file are extents. Regions store
 * the opposite corner so drawing can send four UV bounds directly to GL. */
AtlasEngine *engine_construct(AtlasEngine *engine, int best, int plays, char *atlas, int length)
{
    engine->methods = &engine_vtable.calls;
    engine->mode = 1;
    engine->best_score = best;
    engine->games_played = plays;
    unsigned short *indices = malloc(256 * 6 * sizeof(*indices));
    engine->indices = indices;
    engine->positions = malloc(256 * 8 * sizeof(*engine->positions));
    engine->texcoords = malloc(256 * 8 * sizeof(*engine->texcoords));
    engine->alpha = malloc(256 * 4 * sizeof(*engine->alpha));
    for (int i = 0; i < 256; ++i) {
        unsigned short *triangle = indices + 6 * i;
        unsigned short base = 4 * i;
        triangle[0] = base;
        triangle[1] = base + 1;
        triangle[2] = base + 2;
        triangle[3] = base;
        triangle[4] = base + 2;
        triangle[5] = base + 3;
    }
    engine->atlas = malloc(512 * sizeof(*engine->atlas));
    memset(engine->atlas, 0, 512 * sizeof(*engine->atlas));

    char line[256], name[64];
    char *cursor = line;
    for (int i = 0; i < length; ++i) {
        char ch = atlas[i];
        if (ch != '\n' && ch != '\r' && ch != '\0') {
            *cursor++ = ch;
            continue;
        }
        *cursor = 0;
        if (strlen(line) > 1) {
            float u, v, du, dv;
            int width, height;
            sscanf(line, "%s %d %d %f %f %f %f", name, &width, &height, &u, &v, &du, &dv);
            Region *region = game_new(sizeof(*region));
            init_region(region, name, width, height, u, v, u + du, v + dv);
            engine->atlas[region->id] = region;
            printf("Engine :: Image %s %d %d %f %f %f %f.\n", region->name,
                   region->width, region->height, region->u0, region->v0, region->u1, region->v1);
        }
        cursor = line;
        line[0] = 0;
    }
    return engine;
}

/* 0xd1a0 / 0xd340 */
static void *math_tables;
extern void *dispose_math_tables(void *);
__attribute__((noinline))
AtlasEngine *engine_destroy(AtlasEngine *engine)
{
    engine->methods = &engine_vtable.calls;
    void *tables = math_tables;
    if (tables) {
        dispose_math_tables(tables);
        game_delete(tables);
    }
    puts("Engine :: Dealloc.");
    free(engine->indices);
    free(engine->positions);
    free(engine->texcoords);
    free(engine->alpha);
    for (int i = 0; i < 512; ++i) {
        Region *region = engine->atlas[i];
        if (region) {
            free(region->name);
            game_delete(region);
        }
        engine->atlas[i] = 0;
    }
    glDeleteTextures(1, &engine->atlas_texture);
    glDeleteTextures(1, &engine->scene_target.texture);
    glDeleteProgram(engine->sprites.program);
    glDeleteBuffers(1, &engine->renderbuffer);
    glDeleteBuffers(1, &engine->screen_framebuffer);
    glDeleteBuffers(1, &engine->scene_target.framebuffer);
    return engine;
}

/* The distinct destructor entries are present in the original vtable. */
static AtlasEngine *base_destroy(AtlasEngine *engine) { return engine_destroy(engine); }
static void base_delete(AtlasEngine *engine) { engine_destroy(engine); game_delete(engine); }
static void base_frame(AtlasEngine *engine, float dt) { (void)engine; (void)dt; }
static void base_load(AtlasEngine *engine) { (void)engine; }
static void base_event(AtlasEngine *engine, int event, int argument)
{
    (void)engine; (void)event; (void)argument;
}

static void base_begin(AtlasEngine *engine, int x, int y)
{
    (void)engine;
    printf("Engine :: Touch begin %d %d.\n", x, y);
}
static void base_end(AtlasEngine *engine, int x0, int y0, int x, int y)
{
    (void)engine;
    printf("Engine :: Touch ended %d %d %d %d.\n", x0, y0, x, y);
}
static void base_move(AtlasEngine *engine, int x0, int y0, int x, int y)
{
    (void)engine;
    printf("Engine :: Touch moved %d %d %d %d.\n", x0, y0, x, y);
}
static const EngineTable engine_vtable = { 0, 0, {
    base_destroy, base_delete, base_frame, base_begin, base_end, base_move,
    base_load, base_event, engine_output_score, engine_pause, engine_resume
} };

/* OpenGL ES 2.0 entry points used in this translation unit. */
enum {
    GL_ONE = 1, GL_ONE_MINUS_SRC_ALPHA = 0x303, GL_DEPTH_TEST = 0xb71,
    GL_BLEND = 0xbe2, GL_TEXTURE_2D = 0xde1, GL_UNSIGNED_BYTE = 0x1401,
    GL_RGBA = 0x1908, GL_NEAREST = 0x2600, GL_LINEAR = 0x2601,
    GL_TEXTURE_MAG_FILTER = 0x2800, GL_TEXTURE_MIN_FILTER = 0x2801,
    GL_TEXTURE_WRAP_S = 0x2802, GL_TEXTURE_WRAP_T = 0x2803,
    GL_CLAMP_TO_EDGE = 0x812f, GL_TEXTURE0 = 0x84c0, GL_FRAGMENT_SHADER = 0x8b30,
    GL_VERTEX_SHADER = 0x8b31, GL_COLOR_ATTACHMENT0 = 0x8ce0,
    GL_FRAMEBUFFER = 0x8d40, GL_RENDERBUFFER = 0x8d41
};
extern void glEnable(unsigned), glDisable(unsigned), glBlendFunc(unsigned, unsigned);
extern void glGenRenderbuffers(int, unsigned *), glBindRenderbuffer(unsigned, unsigned);
extern void glGenFramebuffers(int, unsigned *), glBindFramebuffer(unsigned, unsigned);
extern void glFramebufferRenderbuffer(unsigned, unsigned, unsigned, unsigned);
extern void glGenTextures(int, unsigned *), glBindTexture(unsigned, unsigned);
extern void glTexParameteri(unsigned, unsigned, int), glActiveTexture(unsigned);
extern void glTexImage2D(unsigned, int, int, int, int, int, unsigned, unsigned, const void *);
extern void glFramebufferTexture2D(unsigned, unsigned, unsigned, unsigned, int);
extern unsigned glCreateShader(unsigned), glCreateProgram(void);
extern void glShaderSource(unsigned, int, const char *const *, const int *);
extern void glCompileShader(unsigned), glAttachShader(unsigned, unsigned), glLinkProgram(unsigned);
extern int glGetUniformLocation(unsigned, const char *), glGetAttribLocation(unsigned, const char *);
extern void glDetachShader(unsigned, unsigned), glDeleteShader(unsigned);

static inline __attribute__((always_inline)) void make_target(RenderTarget *target, int extent, int filter)
{
    glGenTextures(1, &target->texture);
    glBindTexture(GL_TEXTURE_2D, target->texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, filter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, filter);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, extent, extent, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    glGenFramebuffers(1, &target->framebuffer);
    glActiveTexture(GL_TEXTURE0);
    glBindFramebuffer(GL_FRAMEBUFFER, target->framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, target->texture, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
}

/* The IPA contains these GLSL strings, split into lines. The two programs
 * share coordinate transforms. Only the sprite program multiplies by alpha. */
static inline __attribute__((always_inline)) void make_program(
    ShaderProgram *program, int with_alpha,
    const char *const *vertex, int vertex_lines, const char *const *fragment, int fragment_lines)
{
    unsigned vs = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vs, vertex_lines, vertex, 0);
    glCompileShader(vs);
    unsigned fs = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fs, fragment_lines, fragment, 0);
    glCompileShader(fs);
    program->program = glCreateProgram();
    glAttachShader(program->program, vs);
    glAttachShader(program->program, fs);
    glLinkProgram(program->program);
    program->matrix = glGetUniformLocation(program->program, "uMatrix");
    program->sampler = glGetUniformLocation(program->program, "sTexture");
    program->position = glGetAttribLocation(program->program, "aPosition");
    program->texcoord = glGetAttribLocation(program->program, "aTexCoord");
    program->alpha = with_alpha ? glGetAttribLocation(program->program, "aAlpha") : 0;
    glDetachShader(program->program, vs);
    glDeleteShader(vs);
    glDetachShader(program->program, fs);
    glDeleteShader(fs);
    printf(with_alpha ? "Engine :: Location of program 0: m_progLoc %d\n"
                      : "Engine :: Location of program 1: m_progLoc_1 %d\n", program->program);
    printf(with_alpha ? "Engine :: Location of variables 0: m_matLoc %d m_sampLoc %d m_posLoc %d m_texLoc %d m_alpLoc %d\n"
                      : "Engine :: Location of variables 1: m_matLoc_1 %d m_sampLoc_1 %d m_posLoc_1 %d m_texLoc_1 %d m_alpLoc_1 %d\n",
           program->matrix, program->sampler, program->position, program->texcoord, program->alpha);
}

#ifdef FLAP_RENDERER_REFERENCE_OBJECT
/* The original compiled the pool vtables and setup in a single object. */
const SpriteVTable number_pool_vtable, sparkle_pool_vtable;
#endif
extern void *init_math_tables(void *);
static Tween *new_tween(void)
{
    Tween *tween = game_new(sizeof(*tween));
    tween->finished = 1;
    tween->value = 0.0f;
    return tween;
}

static SpritePool *new_pool(const SpriteMethods *methods)
{
    SpritePool *pool = game_new(sizeof(*pool));
    pool->object.active = 0;
    pool->object.visible = 0;
    pool->object.methods = methods;
    return pool;
}

static const char *const sprite_vertex_lines[] = {
    "uniform mat4 uMatrix; \n",
    "attribute vec4 aPosition; \n",
    "attribute vec2 aTexCoord; \n",
    "attribute float aAlpha;\n",
    "varying vec2 vTexCoord; \n",
    "varying float vAlpha; \n",
    "void main() { \n",
    "gl_Position = uMatrix * aPosition; \n",
    "gl_Position.x -= 1.0; \n",
    "gl_Position.y += 1.0; \n",
    "vTexCoord = aTexCoord; \n",
    "vAlpha = aAlpha; \n",
    "}",
};

static const char *const sprite_fragment_lines[] = {
    "precision lowp float;\n",
    "uniform lowp sampler2D sTexture;\n",
    "varying mediump vec2 vTexCoord;\n",
    "varying lowp float vAlpha;\n",
    "void main() {\n",
    "gl_FragColor = vAlpha * texture2D(sTexture, vTexCoord);\n",
    "}",
};

static const char *const blit_vertex_lines[] = {
    "uniform mat4 uMatrix; \n",
    "attribute vec4 aPosition; \n",
    "attribute vec2 aTexCoord; \n",
    "varying vec2 vTexCoord; \n",
    "void main() { \n",
    "gl_Position = uMatrix * aPosition; \n",
    "gl_Position.x -= 1.0; \n",
    "gl_Position.y += 1.0; \n",
    "vTexCoord = aTexCoord; \n",
    "}",
};

static const char *const blit_fragment_lines[] = {
    "precision lowp float;\n",
    "uniform lowp sampler2D sTexture;\n",
    "varying mediump vec2 vTexCoord;\n",
    "void main() {\n",
    "gl_FragColor = texture2D(sTexture, vTexCoord);\n",
    "}",
};

/* 0xd268 / 0xd408. The first pass targets a 512-square nearest-filtered
 * texture. A second, 1024-square linear-filtered target scales to the screen. */
void viewGameSetup(AtlasEngine *engine)
{
    puts("Engine :: OpenGL Config.");
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glDisable(GL_DEPTH_TEST);
    puts("Engine :: Create Screen Buffer.");
    glGenRenderbuffers(1, &engine->renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, engine->renderbuffer);
    glGenFramebuffers(1, &engine->screen_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, engine->screen_framebuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, engine->renderbuffer);
    puts("Engine :: Create Offscreen Screen Buffer.");
    make_target(&engine->scene_target, 512, GL_NEAREST);
    printf("Engine :: Offscreen Texture Id %d\n", engine->scene_target.texture);
    puts("Engine :: Create Offscreen Screen Buffer 2.");
    make_target(&engine->upscale_target, 1024, GL_LINEAR);
    printf("Engine :: Offscreen Texture Id 1 %d\n", engine->upscale_target.texture);
    puts("Engine :: Load program 0.");
    const char *sprite_vertex[sizeof(sprite_vertex_lines) / sizeof(*sprite_vertex_lines)];
    __builtin_memcpy(sprite_vertex, sprite_vertex_lines, sizeof(sprite_vertex));
    const char *sprite_fragment[sizeof(sprite_fragment_lines) / sizeof(*sprite_fragment_lines)];
    __builtin_memcpy(sprite_fragment, sprite_fragment_lines, sizeof(sprite_fragment));
    make_program(&engine->sprites, 1, sprite_vertex, 13, sprite_fragment, 7);
    puts("Engine :: Load program 1.");
    const char *blit_vertex[sizeof(blit_vertex_lines) / sizeof(*blit_vertex_lines)];
    __builtin_memcpy(blit_vertex, blit_vertex_lines, sizeof(blit_vertex));
    const char *blit_fragment[sizeof(blit_fragment_lines) / sizeof(*blit_fragment_lines)];
    __builtin_memcpy(blit_fragment, blit_fragment_lines, sizeof(blit_fragment));
    make_program(&engine->blit, 0, blit_vertex, 10, blit_fragment, 6);

    puts("Engine :: Other initialzing.");
    engine->field_124 = 0;
    memset(&engine->quads, 0, sizeof(engine->quads) + sizeof(engine->projection));
    engine->projection[0][0] = 2.0f / 288.0f;
    engine->projection[0][5] = -2.0f / 512.0f;
    engine->projection[0][15] = 1.0f;
    void *tables = game_new(1);
    init_math_tables(tables);
    math_tables = tables;
    engine->fade = new_tween();
    engine->flash = new_tween();
    engine->black = find_sprite(engine, "black");
    engine->white = find_sprite(engine, "white");
    engine->touch_count = 0;

    engine->numbers = new_pool(&number_pool_vtable.calls);
    init_number_pool(engine->numbers, 20);
    engine->sparkles = new_pool(&sparkle_pool_vtable.calls);
    init_sparkle_pool(engine->sparkles, 10);
    engine->score_digits = init_frameset(game_new(sizeof(FrameSet)), "number_score");
    ScorePanel *panel = game_new(sizeof(*panel));
    init_score_panel(panel);
    engine->panel = panel;
    engine->shake_ticks = 0;
    engine->paused = 0;
    engine->output_count = 0;
    engine->queue_write = 0;
    memset(engine->delay, 0, sizeof(engine->delay));
    engine->methods->load(engine);
    start_transition(engine, 0, 0, 0.5f);
}

extern double round(double);

/* 0xd9c8 / 0xdb68. The intermediate pass uses an integral zoom that
 * fits inside a 1024-square texture. Screen coordinates use the width
 * ratio and center the visible game area independently of that zoom. */
void viewGameResize(AtlasEngine *engine, int width, int height)
{
    glBindRenderbuffer(GL_RENDERBUFFER, engine->renderbuffer);
    double horizontal = width / 288.0;
    double vertical = height / 512.0;
    double rounded_height = round(vertical);
    double rounded_width = round(horizontal);
    int scale = (int)round(rounded_width > rounded_height ? vertical : horizontal);
    engine->screen_width = width;
    engine->screen_height = height;
    engine->texture_scale = scale;
    engine->scaled_width = 288 * scale;
    engine->scaled_height = 512 * scale;
    while (engine->scaled_width > 1024 || engine->scaled_height > 1024) {
        --engine->texture_scale;
        engine->scaled_width -= 288;
        engine->scaled_height -= 512;
    }
    int scaled_width = engine->scaled_width, scaled_height = engine->scaled_height;
    engine->upscale_u = scaled_width / 1024.0f;
    engine->upscale_v = scaled_height / 1024.0f;
    engine->display_scale = width / 288.0f;
    engine->display_width = (int)(288 * engine->display_scale);
    engine->display_height = (int)(512 * engine->display_scale);
    engine->origin_x = (width - engine->display_width) >> 1;
    engine->origin_y = (height - engine->display_height) >> 1;
    engine->scene_u = 288.0f / 512.0f;
    engine->scene_v = 1.0f;
    engine->projection[1][0] = 2.0f / scaled_width;
    engine->projection[1][5] = -2.0f / scaled_height;
    engine->projection[1][15] = 1.0f;
    engine->projection[2][0] = 2.0f / width;
    engine->projection[2][5] = -2.0f / height;
    engine->projection[2][15] = 1.0f;
    printf("Engine :: Resize %d x %d\n", width, height);
}
