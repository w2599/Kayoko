//
//  KayokoHelper.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHelper.h"

#define CHUseSubstrate

#import "KayokoMenu.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import "PreferenceKeys.h"

#import <CaptainHook/CaptainHook.h>
#import <CoreFoundation/CFNotificationCenter.h>
#import <Foundation/Foundation.h>
#import <libSandy.h>

@interface TIKeyboardCandidate : NSObject
@end

@interface TIAutocorrectionList : NSObject
+ (TIAutocorrectionList *)listWithAutocorrection:(TIKeyboardCandidate *)arg1
                                     predictions:(NSArray<TIKeyboardCandidate *> *)predictions
                                       emojiList:(NSArray<TIKeyboardCandidate *> *)emojiList;
@end

@interface UIKeyboardAutocorrectionController : NSObject
- (void)setTextSuggestionList:(TIAutocorrectionList *)textSuggestionList;
- (void)setAutocorrectionList:(TIAutocorrectionList *)textSuggestionList;
@end

@interface TUIPredictionView : UIView
@end

@interface TIKeyboardCandidateSingle : TIKeyboardCandidate
@property(nonatomic, copy) NSString *candidate;
@property(nonatomic, copy) NSString *input;
@end

@interface TIZephyrCandidate : TIKeyboardCandidateSingle
@property(nonatomic, copy) NSString *label;
@property(nonatomic, copy) NSString *fromBundleId;
@end

@interface UIPredictionViewController : UIViewController
@end

@class UIKBInputDelegateManager;

@interface UIKeyboardImpl : UIView
@property(nonatomic, strong, readonly) UIKeyboardAutocorrectionController *autocorrectionController;
@property(nonatomic, strong) UIKBInputDelegateManager *inputDelegateManager;
@property(nonatomic, strong, readonly) UIResponder<UITextInput> *inputDelegate;
+ (instancetype)activeInstance;
- (void)insertText:(NSString *)text;
@end

@interface UIKBInputDelegateManager : NSObject
- (UITextRange *)selectedTextRange;
- (NSString *)textInRange:(UITextRange *)range;
- (void)insertText:(NSString *)text;
@end

@interface UIKeyboardLayout : UIView
@end

@interface UIKeyboardLayoutStar : UIKeyboardLayout
@end

@interface UIKBTree : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *properties;
@end

@interface UIKBInputBackdropView : UIView
@end

@interface UISystemKeyboardDockController : NSObject
@end

@interface UIMenu (Kayoko)
- (UIMenu *)menuByReplacingChildren:(NSArray<UIMenuElement *> *)children;
@end

@interface _UICalloutBarSystemButtonDescription : NSObject
@property(nonatomic, readonly) SEL action;
+ (instancetype)buttonDescriptionWithTitle:(NSString *)arg1 action:(SEL)arg2 type:(int)arg3;
@end

@interface UICalloutBar : UIView
@end

CHDeclareClass(UIKeyboardAutocorrectionController);
CHDeclareClass(UIPredictionViewController);
CHDeclareClass(UIKeyboardLayoutStar);
CHDeclareClass(UIKBInputBackdropView);
CHDeclareClass(UIKeyboardImpl);
CHDeclareClass(UISystemKeyboardDockController);
CHDeclareClass(_UIEditMenuPresentation);
CHDeclareClass(UICalloutBar);

NSUserDefaults *kayokoHelperPreferences = nil;

BOOL kayokoHelperPrefsEnabled = NO;
NSUInteger kayokoHelperPrefsActivationMethod = 0;
BOOL kayokoHelperPrefsAutomaticallyPaste = NO;

NSString *const kayokoMenuName = @"Kayoko";
NSString *const kayokoSelectorName = @"_Kayoko_OpenTools_ab2e39c7";
NSString *const kayokoSelectorSignature = @"v@:";

static BOOL shouldShowCustomSuggestions = NO;
static BOOL applicationIsInForeground = YES;

static TIAutocorrectionList *kayokoCreateAutocorrectionList(void);
static void kayokoPaste(void);
static BOOL kayokoIsKeyboardExtensionProcess(void);

#pragma mark - UIKeyboardAutocorrectionController class hooks

