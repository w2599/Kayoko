#define CHUseSubstrate

#import <CaptainHook/CaptainHook.h>
#import <HBLog.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

#import "KayokoHelper.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"

#define ITEM_ID "com.82flex.kayoko.globe"

CHDeclareClass(UIInputSwitcherView);
CHDeclareClass(UIKeyboardDockItem);
CHDeclareClass(UIKeyboardDockItemButton);
CHDeclareClass(UISystemKeyboardDockController);
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

@interface UIInputSwitcherView : UIView
@end

@interface UIKeyboardDockItem : NSObject
- (id)initWithImageName:(id)arg1 identifier:(id)arg2;
- (void)setImageName:(NSString *)arg1;
@end

@interface UIKeyboardDockItemButton : UIButton
@end

@interface UISystemKeyboardDockController : NSObject
@end

@interface UIInputSetHostView : UIView
@end

@interface _UIHostedWindow : UIWindow
@end

static Ivar kayokoInstanceIvar(id object, const char *name) {
    return class_getInstanceVariable(object_getClass(object), name);
}

static id kayokoObjectIvar(id object, const char *name) {
    Ivar ivar = kayokoInstanceIvar(object, name);
    if (!ivar) {
        return nil;
    }

    return object_getIvar(object, ivar);
}

static void kayokoSetObjectIvar(id object, const char *name, id value) {
    Ivar ivar = kayokoInstanceIvar(object, name);
    if (!ivar) {
        return;
    }

    object_setIvar(object, ivar, value);
}

static BOOL kayokoBoolIvar(id object, const char *name) {
    Ivar ivar = kayokoInstanceIvar(object, name);
    if (!ivar) {
        return NO;
    }

    return *(BOOL *)((uint8_t *)(__bridge void *)object + ivar_getOffset(ivar));
}

static CGRect kayokoSwipeAllowedBoundsForView(UIView *view) {
    UIEdgeInsets safeAreaInsets = view.safeAreaInsets;
    safeAreaInsets.bottom += kKayokoSwipeUpAdditionalBottomSafetyInset;
    CGRect allowedBounds = UIEdgeInsetsInsetRect(view.bounds, safeAreaInsets);
    if (CGRectGetWidth(allowedBounds) <= 0 || CGRectGetHeight(allowedBounds) <= 0) {
        return CGRectNull;
    }

    return allowedBounds;
}

static BOOL kayokoPointIsInsideAllowedSwipeRegion(UIView *view, CGPoint point) {
    CGRect allowedBounds = kayokoSwipeAllowedBoundsForView(view);
    if (CGRectIsNull(allowedBounds)) {
        return NO;
    }

    return CGRectContainsPoint(allowedBounds, point);
}

static id kayokoSharedApplication(void) {
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

static void kayokoCancelAllTouches(void) {
    id application = kayokoSharedApplication();
    SEL cancelAllTouchesSelector = NSSelectorFromString(@"_cancelAllTouches");
    if (![application respondsToSelector:cancelAllTouchesSelector]) {
        return;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [application performSelector:cancelAllTouchesSelector];
#pragma clang diagnostic pop
}

static void kayokoShowKayokoAndCancelTouches(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    kayokoCancelAllTouches();
}

static void kayokoDiscardSwipeUpGestureRecognizer(UIView *view);
static void kayokoSetManualSwipeUpActive(UIWindow *window, BOOL active);

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

    return kayokoPointIsInsideAllowedSwipeRegion(view, [touch locationInView:view]);
}

- (void)handleSwipeUpGesture:(UISwipeGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateRecognized) {
        return;
    }

    if (self.isKeyboardExtension) {
        HBLogDebug(@"Kayoko: manual-feed swipe recognizer action state=%ld", (long)recognizer.state);
        UIWindow *window = (UIWindow *)recognizer.view;
        if ([window isKindOfClass:[UIWindow class]]) {
            kayokoSetManualSwipeUpActive(window, NO);
            kayokoDiscardSwipeUpGestureRecognizer(window);
            HBLogDebug(@"Kayoko: discarded manual-feed swipe recognizer after recognition");
        }
    }

    kayokoShowKayokoAndCancelTouches();
}

@end

static KayokoSwipeUpGestureHandler *kayokoSwipeUpGestureHandlerForView(UIView *view, BOOL keyboardExtension) {
    KayokoSwipeUpGestureHandler *handler = objc_getAssociatedObject(view, &kKayokoSwipeUpGestureHandlerKey);
    if (handler) {
        return handler;
    }

    handler = [[KayokoSwipeUpGestureHandler alloc] initWithView:view keyboardExtension:keyboardExtension];
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureHandlerKey, handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return handler;
}

