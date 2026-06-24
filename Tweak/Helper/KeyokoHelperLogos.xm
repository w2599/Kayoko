#import <HBLog.h>
#import <substrate.h>

@import Foundation;
@import UIKit;
#include <math.h>

#import "KayokoHelper.h"
#import "NotificationKeys.h"
#import "PasteboardManager.h"

#define ITEM_ID "codes.aurora.kayoko.globe"

static BOOL kayokoSwipeUpTracking = NO;
static BOOL kayokoSwipeUpDidTrigger = NO;
static CGPoint kayokoSwipeUpStartPoint = CGPointZero;

static UIInputSetHostView *kayokoFindInputSetHostView(UIView *view) {
    if ([view isKindOfClass:NSClassFromString(@"UIInputSetHostView")]) {
        return (UIInputSetHostView *)view;
    }

    for (UIView *subview in view.subviews) {
        UIInputSetHostView *hostView = kayokoFindInputSetHostView(subview);
        if (hostView) {
            return hostView;
        }
    }

    return nil;
}

static BOOL kayokoPointIsInsideInputSetHostView(UIWindow *window, CGPoint point) {
    UIInputSetHostView *hostView = kayokoFindInputSetHostView(window);
    if (!hostView || !hostView.window) {
        return NO;
    }

    CGRect hostFrame = [hostView convertRect:hostView.bounds toView:window];
    return CGRectContainsPoint(hostFrame, point);
}

static BOOL kayokoPointIsInsideWindow(UIWindow *window, CGPoint point) {
    return CGRectContainsPoint(window.bounds, point);
}

static void kayokoResetSwipeUpTracking(void) {
    kayokoSwipeUpTracking = NO;
    kayokoSwipeUpDidTrigger = NO;
    kayokoSwipeUpStartPoint = CGPointZero;
}

static void kayokoShowKayoko(void) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

static void kayokoHandleSwipeUpLocation(CGPoint location) {
    if (!kayokoSwipeUpTracking || kayokoSwipeUpDidTrigger) {
        return;
    }

    CGFloat deltaX = location.x - kayokoSwipeUpStartPoint.x;
    CGFloat deltaY = location.y - kayokoSwipeUpStartPoint.y;
    if (deltaY <= -70.0 && fabs(deltaX) <= 120.0) {
        kayokoSwipeUpDidTrigger = YES;
        kayokoShowKayoko();
    }
}

static void kayokoTrackSwipeUpInKeyboardWindow(UIWindow *window, UIEvent *event, BOOL requiresInputSetHostView) {
    if (event.type != UIEventTypeTouches) {
        return;
    }

    NSSet<UITouch *> *touches = [event allTouches];
    if (touches.count != 1) {
        kayokoResetSwipeUpTracking();
        return;
    }

    UITouch *touch = [touches anyObject];
    if (touch.window != window) {
        return;
    }

    CGPoint location = [touch locationInView:window];
    switch (touch.phase) {
        case UITouchPhaseBegan:
            kayokoSwipeUpTracking = requiresInputSetHostView ? kayokoPointIsInsideInputSetHostView(window, location)
                                                             : kayokoPointIsInsideWindow(window, location);
            kayokoSwipeUpDidTrigger = NO;
            kayokoSwipeUpStartPoint = location;
            break;
        case UITouchPhaseMoved:
            kayokoHandleSwipeUpLocation(location);
            break;
        case UITouchPhaseEnded:
            kayokoHandleSwipeUpLocation(location);
            kayokoResetSwipeUpTracking();
            break;
        case UITouchPhaseCancelled:
            kayokoResetSwipeUpTracking();
            break;
        default:
            break;
    }
}

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

%group KayokoActivationGlobe

%hook UIInputSwitcherView

- (void)_reloadInputSwitcherItems {
    %orig;
    BOOL isForDictation = MSHookIvar<BOOL>(self, "m_isForDictation");
    if (isForDictation) {
        return;
    }
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    NSMutableArray *newItems = [NSMutableArray arrayWithArray:items];
    UIInputSwitcherItem *item = [[%c(UIInputSwitcherItem) alloc] initWithIdentifier:@ITEM_ID];
    [item setLocalizedTitle:[[PasteboardManager localizationBundle] localizedStringForKey:@"Kayoko"
                                                                                    value:nil
                                                                                    table:@"Tweak"]];
    if (item) {
        [newItems insertObject:item atIndex:newItems.count - 1];
    }
    MSHookIvar<NSArray *>(self, "m_inputSwitcherItems") = newItems;
}

- (void)didSelectItemAtIndex:(unsigned long long)index {
    NSArray *items = MSHookIvar<NSArray *>(self, "m_inputSwitcherItems");
    UIInputSwitcherItem *item = items[index];
    if ([item.identifier isEqualToString:@ITEM_ID]) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
    }
    %orig;
}

%end

%end // KayokoActivationGlobe

%group KayokoActivationDictation

%hook UIKeyboardDockItem

- (id)initWithImageName:(id)arg1 identifier:(id)arg2 {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    return %orig;
}

- (void)setImageName:(NSString *)arg1 {
    if ([arg1 isEqualToString:@"mic"]) {
        if (@available(iOS 16, *)) {
            arg1 = @"list.clipboard";
        } else {
            arg1 = @"doc.on.clipboard";
        }
    }
    %orig;
}

%end

%hook UIKeyboardDockItemButton

- (CGRect)imageRectForContentRect:(CGRect)arg1 {
    CGRect origRect = %orig;
    if (@available(iOS 16, *)) {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.92, origRect.size.height * 0.92);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2, origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    } else {
        if (ABS(origRect.size.width - origRect.size.height) > 1.0) {
            CGSize newSize = CGSizeMake(origRect.size.width * 0.86, origRect.size.height * 0.86);
            CGPoint newOrigin = CGPointMake(origRect.origin.x + (origRect.size.width - newSize.width) / 2, origRect.origin.y + (origRect.size.height - newSize.height) / 2);
            return CGRectMake(newOrigin.x, newOrigin.y, newSize.width, newSize.height);
        }
    }
    return origRect;
}

%end

%hook UISystemKeyboardDockController

- (void)dictationItemButtonWasPressed:(id)arg1 withEvent:(id)arg2 isRunningButton:(BOOL)arg3 {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreShow, nil, nil, YES);
}

%end

%end // KayokoActivationDictation

%group KayokoActivationSwipeUp

%hook UIRemoteKeyboardWindow

- (void)sendEvent:(UIEvent *)event {
    kayokoTrackSwipeUpInKeyboardWindow(self, event, YES);
    %orig;
}

%end

%end // KayokoActivationSwipeUp

%group KayokoActivationSwipeUpKeyboardExtension

%hook _UIHostedWindow

- (void)sendEvent:(UIEvent *)event {
    kayokoTrackSwipeUpInKeyboardWindow(self, event, NO);
    %orig;
}

%end

%end // KayokoActivationSwipeUpKeyboardExtension


void EnableKayokoActivationGlobe(void) {
    %init(KayokoActivationGlobe);
}

void EnableKayokoActivationDictation(void) {
    %init(KayokoActivationDictation);
}

void EnableKayokoActivationSwipeUp(void) {
    %init(KayokoActivationSwipeUp);
}

void EnableKayokoActivationSwipeUpForKeyboardExtension(void) {
    %init(KayokoActivationSwipeUpKeyboardExtension);
}
