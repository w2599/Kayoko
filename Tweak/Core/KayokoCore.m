//
//  KayokoCore.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCore.h"

#define CHUseSubstrate

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>

#import <HBLog.h>
#import <notify.h>
#import <roothide.h>

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
static void kayokoHideImmediately(void);

CHDeclareClass(UIStatusBarWindow);
CHDeclareClass(SpringBoard);
CHDeclareClass(UIViewController);
CHDeclareClass(SBHIconManager);
CHDeclareClass(SBMainSwitcherViewController);
CHDeclareClass(SBMainSwitcherControllerCoordinator);

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

static void kayokoPreloadInitialHistory() {
    didRequestInitialHistoryPreload = YES;

    PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
    [pasteboardManager prepareHistoryStore];
    if (kayokoMainViewController) {
        [kayokoMainViewController preloadHistoryIfNeeded];
    }
}

static void kayokoApplyHeightPreferenceToView(BOOL applyWhenHidden) {
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

static void kayokoApplyPreferencesToView() {
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

    kayokoApplyHeightPreferenceToView(YES);
}

#pragma mark - UIStatusBarWindow class hooks

CHOptimizedMethod1(self, id, UIStatusBarWindow, initWithFrame, CGRect, frame) {
    UIStatusBarWindow *window = CHSuper1(UIStatusBarWindow, initWithFrame, frame);

    if (!kayokoMainViewController) {
        CGRect bounds = [[UIScreen mainScreen] bounds];
        UIControl *outsideDismissOverlayView = [[UIControl alloc] initWithFrame:[window bounds]];
        [outsideDismissOverlayView
            setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [outsideDismissOverlayView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.18]];
        [outsideDismissOverlayView setAlpha:0];
        [outsideDismissOverlayView setHidden:YES];
        [outsideDismissOverlayView setUserInteractionEnabled:NO];
        [window addSubview:outsideDismissOverlayView];

        kayokoMainViewController = [[KayokoMainViewController alloc]
            initWithFrame:CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints, bounds.size.width,
                                     kayokoPrefsHeightInPoints)];
        [kayokoMainViewController setOutsideDismissOverlayView:outsideDismissOverlayView];
        kayokoApplyPreferencesToView();
        [window addSubview:[kayokoMainViewController view]];
        if (didRequestInitialHistoryPreload) {
            [kayokoMainViewController preloadHistoryIfNeeded];
        }
    }

    return window;
}

#pragma mark - SpringBoard class hooks

CHOptimizedMethod1(self, void, SpringBoard, applicationDidFinishLaunching, id, application) {
    CHSuper1(SpringBoard, applicationDidFinishLaunching, application);
    kayokoPreloadInitialHistory();
}

static BOOL kayokoIsHomeScreenController(id controller) {
    static Class iconControllerClass = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      iconControllerClass = NSClassFromString(@"SBIconController");
    });
    return iconControllerClass && [controller isKindOfClass:iconControllerClass];
}

static void kayokoHideForHomeScreenIfVisible(id controller) {
    if (!kayokoIsHomeScreenController(controller)) {
        return;
    }

    hide();
}

CHOptimizedMethod1(self, void, UIViewController, viewWillAppear, BOOL, animated) {
    CHSuper1(UIViewController, viewWillAppear, animated);
    kayokoHideForHomeScreenIfVisible(self);
}

CHOptimizedMethod1(self, void, SBHIconManager, rootFolderControllerViewWillAppear, id, controller) {
    CHSuper1(SBHIconManager, rootFolderControllerViewWillAppear, controller);
    hide();
}

static void kayokoHideForLayoutStateTransition(void) {
    if (!kayokoMainViewController || [kayokoMainViewController isHidden]) {
        return;
    }

    hide();
}

static void kayokoHideForAppSwitcherIfVisible(id switcher) {
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

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    kayokoHideForLayoutStateTransition();
}

CHOptimizedMethod2(self, void, SBMainSwitcherViewController, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    kayokoHideForAppSwitcherIfVisible(self);
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidBeginWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidBeginWithTransitionContext, context);
    kayokoHideForLayoutStateTransition();
}

CHOptimizedMethod2(self, void, SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, id, coordinator,
                   transitionDidEndWithTransitionContext, id, context) {
    CHSuper2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator, coordinator,
             transitionDidEndWithTransitionContext, context);
    kayokoHideForAppSwitcherIfVisible(self);
}

#pragma mark - Notification callbacks

static void kayokoPasteWillStart() { isInPasteProgress = YES; }

