//
//  KayokoHelperRuntime.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelperRuntime.h"

#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

#import <AudioToolbox/AudioToolbox.h>
#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

CHDeclareClass(UIKeyboardLayoutStar);
CHDeclareClass(UIKBInputBackdropView);
CHDeclareClass(UIKeyboardImpl);
CHDeclareClass(UISearchBar);
CHDeclareClass(UITextField);

static const NSTimeInterval kKayokoPendingPasteExpirationDelay = 2.8;
static const NSTimeInterval kKayokoKeyboardHideSuppressionInterval = 1.0;

@interface UIKeyboardLayoutStar : UIView
@end

@interface UIKBInputBackdropView : UIView
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
@property(nonatomic, strong, readonly) id inputDelegate;
@end

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperFocusSession : NSObject
@property(nonatomic, assign, getter=hasCapturedFocusSession) BOOL capturedFocusSession;
@property(nonatomic, weak, nullable) UIResponder *firstResponder;
@property(nonatomic, weak, nullable) UIResponder *keyboardInputDelegate;
@property(nonatomic, weak, nullable) UIWindow *keyWindow;
- (void)clear;
- (void)finishCapturing;
- (BOOL)matchesKeyWindow:(UIWindow *)keyWindow;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHelperFocusSession

- (void)clear {
    self.capturedFocusSession = NO;
    self.firstResponder = nil;
    self.keyboardInputDelegate = nil;
    self.keyWindow = nil;
}

- (void)finishCapturing {
    self.capturedFocusSession = self.keyboardInputDelegate || self.firstResponder;
}

- (BOOL)matchesKeyWindow:(UIWindow *)keyWindow {
    UIWindow *capturedKeyWindow = self.keyWindow;
    return !capturedKeyWindow || capturedKeyWindow == keyWindow;
}

@end

@interface KayokoHelperPendingPasteSession : NSObject
@property(nonatomic, assign, getter=hasPendingPaste) BOOL pendingPaste;
@property(nonatomic, assign) BOOL canExecute;
@property(nonatomic, assign) BOOL requiresKeyboardDelegate;
@property(nonatomic, assign) NSUInteger token;
@property(nonatomic, weak, nullable) UIResponder *responder;
@property(nonatomic, weak, nullable) UIWindow *keyWindow;
- (void)clear;
@end

@implementation KayokoHelperPendingPasteSession

- (void)clear {
    self.pendingPaste = NO;
    self.canExecute = NO;
    self.requiresKeyboardDelegate = NO;
    self.responder = nil;
    self.keyWindow = nil;
}

@end

@class KayokoKeyboardObserver;

@interface KayokoHelperRuntime ()

@property(nonatomic, assign, getter=isSpringBoardRuntime) BOOL springBoardRuntime;
@property(nonatomic, assign, getter=isAutomaticallyPasteEnabled) BOOL automaticallyPasteEnabled;
@property(nonatomic, assign, getter=isHapticFeedbackEnabled) BOOL hapticFeedbackEnabled;
@property(nonatomic, assign) BOOL applicationInForeground;
@property(nonatomic, strong) KayokoHelperFocusSession *focusSession;
@property(nonatomic, strong) KayokoHelperPendingPasteSession *pendingPasteSession;
@property(nonatomic, assign) BOOL lastKeyboardInputWasKayokoOwned;
@property(nonatomic, assign) NSTimeInterval lastKayokoKeyboardInputTime;
@property(nonatomic, weak, nullable) UIResponder *resolvedCurrentFirstResponder;
@property(nonatomic, strong, nullable) KayokoKeyboardObserver *keyboardObserver;
@property(nonatomic, assign, getter=hasInstalledObservers) BOOL installedObservers;

#pragma mark - Runtime Hook Events

- (void)keyboardWindowDidMoveToWindow;
- (void)keyboardImplDidBecomeActive;
- (void)keyboardImplWillLeaveActive;
- (void)keyboardImplDidSetDelegate:(id)delegate;
- (void)rememberResponderWillResign:(UIResponder *)responder;

#pragma mark - Keyboard Notifications

- (void)windowDidResignKeyWithNotification:(NSNotification *)notification;
- (void)keyboardWillHideWithNotification:(NSNotification *)notification;
- (void)keyboardDidShowWithNotification:(NSNotification *)notification;

#pragma mark - Darwin Notifications

- (void)postCoreShow;
- (void)postCoreHide;
- (void)showKayoko;
- (void)showKayokoAfterCapturingCurrentFocus;
- (void)showKayokoFromResponder:(UIResponder *)responder;

#pragma mark - Application And Window State

