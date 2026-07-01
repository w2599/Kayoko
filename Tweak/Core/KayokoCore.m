//
//  KayokoCore.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCore.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import <HBLog.h>
#import <notify.h>
#import <roothide.h>
#import <substrate.h>

#import "Controllers/KayokoMainViewController.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

static NSTimeInterval kKayokoMinimumFeedbackInterval = 0.6;

KayokoMainViewController *kayokoMainViewController = nil;

NSUserDefaults *kayokoPreferences = nil;
BOOL kayokoPrefsEnabled = NO;
NSUInteger kayokoHelperPrefsActivationMethod = 0;

NSUInteger kayokoPrefsMaximumHistoryAmount = 0;
BOOL kayokoPrefsSaveText = NO;
BOOL kayokoPrefsSaveImages = NO;
BOOL kayokoPrefsSwipeToSelectWords = NO;
BOOL kayokoPrefsAutomaticallyPaste = NO;
BOOL kayokoPrefsDismissOnOutsideTouch = NO;
BOOL kayokoPrefsDisablePasteTips = NO;
BOOL kayokoPrefsPlaySoundEffects = NO;
BOOL kayokoPrefsPlayHapticFeedback = NO;
NSUInteger kayokoPrefsPreviewLineCount = 1;

CGFloat kayokoPrefsHeightInPoints = 420;

static BOOL isInPasteProgress = NO;

static NSTimeInterval lastPasteFeedbackOccurred = 0;
static NSTimeInterval lastCopyFeedbackOccurred = 0;

static AVAudioPlayer *copySoundPlayer = nil;
static AVAudioPlayer *pasteSoundPlayer = nil;
static BOOL didPreparePasteboardQueue = NO;
static BOOL pendingHeightPreferenceApply = NO;
static BOOL didRequestInitialHistoryPreload = NO;
static int kayokoLockStateToken = 0;

static void hide(void);
static void hide_immediately(void);

NS_ASSUME_NONNULL_BEGIN

@interface UIStatusBarStyleRequest : NSObject
@property(nonatomic, assign, readonly) long long style;
@end

@interface UIStatusBarWindow : UIWindow
@end

@interface UIApplication (KayokoPrivate)
- (UIInterfaceOrientation)_frontMostAppOrientation;
@end

