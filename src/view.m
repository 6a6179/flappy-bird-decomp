// dot_EAGLView, recovered from ARMv7 Objective-C metadata and Thumb code.
// The addresses in comments are from the ARMv7 slice.
#import "view_abi.h"
#import "gameplay.h"
#import "native.h"

_Static_assert(sizeof(Game) == 0x5d4, "32-bit game allocation size");

enum { GL_TEXTURE_2D = 0xde1, GL_LINEAR = 0x2601, GL_TEXTURE_MIN_FILTER = 0x2801,
       GL_TEXTURE_MAG_FILTER = 0x2800, GL_RGBA = 0x1908, GL_UNSIGNED_BYTE = 0x1401,
       GL_RENDERBUFFER = 0x8d41 };
enum {
    NSDocumentDirectory = 9,
    NSUserDomainMask = 1,
    kEAGLRenderingAPIOpenGLES2 = 2,
    kCGBitmapByteOrder32Big = 0x4000,
    kCGImageAlphaPremultipliedLast = 1
};

enum { TouchBegan, TouchMoved, TouchStationary, TouchEnded, TouchCancelled };

@interface dot_EAGLView : UIView <GADBannerViewDelegate, GKLeaderboardViewControllerDelegate> {
    id _displayLink;
    EAGLContext *_context;
    ALDevice *device;
    ALContext *context;
    ALChannelSource *channel0, *channel1, *channel2;
    ALBuffer *sfx_coin_buffer, *sfx_swooshing_buffer, *sfx_die_buffer, *sfx_hit, *sfx_wing;
    char scoreDataFileName[512];
    int highScore, numOfPlay;
    int touches_x[20], touches_y[20], numOfTouches;
    _Bool m_isDisplayAd, m_isGameCenterEnabled;
    NSLock *writeLock;
    NSString *leaderboard;
    _Bool animating;
    int frameInterval;
    GADBannerView *admobBannerView;
    NSMutableArray *storedScores;
    NSString *storedScoresFilename;
}
@property(nonatomic, readonly) _Bool animating;
@property(nonatomic) int frameInterval;
@property(nonatomic, retain) GADBannerView *admobBannerView;
@property(nonatomic, readonly) NSString *storedScoresFilename;
@property(nonatomic, readonly) NSMutableArray *storedScores;
- (void)drawView:(id)sender;
@end

// ld grouped the translation unit's ios_base::Init object with its singleton.
static struct {
    char iosBaseInit;
    dot_EAGLView *currentView;
} viewGlobals __attribute__((used)); // 0xfd380; currentView at +4

static CGRect rect(float x, float y, float width, float height) {
    return (CGRect){{x, y}, {width, height}};
}

static int gameX(AtlasEngine *engine, float x) {
    return (int)((x - engine->origin_x) / engine->display_width * ScreenWidth);
}
static int gameY(AtlasEngine *engine, float y) {
    return (int)((y - engine->origin_y) / engine->display_height * ScreenHeight);
}

@implementation dot_EAGLView
@synthesize animating, frameInterval, admobBannerView, storedScores, storedScoresFilename;

