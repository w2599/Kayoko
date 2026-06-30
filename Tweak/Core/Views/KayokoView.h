//
//  KayokoView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class KayokoClearConfirmationView;
@class KayokoEmptyStateView;
@class KayokoFavoritesTableView;
@class KayokoHistoryTableView;
@class KayokoPreviewView;
@class KayokoTableView;

NS_ASSUME_NONNULL_BEGIN

@interface _UIGrabber : UIControl
@end

@interface KayokoView : UIView

@property(nonatomic, strong) UIBlurEffect *blurEffect;
@property(nonatomic, strong) UIVisualEffectView *blurEffectView;
@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) _UIGrabber *grabber;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *clearButton;
@property(nonatomic, strong) UIButton *backButton;
@property(nonatomic, strong) UIButton *favoritesButton;
@property(nonatomic, strong) KayokoHistoryTableView *historyTableView;
@property(nonatomic, strong) KayokoFavoritesTableView *favoritesTableView;
@property(nonatomic, strong) KayokoClearConfirmationView *clearConfirmationView;
@property(nonatomic, strong) KayokoEmptyStateView *emptyStateView;
@property(nonatomic, strong) KayokoPreviewView *previewView;
@property(nonatomic, assign, getter=isAnimating) BOOL animating;

@property(nonatomic, copy, nullable) void (^layoutHandler)(void);

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color;
- (void)setTitleText:(NSString *)title;
- (void)setClearButtonEnabledForTableView:(KayokoTableView *)tableView;
- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
                reverse:(BOOL)reverse;

@end

NS_ASSUME_NONNULL_END
