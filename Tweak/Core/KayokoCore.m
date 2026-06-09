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
#import <os/lock.h>

#import <HBLog.h>
#import <roothide.h>
#import <substrate.h>

#import "NotificationKeys.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"
#import "Views/KayokoView.h"
#import <libSandy.h>

#define kMinimumFeedbackInterval 0.6

KayokoView *kayokoView = nil;
UIControl *kayokoBackdropView = nil;

BOOL kayokoPrefsEnabled = NO;
NSUInteger kayokoHelperPrefsActivationMethod = 0;

NSUInteger kayokoPrefsMaximumHistoryAmount = 0;
BOOL kayokoPrefsSaveText = NO;
BOOL kayokoPrefsSaveImages = NO;
BOOL kayokoPrefsAutomaticallyPaste = NO;
BOOL kayokoPrefsDisablePasteTips = NO;
BOOL kayokoPrefsIgnoreRemoteReplication = NO;
BOOL kayokoPrefsAlwaysShowFavoritesOnShow = NO;
BOOL kayokoPrefsShowRecordedTimeInHistory = NO;
BOOL kayokoPrefsShowRecordedTimeInFavorites = NO;
BOOL kayokoPrefsPlaySoundEffects = NO;
BOOL kayokoPrefsPlayHapticFeedback = NO;

CGFloat kayokoPrefsHeightInPoints = 420;

static BOOL isInPasteProgress = NO;

static NSTimeInterval lastPasteFeedbackOccurred = 0;
static NSTimeInterval lastCopyFeedbackOccurred = 0;

static void hide(void);

@interface UIStatusBarStyleRequest : NSObject
@property(nonatomic, assign, readonly) long long style;
@end

