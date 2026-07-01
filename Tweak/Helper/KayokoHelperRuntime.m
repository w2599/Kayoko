//
//  KayokoHelperRuntime.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelper.h"

#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <libSandy.h>

CHDeclareClass(UIKeyboardLayoutStar);
CHDeclareClass(UIKBInputBackdropView);
CHDeclareClass(UIKeyboardImpl);

static NSUserDefaults *kayokoHelperPreferences = nil;
static BOOL kayokoHelperPrefsEnabled = NO;
static NSUInteger kayokoHelperPrefsActivationMethod = 0;
static BOOL kayokoHelperPrefsAutomaticallyPaste = NO;

static BOOL applicationIsInForeground = YES;
static __weak UIResponder *kayokoFirstResponderBeforeShowingKayoko = nil;

@interface UIKeyboardLayoutStar : UIView
@end

@interface UIKBInputBackdropView : UIView
@end

@interface UIKeyboardImpl : UIView
@end

BOOL KayokoHelperEnabled(void) { return kayokoHelperPrefsEnabled; }

NSUInteger KayokoHelperActivationMethod(void) { return kayokoHelperPrefsActivationMethod; }

BOOL KayokoHelperAutomaticallyPasteEnabled(void) { return kayokoHelperPrefsAutomaticallyPaste; }

static CFStringRef KayokoHelperNotificationName(NSString *name) { return (__bridge CFStringRef)name; }

void KayokoHelperPostCoreShow(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         KayokoHelperNotificationName(kNotificationKeyCoreShow), nil, nil, YES);
}

static void KayokoHelperPostCoreHide(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         KayokoHelperNotificationName(kNotificationKeyCoreHide), nil, nil, YES);
}

