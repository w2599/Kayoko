//
//  KayokoSwipeUpHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelper.h"

#import <CaptainHook/CaptainHook.h>
#import <HBLog.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

CHDeclareClass(UIInputSetHostView);
CHDeclareClass(_UIHostedWindow);

static char kKayokoSwipeUpGestureRecognizerKey;
static char kKayokoSwipeUpGestureHandlerKey;
static char kKayokoManualSwipeUpActiveKey;

static CGFloat const kKayokoSwipeUpAdditionalBottomSafetyInset = 0.0;

@interface UIGestureRecognizer (KayokoManualTouchDelivery)
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
@end

@interface UIInputSetHostView : UIView
@end

@interface _UIHostedWindow : UIWindow
@end

static CGRect KayokoSwipeAllowedBoundsForView(UIView *view) {
    UIEdgeInsets safeAreaInsets = view.safeAreaInsets;
    safeAreaInsets.bottom += kKayokoSwipeUpAdditionalBottomSafetyInset;
    CGRect allowedBounds = UIEdgeInsetsInsetRect(view.bounds, safeAreaInsets);
    if (CGRectGetWidth(allowedBounds) <= 0 || CGRectGetHeight(allowedBounds) <= 0) {
        return CGRectNull;
    }

    return allowedBounds;
}

static BOOL KayokoPointIsInsideAllowedSwipeRegion(UIView *view, CGPoint point) {
    CGRect allowedBounds = KayokoSwipeAllowedBoundsForView(view);
    if (CGRectIsNull(allowedBounds)) {
        return NO;
    }

    return CGRectContainsPoint(allowedBounds, point);
}

static id KayokoSharedApplication(void) {
    Class applicationClass = NSClassFromString(@"UIApplication");
    SEL sharedApplicationSelector = NSSelectorFromString(@"sharedApplication");
    if (![applicationClass respondsToSelector:sharedApplicationSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [applicationClass performSelector:sharedApplicationSelector];
#pragma clang diagnostic pop
}

static void KayokoCancelAllTouches(void) {
    id application = KayokoSharedApplication();
    SEL cancelAllTouchesSelector = NSSelectorFromString(@"_cancelAllTouches");
    if (![application respondsToSelector:cancelAllTouchesSelector]) {
        return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [application performSelector:cancelAllTouchesSelector];
#pragma clang diagnostic pop
}

static void KayokoShowKayokoAndCancelTouches(void) {
    KayokoHelperCaptureCurrentFirstResponder();
    KayokoHelperPostCoreShow();
    KayokoCancelAllTouches();
}

static void KayokoDiscardSwipeUpGestureRecognizer(UIView *view);
static void KayokoSetManualSwipeUpActive(UIWindow *window, BOOL active);

@interface KayokoSwipeUpGestureHandler : NSObject <UIGestureRecognizerDelegate>
- (instancetype)initWithView:(UIView *)view keyboardExtension:(BOOL)keyboardExtension;
- (void)handleSwipeUpGesture:(UISwipeGestureRecognizer *)recognizer;
@end

@interface KayokoSwipeUpGestureHandler ()
@property(nonatomic, weak, readonly) UIView *view;
@property(nonatomic, assign, readonly, getter=isKeyboardExtension) BOOL keyboardExtension;
@end

@implementation KayokoSwipeUpGestureHandler

- (instancetype)initWithView:(UIView *)view keyboardExtension:(BOOL)keyboardExtension {
    self = [super init];
    if (self) {
        _view = view;
        _keyboardExtension = keyboardExtension;
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    UIView *view = self.view;
    if (!view || gestureRecognizer != objc_getAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey)) {
        return YES;
    }

    return KayokoPointIsInsideAllowedSwipeRegion(view, [touch locationInView:view]);
}

- (void)handleSwipeUpGesture:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    if (self.isKeyboardExtension) {
        HBLogDebug(@"Kayoko: manual-feed swipe recognizer action state=%ld", (long)recognizer.state);
        UIWindow *window = (UIWindow *)recognizer.view;
        if ([window isKindOfClass:[UIWindow class]]) {
            KayokoSetManualSwipeUpActive(window, NO);
            KayokoDiscardSwipeUpGestureRecognizer(window);
            HBLogDebug(@"Kayoko: discarded manual-feed swipe recognizer after recognition");
        }
    }

    KayokoShowKayokoAndCancelTouches();
}

@end

static KayokoSwipeUpGestureHandler *KayokoSwipeUpGestureHandlerForView(UIView *view, BOOL keyboardExtension) {
    KayokoSwipeUpGestureHandler *handler = objc_getAssociatedObject(view, &kKayokoSwipeUpGestureHandlerKey);
    if (handler) {
        return handler;
    }

    handler = [[KayokoSwipeUpGestureHandler alloc] initWithView:view keyboardExtension:keyboardExtension];
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return handler;
}

static UISwipeGestureRecognizer *KayokoEnsureSwipeUpGestureRecognizer(UIView *view, BOOL keyboardExtension) {
    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey);
    if (recognizer) {
        return recognizer;
    }

    KayokoSwipeUpGestureHandler *handler = KayokoSwipeUpGestureHandlerForView(view, keyboardExtension);
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:handler action:@selector(handleSwipeUpGesture:)];
    recognizer.direction = UISwipeGestureRecognizerDirectionUp;
    recognizer.numberOfTouchesRequired = 1;
    recognizer.cancelsTouchesInView = NO;
    recognizer.delegate = handler;
    [view addGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return recognizer;
}

static void KayokoDiscardSwipeUpGestureRecognizer(UIView *view) {
    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        return;
    }

    [view removeGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureHandlerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL KayokoManualSwipeUpIsActive(UIWindow *window) {
    NSNumber *active = objc_getAssociatedObject(window, &kKayokoManualSwipeUpActiveKey);
    return [active boolValue];
}

static void KayokoSetManualSwipeUpActive(UIWindow *window, BOOL active) {
    objc_setAssociatedObject(window, &kKayokoManualSwipeUpActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSSet<UITouch *> *KayokoTouchesForWindow(UIWindow *window, UIEvent *event) {
    NSMutableSet<UITouch *> *touches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == window) {
            [touches addObject:touch];
        }
    }
    return touches;
}

static NSSet<UITouch *> *KayokoTouchesForWindowWithPhase(UIWindow *window, UIEvent *event, UITouchPhase phase) {
    NSMutableSet<UITouch *> *touches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == window && touch.phase == phase) {
            [touches addObject:touch];
        }
    }
    return touches;
}