@interface SBStatusBarManager : NSObject
+ (instancetype)sharedInstance;
- (UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

@interface SBWindowSceneStatusBarManager : NSObject
+ (instancetype)windowSceneStatusBarManagerForEmbeddedDisplay;
- (UIStatusBarStyleRequest *)frontmostStatusBarStyleRequest;
@end

static BOOL KayokoViewContainsFirstResponder(UIView *view) {
    if (!view) {
        return NO;
    }
    if ([view isFirstResponder]) {
        return YES;
    }
    for (UIView *subview in [view subviews]) {
        if (KayokoViewContainsFirstResponder(subview)) {
            return YES;
        }
    }
    return NO;
}

@interface KayokoCoreBackdropTapHandler : NSObject
- (void)backdropTapped:(id)sender;
@end

@implementation KayokoCoreBackdropTapHandler

- (void)backdropTapped:(id)sender {
    hide();
}

@end

static KayokoCoreBackdropTapHandler *kayokoBackdropTapHandler = nil;

static CGRect KayokoScreenBoundsForWindow(UIWindow *statusBarWindow) {
    CGRect screenBounds = CGRectZero;
    if (statusBarWindow) {
        screenBounds = [statusBarWindow convertRect:[statusBarWindow bounds] toWindow:nil];
        screenBounds = CGRectStandardize(screenBounds);
    }

    if (CGRectIsEmpty(screenBounds) || screenBounds.size.width <= 0 || screenBounds.size.height <= 0) {
        screenBounds = [[UIScreen mainScreen] bounds];
    }

    return screenBounds;
}

static CGFloat KayokoTopInsetForWindow(UIWindow *statusBarWindow) {
    CGFloat topInset = 0;
    if (statusBarWindow && [statusBarWindow respondsToSelector:@selector(safeAreaInsets)]) {
        if (@available(iOS 11.0, *)) {
            topInset = [statusBarWindow safeAreaInsets].top;
        }
    }

    if (topInset <= 0) {
        @try {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
            #pragma clang diagnostic pop
            if (statusBarFrame.size.height > 0) {
                topInset = statusBarFrame.size.height;
            }
        } @catch (NSException *exception) {
            // ignore
        }
    }

    return topInset;
}

static CGFloat KayokoPanelHeightForWindow(UIWindow *statusBarWindow) {
    CGRect screenBounds = KayokoScreenBoundsForWindow(statusBarWindow);
    CGFloat availableHeight = screenBounds.size.height - KayokoTopInsetForWindow(statusBarWindow);
    if (availableHeight <= 0) {
        return 0;
    }

    return MIN(kayokoPrefsHeightInPoints, availableHeight);
}

static CGFloat KayokoPanelWidthForWindow(UIWindow *statusBarWindow) {
    CGRect screenBounds = KayokoScreenBoundsForWindow(statusBarWindow);
    CGFloat availableWidth = screenBounds.size.width;
    if (availableWidth <= 0) {
        return 0;
    }

    if (screenBounds.size.width > screenBounds.size.height) {
        CGFloat insetWidth = availableWidth - 32.0;
        if (insetWidth > 0) {
            availableWidth = MIN(insetWidth, 560.0);
        }
    }

    return availableWidth;
}

static CGRect KayokoBackdropFrameForWindow(UIWindow *statusBarWindow) {
    if (!statusBarWindow) {
        return CGRectZero;
    }

    return [statusBarWindow convertRect:KayokoScreenBoundsForWindow(statusBarWindow) fromWindow:nil];
}

static void KayokoEnsureBackdropInStatusBarWindow(UIWindow *statusBarWindow) {
    if (!statusBarWindow) {
        return;
    }

    if (!kayokoBackdropView) {
        kayokoBackdropView = [[UIControl alloc] initWithFrame:KayokoBackdropFrameForWindow(statusBarWindow)];
        [kayokoBackdropView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
        [kayokoBackdropView setBackgroundColor:[UIColor colorWithWhite:0 alpha:0.025]];
        [kayokoBackdropView setHidden:YES];

        if (!kayokoBackdropTapHandler) {
            kayokoBackdropTapHandler = [[KayokoCoreBackdropTapHandler alloc] init];
        }
        [kayokoBackdropView addTarget:kayokoBackdropTapHandler
                               action:@selector(backdropTapped:)
                     forControlEvents:UIControlEventTouchUpInside];
    }

    if ([kayokoBackdropView superview] != statusBarWindow) {
        [kayokoBackdropView removeFromSuperview];
        [statusBarWindow addSubview:kayokoBackdropView];
    }

    [kayokoBackdropView setFrame:KayokoBackdropFrameForWindow(statusBarWindow)];

    if (kayokoView && [kayokoView superview] == statusBarWindow) {
        [statusBarWindow insertSubview:kayokoBackdropView belowSubview:kayokoView];
        [kayokoView setBackdropView:kayokoBackdropView];
    }
}

#pragma mark - UIStatusBarWindow class hooks

static CGFloat kayokoDesiredScreenY = -1;

static CGFloat KayokoBaseScreenYForWindow(UIWindow *statusBarWindow) {
    CGRect screenBounds = KayokoScreenBoundsForWindow(statusBarWindow);
    CGFloat topBoundary = CGRectGetMinY(screenBounds) + KayokoTopInsetForWindow(statusBarWindow);
    CGFloat baseY = CGRectGetMaxY(screenBounds) - KayokoPanelHeightForWindow(statusBarWindow);
    return baseY < topBoundary ? topBoundary : baseY;
}

static void KayokoUpdateFrameInStatusBarWindow(UIWindow *statusBarWindow, BOOL animated, NSDictionary *userInfo) {
    if (!statusBarWindow || !kayokoView) {
        return;
    }

    KayokoEnsureBackdropInStatusBarWindow(statusBarWindow);

    CGRect screenBounds = KayokoScreenBoundsForWindow(statusBarWindow);
    CGFloat panelHeight = KayokoPanelHeightForWindow(statusBarWindow);
    CGFloat panelWidth = KayokoPanelWidthForWindow(statusBarWindow);
    CGFloat topBoundary = CGRectGetMinY(screenBounds) + KayokoTopInsetForWindow(statusBarWindow);
    CGFloat baseScreenY = KayokoBaseScreenYForWindow(statusBarWindow);
    if (kayokoDesiredScreenY < 0) {
        kayokoDesiredScreenY = baseScreenY;
    }

    CGFloat desiredScreenY = kayokoDesiredScreenY;
    if (desiredScreenY < topBoundary) {
        desiredScreenY = topBoundary;
    }
    if (desiredScreenY > baseScreenY) {
        desiredScreenY = baseScreenY;
    }

    CGRect targetFrameOnScreen = CGRectMake(CGRectGetMinX(screenBounds) + ((screenBounds.size.width - panelWidth) / 2.0),
                                            desiredScreenY, panelWidth, panelHeight);
    CGRect targetFrame = [statusBarWindow convertRect:targetFrameOnScreen fromWindow:nil];

    if ([kayokoView superview] != statusBarWindow) {
        [kayokoView removeFromSuperview];
        [statusBarWindow addSubview:kayokoView];
    }

    [statusBarWindow insertSubview:kayokoBackdropView belowSubview:kayokoView];

    [kayokoView setAutoresizingMask:UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin |
                                   UIViewAutoresizingFlexibleTopMargin];
    [[kayokoView superview] bringSubviewToFront:kayokoView];

    if (!animated) {
        [kayokoView setFrame:targetFrame];
        return;
    }

    NSNumber *durationNumber = userInfo[UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curveNumber = userInfo[UIKeyboardAnimationCurveUserInfoKey];
    NSTimeInterval duration = durationNumber ? [durationNumber doubleValue] : 0.25;

    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    if (curveNumber) {
        options |= ((UIViewAnimationOptions)([curveNumber integerValue] << 16));
    } else {
        options |= UIViewAnimationOptionCurveEaseInOut;
    }

    [UIView animateWithDuration:duration
        delay:0
        options:options
        animations:^{
          [kayokoView setFrame:targetFrame];
        }
        completion:nil];
}

@interface KayokoCoreKeyboardObserver : NSObject
@end

@implementation KayokoCoreKeyboardObserver

- (void)animateKayokoToY:(CGFloat)targetY withKeyboardNotification:(NSNotification *)notification {
    if (!kayokoView || [kayokoView isHidden]) {
        return;
    }

    NSDictionary *userInfo = [notification userInfo] ?: @{};
    NSNumber *durationNumber = userInfo[UIKeyboardAnimationDurationUserInfoKey];
    NSNumber *curveNumber = userInfo[UIKeyboardAnimationCurveUserInfoKey];

    NSTimeInterval duration = durationNumber ? [durationNumber doubleValue] : 0.25;
    UIViewAnimationOptions options = UIViewAnimationOptionBeginFromCurrentState;
    if (curveNumber) {
        options |= ((UIViewAnimationOptions)([curveNumber integerValue] << 16));
    } else {
        options |= UIViewAnimationOptionCurveEaseInOut;
    }

    CGRect frame = [kayokoView frame];
    frame.origin.y = targetY;

    if ([kayokoView superview]) {
        [[kayokoView superview] bringSubviewToFront:kayokoView];
    }

    [UIView animateWithDuration:duration
        delay:0
        options:options
        animations:^{
          [kayokoView setFrame:frame];
        }
        completion:nil];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo] ?: @{};
    if (userInfo[UIKeyboardIsLocalUserInfoKey] && ![userInfo[UIKeyboardIsLocalUserInfoKey] boolValue]) {
        return;
    }

    UIWindow *statusBarWindow = (UIWindow *)[kayokoView superview];
    CGRect screenBounds = KayokoScreenBoundsForWindow(statusBarWindow);
    CGRect keyboardEndFrame = CGRectZero;
    NSValue *keyboardFrameValue = userInfo[UIKeyboardFrameEndUserInfoKey];
    if (keyboardFrameValue) {
        keyboardEndFrame = [keyboardFrameValue CGRectValue];
    }

    CGFloat panelHeight = KayokoPanelHeightForWindow(statusBarWindow);
    CGFloat topBoundary = CGRectGetMinY(screenBounds) + KayokoTopInsetForWindow(statusBarWindow);
    CGFloat baseY = KayokoBaseScreenYForWindow(statusBarWindow);
    CGFloat keyboardTopY = keyboardEndFrame.origin.y;
    if (panelHeight <= 0 || keyboardTopY <= CGRectGetMinY(screenBounds) || keyboardTopY > CGRectGetMaxY(screenBounds)) {
        // 键盘 frame 不可信时不移动（避免跳动）。
        return;
    }

    CGFloat targetScreenY = keyboardTopY - panelHeight;
    if (targetScreenY < topBoundary) {
        targetScreenY = topBoundary;
    }
    if (targetScreenY > baseY) {
        targetScreenY = baseY;
    }

    kayokoDesiredScreenY = targetScreenY;
    KayokoUpdateFrameInStatusBarWindow(statusBarWindow, YES, [notification userInfo] ?: @{});
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary *userInfo = [notification userInfo] ?: @{};
    if (userInfo[UIKeyboardIsLocalUserInfoKey] && ![userInfo[UIKeyboardIsLocalUserInfoKey] boolValue]) {
        return;
    }

    BOOL kayokoHadFocus = (kayokoView && ![kayokoView isHidden] && KayokoViewContainsFirstResponder(kayokoView));

    UIWindow *statusBarWindow = (UIWindow *)[kayokoView superview];
    kayokoDesiredScreenY = KayokoBaseScreenYForWindow(statusBarWindow);
    KayokoUpdateFrameInStatusBarWindow(statusBarWindow, YES, userInfo);

    // 如果键盘是由 Kayoko 内置搜索等输入触发的，键盘收起后把焦点还给 App 的输入框。
    if (kayokoHadFocus) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
          CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                               (CFStringRef)kNotificationKeyHelperRestoreFirstResponder, nil, nil,
                                               YES);
        });
    }
}

