/* The display-link callback advances the game by one fixed step, then renders
 * the sprite, intermediate upscale and screen passes. ARMv7 0xdba0 / ARMv7s 0xdd40. */
#include "native.h"

// These RNG words are defined by the engine and shared with the scene code.
unsigned flap_random_z, flap_random_w;
extern void glEnable(unsigned);
extern void glDisable(unsigned);
extern void glBlendFunc(unsigned, unsigned);
extern void glBindFramebuffer(unsigned, unsigned);
extern void glBindRenderbuffer(unsigned, unsigned);
extern void glViewport(int, int, int, int);
extern void glClearColor(float, float, float, float);
extern void glClear(unsigned);
extern void glUseProgram(unsigned);
extern void glEnableVertexAttribArray(unsigned);
extern void glDisableVertexAttribArray(unsigned);
extern void glVertexAttribPointer(unsigned, int, unsigned, unsigned char, int, const void *);
extern void glUniformMatrix4fv(int, int, unsigned char, const float *);
extern void glActiveTexture(unsigned);
extern void glBindTexture(unsigned, unsigned);
extern void glUniform1i(int, int);
extern void glDrawElements(unsigned, int, unsigned, const void *);

enum {
    GL_BLEND = 0xbe2, GL_ONE = 1, GL_ONE_MINUS_SRC_ALPHA = 0x303,
    GL_FRAMEBUFFER = 0x8d40, GL_RENDERBUFFER = 0x8d41, GL_COLOR_BUFFER_BIT = 0x4000,
    GL_SHORT = 0x1402, GL_FLOAT = 0x1406, GL_UNSIGNED_SHORT = 0x1403,
    GL_TEXTURE0 = 0x84c0, GL_TEXTURE_2D = 0xde1, GL_TRIANGLES = 4
};

static inline __attribute__((always_inline)) int shake_delta(int distance)
{
    flap_random_z = 36969u * (flap_random_z & 65535u) + ((int)flap_random_z >> 16);
    flap_random_w = 18000u * (flap_random_w & 65535u) + ((int)flap_random_w >> 16);
    unsigned random = (flap_random_z << 16) + flap_random_w;
    int positive = (int)random < 0 ? (int)(0u - random) : (int)random;
    return positive % (2 * distance) - distance;
}

static int running_or_visible(Tween *tween)
{
    return !tween->finished || tween->value != 0;
}

static inline __attribute__((always_inline)) void overlay(AtlasEngine *e, Tween *tween, Region *sprite)
{
    if (running_or_visible(tween)) {
        Region *image = e->atlas[sprite->id];
        append_quad(e, -144, -256, 720, 1280,
                    image->u0, image->v0, image->u1, image->v1, tween->value);
    }
}

static void clear_to_black(void)
{
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
}

static inline __attribute__((always_inline)) void draw_batch(AtlasEngine *e, ShaderProgram *shader, int per_vertex_alpha,
                              const float *projection, const unsigned *texture)
{
    if (e->quads > 0) {
        glUseProgram(shader->program);
        glEnableVertexAttribArray(shader->position);
        glVertexAttribPointer(shader->position, 2, GL_SHORT, 0, 4, e->positions);
        glEnableVertexAttribArray(shader->texcoord);
        glVertexAttribPointer(shader->texcoord, 2, GL_FLOAT, 0, 8, e->texcoords);
        if (per_vertex_alpha) {
            glEnableVertexAttribArray(e->sprites.alpha);
            glVertexAttribPointer(e->sprites.alpha, 1, GL_FLOAT, 0, 4, e->alpha);
        }
        glUniformMatrix4fv(shader->matrix, 1, 0, projection);
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, *texture);
        glUniform1i(shader->sampler, 0);
        glDrawElements(GL_TRIANGLES, 6 * e->quads, GL_UNSIGNED_SHORT, e->indices);
        glDisableVertexAttribArray(shader->position);
        glDisableVertexAttribArray(shader->texcoord);
        if (per_vertex_alpha)
            glDisableVertexAttribArray(e->sprites.alpha);
    }
    e->quads = 0;
}

void viewGameFrame(AtlasEngine *e)
{
    const float dt = 0.015f;
    e->output_count = 0;
    if (!e->paused) {
        /* The running branch supplies a known zero for the first slot. Using
         * it here reproduces the compiler's separate counter initialization. */
        for (int i = e->paused; i != EngineEventSlots; ++i) {
            if (e->delay[i] > 0 && (e->delay[i] -= 30) <= 0)
                e->methods->event(e, e->event[i], e->argument[i]);
        }
    }
    e->methods->frame(e, dt);
    if (!e->paused) {
        e->numbers->object.methods->update(e->numbers, dt);
        e->panel->object.methods->update(e->panel, dt);
        e->sparkles->object.methods->update(e->sparkles, dt);
        if (running_or_visible(e->fade)) {
            advance_tween(e->fade);
            if (e->fade->finished)
                e->methods->event(e, e->fade_event, (int)(Size)e);
        }
        if (running_or_visible(e->flash))
            advance_tween(e->flash);
        if (e->shake_ticks > 0) {
            --e->shake_ticks;
            e->shake_x = shake_delta(e->shake_distance);
            e->shake_y = shake_delta(e->shake_distance);
        } else {
            e->shake_x = e->shake_y = 0;
        }
    }
    e->numbers->object.methods->draw(e->numbers, e);
    e->panel->object.methods->draw(e->panel, e);
    e->sparkles->object.methods->draw(e->sparkles, e);
    overlay(e, e->fade, e->black);
    overlay(e, e->flash, e->white);

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
    glBindFramebuffer(GL_FRAMEBUFFER, e->scene_target.framebuffer);
    glViewport(0, 0, ScreenWidth, ScreenHeight);
    clear_to_black();
    draw_batch(e, &e->sprites, 1, e->projection[0], &e->atlas_texture);

    glDisable(GL_BLEND);
    append_quad(e, e->scaled_width, 0, 0, e->scaled_height, e->scene_u, e->scene_v, 0, 0, 1);
    glBindFramebuffer(GL_FRAMEBUFFER, e->upscale_target.framebuffer);
    glViewport(0, 0, e->scaled_width, e->scaled_height);
    clear_to_black();
    draw_batch(e, &e->blit, 0, e->projection[1], &e->scene_target.texture);

    int shake_x = e->shake_x, shake_y = e->shake_y;
    int left = (e->screen_width - e->display_width) >> 1;
    int top = (e->screen_height - e->display_height) >> 1;
    append_quad(e, e->screen_width + shake_x - left, shake_y + top, shake_x + left, e->screen_height + shake_y - top,
                e->upscale_u, e->upscale_v, 0, 0, 1);
    glViewport(0, 0, e->screen_width, e->screen_height);
    glBindFramebuffer(GL_FRAMEBUFFER, e->screen_framebuffer);
    clear_to_black();
    draw_batch(e, &e->blit, 0, e->projection[2], &e->upscale_target.texture);
    glBindRenderbuffer(GL_RENDERBUFFER, e->renderbuffer);
}
