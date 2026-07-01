//
//  KayokoCoreRuntime.m
//  Kayoko
//

#import "KayokoCoreRuntime.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreFoundation/CoreFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import <HBLog.h>
#import <notify.h>
#import <roothide.h>

#import "Controllers/KayokoMainViewController.h"
#import "KayokoCore.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

static NSTimeInterval const kKayokoMinimumFeedbackInterval = 0.6;

static KayokoMainViewController *kayokoMainViewController = nil;
static NSUserDefaults *kayokoPreferences = nil;

static BOOL kayokoPrefsEnabled = NO;
static NSUInteger kayokoHelperPrefsActivationMethod = 0;
static NSUInteger kayokoPrefsMaximumHistoryAmount = 0;
static BOOL kayokoPrefsSaveText = NO;
static BOOL kayokoPrefsSaveImages = NO;
static BOOL kayokoPrefsSwipeToSelectWords = NO;
static BOOL kayokoPrefsAutomaticallyPaste = NO;
static BOOL kayokoPrefsDismissOnOutsideTouch = NO;
static BOOL kayokoPrefsDisablePasteTips = NO;
static BOOL kayokoPrefsPlaySoundEffects = NO;
static BOOL kayokoPrefsPlayHapticFeedback = NO;
static NSUInteger kayokoPrefsPreviewLineCount = 1;
static CGFloat kayokoPrefsHeightInPoints = 420;

static BOOL isInPasteProgress = NO;
static NSTimeInterval lastPasteFeedbackOccurred = 0;
static NSTimeInterval lastCopyFeedbackOccurred = 0;
static AVAudioPlayer *copySoundPlayer = nil;
static AVAudioPlayer *pasteSoundPlayer = nil;
static BOOL didPreparePasteboardQueue = NO;
static BOOL pendingHeightPreferenceApply = NO;
static BOOL didRequestInitialHistoryPreload = NO;
static int kayokoLockStateToken = 0;

static void KayokoCoreApplyPreferencesToView(void);

NS_ASSUME_NONNULL_BEGIN

@interface UIStatusBarStyleRequest : NSObject
@property(nonatomic, assign, readonly) long long style;
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

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end

NS_ASSUME_NONNULL_END

BOOL KayokoCoreEnabled(void) { return kayokoPrefsEnabled; }

NSUInteger KayokoCoreActivationMethod(void) { return kayokoHelperPrefsActivationMethod; }

BOOL KayokoCorePasteTipsDisabled(void) { return kayokoPrefsDisablePasteTips; }

BOOL KayokoCorePanelVisible(void) { return kayokoMainViewController && ![kayokoMainViewController isHidden]; }

BOOL KayokoCoreFullscreenSearchActive(void) {
    return KayokoCorePanelVisible() && [kayokoMainViewController isFullscreenSearchActive];
}

static void KayokoCoreRequestHelperFocusRestore(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyHelperRestoreFocus, nil, nil, YES);
}

void KayokoCoreInstallPanelInStatusBarWindow(UIWindow *window) {
    if (kayokoMainViewController) {
        return;
    }

    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIControl *outsideDismissOverlayView = [[UIControl alloc] initWithFrame:[window bounds]];
    [outsideDismissOverlayView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [outsideDismissOverlayView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.18]];
    [outsideDismissOverlayView setAlpha:0];
    [outsideDismissOverlayView setHidden:YES];
    [outsideDismissOverlayView setUserInteractionEnabled:NO];
    [window addSubview:outsideDismissOverlayView];

    kayokoMainViewController =
        [[KayokoMainViewController alloc] initWithFrame:CGRectMake(0, bounds.size.height - kayokoPrefsHeightInPoints,
                                                                   bounds.size.width, kayokoPrefsHeightInPoints)];
    [kayokoMainViewController setFocusRestoreRequestHandler:^{
      KayokoCoreRequestHelperFocusRestore();
    }];
    [kayokoMainViewController setOutsideDismissOverlayView:outsideDismissOverlayView];
    KayokoCoreApplyPreferencesToView();
    [window addSubview:[kayokoMainViewController view]];
    if (didRequestInitialHistoryPreload) {
        [kayokoMainViewController preloadHistoryIfNeeded];
    }
}

void KayokoCorePreloadInitialHistory(void) {
    didRequestInitialHistoryPreload = YES;

    PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
    [pasteboardManager prepareHistoryStore];
    if (kayokoMainViewController) {
        [kayokoMainViewController preloadHistoryIfNeeded];
    }
}

static void KayokoCoreApplyHeightPreferenceToView(BOOL applyWhenHidden) {
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

static void KayokoCoreApplyPreferencesToView(void) {
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

    KayokoCoreApplyHeightPreferenceToView(YES);
}

void KayokoCoreLoadPreferences(void) {
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

    KayokoCoreApplyPreferencesToView();
}

void KayokoCoreLoadHeightPreference(void) {
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
      KayokoCoreApplyHeightPreferenceToView(NO);
    });
}