@end

/**
 * Sets up the history view.
 *
 * Using the status bar's window is hacky, yet it's present on SpringBoard and in apps.
 * It's important to note that it runs on the SpringBoard process too, which gives us file system read/write.
 *
 * @param frame
 */
static void (*orig_UIStatusBarWindow_initWithFrame)(UIStatusBarWindow *self, SEL _cmd, CGRect frame);
static void override_UIStatusBarWindow_initWithFrame(UIStatusBarWindow *self, SEL _cmd, CGRect frame) {
    orig_UIStatusBarWindow_initWithFrame(self, _cmd, frame);

    // 初始化时默认贴底（屏幕坐标系）。
    if (kayokoDesiredScreenY < 0) {
        kayokoDesiredScreenY = KayokoBaseScreenYForWindow((UIWindow *)self);
    }

    if (!kayokoView) {
        CGFloat panelWidth = KayokoPanelWidthForWindow((UIWindow *)self);
        CGFloat panelHeight = KayokoPanelHeightForWindow((UIWindow *)self);
        kayokoView = [[KayokoView alloc] initWithFrame:CGRectMake(0, 0, panelWidth, panelHeight)];
        [kayokoView setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
        [kayokoView setAlwaysShowFavoritesOnShow:kayokoPrefsAlwaysShowFavoritesOnShow];
        [kayokoView setShowRecordedTimeInHistory:kayokoPrefsShowRecordedTimeInHistory];
        [kayokoView setShowRecordedTimeInFavorites:kayokoPrefsShowRecordedTimeInFavorites];
        [kayokoView setHidden:YES];
        [self addSubview:kayokoView];
    }

    KayokoEnsureBackdropInStatusBarWindow((UIWindow *)self);

    KayokoUpdateFrameInStatusBarWindow((UIWindow *)self, NO, nil);
}

static void (*orig_UIStatusBarWindow_setFrame)(UIStatusBarWindow *self, SEL _cmd, CGRect frame);
static void override_UIStatusBarWindow_setFrame(UIStatusBarWindow *self, SEL _cmd, CGRect frame) {
    orig_UIStatusBarWindow_setFrame(self, _cmd, frame);

    // statusBarWindow 在键盘/编辑时可能会被系统移动；同步更新 Kayoko 的 frame 以保持屏幕位置不变。
    if (kayokoView && [kayokoView superview] == self) {
        KayokoUpdateFrameInStatusBarWindow((UIWindow *)self, NO, nil);
    }
}

#pragma mark - Notification callbacks

static void kayokoPasteWillStart() { isInPasteProgress = YES; }

/**
 * Receives the notification that the pasteboard changed from the daemon and pulls the new changes.
 */
static void _kayokoCopy() {
    NSLog(@"[----] [Kayoko] Copying ...");
    [[PasteboardManager sharedInstance] pullPasteboardChangesWithCompletion:^(BOOL didSaveAnyItem) {
        NSLog(@"[----] [Kayoko] didSaveAnyItem: %d", didSaveAnyItem);
        if (isInPasteProgress) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              isInPasteProgress = NO;
            });
            return;
        }
        if (!didSaveAnyItem) {
            return;
        }
        NSTimeInterval now = CACurrentMediaTime();
        if (fabs(now - lastCopyFeedbackOccurred) < kMinimumFeedbackInterval) {
            return;
        }
        lastCopyFeedbackOccurred = now;
        if (kayokoPrefsPlaySoundEffects) {
            static dispatch_once_t onceToken;
            static SystemSoundID copySoundID = 0;
            dispatch_once(&onceToken, ^{
              CFURLRef soundURL = (__bridge CFURLRef)[NSURL fileURLWithPath:jbroot(
                                                 @"/Library/PreferenceBundles/KayokoPreferences.bundle/Copy.aiff")];
              AudioServicesCreateSystemSoundID(soundURL, &copySoundID);
            });
            if (copySoundID != 0) {
                AudioServicesPlaySystemSound(copySoundID);
            }
        }
        if (kayokoPrefsPlayHapticFeedback) {
            AudioServicesPlaySystemSound(1519);
        }
    }];
}

