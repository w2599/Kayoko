//
//  KayokoMainViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController : NSObject

@property(nonatomic, strong, readonly) UIView *view;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL dismissOnOutsideTouch;
@property(nonatomic, assign) BOOL swipeToSelectWords;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, assign) BOOL shouldPlayFeedback;

- (instancetype)initWithFrame:(CGRect)frame;

- (BOOL)isHidden;
- (CGRect)frame;
- (void)setFrame:(CGRect)frame;
- (CGAffineTransform)transform;
- (void)setTransform:(CGAffineTransform)transform;
- (void)setNeedsLayout;
- (nullable UIView *)superview;
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style;
- (void)setOutsideDismissOverlayView:(nullable UIControl *)outsideDismissOverlayView;

- (void)handleHistoryChanged;
- (void)preloadHistoryIfNeeded;
- (void)show;
- (void)hide;
- (void)reload;

@end

NS_ASSUME_NONNULL_END