- (UIWindow *)activeKeyWindowForApplication:(UIApplication *)application;
- (BOOL)applicationHasActiveKeyWindow:(UIApplication *)application;
- (UIWindow *)capturedFocusKeyWindowForSpringBoard;
- (BOOL)makeCapturedFocusKeyWindowKeyIfNeeded:(UIWindow *)keyWindow;
- (UIWindow *)keyWindowForRestoringCapturedFocusInApplication:(UIApplication *)application;
- (BOOL)applicationHasPasteContext:(UIApplication *)application;
- (BOOL)applicationCanPerformPaste:(UIApplication *)application;

#pragma mark - Keyboard State

- (UIKeyboardImpl *)activeKeyboardImpl;
- (UIResponder *)activeKeyboardInputDelegate;

#pragma mark - SpringBoard Input Isolation

- (BOOL)objectHasKayokoClassPrefix:(id)object;
- (BOOL)viewHierarchyIsKayokoOwned:(UIView *)view;
- (BOOL)responderIsKayokoOwned:(UIResponder *)responder;
- (BOOL)shouldHandleActivationForCurrentInput;
- (void)playActivationRejectedFeedbackIfNeeded;
- (void)rememberKayokoKeyboardInput;
- (void)clearLastKayokoKeyboardInput;
- (BOOL)hasRecentKayokoKeyboardInput;
- (UIResponder *)currentFirstResponder;
- (UIResponder *)currentKayokoInputResponder;
- (BOOL)currentInputIsKayokoOwnedUpdatingLast:(BOOL)clearsLastForExternalInput;
- (BOOL)currentInputIsKayokoOwned;
- (BOOL)keyboardHideIsFromKayokoInput;

#pragma mark - Focus Capture And Restore

- (UIResponder *)restorableKeyboardInputDelegate;
- (BOOL)restoreResponder:(UIResponder *)responder;
- (void)captureFocusSessionInKeyWindow:(UIWindow *)keyWindow;
- (void)captureFocusSessionFromResponder:(UIResponder *)responder keyWindow:(UIWindow *)keyWindow;
- (void)captureResponderForFocusRestore:(UIResponder *)responder;
- (BOOL)restoreCapturedFocusSessionInKeyWindow:(UIWindow *)keyWindow;

#pragma mark - Pending Paste

- (UIResponder *)capturedFocusResponderForPasteRequiringKeyboardDelegate:(BOOL *)requiresKeyboardDelegate;
- (void)postPasteWillStart;
- (BOOL)preparePasteboardForPaste;
- (BOOL)pasteIntoKayokoInputResponder:(UIResponder *)responder;
- (void)performPaste;
- (BOOL)pendingPasteIsReady;
- (void)attemptPendingPaste;
- (void)schedulePendingPasteCheck;
- (BOOL)beginPendingPaste;

#pragma mark - Installation

- (void)installRuntimeHooks;
- (void)installSpringBoardInputIsolationHooks;
- (void)installRuntimeObserversObservingWindowResign:(BOOL)observesWindowResign;

@end

@interface KayokoKeyboardObserver : NSObject
- (instancetype)initWithRuntime:(KayokoHelperRuntime *)runtime;
@end

static CFStringRef kayokoHelperNotificationName(NSString *name) { return (__bridge CFStringRef)name; }

static void kayokoHelperPasteNotificationCallback(CFNotificationCenterRef center, void *observer,
                                                  CFNotificationName name, const void *object,
                                                  CFDictionaryRef userInfo) {
    [[KayokoHelperRuntime sharedRuntime] paste];
}

static void kayokoHelperCaptureFocusNotificationCallback(CFNotificationCenterRef center, void *observer,
                                                         CFNotificationName name, const void *object,
                                                         CFDictionaryRef userInfo) {
    [[KayokoHelperRuntime sharedRuntime] captureCurrentFirstResponder];
}

static void kayokoHelperRestoreFocusNotificationCallback(CFNotificationCenterRef center, void *observer,
                                                         CFNotificationName name, const void *object,
                                                         CFDictionaryRef userInfo) {
    [[KayokoHelperRuntime sharedRuntime] restoreCapturedFirstResponder];
}

CHOptimizedMethod0(self, void, UIKeyboardLayoutStar, didMoveToWindow) {
    CHSuper0(UIKeyboardLayoutStar, didMoveToWindow);
    [[KayokoHelperRuntime sharedRuntime] keyboardWindowDidMoveToWindow];
}