static BOOL limitedCallback(CFTimeInterval interval) {
    static CFTimeInterval lastTime = 0;
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    CFTimeInterval now = CACurrentMediaTime();
    os_unfair_lock_lock(&lock);
    BOOL limited = (now - lastTime) < interval;
    if (!limited) {
        lastTime = now;
    }
    os_unfair_lock_unlock(&lock);
    return limited;
}

static void kayokoCopy() {
    if (limitedCallback(0.1)) {
        NSLog(@"[----] [kayoko]: 频率过高，已限制");
        return;
    }

    // NSLog(@"[----] kayokoCopy");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (kayokoPrefsIgnoreRemoteReplication) {
            BOOL isRemote = [[UIPasteboard generalPasteboard] containsPasteboardTypes:@[@"com.apple.is-remote-clipboard"]];
            if (isRemote) {
                NSLog(@"[----] [kayoko]: 检测到远程复制，忽略此次粘贴板变更");
                return;
            }
        }

        // 从macOS远程复制文件时会有com.apple.icns类型
        BOOL isRemoteFile = [[UIPasteboard generalPasteboard] containsPasteboardTypes:@[@"com.apple.icns"]];
        if (isRemoteFile) {
            NSLog(@"[----] [kayoko]: 检测到远程文件，忽略此次粘贴板变更");
            return;
        }

        _kayokoCopy();
    });
}

