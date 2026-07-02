//
//  KayokoHelperRuntime.h
//  Kayoko
//

#import "KayokoHelperConfiguration.h"

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHelperRuntime : NSObject

+ (instancetype)sharedRuntime;

- (void)installApplicationRuntimeWithConfiguration:(KayokoHelperConfiguration *)configuration;
- (void)installSpringBoardRuntimeWithConfiguration:(KayokoHelperConfiguration *)configuration;

- (void)showKayoko;
- (void)showKayokoAfterCapturingCurrentFocus;
- (void)showKayokoFromResponder:(UIResponder *)responder;
- (BOOL)shouldHandleActivationForCurrentInput;
- (void)playActivationRejectedFeedbackIfNeeded;
- (void)captureCurrentFirstResponder;
- (void)restoreCapturedFirstResponder;
- (void)paste;
- (BOOL)pasteIntoCurrentKayokoInput;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