CHOptimizedMethod0(self, void, UIKBInputBackdropView, didMoveToWindow) {
    CHSuper0(UIKBInputBackdropView, didMoveToWindow);
    [[KayokoHelperRuntime sharedRuntime] keyboardWindowDidMoveToWindow];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationDidBecomeActive, BOOL, didBecomeActive) {
    CHSuper1(UIKeyboardImpl, applicationDidBecomeActive, didBecomeActive);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplDidBecomeActive];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillResignActive, BOOL, willResignActive) {
    CHSuper1(UIKeyboardImpl, applicationWillResignActive, willResignActive);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplWillLeaveActive];
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillSuspend, BOOL, willSuspend) {
    CHSuper1(UIKeyboardImpl, applicationWillSuspend, willSuspend);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplWillLeaveActive];
}

CHOptimizedMethod3(self, void, UIKeyboardImpl, setDelegate, id, delegate, force, BOOL, force, fromBecomeFirstResponder,
                   BOOL, fromBecomeFirstResponder) {
    CHSuper3(UIKeyboardImpl, setDelegate, delegate, force, force, fromBecomeFirstResponder, fromBecomeFirstResponder);
    [[KayokoHelperRuntime sharedRuntime] keyboardImplDidSetDelegate:delegate];
}

CHOptimizedMethod0(self, BOOL, UISearchBar, resignFirstResponder) {
    [[KayokoHelperRuntime sharedRuntime] rememberResponderWillResign:self];
    return CHSuper0(UISearchBar, resignFirstResponder);
}

CHOptimizedMethod0(self, BOOL, UITextField, resignFirstResponder) {
    [[KayokoHelperRuntime sharedRuntime] rememberResponderWillResign:self];
    return CHSuper0(UITextField, resignFirstResponder);
}

@implementation KayokoHelperRuntime

#pragma mark - Lifecycle

+ (instancetype)sharedRuntime {
    static KayokoHelperRuntime *runtime;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      runtime = [[self alloc] initPrivate];
    });
    return runtime;
}

- (instancetype)initPrivate {
    self = [super init];
    if (self) {
        _applicationInForeground = YES;
        _focusSession = [[KayokoHelperFocusSession alloc] init];
        _pendingPasteSession = [[KayokoHelperPendingPasteSession alloc] init];
    }
    return self;
}

#pragma mark - Runtime Installation Entry Points

- (void)installApplicationRuntimeWithConfiguration:(KayokoHelperConfiguration *)configuration {
    self.springBoardRuntime = NO;
    self.automaticallyPasteEnabled = configuration.automaticallyPasteEnabled;
    self.hapticFeedbackEnabled = configuration.hapticFeedbackEnabled;
    [self installRuntimeHooks];
    [self installRuntimeObserversObservingWindowResign:YES];
}

- (void)installSpringBoardRuntimeWithConfiguration:(KayokoHelperConfiguration *)configuration {
    self.springBoardRuntime = YES;
    self.automaticallyPasteEnabled = configuration.automaticallyPasteEnabled;
    self.hapticFeedbackEnabled = configuration.hapticFeedbackEnabled;
    [self installSpringBoardInputIsolationHooks];
    [self installRuntimeHooks];
    [self installRuntimeObserversObservingWindowResign:NO];
}

#pragma mark - Public Runtime API

- (void)showKayoko {
    [self postCoreShow];
}

- (void)showKayokoAfterCapturingCurrentFocus {
    [self captureCurrentFirstResponder];
    [self postCoreShow];
}

- (void)showKayokoFromResponder:(UIResponder *)responder {
    if ([responder isKindOfClass:[UIResponder class]] && ![self responderIsKayokoOwned:responder]) {
        [self captureFocusSessionFromResponder:responder
                                     keyWindow:[self activeKeyWindowForApplication:[UIApplication sharedApplication]]];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      [self postCoreShow];
    });
}

- (void)captureCurrentFirstResponder {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *keyWindow = [self activeKeyWindowForApplication:application];
    if (!keyWindow) {
        return;
    }

    if ([self currentInputIsKayokoOwned]) {
        return;
    }

    [self captureFocusSessionInKeyWindow:keyWindow];
    [application sendAction:@selector(kayokoCaptureFirstResponderForFocusRestore:) to:nil from:nil forEvent:nil];
    [self.focusSession finishCapturing];
}

- (void)restoreCapturedFirstResponder {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *keyWindow = [self keyWindowForRestoringCapturedFocusInApplication:application];
    [self restoreCapturedFocusSessionInKeyWindow:keyWindow];
}

- (void)paste {
    if (!self.applicationInForeground) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (![self applicationHasPasteContext:application]) {
        return;
    }

    BOOL hasPendingPaste = [self beginPendingPaste];
    [self restoreCapturedFirstResponder];

    if (hasPendingPaste) {
        self.pendingPasteSession.canExecute = YES;
        [self schedulePendingPasteCheck];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self performPaste];
        });
    }
}

