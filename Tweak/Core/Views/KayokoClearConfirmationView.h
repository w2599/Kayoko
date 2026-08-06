//
//  KayokoClearConfirmationView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoClearConfirmationView : UIView

@property(nonatomic, strong, readonly) UIButton *cancelButton;
@property(nonatomic, strong, readonly) UIButton *confirmButton;
@property(nonatomic, strong, readonly) UISegmentedControl *contentTypeControl;
@property(nonatomic, assign) CGFloat keyboardBottomInset;

- (void)updateWithHistoryKey:(NSString *)historyKey;
- (void)updateWithHistoryKey:(NSString *)historyKey contentType:(NSUInteger)contentType;

@end

NS_ASSUME_NONNULL_END