@interface SBStatusBarManager : NSObject
+ (nullable instancetype)sharedInstance;
- (nullable UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBWindowSceneStatusBarManager : NSObject
+ (nullable instancetype)windowSceneStatusBarManagerForEmbeddedDisplay;
- (nullable UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SpringBoard : UIApplication
- (void)applicationDidFinishLaunching:(id)application;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

@interface SBMainSwitcherViewController : UIViewController
- (BOOL)isMainSwitcherVisible;
@end

@interface SBMainSwitcherControllerCoordinator : NSObject
- (BOOL)isAnySwitcherVisible;
@end

@interface SBHIconManager : NSObject
- (void)rootFolderControllerViewWillAppear:(id)controller;
@end

NS_ASSUME_NONNULL_END

static void preload_initial_history() {
    didRequestInitialHistoryPreload = YES;

    PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
    [pasteboardManager prepareHistoryStore];
    if (kayokoMainViewController) {
        [kayokoMainViewController preloadHistoryIfNeeded];
    }
}

static void apply_height_preference_to_view(BOOL applyWhenHidden) {
    if (!kayokoMainViewController) {
        return;
    }

    if (!applyWhenHidden && [kayokoMainViewController isHidden]) {
        return;
    }

    UIView *panelView = [kayokoMainViewController view];
    UIView *containerView = [panelView superview];
    CGRect bounds = containerView ? [containerView bounds] : [[UIScreen mainScreen] bounds];
    CGFloat height = MIN(kayokoPrefsHeightInPoints, CGRectGetHeight(bounds));
    CGRect newFrame = CGRectMake(CGRectGetMinX(bounds), CGRectGetMaxY(bounds) - height, CGRectGetWidth(bounds), height);
    if (!CGRectEqualToRect([panelView frame], newFrame)) {
        if (!CGAffineTransformIsIdentity([panelView transform])) {
            [panelView setTransform:CGAffineTransformIdentity];
        }
        [panelView setFrame:newFrame];
        [panelView setNeedsLayout];
    }
}

static void apply_preferences_to_view() {
    if (!kayokoMainViewController) {
        return;
    }

    if ([kayokoMainViewController automaticallyPaste] != kayokoPrefsAutomaticallyPaste) {
        [kayokoMainViewController setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
    }
    if ([kayokoMainViewController dismissOnOutsideTouch] != kayokoPrefsDismissOnOutsideTouch) {
        [kayokoMainViewController setDismissOnOutsideTouch:kayokoPrefsDismissOnOutsideTouch];
    }
    if ([kayokoMainViewController swipeToSelectWords] != kayokoPrefsSwipeToSelectWords) {
        [kayokoMainViewController setSwipeToSelectWords:kayokoPrefsSwipeToSelectWords];
    }
    if ([kayokoMainViewController previewLineCount] != kayokoPrefsPreviewLineCount) {
        [kayokoMainViewController setPreviewLineCount:kayokoPrefsPreviewLineCount];
    }
    if ([kayokoMainViewController shouldPlayFeedback] != kayokoPrefsPlayHapticFeedback) {
        [kayokoMainViewController setShouldPlayFeedback:kayokoPrefsPlayHapticFeedback];
    }

    apply_height_preference_to_view(YES);
}

#pragma mark - UIStatusBarWindow class hooks

static void (*orig_UIStatusBarWindow_initWithFrame)(UIStatusBarWindow *self, SEL _cmd, CGRect frame);
static void override_UIStatusBarWindow_initWithFrame(UIStatusBarWindow *self, SEL _cmd, CGRect frame) {
    orig_UIStatusBarWindow_initWithFrame(self, _cmd, frame);

    if (!kayokoMainViewController) {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        UIControl *outsideDismissOverlayView = [[UIControl alloc] initWithFrame:[self bounds]];
        [outsideDismissOverlayView
            setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [outsideDismissOverlayView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.18]];
        [outsideDismissOverlayView setAlpha:0];
        [outsideDismissOverlayView setHidden:YES];
        [outsideDismissOverlayView setUserInteractionEnabled:NO];
        [self addSubview:outsideDismissOverlayView];

        kayokoMainViewController = [[KayokoMainViewController alloc]
            initWithFrame:CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints, bounds.size.width,
                                     kayokoPrefsHeightInPoints)];
        [kayokoMainViewController setOutsideDismissOverlayView:outsideDismissOverlayView];
        apply_preferences_to_view();
        [self addSubview:[kayokoMainViewController view]];
        if (didRequestInitialHistoryPreload) {
            [kayokoMainViewController preloadHistoryIfNeeded];
        }
    }
}

#pragma mark - SpringBoard class hooks

static void (*orig_SpringBoard_applicationDidFinishLaunching)(SpringBoard *self, SEL _cmd, id application);
static void override_SpringBoard_applicationDidFinishLaunching(SpringBoard *self, SEL _cmd, id application) {
    orig_SpringBoard_applicationDidFinishLaunching(self, _cmd, application);
    preload_initial_history();
}

static BOOL is_home_screen_controller(id controller) {
    static Class iconControllerClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      iconControllerClass = NSClassFromString(@"SBIconController");
    });
    return iconControllerClass && [controller isKindOfClass:iconControllerClass];
}

static void hide_for_home_screen_if_visible(id controller) {
    if (!is_home_screen_controller(controller)) {
        return;
    }

    hide();
}

static void (*orig_UIViewController_viewWillAppear)(UIViewController *self, SEL _cmd, BOOL animated);
static void override_UIViewController_viewWillAppear(UIViewController *self, SEL _cmd, BOOL animated) {
    orig_UIViewController_viewWillAppear(self, _cmd, animated);
    hide_for_home_screen_if_visible(self);
}

static void (*orig_SBHIconManager_rootFolderControllerViewWillAppear)(SBHIconManager *self, SEL _cmd, id controller);
static void override_SBHIconManager_rootFolderControllerViewWillAppear(SBHIconManager *self, SEL _cmd, id controller) {
    orig_SBHIconManager_rootFolderControllerViewWillAppear(self, _cmd, controller);
    hide();
}

static void hide_for_layout_state_transition(void) {
    if (!kayokoMainViewController || [kayokoMainViewController isHidden]) {
        return;
    }

    hide();
}

static void hide_for_app_switcher_if_visible(id switcher) {
    if (!kayokoMainViewController || [kayokoMainViewController isHidden]) {
        return;
    }

    BOOL switcherVisible = NO;
    if ([switcher respondsToSelector:@selector(isMainSwitcherVisible)]) {
        switcherVisible = [(SBMainSwitcherViewController *)switcher isMainSwitcherVisible];
    } else if ([switcher respondsToSelector:@selector(isAnySwitcherVisible)]) {
        switcherVisible = [(SBMainSwitcherControllerCoordinator *)switcher isAnySwitcherVisible];
    }

    if (switcherVisible) {
        hide();
    }
}

