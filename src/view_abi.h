// Declarations for the 32-bit calling conventions used by the recovered view.
// The native engine's function and field names are descriptive.
#pragma once

#include "renderer.h"
#ifdef FLAP_EDITABLE_VIEW
#import <objc/NSObject.h>
#else
typedef signed char BOOL;
#endif
typedef struct CGPoint { float x, y; } CGPoint;
typedef struct CGSize { float width, height; } CGSize;
typedef struct CGRect { CGPoint origin; CGSize size; } CGRect;
#ifndef FLAP_EDITABLE_VIEW
#define nil ((id)0)

__attribute__((objc_root_class))
@interface NSObject { Class isa; }
+ (id)alloc;
+ (Class)class;
- (id)init;
- (id)retain;
- (void)release;
- (void)dealloc;
- (id)copy;
@end
#endif
@class UIViewController, UIWindow, CALayer, NSString, NSRunLoop;
@class NSError, NSArray, NSDictionary, UIImage, EAGLContext, NSData, NSLock;
@class NSMutableArray, GADBannerView, ALDevice, ALContext, ALChannelSource, ALBuffer;

@interface NSString : NSObject
- (const char *)UTF8String;
- (id)initWithFormat:(NSString *)format, ...;
+ (id)stringWithFormat:(NSString *)format, ...;
@end
@interface NSArray : NSObject
+ (id)arrayWithObjects:(id)first, ...;
+ (id)arrayWithObjects:(const id *)objects count:(unsigned)count;
- (id)objectAtIndex:(unsigned)index;
@end
@interface NSDictionary : NSObject
+ (id)dictionaryWithObjectsAndKeys:(id)first, ...;
@end
@interface NSNumber : NSObject
+ (id)numberWithBool:(BOOL)value;
@end
@interface NSMutableArray : NSArray @end
@interface NSLock : NSObject @end
@interface NSBundle : NSObject
+ (id)mainBundle;
- (NSString *)resourcePath;
- (NSString *)pathForResource:(NSString *)name ofType:(NSString *)extension;
@end
@interface NSRunLoop : NSObject
+ (NSRunLoop *)currentRunLoop;
@end
@interface NSDate : NSObject
+ (id)date;
- (double)timeIntervalSince1970;
@end
@interface NSData : NSObject
- (id)initWithContentsOfFile:(NSString *)path;
@end
@interface UIImage : NSObject
- (id)initWithData:(NSData *)data;
- (void *)CGImage;
@end
@interface CALayer : NSObject
- (CGRect)bounds;
- (float)contentsScale;
@end
@interface CAEAGLLayer : CALayer
- (void)setOpaque:(BOOL)opaque;
- (void)setDrawableProperties:(NSDictionary *)properties;
@end
@interface CADisplayLink : NSObject
+ (id)displayLinkWithTarget:(id)target selector:(SEL)action;
- (void)setFrameInterval:(int)interval;
- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSString *)mode;
- (void)invalidate;
@end
@interface EAGLContext : NSObject
- (id)initWithAPI:(unsigned)api;
+ (id)currentContext;
+ (BOOL)setCurrentContext:(EAGLContext *)context;
- (BOOL)renderbufferStorage:(unsigned)target fromDrawable:(id)drawable;
- (BOOL)presentRenderbuffer:(unsigned)target;
@end
@interface UIView : NSObject { unsigned char privateUIViewStorage[48]; }
- (id)initWithFrame:(CGRect)frame;
- (UIWindow *)window;
- (CALayer *)layer;
- (CGRect)frame;
- (CGRect)bounds;
- (void)setFrame:(CGRect)frame;
- (void)setMultipleTouchEnabled:(BOOL)enabled;
- (void)addSubview:(UIView *)view;
- (void)removeFromSuperview;
+ (void)animateWithDuration:(double)duration animations:(void (^)(void))animations;
@end
@interface UIWindow : UIView
- (UIViewController *)rootViewController;
@end
@interface UIViewController : NSObject
- (UIView *)view;
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion;
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion;
@end
@interface UIActivityViewController : UIViewController
- (id)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)activities;
@end
@interface NSURL : NSObject
+ (id)URLWithString:(NSString *)url;
@end
@interface UIApplication : NSObject
+ (id)sharedApplication;
- (BOOL)openURL:(NSURL *)url;
@end
@interface UITouch : NSObject
- (CGPoint)locationInView:(UIView *)view;
- (CGPoint)previousLocationInView:(UIView *)view;
- (int)phase;
@end
@interface NSSet : NSObject
- (unsigned)countByEnumeratingWithState:(void *)state objects:(id *)buffer count:(unsigned)length;
@end
@interface ALBuffer : NSObject @end
@interface ALChannelSource : NSObject
+ (id)channelWithSources:(int)count;
- (void)setGain:(float)gain;
- (id)play:(ALBuffer *)buffer;
@end
@interface ALDevice : NSObject
+ (id)deviceWithDeviceSpecifier:(const char *)specifier;
@end
@interface ALContext : NSObject
+ (id)contextOnDevice:(ALDevice *)device attributes:(const int *)attributes;
@end
@interface OpenALManager : NSObject
+ (id)sharedInstance;
- (void)setCurrentContext:(ALContext *)context;
- (ALBuffer *)bufferFromFile:(NSString *)file;
@end
@interface OALAudioSession : NSObject
+ (id)sharedInstance;
- (void)setHandleInterruptions:(BOOL)value;
- (void)setAllowIpod:(BOOL)value;
- (void)setUseHardwareIfAvailable:(BOOL)value;
- (void)setHonorSilentSwitch:(BOOL)value;
@end
#ifdef FLAP_EDITABLE_VIEW
#import "gad_banner_delegate.h"
@class GKLeaderboardViewController;
@protocol GKLeaderboardViewControllerDelegate <NSObject>
- (void)leaderboardViewControllerDidFinish:(GKLeaderboardViewController *)viewController;
@end
#else
@protocol GADBannerViewDelegate @end
@protocol GKLeaderboardViewControllerDelegate @end
#endif
@interface GADRequest : NSObject
+ (id)request;
- (void)setTestDevices:(NSArray *)devices;
@end
@interface GADBannerView : UIView
- (void)setAdUnitID:(NSString *)unitID;
- (void)setDelegate:(id)delegate;
- (void)setRootViewController:(UIViewController *)controller;
- (void)loadRequest:(GADRequest *)request;
@end
@interface GKLocalPlayer : NSObject
+ (id)localPlayer;
- (BOOL)isAuthenticated;
- (void)loadDefaultLeaderboardCategoryIDWithCompletionHandler:(void (^)(NSString *, NSError *))completion;
- (void)setAuthenticateHandler:(void (^)(UIViewController *, NSError *))handler;
@end
@interface GKScore : NSObject
- (id)initWithCategory:(NSString *)category;
- (void)setShouldSetDefaultLeaderboard:(BOOL)value;
- (void)setValue:(long long)value;
- (void)reportScoreWithCompletionHandler:(void (^)(NSError *))completion;
@end
@interface GKLeaderboardViewController : UIViewController
- (void)setLeaderboardDelegate:(id)delegate;
@end