+ (Class)layerClass { return [CAEAGLLayer class]; }

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    animating = 0;
    viewGlobals.currentView = self;
    [self setMultipleTouchEnabled:0];
    const char *resources = [[[NSBundle mainBundle] resourcePath] UTF8String];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, 1);
    const char *documents = [[paths objectAtIndex:0] UTF8String];

    device = [[ALDevice deviceWithDeviceSpecifier:0] retain];
    context = [[ALContext contextOnDevice:device attributes:0] retain];
    [[OpenALManager sharedInstance] setCurrentContext:context];
    [[OALAudioSession sharedInstance] setHandleInterruptions:1];
    [[OALAudioSession sharedInstance] setAllowIpod:1];
    [[OALAudioSession sharedInstance] setUseHardwareIfAvailable:0];
    [[OALAudioSession sharedInstance] setHonorSilentSwitch:1];
    channel0 = [[ALChannelSource channelWithSources:2] retain];
    channel1 = [[ALChannelSource channelWithSources:2] retain];
    channel2 = [[ALChannelSource channelWithSources:2] retain];
    sfx_coin_buffer = [[[OpenALManager sharedInstance] bufferFromFile:@"sfx_point.aif"] retain];
    sfx_swooshing_buffer = [[[OpenALManager sharedInstance] bufferFromFile:@"sfx_swooshing.caf"] retain];
    sfx_die_buffer = [[[OpenALManager sharedInstance] bufferFromFile:@"sfx_die.caf"] retain];
    sfx_hit = [[[OpenALManager sharedInstance] bufferFromFile:@"sfx_hit.caf"] retain];
    sfx_wing = [[[OpenALManager sharedInstance] bufferFromFile:@"sfx_wing.caf"] retain];

    char atlasPath[512], atlas[10240];
    strcpy(atlasPath, resources);
    strcat(atlasPath, "/atlas.txt");
    FILE *file = fopen(atlasPath, "r");
    int length = 0;
    if (file) {
        length = (int)fread(atlas, 1, sizeof(atlas), file);
    }
    fclose(file);  // The original assumes atlas.txt shipped in the bundle.
    numOfPlay = 0;
    highScore = 0;
    strcpy(scoreDataFileName, documents);
    strcat(scoreDataFileName, "/score.dat");
    file = fopen(scoreDataFileName, "rb");
    if (file) {
        int values[2] = {0, 0};
        fread(values, sizeof(int), 2, file);
        highScore = values[0];
        numOfPlay = values[1];
        fclose(file);
    }
    file = fopen(scoreDataFileName, "wb");
    if (file) {
        int values[] = { highScore, numOfPlay };
        fwrite(values, sizeof(int), 2, file);
        fclose(file);
    }
    Game *game = viewOperatorNew(sizeof(Game));
    viewGameConstruct(game, highScore, numOfPlay, atlas, length);
    flap_game = &game->engine;
    m_isDisplayAd = 0;
    paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, 1);
    NSString *directory = [paths objectAtIndex:0];
    storedScoresFilename = [[NSString alloc] initWithFormat:@"%@/storedScores.plist", directory];
    writeLock = [[NSLock alloc] init];
    return self;
}

- (void)adViewDidReceiveAd:(id)ad {
    if (!m_isDisplayAd) {
        Game *game = (Game *)flap_game;
        if (!game->title_screen && !game->reported_score) return;
        [[[[self window] rootViewController] view] addSubview:[self admobBannerView]];
        [UIView animateWithDuration:0.5 animations:^{
            [admobBannerView setFrame:rect(
                ([[self window] bounds].size.width - [admobBannerView frame].size.width) * 0.5f,
                0, [admobBannerView frame].size.width, [admobBannerView frame].size.height)];
        }];
        m_isDisplayAd = 1;
    }
    NSLog(@"Received Ad Success.");
}

- (void)adView:(id)view didFailToReceiveAdWithError:(id)error {
    if (m_isDisplayAd) {
        [[self admobBannerView] removeFromSuperview];
        m_isDisplayAd = 0;
    }
    NSLog(@"Received Ad Error %@", error);
}

// ARM's VCVT.S32.F64 saturates outside the signed 32-bit range.
+ (int)GetTime {
    double milliseconds = [[NSDate date] timeIntervalSince1970] * 1000.0;
    int truncated = (int)milliseconds;
    return truncated % 32000;
}

- (void)checkLocalPlayer {
    if ([[GKLocalPlayer localPlayer] isAuthenticated]) {
        NSLog(@"isAuthenticated");
        m_isGameCenterEnabled = 1;
        [[GKLocalPlayer localPlayer] loadDefaultLeaderboardCategoryIDWithCompletionHandler:
            ^(NSString *category, NSError *error) { leaderboard = [category copy]; }];
    } else {
        NSLog(@"is not Authenticated");
        m_isGameCenterEnabled = 0;
    }
}

