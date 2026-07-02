//
//  KayokoHelperHookInstaller.m
//  Kayoko
//

#import "KayokoHelperHookInstaller.h"
#import "PreferenceKeys.h"

@implementation KayokoHelperHookInstaller

+ (void)installApplicationHooksWithActivationMethod:(NSUInteger)activationMethod {
    if (activationMethod & kActivationMethodPredictionBar) {
        [self installPredictionBarHooks];
    }
    if (activationMethod & kActivationMethodDictationKey) {
        [self installDictationHooks];
    }
    if (activationMethod & kActivationMethodInputSwitcher) {
        [self installInputSwitcherHooks];
    }
    if (activationMethod & kActivationMethodSwipeUp) {
        [self installSwipeUpHooks];
    }
    if (activationMethod & kActivationMethodCalloutBar) {
        [self installCalloutBarHooks];
    }
}

+ (void)installKeyboardExtensionHooksWithActivationMethod:(NSUInteger)activationMethod {
    if (activationMethod & kActivationMethodSwipeUp) {
        [self installKeyboardExtensionSwipeUpHooks];
    }
}

@end
