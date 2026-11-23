#import <UIKit/UIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import <math.h>

typedef enum {
    GADTicketGestureInitial,
    GADTicketGestureFirstRight,
    GADTicketGestureFirstLeft,
    GADTicketGestureSecondRight,
    GADTicketGestureSecondLeft
} GADTicketGestureState;

@interface GADImpressionTicketGestureRecognizerPrivate : NSObject {
    GADTicketGestureState gestureState_;
    NSUInteger distanceMoved_;
}
@property(nonatomic) GADTicketGestureState gestureState;
@property(nonatomic) NSUInteger distanceMoved;
@end

@implementation GADImpressionTicketGestureRecognizerPrivate
@synthesize gestureState = gestureState_;
@synthesize distanceMoved = distanceMoved_;

- (id)init
{
    self = [super init];
    if (self) {
        self.gestureState = GADTicketGestureInitial;
        self.distanceMoved = 0;
    }
    return self;
}
@end

@interface GADImpressionTicketGestureRecognizer : UIGestureRecognizer {
    GADImpressionTicketGestureRecognizerPrivate *_vars;
}
@property(nonatomic, retain) GADImpressionTicketGestureRecognizerPrivate *vars;
@end

@implementation GADImpressionTicketGestureRecognizer
@synthesize vars = _vars;

- (id)init
{
    self = [super init];
    if (self)
        _vars = [[GADImpressionTicketGestureRecognizerPrivate alloc] init];
    return self;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    if ([touches count] != 1)
        self.state = UIGestureRecognizerStateFailed;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];
    if (self.state == UIGestureRecognizerStateFailed)
        return;
    CGPoint point = [[touches anyObject] locationInView:self.view];
    CGPoint previous = [[touches anyObject] previousLocationInView:self.view];
    if (fabs(point.y - previous.y) > 5) {
        self.state = UIGestureRecognizerStateFailed;
        return;
    }

    BOOL movingRight = point.x >= previous.x;
    BOOL movingLeft = point.x <= previous.x;
    switch (self.vars.gestureState) {
    case GADTicketGestureInitial:
        if (point.x < previous.x) {
            self.state = UIGestureRecognizerStateFailed;
            break;
        }
        self.vars.distanceMoved += fabs(point.x - previous.x);
        self.vars.gestureState = GADTicketGestureFirstRight;
        break;
    case GADTicketGestureFirstRight:
        if (movingRight) {
            self.vars.distanceMoved += fabs(point.x - previous.x);
            self.vars.gestureState = GADTicketGestureFirstRight;
        } else if (movingLeft) {
            if (self.vars.distanceMoved <= 14) {
                self.state = UIGestureRecognizerStateFailed;
            } else {
                self.vars.distanceMoved = fabs(point.x - previous.x);
                self.vars.gestureState = GADTicketGestureFirstLeft;
            }
        }
        break;
    case GADTicketGestureFirstLeft:
        if (movingLeft) {
            self.vars.distanceMoved += fabs(point.x - previous.x);
            self.vars.gestureState = GADTicketGestureFirstLeft;
        } else if (movingRight) {
            if (self.vars.distanceMoved <= 14) {
                self.state = UIGestureRecognizerStateFailed;
            } else {
                self.vars.distanceMoved = fabs(point.x - previous.x);
                self.vars.gestureState = GADTicketGestureSecondRight;
            }
        }
        break;
    case GADTicketGestureSecondRight:
        if (movingRight) {
            self.vars.distanceMoved += fabs(point.x - previous.x);
            self.vars.gestureState = GADTicketGestureSecondRight;
        } else if (movingLeft) {
            if (self.vars.distanceMoved <= 14) {
                self.state = UIGestureRecognizerStateFailed;
            } else {
                self.vars.distanceMoved = fabs(point.x - previous.x);
                self.vars.gestureState = GADTicketGestureSecondLeft;
            }
        }
        break;
    case GADTicketGestureSecondLeft:
        if (movingLeft)
            self.vars.distanceMoved += fabs(point.x - previous.x);
        else if (movingRight)
            self.state = UIGestureRecognizerStateFailed;
        break;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesEnded:touches withEvent:event];
    if (self.state == UIGestureRecognizerStatePossible &&
        self.vars.gestureState == GADTicketGestureSecondLeft) {
        self.state = UIGestureRecognizerStateRecognized;
    } else {
        self.state = UIGestureRecognizerStateFailed;
        self.vars.gestureState = GADTicketGestureInitial;
    }
}
@end

@interface GADUIWebViewGestureDelgate : NSObject <UIGestureRecognizerDelegate>
@end

@implementation GADUIWebViewGestureDelgate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other
{
    return ![other isKindOfClass:[GADImpressionTicketGestureRecognizer class]];
}
@end