- (void)setup {
    CAEAGLLayer *layer = (CAEAGLLayer *)[self layer];
    [layer setOpaque:1];
    [layer setDrawableProperties:[NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:0], kEAGLDrawablePropertyRetainedBacking,
        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil]];
    frameInterval = 1;
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:_context];
    int seed = [dot_EAGLView GetTime];
    printf("Engine: Randomize %d.\n", seed);
    flap_random_w = seed % 32000;
    flap_random_z = seed % 65535;
    viewGameSetup(flap_game);

    unsigned texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    NSString *path = [[NSBundle mainBundle] pathForResource:@"atlas" ofType:@"png"];
    NSData *data = [[NSData alloc] initWithContentsOfFile:path];
    UIImage *image = [[UIImage alloc] initWithData:data];
    if (!image) NSLog(@"Do real error checking here");
    Size width = CGImageGetWidth([image CGImage]);
    Size height = CGImageGetHeight([image CGImage]);
    void *space = CGColorSpaceCreateDeviceRGB();
    void *pixels = malloc(width * height * 4);
    void *bitmap = CGBitmapContextCreate(pixels, width, height, 8, width * 4, space,
                                         kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGContextClearRect(bitmap, rect(0, 0, width, height));
    CGContextTranslateCTM(bitmap, 0, 0);
    CGContextDrawImage(bitmap, rect(0, 0, width, height), [image CGImage]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    CGContextRelease(bitmap);
    free(pixels);
    [image release];
    [data release];
    numOfTouches = 0;
    flap_game->atlas_texture = texture;
}

+ (id)instance { return viewGlobals.currentView; }

- (void)dealloc {
    [storedScores release];
    [writeLock release];
    [storedScoresFilename release];
    [channel0 release];
    [channel1 release];
    [channel2 release];
    [context release];
    [device release];
    viewGlobals.currentView = nil;
    if (flap_game) flap_game->methods->delete_object(flap_game);
    flap_game = 0;
    if ([EAGLContext currentContext] == _context) [EAGLContext setCurrentContext:nil];
    _context = nil;
    [super dealloc];
}

- (void)start {
    if (animating) return;
    _displayLink = [NSClassFromString(@"CADisplayLink") displayLinkWithTarget:self selector:@selector(drawView:)];
    [_displayLink setFrameInterval:frameInterval];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    animating = 1;
    flap_game->methods->resume(flap_game);
}

- (void)stop {
    if (!animating) return;
    [_displayLink invalidate];
    _displayLink = nil;
    animating = 0;
    flap_game->methods->pause(flap_game);
}

- (void)drawView:(id)sender {
    [EAGLContext setCurrentContext:_context];
    engine_set_touches(flap_game, touches_x, touches_y, numOfTouches);
    viewGameFrame(flap_game);
    // The native frame queues UIKit, Game Center and audio work for the view.
    for (int i = 0; i < flap_game->output_count; ++i) {
        switch (flap_game->output_type[i]) {
        case ConfigureTitle: {
            if (!m_isDisplayAd && ![self admobBannerView]) {
                if ([[self window] bounds].size.width == 320) {
                    admobBannerView = [[GADBannerView alloc] initWithFrame:rect(0, 0, 320, 50)];
                } else {
                    admobBannerView = [[GADBannerView alloc] initWithFrame:rect(
                        ([[self window] bounds].size.width - 728) * 0.5f, 0, 728, 90)];
                }
                [[self admobBannerView] setAdUnitID:@"0b00de9079314130"];
                [[self admobBannerView] setRootViewController:[[self window] rootViewController]];
                [[self admobBannerView] setDelegate:self];
            }
            [admobBannerView setFrame:rect(
                ([[self window] bounds].size.width - [admobBannerView frame].size.width) * 0.5f,
                -[admobBannerView frame].size.height,
                [admobBannerView frame].size.width, [admobBannerView frame].size.height)];
            if (!m_isDisplayAd) {
                GADRequest *request = [GADRequest request];
                [request setTestDevices:[NSArray arrayWithObjects:@"a950a1dca695ac6bbc46f22c4e4923d4", @"Simulator", nil]];
                [[self admobBannerView] loadRequest:request];
            } else {
                [UIView animateWithDuration:0.5 animations:^{
                    [admobBannerView setFrame:rect(
                        ([[self window] bounds].size.width - [admobBannerView frame].size.width) * 0.5f,
                        0, [admobBannerView frame].size.width, [admobBannerView frame].size.height)];
                }];
            }
            [[GKLocalPlayer localPlayer] setAuthenticateHandler:^(UIViewController *controller, NSError *error) {
                if (!error && controller) {
                    [[[viewGlobals.currentView window] rootViewController] presentViewController:controller animated:1 completion:nil];
                } else {
                    [self checkLocalPlayer];
                }
            }];
            break;
        }
        case RoundStarted:
            if (m_isDisplayAd) {
                ++numOfPlay;
                if ([self admobBannerView]) [[self admobBannerView] removeFromSuperview];
                m_isDisplayAd = 0;
            }
            break;
        case RoundEnded:
            [admobBannerView setFrame:rect(
                ([[self window] bounds].size.width - [admobBannerView frame].size.width) * 0.5f,
                -[admobBannerView frame].size.height,
                [admobBannerView frame].size.width, [admobBannerView frame].size.height)];
            if (!m_isDisplayAd) {
                GADRequest *request = [GADRequest request];
                [request setTestDevices:[NSArray arrayWithObjects:@"a950a1dca695ac6bbc46f22c4e4923d4", @"Simulator", nil]];
                [[self admobBannerView] loadRequest:request];
            } else {
                [UIView animateWithDuration:0.5 animations:^{
                    [admobBannerView setFrame:rect(
                        ([[self window] bounds].size.width - [admobBannerView frame].size.width) * 0.5f,
                        0, [admobBannerView frame].size.width, [admobBannerView frame].size.height)];
                }];
            }
            break;
        case ReportScore: {
            if ([[GKLocalPlayer localPlayer] isAuthenticated]) {
                GKScore *score = [[GKScore alloc] initWithCategory:leaderboard];
                [score setShouldSetDefaultLeaderboard:0];
                [score setValue:(long long)flap_game->output_value[i]];
                [score reportScoreWithCompletionHandler:^(NSError *error) {
                    if (!error) NSLog(@"Submit Successfully.");
                }];
            }
            double current = flap_game->output_value[i];
            highScore = (int)(current > highScore ? current : highScore);
            FILE *file = fopen(scoreDataFileName, "wb");
            if (file) {
                int scores[] = {highScore, numOfPlay};
                fwrite(scores, sizeof(int), 2, file);
                fclose(file);
            }
            break;
        }
        case ShareScore: {
            NSString *text = [NSString stringWithFormat:@"OMG! I scored %d pts in #flapflap!!! -> http://itunes.apple.com/app/id642099621",
                              (int)flap_game->output_value[i]];
            NSArray *items = @[text];
            UIActivityViewController *controller = [[UIActivityViewController alloc]
                initWithActivityItems:items applicationActivities:nil];
            [[[self window] rootViewController] presentViewController:controller animated:1 completion:nil];
            break;
        }
        case ShowLeaderboard: {
            if ([[GKLocalPlayer localPlayer] isAuthenticated]) {
                GKLeaderboardViewController *controller = [[GKLeaderboardViewController alloc] init];
                [controller setLeaderboardDelegate:self];
                [[[self window] rootViewController] presentViewController:controller animated:1 completion:nil];
                [controller release];
            }
            break;
        }
        case PlayPoint:
            if ([self admobBannerView]) [[self admobBannerView] removeFromSuperview];
            [channel0 setGain:0.2f];
            [channel0 play:sfx_coin_buffer];
            break;
        case PlaySwoosh:
            [channel1 setGain:1];
            [channel1 play:sfx_swooshing_buffer];
            break;
        case PlayDie:
            [channel2 setGain:1];
            [channel2 play:sfx_die_buffer];
            break;
        case PlayWing:
            if ([self admobBannerView]) [[self admobBannerView] removeFromSuperview];
            [channel2 setGain:1];
            [channel2 play:sfx_wing];
            break;
        case PlayHit:
            [channel0 setGain:1];
            [channel0 play:sfx_hit];
            break;
        case OpenAppStore:
            NSLog(@"Rate!");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id642099621"]];
            break;
        }
    }
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)leaderboardViewControllerDidFinish:(UIViewController *)controller {
    NSLog(@"Finished.");
    [controller dismissViewControllerAnimated:1 completion:nil];
}

- (void)layoutSubviews {
    viewGameResize(flap_game,
        (int)([[self layer] bounds].size.width * [[self layer] contentsScale]),
        (int)([[self layer] bounds].size.height * [[self layer] contentsScale]));
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:[self layer]];
    [self drawView:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(id)event {
    AtlasEngine *engine = flap_game;
    engine->touch_count = 0;
    numOfTouches = 0;
    for (UITouch *touch in touches) {
        int x = gameX(engine, [touch locationInView:self].x);
        int y = gameY(engine, [touch locationInView:self].y);
        if ([touch phase] == TouchBegan) engine->methods->begin(engine, x, y);
        if ([touch phase] == TouchBegan || [touch phase] == TouchMoved || [touch phase] == TouchStationary) {
            touches_x[numOfTouches] = x;
            touches_y[numOfTouches] = y;
            ++numOfTouches;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(id)event {
    AtlasEngine *engine = flap_game;
    engine->touch_count = 0;
    numOfTouches = 0;
    for (UITouch *touch in touches) {
        int x = gameX(engine, [touch locationInView:self].x);
        int y = gameY(engine, [touch locationInView:self].y);
        if ([touch phase] == TouchMoved) {
            int oldX = gameX(engine, [touch previousLocationInView:self].x);
            int oldY = gameY(engine, [touch previousLocationInView:self].y);
            engine->methods->move(engine, oldX, oldY, x, y);
        }
        if ([touch phase] == TouchBegan || [touch phase] == TouchMoved || [touch phase] == TouchStationary) {
            touches_x[numOfTouches] = x;
            touches_y[numOfTouches] = y;
            ++numOfTouches;
        }
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(id)event {
    AtlasEngine *engine = flap_game;
    engine->touch_count = 0;
    numOfTouches = 0;
    for (UITouch *touch in touches) {
        int x = gameX(engine, [touch locationInView:self].x);
        int y = gameY(engine, [touch locationInView:self].y);
        if ([touch phase] == TouchEnded) {
            int oldX = gameX(engine, [touch previousLocationInView:self].x);
            int oldY = gameY(engine, [touch previousLocationInView:self].y);
            flap_game->methods->end(flap_game, oldX, oldY, x, y);
        }
        if ([touch phase] == TouchBegan || [touch phase] == TouchMoved || [touch phase] == TouchStationary) {
            touches_x[numOfTouches] = x;
            touches_y[numOfTouches] = y;
            ++numOfTouches;
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(id)event {
    AtlasEngine *engine = flap_game;
    engine->touch_count = 0;
    numOfTouches = 0;
    for (UITouch *touch in touches) {
        int x = gameX(engine, [touch locationInView:self].x);
        int y = gameY(engine, [touch locationInView:self].y);
        if ([touch phase] == TouchBegan || [touch phase] == TouchMoved || [touch phase] == TouchStationary) {
            touches_x[numOfTouches] = x;
            touches_y[numOfTouches] = y;
            ++numOfTouches;
        }
    }
}
@end
