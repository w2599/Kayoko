//
//  KayokoInputSwitcherHooks.m
//  Kayoko
//

#define CHUseSubstrate

#import "KayokoHelper.h"

#import "PasteboardManager.h"

#import <CaptainHook/CaptainHook.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kKayokoInputSwitcherItemIdentifier = @"com.82flex.kayoko.globe";

CHDeclareClass(UIInputSwitcherView);

@interface UIInputSwitcherView : UIView
@end

@interface UIInputSwitcherItem : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *localizedTitle;
@property(nonatomic, copy) NSString *localizedSubtitle;
@property(nonatomic, strong) UIFont *titleFont;
@property(nonatomic, strong) UIFont *subtitleFont;
@property(assign, nonatomic) BOOL usesDeviceLanguage;
@property(nonatomic, strong) UISwitch *switchControl;
@property(nonatomic, copy) id switchIsOnBlock;
@property(nonatomic, copy) id switchToggleBlock;
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

static Ivar KayokoInstanceIvar(id object, const char *name) {
    return class_getInstanceVariable(object_getClass(object), name);
}

static id KayokoObjectIvar(id object, const char *name) {
    Ivar ivar = KayokoInstanceIvar(object, name);
    if (!ivar) {
        return nil;
    }

    return object_getIvar(object, ivar);
}

static void KayokoSetObjectIvar(id object, const char *name, id value) {
    Ivar ivar = KayokoInstanceIvar(object, name);
    if (!ivar) {
        return;
    }

    object_setIvar(object, ivar, value);
}

static BOOL KayokoBoolIvar(id object, const char *name) {
    Ivar ivar = KayokoInstanceIvar(object, name);
    if (!ivar) {
        return NO;
    }

    return *(BOOL *)((uint8_t *)(__bridge void *)object + ivar_getOffset(ivar));
}

CHOptimizedMethod0(self, void, UIInputSwitcherView, _reloadInputSwitcherItems) {
    CHSuper0(UIInputSwitcherView, _reloadInputSwitcherItems);
    BOOL isForDictation = KayokoBoolIvar(self, "m_isForDictation");
    if (isForDictation) {
        return;
    }
    NSArray *items = KayokoObjectIvar(self, "m_inputSwitcherItems");
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];
    UIInputSwitcherItem *item =
        [[NSClassFromString(@"UIInputSwitcherItem") alloc] initWithIdentifier:kKayokoInputSwitcherItemIdentifier];
    [item setLocalizedTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Kayoko"
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
    if (item) {
        [newItems insertObject:item atIndex:newItems.count - 1];
    }
    KayokoSetObjectIvar(self, "m_inputSwitcherItems", newItems);
}

CHOptimizedMethod1(self, void, UIInputSwitcherView, didSelectItemAtIndex, unsigned long long, index) {
    NSArray *items = KayokoObjectIvar(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:kKayokoInputSwitcherItemIdentifier]) {
        KayokoHelperCaptureCurrentFirstResponder();
        KayokoHelperPostCoreShow();
    }
    CHSuper1(UIInputSwitcherView, didSelectItemAtIndex, index);
}

void EnableKayokoActivationGlobe(void) {
    static dispatch_once_t sOnceToken;
    dispatch_once(&sOnceToken, ^{
      CHLoadClass_(&UIInputSwitcherView$, NSClassFromString(@"UIInputSwitcherView"));

      CHHook0(UIInputSwitcherView, _reloadInputSwitcherItems);
      CHHook1(UIInputSwitcherView, didSelectItemAtIndex);
    });
}