static UISwipeGestureRecognizer *kayokoEnsureSwipeUpGestureRecognizer(UIView *view, BOOL keyboardExtension) {
    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey);
    if (recognizer) {
        return recognizer;
    }

    KayokoSwipeUpGestureHandler *handler = kayokoSwipeUpGestureHandlerForView(view, keyboardExtension);
    recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:handler action:@selector(handleSwipeUpGesture:)];
    recognizer.direction = UISwipeGestureRecognizerDirectionUp;
    recognizer.numberOfTouchesRequired = 1;
    recognizer.cancelsTouchesInView = NO;
    recognizer.delegate = handler;
    [view addGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey, recognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return recognizer;
}

static void kayokoDiscardSwipeUpGestureRecognizer(UIView *view) {
    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        return;
    }

    [view removeGestureRecognizer:recognizer];
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureRecognizerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(view, &kKayokoSwipeUpGestureHandlerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL kayokoManualSwipeUpIsActive(UIWindow *window) {
    NSNumber *active = objc_getAssociatedObject(window, &kKayokoManualSwipeUpActiveKey);
    return [active boolValue];
}

static void kayokoSetManualSwipeUpActive(UIWindow *window, BOOL active) {
    objc_setAssociatedObject(window, &kKayokoManualSwipeUpActiveKey, @(active), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSSet<UITouch *> *kayokoTouchesForWindow(UIWindow *window, UIEvent *event) {
    NSMutableSet<UITouch *> *touches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == window) {
            [touches addObject:touch];
        }
    }
    return touches;
}

static NSSet<UITouch *> *kayokoTouchesForWindowWithPhase(UIWindow *window, UIEvent *event, UITouchPhase phase) {
    NSMutableSet<UITouch *> *touches = [NSMutableSet set];
    for (UITouch *touch in [event allTouches]) {
        if (touch.window == window && touch.phase == phase) {
            [touches addObject:touch];
        }
    }
    return touches;
}

static void kayokoManuallyFeedSwipeUpRecognizerInKeyboardWindow(UIWindow *window, UIEvent *event) {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSSet<UITouch *> *windowTouches = kayokoTouchesForWindow(window, event);
    if (windowTouches.count > 1) {
        if (kayokoManualSwipeUpIsActive(window)) {
            UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(window, &kKayokoSwipeUpGestureRecognizerKey);
            [recognizer touchesCancelled:windowTouches withEvent:event];
            kayokoSetManualSwipeUpActive(window, NO);
            kayokoDiscardSwipeUpGestureRecognizer(window);
        }
        return;
    }

    NSSet<UITouch *> *beganTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseBegan);
    if (beganTouches.count > 0) {
        UITouch *touch = [beganTouches anyObject];
        BOOL active = beganTouches.count == 1 && kayokoPointIsInsideAllowedSwipeRegion(window, [touch locationInView:window]);
        kayokoSetManualSwipeUpActive(window, active);
        HBLogDebug(@"Kayoko: manual swipe recognizer began active=%@", active ? @"YES" : @"NO");
        if (active) {
            kayokoDiscardSwipeUpGestureRecognizer(window);
            UISwipeGestureRecognizer *recognizer = kayokoEnsureSwipeUpGestureRecognizer(window, YES);
            HBLogDebug(@"Kayoko: installed manual-feed swipe recognizer on _UIHostedWindow from began");
            [recognizer touchesBegan:beganTouches withEvent:event];
        }
        return;
    }

    if (!kayokoManualSwipeUpIsActive(window)) {
        return;
    }

    UISwipeGestureRecognizer *recognizer = objc_getAssociatedObject(window, &kKayokoSwipeUpGestureRecognizerKey);
    if (!recognizer) {
        kayokoSetManualSwipeUpActive(window, NO);
        return;
    }

    NSSet<UITouch *> *movedTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseMoved);
    if (movedTouches.count > 0) {
        [recognizer touchesMoved:movedTouches withEvent:event];
    }

    NSSet<UITouch *> *endedTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseEnded);
    if (endedTouches.count > 0) {
        [recognizer touchesEnded:endedTouches withEvent:event];
        kayokoSetManualSwipeUpActive(window, NO);
        kayokoDiscardSwipeUpGestureRecognizer(window);
    }

    NSSet<UITouch *> *cancelledTouches = kayokoTouchesForWindowWithPhase(window, event, UITouchPhaseCancelled);
    if (cancelledTouches.count > 0) {
        [recognizer touchesCancelled:cancelledTouches withEvent:event];
        kayokoSetManualSwipeUpActive(window, NO);
        kayokoDiscardSwipeUpGestureRecognizer(window);
    }
}

