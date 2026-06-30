//
//  KayokoMainView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface _UIGrabber : UIControl
@end

@interface KayokoMainView : UIView

@property(nonatomic, strong) UIBlurEffect *blurEffect;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) _UIGrabber *grabber;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *clearButton;
@property(nonatomic, strong) UIButton *backButton;
@property(nonatomic, strong) UIButton *favoritesButton;
@property(nonatomic, assign, getter=isAnimating) BOOL animating;

@property(nonatomic, copy, nullable) void (^layoutHandler)(void);

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color;
- (void)setTitleText:(NSString *)title;
- (void)setClearButtonEnabledForItemCount:(NSUInteger)itemCount;
- (void)installContentView:(UIView *)contentView hidden:(BOOL)hidden;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
                reverse:(BOOL)reverse;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
                reverse:(BOOL)reverse
             completion:(nullable void (^)(void))completion;

@end

NS_ASSUME_NONNULL_END
