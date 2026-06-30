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

@interface TIKeyboardCandidate : NSObject
@end

@interface TIAutocorrectionList : NSObject
+ (TIAutocorrectionList *)listWithAutocorrection:(nullable TIKeyboardCandidate *)arg1
                                     predictions:(NSArray<TIKeyboardCandidate *> *)predictions
                                       emojiList:(nullable NSArray<TIKeyboardCandidate *> *)emojiList;
@end

@interface UIKeyboardAutocorrectionController : NSObject
- (void)setTextSuggestionList:(nullable TIAutocorrectionList *)textSuggestionList;
- (void)setAutocorrectionList:(nullable TIAutocorrectionList *)textSuggestionList;
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

@interface UIKeyboardLayout : UIView
@end

@interface UIKeyboardLayoutStar : UIKeyboardLayout
@end

@interface UIKBInputBackdropView : UIView
@end

@interface UIInputSetHostView : UIView
@end

@interface _UIHostedWindow : UIWindow
@end

@interface UISystemKeyboardDockController : NSObject
@end

@interface UIKBInputDelegateManager : NSObject
- (nullable UITextRange *)selectedTextRange;
- (nullable NSString *)textInRange:(UITextRange *)range;
- (void)insertText:(NSString *)text;
@end

@interface UIKeyboardImpl : UIView
@property(nonatomic, strong, readonly) UIKeyboardAutocorrectionController *autocorrectionController;
@property(nonatomic, strong) UIKBInputDelegateManager *inputDelegateManager;
@property(nonatomic, strong, readonly) UIResponder<UITextInput> *inputDelegate;
+ (nullable instancetype)activeInstance;
- (void)insertText:(NSString *)text;
@end

@interface UIKBTree : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *properties;
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

NS_ASSUME_NONNULL_END