/**
 * Shows the history.
 */
static void show() {
    if ([kayokoView isHidden]) {
        UIWindow *statusBarWindow = (UIWindow *)[kayokoView superview];

        kayokoDesiredScreenY = KayokoBaseScreenYForWindow(statusBarWindow);
        KayokoUpdateFrameInStatusBarWindow(statusBarWindow, NO, nil);

        [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleUnspecified];

        /* iOS 15 */
        SBStatusBarManager *statusBarManager = [objc_getClass("SBStatusBarManager") sharedInstance];
        if (statusBarManager) {
            UIStatusBarStyleRequest *styleRequest = [statusBarManager frontmostStatusBarStyleRequest];
            if (styleRequest) {
                long long style = [styleRequest style];
                BOOL isKindOfDark = style == 1;
                if (isKindOfDark) {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
                } else {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
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
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleDark];
                } else {
                    [kayokoView setOverrideUserInterfaceStyle:UIUserInterfaceStyleLight];
                }
            }
        }

        [kayokoView show];

        if (kayokoPrefsPlayHapticFeedback && (kayokoHelperPrefsActivationMethod & kActivationMethodDictationKey)) {
            AudioServicesPlaySystemSound(1519);
        }
    }
}

static void showHistory(){
    kayokoView.alwaysShowFavoritesOnShow = NO;
    show();
}

