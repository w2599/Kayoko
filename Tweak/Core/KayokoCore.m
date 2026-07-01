//
//  KayokoCore.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoCore.h"

#import <CoreFoundation/CoreFoundation.h>

#import "KayokoCoreRuntime.h"
#import "KayokoSpringBoardHooks.h"
#import "NotificationKeys.h"

static void KayokoCoreAddDarwinObserver(CFStringRef name, CFNotificationCallback callback) {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, callback, name, NULL,
                                    (CFNotificationSuspensionBehavior)CFNotificationSuspensionBehaviorDeliverImmediately);
}

static CFStringRef KayokoCoreNotificationName(NSString *name) { return (__bridge CFStringRef)name; }

static BOOL KayokoCoreIsSpringBoardProcess(void) {
    return [[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.apple.springboard"];
}

static BOOL KayokoCoreIsDruidOrPastedProcess(void) {
    NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
    NSString *processName = [[NSProcessInfo processInfo] processName];
    NSString *executablePath = [args firstObject];
    return ([executablePath hasPrefix:@"/System/Library/"] || [executablePath hasPrefix:@"/usr/libexec/"]) &&
           ([processName isEqualToString:@"druid"] || [processName isEqualToString:@"pasted"]);
}

static void KayokoCoreInstallSpringBoardRuntime(void) {
    KayokoCoreLoadPreferences();
    if (!KayokoCoreEnabled()) {
        return;
    }

    EnableKayokoDisablePasteTips();
    KayokoInstallSpringBoardHooks();
    KayokoCoreStartLockStateObserver();

    KayokoCoreAddDarwinObserver(CFSTR("com.apple.pasteboard.notify.changed"), (CFNotificationCallback)KayokoCoreCopy);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyCoreShow),
                                (CFNotificationCallback)KayokoCoreShow);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kLegacyNotificationKeyCoreShow),
                                (CFNotificationCallback)KayokoCoreShow);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyCoreHide),
                                (CFNotificationCallback)KayokoCoreHide);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kLegacyNotificationKeyCoreHide),
                                (CFNotificationCallback)KayokoCoreHide);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyCoreReload),
                                (CFNotificationCallback)KayokoCoreReload);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyPreferencesReload),
                                (CFNotificationCallback)KayokoCoreLoadPreferences);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyPreferencesHeightReload),
                                (CFNotificationCallback)KayokoCoreLoadHeightPreference);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyHelperPaste),
                                (CFNotificationCallback)KayokoCorePaste);
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyPasteWillStart),
                                (CFNotificationCallback)KayokoCorePasteWillStart);
}

static void KayokoCoreInstallDruidOrPastedRuntime(void) {
    KayokoCoreLoadPreferences();
    if (!KayokoCoreEnabled()) {
        return;
    }

    EnableKayokoDisablePasteTips();
    KayokoCoreAddDarwinObserver(KayokoCoreNotificationName(kNotificationKeyPreferencesReload),
                                (CFNotificationCallback)KayokoCoreLoadPreferences);
}

__attribute((constructor)) static void initialize() {
    if (KayokoCoreIsSpringBoardProcess()) {
        KayokoCoreInstallSpringBoardRuntime();
        return;
    }

    if (KayokoCoreIsDruidOrPastedProcess()) {
        KayokoCoreInstallDruidOrPastedRuntime();
        return;
    }
}