static BOOL KayokoCoreReadUILocked(BOOL *locked) {
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

static BOOL KayokoCoreFrontmostAppIsLandscape(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (![application respondsToSelector:@selector(_frontMostAppOrientation)]) {
        return NO;
    }

    UIInterfaceOrientation orientation = [application _frontMostAppOrientation];
    return UIInterfaceOrientationIsLandscape(orientation);
}

static AVAudioPlayer *KayokoCoreAudioPlayerForSound(NSString *soundName) {
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

static AVAudioPlayer *KayokoCorePlayFeedbackSound(AVAudioPlayer *player, NSString *soundName) {
    if (!player) {
        player = KayokoCoreAudioPlayerForSound(soundName);
    }

    [player setCurrentTime:0];
    [player play];
    return player;
}

static void KayokoCorePlaySuccessHapticFeedbackIfNeeded(void) {
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

static void KayokoCorePlayFailureHapticFeedbackIfNeeded(void) {
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1521);
    }
}

void KayokoCorePasteWillStart(void) { isInPasteProgress = YES; }

static void KayokoCoreCopyNow(void) {
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
        copySoundPlayer = KayokoCorePlayFeedbackSound(copySoundPlayer, @"Copy");
    }
    KayokoCorePlaySuccessHapticFeedbackIfNeeded();
}

void KayokoCoreCopy(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      KayokoCoreCopyNow();
    });
}

void KayokoCoreShow(void) {
    if (!kayokoMainViewController || ![kayokoMainViewController isHidden]) {
        return;
    }

    BOOL locked = NO;
    if (KayokoCoreReadUILocked(&locked) && locked) {
        KayokoCorePlayFailureHapticFeedbackIfNeeded();
        return;
    }

    if (KayokoCoreFrontmostAppIsLandscape()) {
        KayokoCorePlayFailureHapticFeedbackIfNeeded();
        return;
    }

    KayokoCoreApplyHeightPreferenceToView(YES);
    [kayokoMainViewController applyUserInterfaceStyle:UIUserInterfaceStyleUnspecified];

    SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
    if (statusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            [kayokoMainViewController applyUserInterfaceStyle:isKindOfDark ? UIUserInterfaceStyleDark
                                                                           : UIUserInterfaceStyleLight];
        }
    }

    SBWindowSceneStatusBarManager *windowSceneStatusBarManager =
        [objc_getClass("SBWindowSceneStatusBarManager") windowSceneStatusBarManagerForEmbeddedDisplay];
    if (windowSceneStatusBarManager) {
        UIStatusBarStyleRequest *styleRequest = [windowSceneStatusBarManager frontmostStatusBarStyleRequest];
        if (styleRequest) {
            long long style = [styleRequest style];
            BOOL isKindOfDark = style == 1;
            [kayokoMainViewController applyUserInterfaceStyle:isKindOfDark ? UIUserInterfaceStyleDark
                                                                           : UIUserInterfaceStyleLight];
        }
    }

    [kayokoMainViewController show];

    if (kayokoHelperPrefsActivationMethod & kActivationMethodDictationKey) {
        KayokoCorePlaySuccessHapticFeedbackIfNeeded();
    }
}

void KayokoCoreHide(void) {
    if (kayokoMainViewController && ![kayokoMainViewController isHidden]) {
        [kayokoMainViewController hide];
    }
}

void KayokoCoreHideImmediately(void) {
    if (kayokoMainViewController && ![kayokoMainViewController isHidden]) {
        [kayokoMainViewController hideImmediately];
    }
}

void KayokoCoreReload(void) {
    if (kayokoMainViewController) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [kayokoMainViewController handleHistoryChanged];
        });
    }
}

void KayokoCorePaste(void) {
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - lastPasteFeedbackOccurred) < kKayokoMinimumFeedbackInterval) {
        return;
    }
    lastPasteFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        pasteSoundPlayer = KayokoCorePlayFeedbackSound(pasteSoundPlayer, @"Paste");
    }
    KayokoCorePlaySuccessHapticFeedbackIfNeeded();
}

static void KayokoCoreHandleLockStateNotification(void) {
    BOOL locked = NO;
    if (!KayokoCoreReadUILocked(&locked) || !locked) {
        return;
    }

    KayokoCoreHideImmediately();
}

void KayokoCoreStartLockStateObserver(void) {
    if (kayokoLockStateToken != 0) {
        return;
    }

    int status = notify_register_dispatch("com.apple.springboard.lockstate", &kayokoLockStateToken,
                                          dispatch_get_main_queue(), ^(int token) {
                                            (void)token;
                                            KayokoCoreHandleLockStateNotification();
                                          });
    if (status != NOTIFY_STATUS_OK) {
        HBLogDebug(@"Kayoko: Unable to observe SpringBoard lock state: %d", status);
        kayokoLockStateToken = 0;
    }
}