static BOOL kayokoReadUILocked(BOOL *locked) {
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

static BOOL kayokoFrontmostAppIsLandscape(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (![application respondsToSelector:@selector(_frontMostAppOrientation)]) {
        return NO;
    }

    UIInterfaceOrientation orientation = [application _frontMostAppOrientation];
    return UIInterfaceOrientationIsLandscape(orientation);
}

static void kayokoHandleLockStateNotification() {
    BOOL locked = NO;
    if (!kayokoReadUILocked(&locked) || !locked) {
        return;
    }

    kayokoHideImmediately();
}

static void kayokoStartLockStateObserver() {
    if (kayokoLockStateToken != 0) {
        return;
    }

    int status = notify_register_dispatch("com.apple.springboard.lockstate", &kayokoLockStateToken,
                                          dispatch_get_main_queue(), ^(int token) {
                                            (void)token;
                                            kayokoHandleLockStateNotification();
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Kayoko: Unable to observe SpringBoard lock state: %d", status);
        kayokoLockStateToken = 0;
    }
}

static void kayokoInstallHomeScreenHooks() {
    Class iconControllerClass = NSClassFromString(@"SBIconController");
    CHLoadClass(UIViewController);
    SEL viewWillAppearSelector = @selector(viewWillAppear:);
    if (iconControllerClass && [CHClass(UIViewController) instancesRespondToSelector:viewWillAppearSelector]) {
        CHHook1(UIViewController, viewWillAppear);
    }

    Class iconManagerClass = NSClassFromString(@"SBHIconManager");
    CHLoadClass_(&SBHIconManager$, iconManagerClass);
    SEL rootFolderWillAppearSelector = @selector(rootFolderControllerViewWillAppear:);
    if ([iconManagerClass instancesRespondToSelector:rootFolderWillAppearSelector]) {
        CHHook1(SBHIconManager, rootFolderControllerViewWillAppear);
    }
}

static void kayokoInstallAppSwitcherHooks() {
    SEL transitionBeginSelector =
        @selector(layoutStateTransitionCoordinator:transitionDidBeginWithTransitionContext:);
    SEL transitionEndSelector = @selector(layoutStateTransitionCoordinator:transitionDidEndWithTransitionContext:);

    Class switcherViewControllerClass = NSClassFromString(@"SBMainSwitcherViewController");
    CHLoadClass_(&SBMainSwitcherViewController$, switcherViewControllerClass);
    if ([switcherViewControllerClass instancesRespondToSelector:transitionBeginSelector]) {
        CHHook2(SBMainSwitcherViewController, layoutStateTransitionCoordinator,
                transitionDidBeginWithTransitionContext);
    }
    if ([switcherViewControllerClass instancesRespondToSelector:transitionEndSelector]) {
        CHHook2(SBMainSwitcherViewController, layoutStateTransitionCoordinator, transitionDidEndWithTransitionContext);
    }

    Class switcherCoordinatorClass = NSClassFromString(@"SBMainSwitcherControllerCoordinator");
    CHLoadClass_(&SBMainSwitcherControllerCoordinator$, switcherCoordinatorClass);
    if ([switcherCoordinatorClass instancesRespondToSelector:transitionBeginSelector]) {
        CHHook2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator,
                transitionDidBeginWithTransitionContext);
    }
    if ([switcherCoordinatorClass instancesRespondToSelector:transitionEndSelector]) {
        CHHook2(SBMainSwitcherControllerCoordinator, layoutStateTransitionCoordinator,
                transitionDidEndWithTransitionContext);
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

static void kayokoApplyUserInterfaceStyleToView(UIUserInterfaceStyle style) {
    [kayokoMainViewController applyUserInterfaceStyle:style];
}

static void show() {
    if (!kayokoMainViewController || ![kayokoMainViewController isHidden]) {
        return;
    }

    BOOL locked = NO;
    if (kayokoReadUILocked(&locked) && locked) {
        kayokoPlayFailureHapticFeedbackIfNeeded();
        return;
    }

    if (kayokoFrontmostAppIsLandscape()) {
        kayokoPlayFailureHapticFeedbackIfNeeded();
        return;
    }

    kayokoApplyHeightPreferenceToView(YES);
    kayokoApplyUserInterfaceStyleToView(UIUserInterfaceStyleUnspecified);

    /* iOS 15 */
    SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
    if (statusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            if (isKindOfDark) {
                kayokoApplyUserInterfaceStyleToView(UIUserInterfaceStyleDark);
            } else {
                kayokoApplyUserInterfaceStyleToView(UIUserInterfaceStyleLight);
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
                kayokoApplyUserInterfaceStyleToView(UIUserInterfaceStyleDark);
            } else {
                kayokoApplyUserInterfaceStyleToView(UIUserInterfaceStyleLight);
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

static void kayokoHideImmediately() {
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

static void kayokoLoadPreferences() {
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

    kayokoApplyPreferencesToView();
}

static void kayokoLoadHeightPreference() {
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
      kayokoApplyHeightPreferenceToView(NO);
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
        kayokoLoadPreferences();

        if (!kayokoPrefsEnabled) {
            return;
        }

        EnableKayokoDisablePasteTips();

        Class statusBarWindowCls = objc_getClass("UIStatusBarWindow");
        if (@available(iOS 17, *)) {
            statusBarWindowCls = objc_getClass("SBStatusBarWindow");
        }

        CHLoadClass_(&UIStatusBarWindow$, statusBarWindowCls);
        CHHook1(UIStatusBarWindow, initWithFrame);
        CHLoadClass_(&SpringBoard$, NSClassFromString(@"SpringBoard"));
        CHHook1(SpringBoard, applicationDidFinishLaunching);
        kayokoInstallHomeScreenHooks();
        kayokoInstallAppSwitcherHooks();
        kayokoStartLockStateObserver();

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
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoLoadPreferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoLoadHeightPreference,
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
        kayokoLoadPreferences();

        if (!kayokoPrefsEnabled) {
            return;
        }

        EnableKayokoDisablePasteTips();
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoLoadPreferences,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

        return;
    }
}