static void showFavourite(){
    kayokoView.alwaysShowFavoritesOnShow = YES;
    show();
}

/**
 * Hides the history.
 */
static void hide() {
    if (kayokoBackdropView) {
        [kayokoBackdropView setHidden:YES];
    }

    if (kayokoView && ![kayokoView isHidden]) {
        [kayokoView hide];
    }
}

/**
 * Reloads the history.
 */
static void reload() {
    if (![kayokoView isHidden]) {
        [kayokoView reload];
    }
}

#pragma mark - Preferences

/**
 * Loads the user's preferences.
 */
static void load_preferences() {
    NSString *preferencesPath = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kPreferencesIdentifier];
    preferencesPath = jbroot(preferencesPath);
    NSDictionary *storedPreferences = [NSDictionary dictionaryWithContentsOfFile:preferencesPath] ?: @{};

    libSandy_applyProfile("Kayoko");

    NSDictionary *defaultPreferences = @{
        kPreferenceKeyEnabled : @(kPreferenceKeyEnabledDefaultValue),
        kPreferenceKeyActivationMethod : @(kPreferenceKeyActivationMethodDefaultValue),
        kPreferenceKeyMaximumHistoryAmount : @(kPreferenceKeyMaximumHistoryAmountDefaultValue),
        kPreferenceKeySaveText : @(kPreferenceKeySaveTextDefaultValue),
        kPreferenceKeySaveImages : @(kPreferenceKeySaveImagesDefaultValue),
        kPreferenceKeyAutomaticallyPaste : @(kPreferenceKeyAutomaticallyPasteDefaultValue),
        kPreferenceKeyDisablePasteTips : @(kPreferenceKeyDisablePasteTipsDefaultValue),
        kPreferenceKeyIgnoreRemoteReplication : @(kPreferenceKeyIgnoreRemoteReplicationDefaultValue),
        kPreferenceKeyAlwaysShowFavoritesOnShow : @(kPreferenceKeyAlwaysShowFavoritesOnShowDefaultValue),
        kPreferenceKeyShowRecordedTime : @(kPreferenceKeyShowRecordedTimeDefaultValue),
        kPreferenceKeyShowRecordedTimeInHistory : @(kPreferenceKeyShowRecordedTimeInHistoryDefaultValue),
        kPreferenceKeyShowRecordedTimeInFavorites : @(kPreferenceKeyShowRecordedTimeInFavoritesDefaultValue),
        kPreferenceKeyPlaySoundEffects : @(kPreferenceKeyPlaySoundEffectsDefaultValue),
        kPreferenceKeyPlayHapticFeedback : @(kPreferenceKeyPlayHapticFeedbackDefaultValue),
        kPreferenceKeyHeightInPoints : @(kPreferenceKeyHeightInPointsDefaultValue),
    };

    NSMutableDictionary *effectivePreferences = [defaultPreferences mutableCopy];
    [effectivePreferences addEntriesFromDictionary:storedPreferences];

    kayokoPrefsEnabled = [effectivePreferences[kPreferenceKeyEnabled] boolValue];
    kayokoHelperPrefsActivationMethod =
        [effectivePreferences[kPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoPrefsMaximumHistoryAmount =
        [effectivePreferences[kPreferenceKeyMaximumHistoryAmount] unsignedIntegerValue];
    kayokoPrefsSaveText = [effectivePreferences[kPreferenceKeySaveText] boolValue];
    kayokoPrefsSaveImages = [effectivePreferences[kPreferenceKeySaveImages] boolValue];
    kayokoPrefsAutomaticallyPaste = [effectivePreferences[kPreferenceKeyAutomaticallyPaste] boolValue];
    kayokoPrefsDisablePasteTips = [effectivePreferences[kPreferenceKeyDisablePasteTips] boolValue];
    kayokoPrefsIgnoreRemoteReplication = [effectivePreferences[kPreferenceKeyIgnoreRemoteReplication] boolValue];
    if (@available(iOS 16, *)) {
        // iOS16以上默认禁用。
        kayokoPrefsDisablePasteTips = YES;
    }
    kayokoPrefsAlwaysShowFavoritesOnShow =
        [effectivePreferences[kPreferenceKeyAlwaysShowFavoritesOnShow] boolValue];
    NSNumber *legacyShowRecordedTimeValue = effectivePreferences[kPreferenceKeyShowRecordedTime];
    NSNumber *showRecordedTimeInHistoryValue = effectivePreferences[kPreferenceKeyShowRecordedTimeInHistory];
    NSNumber *showRecordedTimeInFavoritesValue = effectivePreferences[kPreferenceKeyShowRecordedTimeInFavorites];
    kayokoPrefsShowRecordedTimeInHistory =
        showRecordedTimeInHistoryValue ? [showRecordedTimeInHistoryValue boolValue]
                                       : (legacyShowRecordedTimeValue ? [legacyShowRecordedTimeValue boolValue]
                                                                      : kPreferenceKeyShowRecordedTimeInHistoryDefaultValue);
    kayokoPrefsShowRecordedTimeInFavorites =
        showRecordedTimeInFavoritesValue ? [showRecordedTimeInFavoritesValue boolValue]
                                         : (legacyShowRecordedTimeValue ? [legacyShowRecordedTimeValue boolValue]
                                                                        : kPreferenceKeyShowRecordedTimeInFavoritesDefaultValue);
    kayokoPrefsPlaySoundEffects = [effectivePreferences[kPreferenceKeyPlaySoundEffects] boolValue];
    kayokoPrefsPlayHapticFeedback = [effectivePreferences[kPreferenceKeyPlayHapticFeedback] boolValue];
    kayokoPrefsHeightInPoints = [effectivePreferences[kPreferenceKeyHeightInPoints] doubleValue];

    [[PasteboardManager sharedInstance] preparePasteboardQueue];
    [[PasteboardManager sharedInstance] setMaximumHistoryAmount:kayokoPrefsMaximumHistoryAmount];
    [[PasteboardManager sharedInstance] setSaveText:kayokoPrefsSaveText];
    [[PasteboardManager sharedInstance] setSaveImages:kayokoPrefsSaveImages];
    [[PasteboardManager sharedInstance] setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];

    if (kayokoView) {
        [kayokoView setAutomaticallyPaste:kayokoPrefsAutomaticallyPaste];
        [kayokoView setShouldPlayFeedback:kayokoPrefsPlayHapticFeedback];
        [kayokoView setAlwaysShowFavoritesOnShow:kayokoPrefsAlwaysShowFavoritesOnShow];
        [kayokoView setShowRecordedTimeInHistory:kayokoPrefsShowRecordedTimeInHistory];
        [kayokoView setShowRecordedTimeInFavorites:kayokoPrefsShowRecordedTimeInFavorites];
        [kayokoView reload];
        UIWindow *statusBarWindow = (UIWindow *)[kayokoView superview];
        kayokoDesiredScreenY = KayokoBaseScreenYForWindow(statusBarWindow);
        KayokoUpdateFrameInStatusBarWindow(statusBarWindow, NO, nil);
    }
}

static void kayokoPreferencesDidReload(CFNotificationCenterRef center, void *observer, CFStringRef name,
                                                                             const void *object, CFDictionaryRef userInfo) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            load_preferences();
        });
}