static void KayokoManuallyFeedSwipeUpRecognizerInKeyboardWindow(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSSet<UITouch *> *windowTouches = KayokoTouchesForWindow(window, event);
    if (windowTouches.count > 1) {
        if (KayokoManualSwipeUpIsActive(window)) {
            UISwipeGestureRecognizer *recognizer =
                objc_getAssociatedObject(window, &kKayokoSwipeUpGestureRecognizerKey);
            [recognizer touchesCancelled:windowTouches withEvent:event];
            KayokoSetManualSwipeUpActive(window, NO);
            KayokoDiscardSwipeUpGestureRecognizer(window);
        }
        return;
    }

    NSSet<UITouch *> *beganTouches = KayokoTouchesForWindowWithPhase(window, event, UITouchPhaseBegan);
    if (beganTouches.count > 0) {
        UITouch *touch = [beganTouches anyObject];
        BOOL active =
            beganTouches.count == 1 && KayokoPointIsInsideAllowedSwipeRegion(window, [touch locationInView:window]);
        KayokoSetManualSwipeUpActive(window, active);
        HBLogDebug(@"Kayoko: manual swipe recognizer began active=%@", active ? @"YES" : @"NO");
        if (active) {
            KayokoDiscardSwipeUpGestureRecognizer(window);
            UISwipeGestureRecognizer *recognizer = KayokoEnsureSwipeUpGestureRecognizer(window, YES);
            HBLogDebug(@"Kayoko: installed manual-feed swipe recognizer on _UIHostedWindow from began");
            [recognizer touchesBegan:beganTouches withEvent:event];
        }
        return;
    }

    if (!KayokoManualSwipeUpIsActive(window)) {
        return;
    }

    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(window, &kKayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        KayokoSetManualSwipeUpActive(window, NO);
        return;
    }

    NSSet<UITouch *> *movedTouches = KayokoTouchesForWindowWithPhase(window, event, UITouchPhaseMoved);
    if (movedTouches.count > 0) {
        [recognizer touchesMoved:movedTouches withEvent:event];
    }

    NSSet<UITouch *> *endedTouches = KayokoTouchesForWindowWithPhase(window, event, UITouchPhaseEnded);
    if (endedTouches.count > 0) {
        [recognizer touchesEnded:endedTouches withEvent:event];
        KayokoSetManualSwipeUpActive(window, NO);
        KayokoDiscardSwipeUpGestureRecognizer(window);
    }

    NSSet<UITouch *> *cancelledTouches = KayokoTouchesForWindowWithPhase(window, event, UITouchPhaseCancelled);
    if (cancelledTouches.count > 0) {
        [recognizer touchesCancelled:cancelledTouches withEvent:event];
        KayokoSetManualSwipeUpActive(window, NO);
        KayokoDiscardSwipeUpGestureRecognizer(window);
    }
}

CHOptimizedMethod0(self, void, UIInputSetHostView, didMoveToWindow) {
    CHSuper0(UIInputSetHostView, didMoveToWindow);

    if (!self.window) {
        return;
    }

    KayokoEnsureSwipeUpGestureRecognizer(self, NO);
}

CHOptimizedMethod1(self, void, _UIHostedWindow, sendEvent, UIEvent *, event) {
    KayokoManuallyFeedSwipeUpRecognizerInKeyboardWindow(self, event);
    CHSuper1(_UIHostedWindow, sendEvent, event);
}

void EnableKayokoActivationSwipeUp(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&UIInputSetHostView$, NSClassFromString(@"UIInputSetHostView"));

      CHHook0(UIInputSetHostView, didMoveToWindow);
    });
}

void EnableKayokoActivationSwipeUpForKeyboardExtension(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&_UIHostedWindow$, NSClassFromString(@"_UIHostedWindow"));

      CHHook1(_UIHostedWindow, sendEvent);
    });
}
