//
//  KayokoClearConfirmationView.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@interface KayokoClearConfirmationView : UIView
@property(nonatomic, copy) NSString *name;
@property(nonatomic, strong, readonly) UILabel *titleLabel;
@property(nonatomic, strong, readonly) UILabel *messageLabel;
@property(nonatomic, strong, readonly) UIButton *cancelButton;
@property(nonatomic, strong, readonly) UIButton *confirmButton;
- (instancetype)initWithName:(NSString *)name;
@end