#pragma mark - Sound effects

static void kayokoPaste() {
    NSTimeInterval now = CACurrentMediaTime();
    if (fabs(now - lastPasteFeedbackOccurred) < kMinimumFeedbackInterval) {
        return;
    }
    lastPasteFeedbackOccurred = now;
    if (kayokoPrefsPlaySoundEffects) {
        static dispatch_once_t onceToken;
        static SystemSoundID pasteSoundID = 0;
        dispatch_once(&onceToken, ^{
          CFURLRef soundURL = (__bridge CFURLRef)[NSURL fileURLWithPath:jbroot(
                                             @"/Library/PreferenceBundles/KayokoPreferences.bundle/Paste.aiff")];
          AudioServicesCreateSystemSoundID(soundURL, &pasteSoundID);
        });
        if (pasteSoundID != 0) {
            AudioServicesPlaySystemSound(pasteSoundID);
        }
    }
    if (kayokoPrefsPlayHapticFeedback) {
        AudioServicesPlaySystemSound(1519);
    }
}

#pragma mark - Constructor

/**
 * Initializes the core.
 *
 * First it loads the preferences and continues if Kayoko is enabled.
 * Secondly it sets up the hooks.
 * Finally it registers the notification callbacks.
 */
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

        MSHookMessageEx(statusBarWindowCls, @selector(initWithFrame:),
                        (IMP)&override_UIStatusBarWindow_initWithFrame, (IMP *)&orig_UIStatusBarWindow_initWithFrame);

        MSHookMessageEx(statusBarWindowCls, @selector(setFrame:), (IMP)&override_UIStatusBarWindow_setFrame,
                (IMP *)&orig_UIStatusBarWindow_setFrame);

                // Kayoko 自带下拉搜索会弹键盘：键盘出现时把 KayokoView 上移到键盘上方，避免被盖住看起来像“消失”。
                static KayokoCoreKeyboardObserver *keyboardObserver;
                keyboardObserver = [[KayokoCoreKeyboardObserver alloc] init];
                [[NSNotificationCenter defaultCenter] addObserver:keyboardObserver
                                                                                                 selector:@selector(keyboardWillShow:)
                                                                                                         name:UIKeyboardWillShowNotification
                                                                                                     object:nil];
                [[NSNotificationCenter defaultCenter] addObserver:keyboardObserver
                                                                                                 selector:@selector(keyboardWillHide:)
                                                                                                         name:UIKeyboardWillHideNotification
                                                                                                     object:nil];

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
            (CFStringRef)kNotificationKeyCoreShowDev, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showHistory,
            (CFStringRef)kNotificationKeyCopyVaultHistoryShow, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showFavourite,
            (CFStringRef)kNotificationKeyCopyVaultFavouriteShow, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)hide,
            (CFStringRef)kNotificationKeyCoreHide, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)reload,
            (CFStringRef)kNotificationKeyCoreReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoPreferencesDidReload,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
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

    NSArray *args = [[NSProcessInfo processInfo] arguments];
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
            CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)kayokoPreferencesDidReload,
            (CFStringRef)kNotificationKeyPreferencesReload, NULL,
            (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

        return;
    }
}
