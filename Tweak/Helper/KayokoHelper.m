//
//  KayokoHelper.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHelperConfiguration.h"
#import "KayokoHelperHookInstaller.h"
#import "KayokoHelperProcessContext.h"
#import "KayokoHelperRuntime.h"

__attribute((constructor)) static void initialize() {
    KayokoHelperConfiguration *configuration = [KayokoHelperConfiguration currentConfiguration];
    if (!configuration.isEnabled) {
        return;
    }

    KayokoHelperProcessContext *context = [KayokoHelperProcessContext currentContext];
    NSUInteger helperActivationMethod = configuration.activationMethod;
    if (configuration.gestureRecognizerMode == kKayokoGestureRecognizerModeSystem) {
        helperActivationMethod &= ~kActivationMethodSwipeUp;
    }

    switch (context.kind) {
    case KayokoHelperProcessKindKeyboardExtension:
        [KayokoHelperHookInstaller installKeyboardExtensionHooksWithActivationMethod:helperActivationMethod];
        return;
    case KayokoHelperProcessKindSpringBoard:
        [[KayokoHelperRuntime sharedRuntime] installSpringBoardRuntimeWithConfiguration:configuration];
        [KayokoHelperHookInstaller installSpringBoardActivationHooksWithActivationMethod:helperActivationMethod];
        return;
    case KayokoHelperProcessKindApplication:
        [KayokoHelperHookInstaller installApplicationHooksWithActivationMethod:helperActivationMethod];
        [[KayokoHelperRuntime sharedRuntime] installApplicationRuntimeWithConfiguration:configuration];
        return;
    case KayokoHelperProcessKindUnsupported:
        return;
    }
}