static void (*orig_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext)(
    SBMainSwitcherViewController *self, SEL _cmd, id coordinator, id context);
static void override_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext(
    SBMainSwitcherViewController *self, SEL _cmd, id coordinator, id context) {
    orig_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext(
        self, _cmd, coordinator, context);
    hide_for_layout_state_transition();
}

static void (*orig_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext)(
    SBMainSwitcherViewController *self, SEL _cmd, id coordinator, id context);
static void override_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext(
    SBMainSwitcherViewController *self, SEL _cmd, id coordinator, id context) {
    orig_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext(
        self, _cmd, coordinator, context);
    hide_for_app_switcher_if_visible(self);
}

static void (*orig_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext)(
    SBMainSwitcherControllerCoordinator *self, SEL _cmd, id coordinator, id context);
static void override_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext(
    SBMainSwitcherControllerCoordinator *self, SEL _cmd, id coordinator, id context) {
    orig_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext(
        self, _cmd, coordinator, context);
    hide_for_layout_state_transition();
}

static void (*orig_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext)(
    SBMainSwitcherControllerCoordinator *self, SEL _cmd, id coordinator, id context);
static void override_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext(
    SBMainSwitcherControllerCoordinator *self, SEL _cmd, id coordinator, id context) {
    orig_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext(
        self, _cmd, coordinator, context);
    hide_for_app_switcher_if_visible(self);
}

#pragma mark - Notification callbacks

static void kayokoPasteWillStart() { isInPasteProgress = YES; }

static BOOL read_ui_locked(BOOL *locked) {
    Class managerClass = NSClassFromString(@"SBLockScreenManager");
    if (![managerClass respondsToSelector:@selector(sharedInstance)]) {
        return NO;
    }

    SBLockScreenManager *manager = [(id)managerClass sharedInstance];
    if (![manager respondsToSelector:@selector(isUILocked)]) {
        return NO;
    }

    if (locked) {
        *locked = [manager isUILocked];
    }
    return YES;
}

static BOOL frontmost_app_is_landscape(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (![application respondsToSelector:@selector(_frontMostAppOrientation)]) {
        return NO;
    }

    UIInterfaceOrientation orientation = [application _frontMostAppOrientation];
    return UIInterfaceOrientationIsLandscape(orientation);
}

static void handle_lock_state_notification() {
    BOOL locked = NO;
    if (!read_ui_locked(&locked) || !locked) {
        return;
    }

    hide_immediately();
}