extern NSString *const NSDefaultRunLoopMode;
extern NSString *const kEAGLDrawablePropertyRetainedBacking, *const kEAGLDrawablePropertyColorFormat, *const kEAGLColorFormatRGBA8;
extern NSArray *NSSearchPathForDirectoriesInDomains(unsigned directory, unsigned domains, BOOL expandTilde);
extern Class NSClassFromString(NSString *name);
extern void NSLog(NSString *format, ...);
typedef struct __sFILE FILE;
extern FILE *fopen(const char *, const char *);
extern Size fread(void *, Size, Size, FILE *);
extern Size fwrite(const void *, Size, Size, FILE *);
extern int fclose(FILE *);
extern char *strcpy(char *, const char *);
extern char *strcat(char *, const char *);
extern int printf(const char *, ...);
extern void *malloc(Size);
extern void free(void *);
extern void glGenTextures(int count, unsigned *textures);
extern void glBindTexture(unsigned target, unsigned texture);
extern void glTexParameteri(unsigned target, unsigned parameter, int value);
extern void glTexImage2D(unsigned target, int level, int internalFormat, int width, int height, int border, unsigned format, unsigned type, const void *pixels);
extern Size CGImageGetWidth(void *image), CGImageGetHeight(void *image);
extern void *CGColorSpaceCreateDeviceRGB(void);
extern void CGColorSpaceRelease(void *colorSpace);
extern void *CGBitmapContextCreate(void *pixels, Size width, Size height, Size bitsPerComponent, Size bytesPerRow, void *colorSpace, unsigned bitmapInfo);
extern void CGContextClearRect(void *context, CGRect rect);
extern void CGContextTranslateCTM(void *context, float x, float y);
extern void CGContextDrawImage(void *context, CGRect rect, void *image);
extern void CGContextRelease(void *context);

extern AtlasEngine *flap_game; // ARMv7 0xfd614
extern unsigned flap_random_w, flap_random_z; // 0xfd61c, 0xfd620
extern void *viewOperatorNew(Size size) __asm("__Znwm");
extern void viewGameSetup(AtlasEngine *); // 0xd268
extern void viewGameResize(AtlasEngine *, int width, int height); // 0xd9c8
extern void viewGameFrame(AtlasEngine *); // 0xdba0