@interface UIInputSwitcherItem : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *localizedSubtitle;
@property(nonatomic, strong) UIFont *titleFont;
@property(nonatomic, strong) UIFont *subtitleFont;
@property(assign, nonatomic) BOOL usesDeviceLanguage;
@property(nonatomic, strong) UISwitch *switchControl;
@property(nonatomic, copy) id switchIsOnBlock;
@property(nonatomic, copy) id switchToggleBlock;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

CHOptimizedMethod0(self, void, UIInputSwitcherView, _reloadInputSwitcherItems) {
    CHSuper0(UIInputSwitcherView, _reloadInputSwitcherItems);
    BOOL isForDictation = kayokoBoolIvar(self, "m_isForDictation");
    if (isForDictation) {
        return;
    }
    NSArray *items = kayokoObjectIvar(self, "m_inputSwitcherItems");
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];
    UIInputSwitcherItem *item = [[NSClassFromString(@"UIInputSwitcherItem") alloc] initWithIdentifier:@ITEM_ID];
    [item setLocalizedTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Kayoko"
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
    if (item) {
        [newItems insertObject:item atIndex:newItems.count - 1];
    }
    kayokoSetObjectIvar(self, "m_inputSwitcherItems", newItems);
}

CHOptimizedMethod1(self, void, UIInputSwitcherView, didSelectItemAtIndex, unsigned long long, index) {
    NSArray *items = kayokoObjectIvar(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:@ITEM_ID]) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    }
    CHSuper1(UIInputSwitcherView, didSelectItemAtIndex, index);
}

CHOptimizedMethod2(self, id, UIKeyboardDockItem, initWithImageName, id, arg1, identifier, id, arg2) {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    return CHSuper2(UIKeyboardDockItem, initWithImageName, arg1, identifier, arg2);
}

CHOptimizedMethod1(self, void, UIKeyboardDockItem, setImageName, NSString *, arg1) {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    CHSuper1(UIKeyboardDockItem, setImageName, arg1);
}

CHOptimizedMethod1(self, CGRect, UIKeyboardDockItemButton, imageRectForContentRect, CGRect, arg1) {
    CGRect origRect = CHSuper1(UIKeyboardDockItemButton, imageRectForContentRect, arg1);
    if (@available(iOS 16, *)) {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.92, origRect.size.height * 0.92);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2, origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    } else {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.86, origRect.size.height * 0.86);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2, origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    }
    return origRect;
}

CHOptimizedMethod3(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, arg1,
                   withEvent, id, arg2, isRunningButton, BOOL, arg3) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

CHOptimizedMethod0(self, void, UIInputSetHostView, didMoveToWindow) {
    CHSuper0(UIInputSetHostView, didMoveToWindow);

    if (!self.window) {
        return;
    }

    kayokoEnsureSwipeUpGestureRecognizer(self, NO);
}

CHOptimizedMethod1(self, void, _UIHostedWindow, sendEvent, UIEvent *, event) {
    kayokoManuallyFeedSwipeUpRecognizerInKeyboardWindow(self, event);
    CHSuper1(_UIHostedWindow, sendEvent, event);
}

void EnableKayokoActivationGlobe(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        CHLoadClass_(&UIInputSwitcherView$, NSClassFromString(@"UIInputSwitcherView"));

        CHHook0(UIInputSwitcherView, _reloadInputSwitcherItems);
        CHHook1(UIInputSwitcherView, didSelectItemAtIndex);
    });
}

void EnableKayokoActivationDictation(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
        CHLoadClass_(&UIKeyboardDockItem$, NSClassFromString(@"UIKeyboardDockItem"));
        CHLoadClass_(&UIKeyboardDockItemButton$, NSClassFromString(@"UIKeyboardDockItemButton"));
        CHLoadClass_(&UISystemKeyboardDockController$, NSClassFromString(@"UISystemKeyboardDockController"));

        CHHook2(UIKeyboardDockItem, initWithImageName, identifier);
        CHHook1(UIKeyboardDockItem, setImageName);
        CHHook1(UIKeyboardDockItemButton, imageRectForContentRect);
        CHHook3(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent, isRunningButton);
    });
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