CHOptimizedMethod1(self, void, UIKeyboardAutocorrectionController, setTextSuggestionList, TIAutocorrectionList *,
                   textSuggestionList) {
    if (shouldShowCustomSuggestions) {
        CHSuper1(UIKeyboardAutocorrectionController, setTextSuggestionList, kayokoCreateAutocorrectionList());
    } else {
        CHSuper1(UIKeyboardAutocorrectionController, setTextSuggestionList, textSuggestionList);
    }
}

CHOptimizedMethod1(self, void, UIKeyboardAutocorrectionController, setAutocorrectionList, TIAutocorrectionList *,
                   autoCorrectionList) {
    if (shouldShowCustomSuggestions) {
        CHSuper1(UIKeyboardAutocorrectionController, setAutocorrectionList, kayokoCreateAutocorrectionList());
    } else {
        CHSuper1(UIKeyboardAutocorrectionController, setAutocorrectionList, autoCorrectionList);
    }
}

static TIAutocorrectionList *kayokoCreateAutocorrectionList() {
    NSArray<NSString *> *labels = @[ @"History", @"Copy", @"Paste" ];
    NSMutableArray<TIZephyrCandidate *> *candidates = [[NSMutableArray alloc] init];
    for (NSString *label in labels) {
        TIZephyrCandidate *candidate = [[objc_getClass("TIZephyrCandidate") alloc] init];
        [candidate setLabel:[[PasteboardManager localizationBundle] localizedStringForKey:label
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
        [candidate setCandidate:[NSString stringWithFormat:@"{kayoko-%@}", label]];
        [candidate setFromBundleId:@"com.82flex.kayoko"];
        [candidates addObject:candidate];
    }

    return [objc_getClass("TIAutocorrectionList") listWithAutocorrection:nil predictions:candidates emojiList:nil];
}

#pragma mark - UIPredictionViewController class hooks

CHOptimizedMethod2(self, void, UIPredictionViewController, predictionView, TUIPredictionView *, predictionView,
                   didSelectCandidate, TIZephyrCandidate *, candidate) {
    if ([candidate respondsToSelector:@selector(fromBundleId)] &&
        [[candidate fromBundleId] isEqualToString:@"com.82flex.kayoko"]) {
        if ([[candidate candidate] isEqualToString:@"{kayoko-History}"]) {
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                 (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
        } else if ([[candidate candidate] isEqualToString:@"{kayoko-Copy}"]) {
            if (@available(iOS 15.0, *)) {
                UIKBInputDelegateManager *delegateManager =
                    [[objc_getClass("UIKeyboardImpl") activeInstance] inputDelegateManager];
                UITextRange *range = [delegateManager selectedTextRange];
                NSString *text = [delegateManager textInRange:range];

                if (![text isEqualToString:@""]) {
                    [[UIPasteboard generalPasteboard] setString:text];
                }
            } else {
                id delegate = [[objc_getClass("UIKeyboardImpl") activeInstance] inputDelegate];
                UITextRange *range = [delegate selectedTextRange];
                NSString *text = [delegate textInRange:range];

                if (![text isEqualToString:@""]) {
                    [[UIPasteboard generalPasteboard] setString:text];
                }
            }
        } else if ([[candidate candidate] isEqualToString:@"{kayoko-Paste}"]) {
            kayokoPaste();
        }
    } else {
        CHSuper2(UIPredictionViewController, predictionView, predictionView, didSelectCandidate, candidate);
    }
}

CHOptimizedMethod2(self, BOOL, UIPredictionViewController, isVisibleForInputDelegate, id, delegate, inputViews, id,
                   inputViews) {
    return YES;
}

#pragma mark - UIKeyboardLayoutStar class hooks

CHOptimizedMethod1(self, void, UIKeyboardLayoutStar, setKeyplaneName, NSString *, name) {
    CHSuper1(UIKeyboardLayoutStar, setKeyplaneName, name);

    shouldShowCustomSuggestions = [name isEqualToString:@"numbers-and-punctuation"] ||
                                  [name isEqualToString:@"numbers-and-punctuation-alternate"];

    if (@available(iOS 15.0, *)) {
        [[[objc_getClass("UIKeyboardImpl") activeInstance] autocorrectionController] setAutocorrectionList:nil];
    } else {
        [[[objc_getClass("UIKeyboardImpl") activeInstance] autocorrectionController] setTextSuggestionList:nil];
    }
}

CHOptimizedMethod1(self, UIKBTree *, UIKeyboardLayoutStar, keyHitTest, CGPoint, point) {
    UIKBTree *orig = CHSuper1(UIKeyboardLayoutStar, keyHitTest, point);

    // Unset the original action and tell the core to show the history.
    if ([[orig name] isEqualToString:@"Dictation-Key"]) {
        [[orig properties] setValue:@(0) forKey:@"KBinteractionType"];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    }

    return orig;
}

CHOptimizedMethod0(self, void, UIKeyboardLayoutStar, didMoveToWindow) {
    CHSuper0(UIKeyboardLayoutStar, didMoveToWindow);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

CHOptimizedMethod0(self, void, UIKBInputBackdropView, didMoveToWindow) {
    CHSuper0(UIKBInputBackdropView, didMoveToWindow);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

#pragma mark - UIKeyboardImpl class hooks

CHOptimizedMethod0(self, BOOL, UIKeyboardImpl, shouldShowDictationKey) { return YES; }

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

#pragma mark - UISystemKeyboardDockController class hooks

CHOptimizedMethod2(self, void, UISystemKeyboardDockController, dictationItemButtonWasPressed, id, arg1, withEvent,
                   UIEvent *, event) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

#pragma mark - _UIEditMenuPresentation class hooks (iOS 16+)

CHOptimizedMethod2(self, void, _UIEditMenuPresentation, displayMenu, UIMenu *, menu, configuration, id, configuration) {
    NSMutableArray<UIMenuElement *> *build = [NSMutableArray new];
    for (id item in [menu children]) {
        if (KayokoMenuItemIsWritingTool(item)) {
            continue;
        }
        if (![item isKindOfClass:[UIMenu class]]) {
            [build addObject:item];
            continue;
        }
        UIMenu *submenu = item;
        if (![submenu.identifier isEqualToString:KayokoAppleMenuIdentifier()]) {
            [build addObject:submenu];
            continue;
        }
        NSMutableArray<UIMenuElement *> *rebuildAppleEditMenu = [submenu.children mutableCopy];
        [rebuildAppleEditMenu addObject:KayokoMenuItemUICommand()];
        UIMenu *rebuildAppleMenu = [submenu menuByReplacingChildren:rebuildAppleEditMenu];
        [build addObject:rebuildAppleMenu];
    }
    UIMenu *newMenu = [menu menuByReplacingChildren:build];
    CHSuper2(_UIEditMenuPresentation, displayMenu, newMenu, configuration, configuration);
}

#pragma mark - UICalloutBar class hooks (iOS 15)

CHOptimizedMethod1(self, void, UICalloutBar, setExtraItems, NSArray<UIMenuItem *> *, items) {
    NSMutableArray<UIMenuItem *> *newItems = [NSMutableArray arrayWithCapacity:items.count];
    for (UIMenuItem *item in items) {
        NSString *selectorName = NSStringFromSelector(item.action);
        if ([selectorName isEqualToString:kayokoSelectorName]) {
            item.action = NSSelectorFromString(@"kayokoDummyAction");
        }
        [newItems addObject:item];
    }
    CHSuper1(UICalloutBar, setExtraItems, [newItems copy]);
}

CHOptimizedMethod0(self, void, UICalloutBar, updateAvailableButtons) {
    Class cbsbdCls = NSClassFromString(@"_UICalloutBarSystemButtonDescription");
    if (!cbsbdCls || ![cbsbdCls respondsToSelector:@selector(buttonDescriptionWithTitle:action:type:)]) {
        return CHSuper0(UICalloutBar, updateAvailableButtons);
    }

    UIMenuItem *kayokoNowItem = KayokoMenuItem();
    _UICalloutBarSystemButtonDescription *buttonDescription =
        [cbsbdCls buttonDescriptionWithTitle:kayokoNowItem.title
                                      action:NSSelectorFromString(kayokoSelectorName)
                                        type:1];

    if (!buttonDescription) {
        return CHSuper0(UICalloutBar, updateAvailableButtons);
    }

    Ivar msbd = class_getInstanceVariable(object_getClass(self), "m_systemButtonDescriptions");
    if (!msbd) {
        return CHSuper0(UICalloutBar, updateAvailableButtons);
    }

    NSMutableArray<_UICalloutBarSystemButtonDescription *> *buttonDescriptions = object_getIvar(self, msbd);
    for (_UICalloutBarSystemButtonDescription *description in buttonDescriptions) {
        if (!description.action) {
            continue;
        }
        NSString *selectorName = NSStringFromSelector(description.action);
        if ([selectorName isEqualToString:NSStringFromSelector(buttonDescription.action)]) {
            return CHSuper0(UICalloutBar, updateAvailableButtons);
        }
    }

    NSInteger insertIndex = NSNotFound;
    NSInteger currentIndex = 0;
    for (_UICalloutBarSystemButtonDescription *description in buttonDescriptions) {
        if (!description.action) {
            continue;
        }
        if ([NSStringFromSelector(description.action) hasPrefix:@"_"]) {
            insertIndex = currentIndex;
            break;
        }
        currentIndex++;
    }

    if (insertIndex == 0) {
        return CHSuper0(UICalloutBar, updateAvailableButtons);
    }

    if (insertIndex == NSNotFound) {
        [buttonDescriptions addObject:buttonDescription];
    } else {
        [buttonDescriptions insertObject:buttonDescription atIndex:insertIndex];
    }

    return CHSuper0(UICalloutBar, updateAvailableButtons);
}

#pragma mark - UIResponder additions

static void kayokoOpenKayokoFromResponder(id self, SEL _cmd) {
    dispatch_async(dispatch_get_main_queue(), ^{
      CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                           (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    });
}

static BOOL kayokoApplicationHasActiveKeyWindow(UIApplication *application) {
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

#pragma mark - Notification callbacks

static void kayokoPaste() {
    if (!applicationIsInForeground) {
        return;
    }

    UIApplication *application = [UIApplication sharedApplication];
    if (!kayokoApplicationHasActiveKeyWindow(application)) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPasteWillStart, nil, nil, YES);

    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];

    // Get the latest copied item if the pasteboard cleared itself.
    // The pasteboard clears itself after inactivity.
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

NS_ASSUME_NONNULL_BEGIN

@interface KayokoKeyboardObserver : NSObject
@end

NS_ASSUME_NONNULL_END

@implementation KayokoKeyboardObserver

- (void)windowDidResignKey:(NSNotification *)notification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

- (void)keyboardWillHide:(NSNotification *)notification {
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    BOOL isLocalKeyboard = [userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocalKeyboard) {
        return;
    }

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreHide, nil, nil, YES);
}

@end

#pragma mark - Preferences

static void kayokoLoadPreferences() {
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

#pragma mark - Constructor

static BOOL kayokoIsKeyboardExtensionProcess() {
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

__attribute((constructor)) static void initialize() {
    kayokoLoadPreferences();

    if (!kayokoHelperPrefsEnabled) {
        return;
    }

    if (kayokoIsKeyboardExtensionProcess()) {
        if (kayokoHelperPrefsActivationMethod & kActivationMethodSwipeUp) {
            EnableKayokoActivationSwipeUpForKeyboardExtension();
        }
        return;
    }

    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    NSUInteger count = [args count];
    if (count == 0) {
        return;
    }

    NSString *executablePath = args[0];
    if (executablePath.length == 0) {
        return;
    }

    BOOL isApplication = [executablePath rangeOfString:@"/Application/"].location != NSNotFound ||
                         [executablePath rangeOfString:@"/Applications/"].location != NSNotFound;
    if (!isApplication) {
        return;
    }

    NSString *processName = [executablePath lastPathComponent];
    BOOL isFileProvider = [[processName lowercaseString] rangeOfString:@"fileprovider"].location != NSNotFound;
    if (isFileProvider) {
        return;
    }

    BOOL isProtectedApplication = [processName isEqualToString:@"AdSheet"] ||
                                  [processName isEqualToString:@"CoreAuthUI"] ||
                                  [processName isEqualToString:@"InCallService"] ||
                                  [processName isEqualToString:@"MessagesNotificationViewService"];
    if (isProtectedApplication) {
        return;
    }

    BOOL isApplicationExtension = [executablePath rangeOfString:@".appex/"].location != NSNotFound;
    if (isApplicationExtension) {
        return;
    }

    applicationIsInForeground = [[UIApplication sharedApplication] applicationState] == UIApplicationStateActive;

    // Prediction Bar
    if (kayokoHelperPrefsActivationMethod & kActivationMethodPredictionBar) {
        CHLoadClass_(&UIKeyboardAutocorrectionController$, NSClassFromString(@"UIKeyboardAutocorrectionController"));
        if (@available(iOS 15.0, *)) {
            CHHook1(UIKeyboardAutocorrectionController, setAutocorrectionList);
        } else {
            CHHook1(UIKeyboardAutocorrectionController, setTextSuggestionList);
        }
        CHLoadClass_(&UIPredictionViewController$, NSClassFromString(@"UIPredictionViewController"));
        CHHook2(UIPredictionViewController, isVisibleForInputDelegate, inputViews);
        CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
        CHHook1(UIKeyboardLayoutStar, setKeyplaneName);
        CHHook2(UIPredictionViewController, predictionView, didSelectCandidate);
    }

    // Dictation Key
    if (kayokoHelperPrefsActivationMethod & kActivationMethodDictationKey) {
        EnableKayokoActivationDictation();
        CHLoadClass_(&UISystemKeyboardDockController$, NSClassFromString(@"UISystemKeyboardDockController"));
        CHHook2(UISystemKeyboardDockController, dictationItemButtonWasPressed, withEvent);
        CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
        CHHook0(UIKeyboardImpl, shouldShowDictationKey);
        CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
        CHHook1(UIKeyboardLayoutStar, keyHitTest);
    }

    // Input Switcher
    if (kayokoHelperPrefsActivationMethod & kActivationMethodInputSwitcher) {
        EnableKayokoActivationGlobe();
    }

    // One-Finger Swipe Up
    if (kayokoHelperPrefsActivationMethod & kActivationMethodSwipeUp) {
        EnableKayokoActivationSwipeUp();
    }

    // Callout Bar
    if (kayokoHelperPrefsActivationMethod & kActivationMethodCalloutBar) {
        class_addMethod(NSClassFromString(@"UIResponder"), NSSelectorFromString(kayokoSelectorName),
                        (IMP)kayokoOpenKayokoFromResponder, "v@:");

        if (@available(iOS 16, *)) {
            Class targetCls = NSClassFromString(@"_UIEditMenuContentPresentation");
            if (!targetCls) {
                targetCls = NSClassFromString(@"_UIEditMenuPresentation");
            }
            CHLoadClass_(&_UIEditMenuPresentation$, targetCls);
            CHHook2(_UIEditMenuPresentation, displayMenu, configuration);
        } else {
            CHLoadClass_(&UICalloutBar$, NSClassFromString(@"UICalloutBar"));
            CHHook1(UICalloutBar, setExtraItems);
            CHHook0(UICalloutBar, updateAvailableButtons);
        }
    }

    CHLoadClass_(&UIKeyboardLayoutStar$, NSClassFromString(@"UIKeyboardLayoutStar"));
    CHHook0(UIKeyboardLayoutStar, didMoveToWindow);
    CHLoadClass_(&UIKBInputBackdropView$, NSClassFromString(@"UIKBInputBackdropView"));
    CHHook0(UIKBInputBackdropView, didMoveToWindow);
    CHLoadClass_(&UIKeyboardImpl$, NSClassFromString(@"UIKeyboardImpl"));
    CHHook1(UIKeyboardImpl, applicationDidBecomeActive);
    CHHook1(UIKeyboardImpl, applicationWillResignActive);
    CHHook1(UIKeyboardImpl, applicationWillSuspend);

    if (kayokoHelperPrefsAutomaticallyPaste) {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
                                        (CFNotificationCallback)kayokoPaste, (CFStringRef)kNotificationKeyHelperPaste,
                                        NULL, (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDrop);
    }

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