- (BOOL)activateKayoko {
    if (![self shouldHandleActivationForCurrentInput]) {
        [self playActivationRejectedFeedbackIfNeeded];
        return NO;
    }

    [self showKayoko];
    return YES;
}

- (BOOL)activateKayokoAfterCapturingCurrentFocus {
    if (![self shouldHandleActivationForCurrentInput]) {
        [self playActivationRejectedFeedbackIfNeeded];
        return NO;
    }

    [self showKayokoAfterCapturingCurrentFocus];
    return YES;
}

- (BOOL)activateKayokoFromResponder:(UIResponder *)responder {
    if (![self shouldHandleActivationForCurrentInput]) {
        [self playActivationRejectedFeedbackIfNeeded];
        return NO;
    }

    [self showKayokoFromResponder:responder];
    return YES;
}

- (void)pasteFromPredictionBar {
    UIResponder *responder = [self currentKayokoInputResponder];
    if (responder) {
        [self pasteIntoKayokoInputResponder:responder];
        return;
    }

    [self paste];
}

#pragma mark - Runtime Hook Events

- (void)keyboardWindowDidMoveToWindow {
    if ([self keyboardHideIsFromKayokoInput]) {
        return;
    }
    [self postCoreHide];
}

- (void)keyboardImplDidBecomeActive {
    self.applicationInForeground = YES;
    [self schedulePendingPasteCheck];
}

- (void)keyboardImplWillLeaveActive {
    self.applicationInForeground = NO;
    [self.pendingPasteSession clear];
}

- (void)keyboardImplDidSetDelegate:(id)delegate {
    if ([delegate isKindOfClass:[UIResponder class]] && [self responderIsKayokoOwned:(UIResponder *)delegate]) {
        [self rememberKayokoKeyboardInput];
        return;
    }
    if ([delegate isKindOfClass:[UIResponder class]] && self.isSpringBoardRuntime) {
        [self clearLastKayokoKeyboardInput];
    }
    [self attemptPendingPaste];
}

- (void)rememberResponderWillResign:(UIResponder *)responder {
    if ([self responderIsKayokoOwned:responder]) {
        [self rememberKayokoKeyboardInput];
    }
}

#pragma mark - Keyboard Notifications

- (void)windowDidResignKeyWithNotification:(NSNotification *)notification {
    if ([self keyboardHideIsFromKayokoInput]) {
        return;
    }
    [self postCoreHide];
}

- (void)keyboardWillHideWithNotification:(NSNotification *)notification {
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    BOOL isLocalKeyboard = [userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocalKeyboard) {
        return;
    }

    if ([self keyboardHideIsFromKayokoInput]) {
        return;
    }

    [self postCoreHide];
}

- (void)keyboardDidShowWithNotification:(NSNotification *)notification {
    if ([self currentInputIsKayokoOwned]) {
        return;
    }
    [self attemptPendingPaste];
}

#pragma mark - Darwin Notifications

- (void)postCoreShow {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         kayokoHelperNotificationName(kKayokoNotificationKeyCoreShow), nil, nil, YES);
}

- (void)postCoreHide {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         kayokoHelperNotificationName(kKayokoNotificationKeyCoreHide), nil, nil, YES);
}

#pragma mark - Application And Window State

- (UIWindow *)activeKeyWindowForApplication:(UIApplication *)application {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return nil;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [application connectedScenes]) {
            if ([scene activationState] != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                if ([window isKeyWindow]) {
                    return window;
                }
            }
        }

        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *keyWindow = [application keyWindow];
#pragma clang diagnostic pop
    return [keyWindow isKeyWindow] ? keyWindow : nil;
}

- (BOOL)applicationHasActiveKeyWindow:(UIApplication *)application {
    return [self activeKeyWindowForApplication:application] != nil;
}

- (UIWindow *)capturedFocusKeyWindowForSpringBoard {
    if (!self.isSpringBoardRuntime || !self.focusSession.hasCapturedFocusSession) {
        return nil;
    }

    return self.focusSession.keyWindow;
}

- (BOOL)makeCapturedFocusKeyWindowKeyIfNeeded:(UIWindow *)keyWindow {
    UIWindow *capturedKeyWindow = [self capturedFocusKeyWindowForSpringBoard];
    if (!capturedKeyWindow || keyWindow != capturedKeyWindow || [keyWindow isKeyWindow]) {
        return YES;
    }

    [keyWindow makeKeyWindow];
    return [keyWindow isKeyWindow];
}