static void start_lock_state_observer() {
    if (kayokoLockStateToken != 0) {
        return;
    }

    int status = notify_register_dispatch("com.apple.springboard.lockstate", &kayokoLockStateToken,
                                          dispatch_get_main_queue(), ^(int token) {
                                            (void)token;
                                            handle_lock_state_notification();
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Kayoko: Unable to observe SpringBoard lock state: %d", status);
        kayokoLockStateToken = 0;
    }
}

static void install_home_screen_hooks() {
    Class iconControllerClass = NSClassFromString(@"SBIconController");
    Class viewControllerClass = objc_getClass("UIViewController");
    SEL viewWillAppearSelector = @selector(viewWillAppear:);
    if (iconControllerClass && [viewControllerClass instancesRespondToSelector:viewWillAppearSelector]) {
        MSHookMessageEx(viewControllerClass, viewWillAppearSelector, (IMP)&override_UIViewController_viewWillAppear,
                        (IMP *)&orig_UIViewController_viewWillAppear);
    }

    Class iconManagerClass = objc_getClass("SBHIconManager");
    SEL rootFolderWillAppearSelector = @selector(rootFolderControllerViewWillAppear:);
    if ([iconManagerClass instancesRespondToSelector:rootFolderWillAppearSelector]) {
        MSHookMessageEx(iconManagerClass, rootFolderWillAppearSelector,
                        (IMP)&override_SBHIconManager_rootFolderControllerViewWillAppear,
                        (IMP *)&orig_SBHIconManager_rootFolderControllerViewWillAppear);
    }
}

static void install_app_switcher_hooks() {
    SEL transitionBeginSelector =
        @selector(layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:);
    SEL transitionEndSelector = @selector(layoutStateTransitionCoordinator:transitionDidEndWithTransitionContext:);

    Class switcherViewControllerClass = objc_getClass("SBMainSwitcherViewController");
    if ([switcherViewControllerClass instancesRespondToSelector:transitionBeginSelector]) {
        MSHookMessageEx(switcherViewControllerClass, transitionBeginSelector,
                        (IMP)&override_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext,
                        (IMP *)&orig_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext);
    }
    if ([switcherViewControllerClass instancesRespondToSelector:transitionEndSelector]) {
        MSHookMessageEx(switcherViewControllerClass, transitionEndSelector,
                        (IMP)&override_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext,
                        (IMP *)&orig_SBMainSwitcherViewController_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext);
    }

    Class switcherCoordinatorClass = objc_getClass("SBMainSwitcherControllerCoordinator");
    if ([switcherCoordinatorClass instancesRespondToSelector:transitionBeginSelector]) {
        MSHookMessageEx(
            switcherCoordinatorClass, transitionBeginSelector,
            (IMP)&override_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext,
            (IMP *)&orig_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidBeginWithTransitionContext);
    }
    if ([switcherCoordinatorClass instancesRespondToSelector:transitionEndSelector]) {
        MSHookMessageEx(
            switcherCoordinatorClass, transitionEndSelector,
            (IMP)&override_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext,
            (IMP *)&orig_SBMainSwitcherControllerCoordinator_layoutStateTransitionCoordinator_transitionDidEndWithTransitionContext);
    }
}

static AVAudioPlayer *kayokoAudioPlayerForSound(NSString *soundName) {
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient
                                     withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                           error:&error];
    if (error) {
        HBLogDebug(@"Kayoko: Failed to configure audio session: %@", error);
    }

    NSString *relativeSoundPath =
        [NSString stringWithFormat:@"/Library/PreferenceBundles/KayokoPreferences.bundle/%@.aiff", soundName];
    NSString *soundPath = jbroot(relativeSoundPath);
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:soundPath]
                                                                   error:&error];
    if (error) {
        HBLogDebug(@"Kayoko: Failed to load %@ sound: %@", soundName, error);
        return nil;
    }

    [player prepareToPlay];
    return player;
}

static AVAudioPlayer *kayokoPlayFeedbackSound(AVAudioPlayer *player, NSString *soundName) {
    if (!player) {
        player = kayokoAudioPlayerForSound(soundName);
    }

    [player setCurrentTime:0];
    [player play];
    return player;
}

static void kayokoPlaySuccessHapticFeedbackIfNeeded(void) {
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

static void kayokoPlayFailureHapticFeedbackIfNeeded(void) {
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1521);
    }
}

static void _kayokoCopy() {
    [[PasteboardManager sharedInstance] pullPasteboardChanges];
    if (isInPasteProgress) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          isInPasteProgress = NO;
        });
        return;
    }
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - lastCopyFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
        return;
    }
    lastCopyFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        copySoundPlayer = kayokoPlayFeedbackSound(copySoundPlayer, @"Copy");
    }
    kayokoPlaySuccessHapticFeedbackIfNeeded();
}

static void kayokoCopy() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      _kayokoCopy();
    });
}

static void apply_user_interface_style_to_view(UIUserInterfaceStyle style) {
    [kayokoMainViewController applyUserInterfaceStyle:style];
}

static void show() {
    if (!kayokoMainViewController || ![kayokoMainViewController isHidden]) {
        return;
    }

    BOOL locked = NO;
    if (read_ui_locked(&locked) && locked) {
        kayokoPlayFailureHapticFeedbackIfNeeded();
        return;
    }

    if (frontmost_app_is_landscape()) {
        kayokoPlayFailureHapticFeedbackIfNeeded();
        return;
    }

    apply_height_preference_to_view(YES);
    apply_user_interface_style_to_view(UIUserInterfaceStyleUnspecified);

    /* iOS 15 */
    SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
    if (statusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            if (isKindOfDark) {
                apply_user_interface_style_to_view(UIUserInterfaceStyleDark);
            } else {
                apply_user_interface_style_to_view(UIUserInterfaceStyleLight);
            }
        }
    }

    /* iOS 16 */
    SBWindowSceneStatusBarManager *windowSceneStatusBarManager =
        [objc_getClass("SBWindowSceneStatusBarManager") windowSceneStatusBarManagerForEmbeddedDisplay];
    if (windowSceneStatusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [windowSceneStatusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            if (isKindOfDark) {
                apply_user_interface_style_to_view(UIUserInterfaceStyleDark);
            } else {
                apply_user_interface_style_to_view(UIUserInterfaceStyleLight);
            }
        }
    }

    [kayokoMainViewController show];

    if (kayokoHelperPrefsActivationMethod & kActivationMethodDictationKey) {
        kayokoPlaySuccessHapticFeedbackIfNeeded();
    }
}

