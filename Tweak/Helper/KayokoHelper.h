//
//  KayokoHelper.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

OBJC_EXTERN NSUserDefaults *_Nullable kayokoHelperPreferences;
OBJC_EXTERN BOOL kayokoHelperPrefsEnabled;
OBJC_EXTERN NSUInteger kayokoHelperPrefsActivationMethod;
OBJC_EXTERN BOOL kayokoHelperPrefsAutomaticallyPaste;

OBJC_EXTERN NSString *const kayokoMenuName;
OBJC_EXTERN NSString *const kayokoSelectorName;
OBJC_EXTERN NSString *const kayokoSelectorSignature;

OBJC_EXTERN void EnableKayokoActivationGlobe(void);
OBJC_EXTERN void EnableKayokoActivationDictation(void);
OBJC_EXTERN void EnableKayokoActivationSwipeUp(void);
OBJC_EXTERN void EnableKayokoActivationSwipeUpForKeyboardExtension(void);

NS_ASSUME_NONNULL_END