- (UIWindow *)keyWindowForRestoringCapturedFocusInApplication:(UIApplication *)application {
    UIWindow *activeKeyWindow = [self activeKeyWindowForApplication:application];
    UIWindow *capturedKeyWindow = [self capturedFocusKeyWindowForSpringBoard];
    if (!capturedKeyWindow) {
        return activeKeyWindow;
    }

    if (!activeKeyWindow || ![self.focusSession matchesKeyWindow:activeKeyWindow]) {
        return capturedKeyWindow;
    }

    return activeKeyWindow;
}

- (BOOL)applicationHasPasteContext:(UIApplication *)application {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return NO;
    }

    if ([self applicationHasActiveKeyWindow:application]) {
        return YES;
    }

    return [self capturedFocusKeyWindowForSpringBoard] != nil;
}

- (BOOL)applicationCanPerformPaste:(UIApplication *)application {
    if ([self applicationHasActiveKeyWindow:application]) {
        return YES;
    }
    if (!self.isSpringBoardRuntime || ![self capturedFocusKeyWindowForSpringBoard]) {
        return NO;
    }

    return [self pendingPasteIsReady];
}

#pragma mark - Keyboard State

- (UIKeyboardImpl *)activeKeyboardImpl {
    Class keyboardImplClass = NSClassFromString(@"UIKeyboardImpl");
    SEL activeInstanceSelector = @selector(activeInstance);
    if (![keyboardImplClass respondsToSelector:activeInstanceSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [keyboardImplClass performSelector:activeInstanceSelector];
#pragma clang diagnostic pop
}

- (UIResponder *)activeKeyboardInputDelegate {
    UIKeyboardImpl *keyboardImpl = [self activeKeyboardImpl];
    SEL inputDelegateSelector = @selector(inputDelegate);
    if (![keyboardImpl respondsToSelector:inputDelegateSelector]) {
        return nil;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    id inputDelegate = [keyboardImpl performSelector:inputDelegateSelector];
#pragma clang diagnostic pop
    if (![inputDelegate isKindOfClass:[UIResponder class]]) {
        return nil;
    }

    return inputDelegate;
}

#pragma mark - SpringBoard Input Isolation

- (BOOL)objectHasKayokoClassPrefix:(id)object {
    if (!self.isSpringBoardRuntime || !object) {
        return NO;
    }

    Class cls = [object class];
    while (cls) {
        if ([NSStringFromClass(cls) hasPrefix:@"Kayoko"]) {
            return YES;
        }
        cls = class_getSuperclass(cls);
    }
    return NO;
}

- (BOOL)viewHierarchyIsKayokoOwned:(UIView *)view {
    if (!self.isSpringBoardRuntime) {
        return NO;
    }

    NSUInteger depth = 0;
    while (view && depth < 64) {
        if ([self objectHasKayokoClassPrefix:view]) {
            return YES;
        }
        view = [view superview];
        depth++;
    }
    return NO;
}

- (BOOL)responderIsKayokoOwned:(UIResponder *)responder {
    if (!self.isSpringBoardRuntime || !responder) {
        return NO;
    }

    UIResponder *currentResponder = responder;
    NSUInteger depth = 0;
    while (currentResponder && depth < 64) {
        if ([self objectHasKayokoClassPrefix:currentResponder]) {
            return YES;
        }
        if ([currentResponder isKindOfClass:[UIView class]] &&
            [self viewHierarchyIsKayokoOwned:[(UIView *)currentResponder superview]]) {
            return YES;
        }
        currentResponder = [currentResponder nextResponder];
        depth++;
    }
    return NO;
}

- (BOOL)shouldHandleActivationForCurrentInput {
    if (!self.isSpringBoardRuntime) {
        return YES;
    }

    return ![self currentInputIsKayokoOwned];
}

- (void)playActivationRejectedFeedbackIfNeeded {
    if (self.isHapticFeedbackEnabled) {
        AudioServicesPlaySystemSound(1521);
    }
}

- (void)rememberKayokoKeyboardInput {
    self.lastKeyboardInputWasKayokoOwned = YES;
    self.lastKayokoKeyboardInputTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)clearLastKayokoKeyboardInput {
    self.lastKeyboardInputWasKayokoOwned = NO;
    self.lastKayokoKeyboardInputTime = 0;
}

- (BOOL)hasRecentKayokoKeyboardInput {
    if (!self.lastKeyboardInputWasKayokoOwned) {
        return NO;
    }

    NSTimeInterval elapsed = [NSDate timeIntervalSinceReferenceDate] - self.lastKayokoKeyboardInputTime;
    if (elapsed <= kKayokoKeyboardHideSuppressionInterval) {
        return YES;
    }

    [self clearLastKayokoKeyboardInput];
    return NO;
}

- (UIResponder *)currentFirstResponder {
    if (!self.isSpringBoardRuntime) {
        return nil;
    }

    self.resolvedCurrentFirstResponder = nil;
    [[UIApplication sharedApplication] sendAction:@selector(kayokoResolveCurrentFirstResponder:)
                                               to:nil
                                             from:nil
                                         forEvent:nil];
    return self.resolvedCurrentFirstResponder;
}

- (UIResponder *)currentKayokoInputResponder {
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    if ([self responderIsKayokoOwned:keyboardInputDelegate]) {
        [self rememberKayokoKeyboardInput];
        return keyboardInputDelegate;
    }

    UIResponder *firstResponder = [self currentFirstResponder];
    if ([self responderIsKayokoOwned:firstResponder]) {
        [self rememberKayokoKeyboardInput];
        return firstResponder;
    }

    return nil;
}

- (BOOL)currentInputIsKayokoOwnedUpdatingLast:(BOOL)clearsLastForExternalInput {
    if (!self.isSpringBoardRuntime) {
        return NO;
    }

    BOOL foundCurrentInput = NO;
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    if (keyboardInputDelegate) {
        foundCurrentInput = YES;
        if ([self responderIsKayokoOwned:keyboardInputDelegate]) {
            [self rememberKayokoKeyboardInput];
            return YES;
        }
    }

    UIResponder *firstResponder = [self currentFirstResponder];
    if (firstResponder) {
        foundCurrentInput = YES;
        if ([self responderIsKayokoOwned:firstResponder]) {
            [self rememberKayokoKeyboardInput];
            return YES;
        }
    }

    if (foundCurrentInput) {
        if (clearsLastForExternalInput) {
            [self clearLastKayokoKeyboardInput];
        }
        return NO;
    }

    return NO;
}

- (BOOL)currentInputIsKayokoOwned {
    return [self currentInputIsKayokoOwnedUpdatingLast:YES];
}

- (BOOL)keyboardHideIsFromKayokoInput {
    if (!self.isSpringBoardRuntime) {
        return NO;
    }

    if ([self currentInputIsKayokoOwnedUpdatingLast:NO]) {
        return YES;
    }

    if ([self hasRecentKayokoKeyboardInput]) {
        return YES;
    }

    return NO;
}

#pragma mark - Focus Capture And Restore

- (UIResponder *)restorableKeyboardInputDelegate {
    UIResponder *keyboardInputDelegate = [self activeKeyboardInputDelegate];
    if ([self responderIsKayokoOwned:keyboardInputDelegate]) {
        return nil;
    }
    return keyboardInputDelegate;
}

- (BOOL)restoreResponder:(UIResponder *)responder {
    if ([self responderIsKayokoOwned:responder]) {
        return NO;
    }

    if (!responder) {
        return NO;
    }

    BOOL requiresKeyboardInputDelegate =
        self.isSpringBoardRuntime && responder == self.focusSession.keyboardInputDelegate;
    if (!requiresKeyboardInputDelegate) {
        if ([responder isFirstResponder]) {
            return YES;
        }

        return [responder becomeFirstResponder];
    }

    if ([self activeKeyboardInputDelegate] == responder) {
        return YES;
    }

    if ([responder isFirstResponder]) {
        [responder resignFirstResponder];
        [self makeCapturedFocusKeyWindowKeyIfNeeded:self.focusSession.keyWindow];
    }

    if (![responder becomeFirstResponder]) {
        return NO;
    }

    return [self activeKeyboardInputDelegate] == responder;
}

- (void)captureFocusSessionInKeyWindow:(UIWindow *)keyWindow {
    [self.focusSession clear];
    if (!keyWindow) {
        return;
    }

    self.focusSession.keyWindow = keyWindow;
    self.focusSession.keyboardInputDelegate = [self restorableKeyboardInputDelegate];
}

- (void)captureFocusSessionFromResponder:(UIResponder *)responder keyWindow:(UIWindow *)keyWindow {
    if ([self responderIsKayokoOwned:responder]) {
        return;
    }

    [self captureFocusSessionInKeyWindow:keyWindow];
    self.focusSession.firstResponder = responder;
    [self.focusSession finishCapturing];
}

- (void)captureResponderForFocusRestore:(UIResponder *)responder {
    if ([self responderIsKayokoOwned:responder]) {
        return;
    }

    self.focusSession.firstResponder = responder;
}

- (BOOL)restoreCapturedFocusSessionInKeyWindow:(UIWindow *)keyWindow {
    if (!keyWindow || !self.focusSession.hasCapturedFocusSession || ![self.focusSession matchesKeyWindow:keyWindow]) {
        return NO;
    }

    if (![self makeCapturedFocusKeyWindowKeyIfNeeded:keyWindow]) {
        return NO;
    }

    if ([self restoreResponder:self.focusSession.keyboardInputDelegate]) {
        return YES;
    }

    return [self restoreResponder:self.focusSession.firstResponder];
}

#pragma mark - Pending Paste

- (UIResponder *)capturedFocusResponderForPasteRequiringKeyboardDelegate:(BOOL *)requiresKeyboardDelegate {
    UIResponder *keyboardInputDelegate = self.focusSession.keyboardInputDelegate;
    if (keyboardInputDelegate && ![self responderIsKayokoOwned:keyboardInputDelegate]) {
        if (requiresKeyboardDelegate) {
            *requiresKeyboardDelegate = YES;
        }
        return keyboardInputDelegate;
    }

    if (requiresKeyboardDelegate) {
        *requiresKeyboardDelegate = NO;
    }
    UIResponder *firstResponder = self.focusSession.firstResponder;
    return [self responderIsKayokoOwned:firstResponder] ? nil : firstResponder;
}

- (void)postPasteWillStart {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         kayokoHelperNotificationName(kKayokoNotificationKeyPasteWillStart), nil, nil,
                                         YES);
}

- (BOOL)preparePasteboardForPaste {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if ([pasteboard string] || [pasteboard image]) {
        return YES;
    }

    PasteboardItem *item = [[PasteboardManager sharedInstance] getLatestHistoryItem];
    if (!item) {
        return NO;
    }

    if (![[item imageName] isEqualToString:@""]) {
        [pasteboard setImage:[[PasteboardManager sharedInstance] getImageForItem:item]];
    } else {
        [pasteboard setString:[item content]];
    }

    return YES;
}

- (BOOL)pasteIntoKayokoInputResponder:(UIResponder *)responder {
    if (!responder) {
        return NO;
    }

    UIApplication *activeApplication = [UIApplication sharedApplication];
    if (!activeApplication || [activeApplication applicationState] != UIApplicationStateActive) {
        return NO;
    }

    [self postPasteWillStart];
    if (![self preparePasteboardForPaste]) {
        return NO;
    }

    [activeApplication sendAction:@selector(paste:) to:responder from:nil forEvent:nil];
    return YES;
}

- (void)performPaste {
    UIApplication *activeApplication = [UIApplication sharedApplication];
    if (!self.applicationInForeground || ![self applicationCanPerformPaste:activeApplication]) {
        return;
    }
    if ([self currentInputIsKayokoOwned]) {
        return;
    }

    [self postPasteWillStart];
    if (![self preparePasteboardForPaste]) {
        return;
    }

    [activeApplication sendAction:@selector(paste:) to:nil from:nil forEvent:nil];
}

- (BOOL)pendingPasteIsReady {
    UIResponder *pendingResponder = self.pendingPasteSession.responder;
    if (!pendingResponder) {
        return NO;
    }

    UIResponder *activeKeyboardInputDelegate = [self activeKeyboardInputDelegate];
    if (activeKeyboardInputDelegate == pendingResponder) {
        return YES;
    }

    return !self.pendingPasteSession.requiresKeyboardDelegate && [pendingResponder isFirstResponder];
}

- (void)attemptPendingPaste {
    if (!self.pendingPasteSession.hasPendingPaste || !self.pendingPasteSession.canExecute) {
        return;
    }
    if ([self currentInputIsKayokoOwned]) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *activeKeyWindow = [self activeKeyWindowForApplication:application];
    BOOL pendingPasteIsReady = [self pendingPasteIsReady];
    if (!self.applicationInForeground) {
        [self.pendingPasteSession clear];
        return;
    }
    if (!self.isSpringBoardRuntime && (!activeKeyWindow || activeKeyWindow != self.pendingPasteSession.keyWindow)) {
        [self.pendingPasteSession clear];
        return;
    }
    if (self.isSpringBoardRuntime && activeKeyWindow && activeKeyWindow != self.pendingPasteSession.keyWindow &&
        !pendingPasteIsReady) {
        return;
    }

    if (!pendingPasteIsReady) {
        return;
    }

    [self performPaste];
    [self.pendingPasteSession clear];
}

- (void)schedulePendingPasteCheck {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self attemptPendingPaste];
    });
}