static void hide() {
    if (![kayokoMainViewController isHidden]) {
        [kayokoMainViewController hide];
    }
}

static void hide_immediately() {
    if (![kayokoMainViewController isHidden]) {
        [kayokoMainViewController hideImmediately];
    }
}

static void reload() {
    if (kayokoMainViewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [kayokoMainViewController handleHistoryChanged];
        });
    }
}

#pragma mark - Preferences

static void load_preferences() {
    kayokoPreferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];

    [kayokoPreferences registerDefaults:@{
        kPreferenceKeyEnabled : @(kPreferenceKeyEnabledDefaultValue),
        kPreferenceKeyActivationMethod : @(kPreferenceKeyActivationMethodDefaultValue),
        kPreferenceKeyMaximumHistoryAmount : @(kPreferenceKeyMaximumHistoryAmountDefaultValue),
        kPreferenceKeySaveText : @(kPreferenceKeySaveTextDefaultValue),
        kPreferenceKeySaveImages : @(kPreferenceKeySaveImagesDefaultValue),
        kPreferenceKeySwipeToSelectWords : @(kPreferenceKeySwipeToSelectWordsDefaultValue),
        kPreferenceKeyAutomaticallyPaste : @(kPreferenceKeyAutomaticallyPasteDefaultValue),
        kPreferenceKeyDismissOnOutsideTouch : @(kPreferenceKeyDismissOnOutsideTouchDefaultValue),
        kPreferenceKeyDisablePasteTips : @(kPreferenceKeyDisablePasteTipsDefaultValue),
        kPreferenceKeyPlaySoundEffects : @(kPreferenceKeyPlaySoundEffectsDefaultValue),
        kPreferenceKeyPlayHapticFeedback : @(kPreferenceKeyPlayHapticFeedbackDefaultValue),
        kPreferenceKeyPreviewLineCount : @(kPreferenceKeyPreviewLineCountDefaultValue),
        kPreferenceKeyHeightInPoints : @(kPreferenceKeyHeightInPointsDefaultValue),
    }];

    kayokoPrefsEnabled = [[kayokoPreferences objectForKey:kPreferenceKeyEnabled] boolValue];
    kayokoHelperPrefsActivationMethod =
        [[kayokoPreferences objectForKey:kPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoPrefsMaximumHistoryAmount = [PasteboardManager
        normalizedMaximumHistoryAmountForValue:[[kayokoPreferences objectForKey:kPreferenceKeyMaximumHistoryAmount]
                                                   unsignedIntegerValue]];
    kayokoPrefsSaveText = [[kayokoPreferences objectForKey:kPreferenceKeySaveText] boolValue];
    kayokoPrefsSaveImages = [[kayokoPreferences objectForKey:kPreferenceKeySaveImages] boolValue];
    kayokoPrefsSwipeToSelectWords = [[kayokoPreferences objectForKey:kPreferenceKeySwipeToSelectWords] boolValue];
    kayokoPrefsAutomaticallyPaste = [[kayokoPreferences objectForKey:kPreferenceKeyAutomaticallyPaste] boolValue];
    kayokoPrefsDismissOnOutsideTouch = [[kayokoPreferences objectForKey:kPreferenceKeyDismissOnOutsideTouch] boolValue];
    kayokoPrefsDisablePasteTips = [[kayokoPreferences objectForKey:kPreferenceKeyDisablePasteTips] boolValue];
    kayokoPrefsPlaySoundEffects = [[kayokoPreferences objectForKey:kPreferenceKeyPlaySoundEffects] boolValue];
    kayokoPrefsPlayHapticFeedback = [[kayokoPreferences objectForKey:kPreferenceKeyPlayHapticFeedback] boolValue];
    kayokoPrefsPreviewLineCount =
        [[kayokoPreferences objectForKey:kPreferenceKeyPreviewLineCount] unsignedIntegerValue];
    kayokoPrefsHeightInPoints = [[kayokoPreferences objectForKey:kPreferenceKeyHeightInPoints] doubleValue];

    PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
    if (!didPreparePasteboardQueue) {
        [pasteboardManager preparePasteboardQueue];
        didPreparePasteboardQueue = YES;
    }
    if ([pasteboardManager maximumHistoryAmount] != kayokoPrefsMaximumHistoryAmount) {
        [pasteboardManager setMaximumHistoryAmount:kayokoPrefsMaximumHistoryAmount];
    }
    if ([pasteboardManager saveText] != kayokoPrefsSaveText) {
        [pasteboardManager setSaveText:kayokoPrefsSaveText];
    }
    if ([pasteboardManager saveImages] != kayokoPrefsSaveImages) {
        [pasteboardManager setSaveImages:kayokoPrefsSaveImages];
    }
    if ([pasteboardManager automaticallyPaste] != kayokoPrefsAutomaticallyPaste) {
        [pasteboardManager setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
    }

    apply_preferences_to_view();
}

static void load_height_preference() {
    NSUserDefaults *heightPreferences = [[NSUserDefaults alloc] initWithSuiteName:kPreferencesIdentifier];
    [heightPreferences registerDefaults:@{
        kPreferenceKeyHeightInPoints : @(kPreferenceKeyHeightInPointsDefaultValue),
    }];
    kayokoPrefsHeightInPoints = [[heightPreferences objectForKey:kPreferenceKeyHeightInPoints] doubleValue];
    if (pendingHeightPreferenceApply) {
        return;
    }

    pendingHeightPreferenceApply = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
      pendingHeightPreferenceApply = NO;
      apply_height_preference_to_view(NO);
    });
}