void KayokoHelperLoadPreferences(void) {
    kayokoHelperPreferences = [[NSUserDefaults alloc]
        initWithSuiteName:[NSString
                              stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", kPreferencesIdentifier]];

#if THEOS_PACKAGE_SCHEME_ROOTHIDE
    libSandy_applyProfile("Kayoko_RootHide");
#else
    libSandy_applyProfile("Kayoko");
#endif

    [kayokoHelperPreferences registerDefaults:@{
        kPreferenceKeyEnabled : @(kPreferenceKeyEnabledDefaultValue),
        kPreferenceKeyActivationMethod : @(kPreferenceKeyActivationMethodDefaultValue),
        kPreferenceKeyAutomaticallyPaste : @(kPreferenceKeyAutomaticallyPasteDefaultValue)
    }];

    kayokoHelperPrefsEnabled = [[kayokoHelperPreferences objectForKey:kPreferenceKeyEnabled] boolValue];
    kayokoHelperPrefsActivationMethod =
        [[kayokoHelperPreferences objectForKey:kPreferenceKeyActivationMethod] unsignedIntegerValue];
    kayokoHelperPrefsAutomaticallyPaste =
        [[kayokoHelperPreferences objectForKey:kPreferenceKeyAutomaticallyPaste] boolValue];
}

BOOL KayokoHelperIsKeyboardExtensionProcess(void) {
    NSBundle *mainBundle = [NSBundle mainBundle];
    NSString *bundlePath = [mainBundle bundlePath];
    BOOL isPluginBundle = [[bundlePath pathExtension] isEqualToString:@"appex"] ||
                          [bundlePath rangeOfString:@"/PlugIns/"].location != NSNotFound;
    if (!isPluginBundle) {
        return NO;
    }

    NSDictionary<NSString *, id> *extensionInfo = [[mainBundle infoDictionary] objectForKey:@"NSExtension"];
    NSString *extensionPointIdentifier = [extensionInfo objectForKey:@"NSExtensionPointIdentifier"];
    return [extensionPointIdentifier isEqualToString:@"com.apple.keyboard-service"];
}

static BOOL KayokoHelperApplicationHasActiveKeyWindow(UIApplication *application) {
    if (!application || [application applicationState] != UIApplicationStateActive) {
        return NO;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [application connectedScenes]) {
            if ([scene activationState] != UISceneActivationStateForegroundActive ||
                ![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            for (UIWindow *window in [(UIWindowScene *)scene windows]) {
                if ([window isKeyWindow]) {
                    return YES;
                }
            }
        }

        return NO;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIWindow *keyWindow = [application keyWindow];
#pragma clang diagnostic pop
    return keyWindow && [keyWindow isKeyWindow];
}

@implementation UIResponder (KayokoFocusRestoration)

- (void)kayokoCaptureFirstResponderForFocusRestore:(id)sender {
    if (![self conformsToProtocol:@protocol(UITextInput)]) {
        return;
    }

    kayokoFirstResponderBeforeShowingKayoko = self;
}

@end

void KayokoHelperCaptureCurrentFirstResponder(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (!KayokoHelperApplicationHasActiveKeyWindow(application)) {
        return;
    }

    kayokoFirstResponderBeforeShowingKayoko = nil;
    [application sendAction:@selector(kayokoCaptureFirstResponderForFocusRestore:) to:nil from:nil forEvent:nil];
}

void KayokoHelperRestoreCapturedFirstResponder(void) {
    UIApplication *application = [UIApplication sharedApplication];
    if (!KayokoHelperApplicationHasActiveKeyWindow(application)) {
        return;
    }

    UIResponder *firstResponder = kayokoFirstResponderBeforeShowingKayoko;
    if (!firstResponder || [firstResponder isFirstResponder]) {
        return;
    }

    [firstResponder becomeFirstResponder];
}

void KayokoHelperOpenKayokoFromResponder(id self, SEL _cmd) {
    if ([self conformsToProtocol:@protocol(UITextInput)]) {
        kayokoFirstResponderBeforeShowingKayoko = self;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      KayokoHelperPostCoreShow();
    });
}

void KayokoHelperPaste(void) {
    if (!applicationIsInForeground) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (!KayokoHelperApplicationHasActiveKeyWindow(application)) {
        return;
    }

    KayokoHelperRestoreCapturedFirstResponder();

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         KayokoHelperNotificationName(kNotificationKeyPasteWillStart), nil, nil, YES);

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (![pasteboard string] && ![pasteboard image]) {
        PasteboardItem *item = [[PasteboardManager sharedInstance] getLatestHistoryItem];
        if (!item) {
            return;
        }

        if (![[item imageName] isEqualToString:@""]) {
            [pasteboard setImage:[[PasteboardManager sharedInstance] getImageForItem:item]];
        } else {
            [pasteboard setString:[item content]];
        }
    }

    [application sendAction:@selector(paste:) to:nil from:nil forEvent:nil];
}

CHOptimizedMethod0(self, void, UIKeyboardLayoutStar, didMoveToWindow) {
    CHSuper0(UIKeyboardLayoutStar, didMoveToWindow);
    KayokoHelperPostCoreHide();
}

CHOptimizedMethod0(self, void, UIKBInputBackdropView, didMoveToWindow) {
    CHSuper0(UIKBInputBackdropView, didMoveToWindow);
    KayokoHelperPostCoreHide();
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationDidBecomeActive, BOOL, didBecomeActive) {
    CHSuper1(UIKeyboardImpl, applicationDidBecomeActive, didBecomeActive);
    applicationIsInForeground = YES;
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillResignActive, BOOL, willResignActive) {
    CHSuper1(UIKeyboardImpl, applicationWillResignActive, willResignActive);
    applicationIsInForeground = NO;
}

CHOptimizedMethod1(self, void, UIKeyboardImpl, applicationWillSuspend, BOOL, willSuspend) {
    CHSuper1(UIKeyboardImpl, applicationWillSuspend, willSuspend);
    applicationIsInForeground = NO;
}

void KayokoHelperInstallRuntimeHooks(void) {
    CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
    CHHook0(UIKeyboardLayoutStar, didMoveToWindow);
    CHLoadClass_(&UIKBInputBackdropView$, NSClassFromString(@"UIKBInputBackdropView"));
    CHHook0(UIKBInputBackdropView, didMoveToWindow);
    CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
    CHHook1(UIKeyboardImpl, applicationDidBecomeActive);
    CHHook1(UIKeyboardImpl, applicationWillResignActive);
    CHHook1(UIKeyboardImpl, applicationWillSuspend);
}

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardObserver : NSObject
@end

NS_ASSUME_NONNULL_END

@implementation KayokoKeyboardObserver

- (void)windowDidResignKey:(NSNotification *)notification {
    KayokoHelperPostCoreHide();
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    BOOL isLocalKeyboard = [userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocalKeyboard) {
        return;
    }

    KayokoHelperPostCoreHide();
}

@end

void KayokoHelperInstallRuntimeObservers(void) {
    if (KayokoHelperAutomaticallyPasteEnabled()) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)KayokoHelperPaste,
                                        KayokoHelperNotificationName(kNotificationKeyHelperPaste), NULL,
                                        (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDrop);
    }

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    (CFNotificationCallback)KayokoHelperCaptureCurrentFirstResponder,
                                    KayokoHelperNotificationName(kNotificationKeyCoreShow), NULL,
                                    (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    (CFNotificationCallback)KayokoHelperCaptureCurrentFirstResponder,
                                    KayokoHelperNotificationName(kLegacyNotificationKeyCoreShow), NULL,
                                    (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                    (CFNotificationCallback)KayokoHelperRestoreCapturedFirstResponder,
                                    KayokoHelperNotificationName(kNotificationKeyHelperRestoreFocus), NULL,
                                    (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);

    static KayokoKeyboardObserver *observer;
    observer = [[KayokoKeyboardObserver alloc] init];

    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(windowDidResignKey:)
                                                 name:UIWindowDidResignKeyNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:observer
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}