- (BOOL)beginPendingPaste {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *activeKeyWindow = [self keyWindowForRestoringCapturedFocusInApplication:application];
    BOOL requiresKeyboardDelegate = NO;
    UIResponder *pendingResponder =
        [self capturedFocusResponderForPasteRequiringKeyboardDelegate:&requiresKeyboardDelegate];
    if (!activeKeyWindow || !pendingResponder) {
        return NO;
    }

    self.pendingPasteSession.pendingPaste = YES;
    self.pendingPasteSession.canExecute = NO;
    self.pendingPasteSession.requiresKeyboardDelegate = requiresKeyboardDelegate;
    self.pendingPasteSession.responder = pendingResponder;
    self.pendingPasteSession.keyWindow = activeKeyWindow;
    self.pendingPasteSession.token++;

    NSUInteger pendingPasteToken = self.pendingPasteSession.token;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kKayokoPendingPasteExpirationDelay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     if (self.pendingPasteSession.hasPendingPaste &&
                         self.pendingPasteSession.token == pendingPasteToken) {
                         [self.pendingPasteSession clear];
                     }
                   });

    return YES;
}

#pragma mark - Installation

- (void)installRuntimeHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
      CHHook0(UIKeyboardLayoutStar, didMoveToWindow);
      CHLoadClass_(&UIKBInputBackdropView$, NSClassFromString(@"UIKBInputBackdropView"));
      CHHook0(UIKBInputBackdropView, didMoveToWindow);
      CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
      CHHook1(UIKeyboardImpl, applicationDidBecomeActive);
      CHHook1(UIKeyboardImpl, applicationWillResignActive);
      CHHook1(UIKeyboardImpl, applicationWillSuspend);
      CHHook3(UIKeyboardImpl, setDelegate, force, fromBecomeFirstResponder);
    });
}

- (void)installSpringBoardInputIsolationHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      CHLoadClass(UISearchBar);
      CHHook0(UISearchBar, resignFirstResponder);
      CHLoadClass(UITextField);
      CHHook0(UITextField, resignFirstResponder);
    });
}

- (void)installRuntimeObserversObservingWindowResign:(BOOL)observesWindowResign {
    if (self.hasInstalledObservers) {
        return;
    }
    self.installedObservers = YES;

    if (self.isAutomaticallyPasteEnabled) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        kayokoHelperPasteNotificationCallback,
                                        kayokoHelperNotificationName(kKayokoNotificationKeyHelperPaste), NULL,
                                        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDrop);
    }

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, kayokoHelperCaptureFocusNotificationCallback,
        kayokoHelperNotificationName(kKayokoNotificationKeyCoreShow), NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, kayokoHelperCaptureFocusNotificationCallback,
        kayokoHelperNotificationName(kKayokoLegacyNotificationKeyCoreShow), NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(), NULL, kayokoHelperRestoreFocusNotificationCallback,
        kayokoHelperNotificationName(kKayokoNotificationKeyHelperRestoreFocus), NULL,
        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

    self.keyboardObserver = [[KayokoKeyboardObserver alloc] initWithRuntime:self];

    if (observesWindowResign) {
        [[NSNotificationCenter defaultCenter] addObserver:self.keyboardObserver
                                                 selector:@selector(windowDidResignKey:)
                                                     name:UIWindowDidResignKeyNotification
                                                   object:nil];
    }

    [[NSNotificationCenter defaultCenter] addObserver:self.keyboardObserver
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self.keyboardObserver
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
}

@end

#pragma mark - Responder Focus Restoration Bridge

@implementation UIResponder (KayokoFocusRestoration)

- (void)kayokoCaptureFirstResponderForFocusRestore:(id)sender {
    [[KayokoHelperRuntime sharedRuntime] captureResponderForFocusRestore:self];
}

- (void)kayokoResolveCurrentFirstResponder:(id)sender {
    [KayokoHelperRuntime sharedRuntime].resolvedCurrentFirstResponder = self;
}

@end

#pragma mark - Keyboard Observer

@interface KayokoKeyboardObserver ()
@property(nonatomic, weak, readonly) KayokoHelperRuntime *runtime;
@end

@implementation KayokoKeyboardObserver

- (instancetype)initWithRuntime:(KayokoHelperRuntime *)runtime {
    self = [super init];
    if (self) {
        _runtime = runtime;
    }
    return self;
}

- (void)windowDidResignKey:(NSNotification *)notification {
    [self.runtime windowDidResignKeyWithNotification:notification];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    [self.runtime keyboardWillHideWithNotification:notification];
}

- (void)keyboardDidShow:(NSNotification *)notification {
    [self.runtime keyboardDidShowWithNotification:notification];
}

@end