#pragma mark - Sound effects

static void kayokoPaste() {
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - lastPasteFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
        return;
    }
    lastPasteFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        pasteSoundPlayer = kayokoPlayFeedbackSound(pasteSoundPlayer, @"Paste");
    }
    kayokoPlaySuccessHapticFeedbackIfNeeded();
}

#pragma mark - Constructor

__attribute((constructor)) static void initialize() {
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    BOOL isSpringBoard = [bundleIdentifier isEqualToString:@"com.apple.springboard"];
    if (isSpringBoard) {
        load_preferences();

        if (!kayokoPrefsEnabled) {
            return;
        }

        EnableKayokoDisablePasteTips();

        Class statusBarWindowCls = objc_getClass("UIStatusBarWindow");
        if (@available(iOS 17, *)) {
            statusBarWindowCls = objc_getClass("SBStatusBarWindow");
        }

        MSHookMessageEx(statusBarWindowCls, @selector(initWithFrame:), (IMP)&override_UIStatusBarWindow_initWithFrame,
                        (IMP *)&orig_UIStatusBarWindow_initWithFrame);
        MSHookMessageEx(objc_getClass("SpringBoard"), @selector(applicationDidFinishLaunching:),
                        (IMP)&override_SpringBoard_applicationDidFinishLaunching,
                        (IMP *)&orig_SpringBoard_applicationDidFinishLaunching);
        install_home_screen_hooks();
        install_app_switcher_hooks();
        start_lock_state_observer();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoCopy,
            CFSTR("com.apple.pasteboard.notify.changed"), NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)show,
            (CFStringRef)kNotificationKeyCoreShow, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)show,
            (CFStringRef)kLegacyNotificationKeyCoreShow, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)hide,
            (CFStringRef)kNotificationKeyCoreHide, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)hide,
            (CFStringRef)kLegacyNotificationKeyCoreHide, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reload,
            (CFStringRef)kNotificationKeyCoreReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_preferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_height_preference,
            (CFStringRef)kNotificationKeyPreferencesHeightReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoPaste,
            (CFStringRef)kNotificationKeyHelperPaste, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoPasteWillStart,
            (CFStringRef)kNotificationKeyPasteWillStart, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

        return;
    }

    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    NSString *processName = [[NSProcessInfo processInfo] processName];
    NSString *executablePath = [args firstObject];
    BOOL isDruidOrPasted =
        ([executablePath hasPrefix:@"/System/Library/"] || [executablePath hasPrefix:@"/usr/libexec/"]) &&
        ([processName isEqualToString:@"druid"] || [processName isEqualToString:@"pasted"]);
    if (isDruidOrPasted) {
        load_preferences();

        if (!kayokoPrefsEnabled) {
            return;
        }

        EnableKayokoDisablePasteTips();
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)load_preferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

        return;
    }
}
