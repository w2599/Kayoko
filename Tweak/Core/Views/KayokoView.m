//
//  KayokoView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoView.h"
#import "KayokoFavoritesTableView.h"
#import "KayokoClearConfirmationView.h"
#import "KayokoHistoryTableView.h"
#import "KayokoPreviewView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import <roothide.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>

static CGFloat const kKayokoViewTopCornerRadius = 25; // 视图顶部圆角半径
static CGFloat const kKayokoViewShadowRadius = 5.0; // 阴影半径
static CGFloat const kKayokoViewShadowOpacity = 0.33; // 阴影不透明度

static CGFloat const kKayokoEdgeIndicatorWidth = 39.0; // 指示器宽度
static CGFloat const kKayokoEdgeIndicatorHeight = 3.0; // 指示器高度
static CGFloat const kKayokoEdgeIndicatorOutsideOffset = -5.15; // 指示器距离视图顶部的偏移量
static NSTimeInterval const kKayokoEdgeIndicatorPulseDuration = 2.5; // 指示器脉冲动画持续时间
static CGFloat const kKayokoSegmentedMultiplier = 0.39; // 切换按钮宽度比例
static CGFloat const kKayokoSecondaryHeaderButtonAlpha = 0.75; // 次级头部按钮透明度
static CGFloat const kKayokoHideTranslationMultiplier = 1.0; // 收起时向下滑动的距离比例
static NSTimeInterval const kKayokoHideAnimationDuration = 0.03; // 收起动画时长
static CGFloat const kKayokoButtonAnchor = 32.0; // 按钮边距

@interface KayokoView ()
@property(nonatomic, strong) UIView *edgeIndicatorView;
@property(nonatomic, strong) KayokoClearConfirmationView *clearConfirmationView;
@end

@implementation KayokoView

// If the user toggles the segmented control while an animation is running,
// store the last requested index here and apply it when the animation completes.
// Use UISegmentedControlNoSegment (-1) as "no pending".
{
    NSInteger _pendingSegmentIndex;
    __weak UIWindow *_adjustedWindow;
    UIWindowLevel _originalWindowLevel;
    BOOL _didAdjustWindowLevel;
    __weak UIView *_clearConfirmationSourceView;
}

- (void)startEdgeIndicatorAnimation {
    UIView *edgeIndicatorView = [self edgeIndicatorView];
    if (!edgeIndicatorView) {
        return;
    }

    if ([[edgeIndicatorView layer] animationForKey:@"kayoko.edgeIndicator.pulse"]) {
        return;
    }

    CABasicAnimation *pulse = [CABasicAnimation animationWithKeyPath:@"opacity"];
    [pulse setFromValue:@0.12];
    [pulse setToValue:@0.62];
    [pulse setDuration:kKayokoEdgeIndicatorPulseDuration];
    [pulse setAutoreverses:YES];
    [pulse setRepeatCount:HUGE_VALF];
    [pulse setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
    [[edgeIndicatorView layer] addAnimation:pulse forKey:@"kayoko.edgeIndicator.pulse"];
}

- (void)stopEdgeIndicatorAnimation {
    [[[self edgeIndicatorView] layer] removeAnimationForKey:@"kayoko.edgeIndicator.pulse"];
}

- (void)updateClearButtonVisibility {
    BOOL isPreviewVisible = ![[self previewView] isHidden];
    BOOL isClearConfirmationVisible = ![[self clearConfirmationView] isHidden];
    BOOL isHistoryVisible = ![[self historyTableView] isHidden];
    BOOL isFavoritesVisible = ![[self favoritesTableView] isHidden];
    [[self clearButton] setHidden:!(isHistoryVisible && !isPreviewVisible && !isClearConfirmationVisible)];
    [[self sortButton] setHidden:!(isFavoritesVisible && !isPreviewVisible && !isClearConfirmationVisible)];
}

- (void)updateClearConfirmationCopy {
    NSBundle *bundle = [PasteboardManager localizationBundle];
    NSString *key = kHistoryKeyHistory;
    NSString *message = [NSString stringWithFormat:[bundle localizedStringForKey:@"This will clear your %@."
                                                                           value:nil
                                                                           table:@"Tweak"],
                         [bundle localizedStringForKey:key value:nil table:@"Tweak"]];

    [[self clearConfirmationView] setName:[bundle localizedStringForKey:@"History"
                                                              value:nil
                                                              table:@"Tweak"]];
    [[[self clearConfirmationView] titleLabel] setText:[bundle localizedStringForKey:@"Are you sure?"
                                                                                value:nil
                                                                                table:@"Tweak"]];
    [[[self clearConfirmationView] messageLabel] setText:message];
    [[[self clearConfirmationView] cancelButton] setTitle:[bundle localizedStringForKey:@"No"
                                                                                 value:nil
                                                                                 table:@"Tweak"]
                                                forState:UIControlStateNormal];
    [[[self clearConfirmationView] confirmButton] setTitle:[bundle localizedStringForKey:@"Yes"
                                                                                   value:nil
                                                                                   table:@"Tweak"]
                                                  forState:UIControlStateNormal];
}

- (void)showClearConfirmation {
    if (_isAnimating || ![[self clearConfirmationView] isHidden]) {
        return;
    }

    [self updateClearConfirmationCopy];
    _clearConfirmationSourceView = [self historyTableView];
    [self showContentView:[self clearConfirmationView] andHideContentView:_clearConfirmationSourceView reverse:NO];

    [[self clearButton] setHidden:YES];
    [[self sortButton] setHidden:YES];
    [[self backButton] setHidden:NO];
    [[self closeButton] setHidden:YES];
}

- (void)hideClearConfirmation {
    if ([[self clearConfirmationView] isHidden] || _isAnimating) {
        return;
    }

    UIView *sourceView = _clearConfirmationSourceView ?: [self historyTableView];
    [self showContentView:sourceView andHideContentView:[self clearConfirmationView] reverse:YES];

    [[self clearButton] setHidden:NO];
    [[self sortButton] setHidden:YES];
    [[self backButton] setHidden:YES];
    [[self closeButton] setHidden:NO];
    _clearConfirmationSourceView = nil;
}

- (void)clearHistoryItems {
    NSString *key = kHistoryKeyHistory;
    NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:key];
    for (NSDictionary *dictionary in items) {
        PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
        [[PasteboardManager sharedInstance] removePasteboardItem:item
                                              fromHistoryWithKey:key
                                               shouldRemoveImage:YES];
    }

    NSArray *updatedItems = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:key];
    [[self historyTableView] reloadDataWithItems:updatedItems];
    [self updateClearButtonVisibility];
}

- (void)handleClearConfirmationCancelPressed {
    [self hideClearConfirmation];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)handleClearConfirmationConfirmPressed {
    [self clearHistoryItems];
    [self hideClearConfirmation];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
}

- (void)selectHistoryAsActiveContentView {
    if (![[self previewView] isHidden]) {
        [[self previewView] setHidden:YES];
        [[self previewView] setAlpha:1];
        [[self previewView] setTransform:CGAffineTransformIdentity];
        [[self previewView] reset];
        _previewSourceTableView = nil;
    }

    if (![[self clearConfirmationView] isHidden]) {
        [[self clearConfirmationView] setHidden:YES];
        [[self clearConfirmationView] setAlpha:1];
        [[self clearConfirmationView] setTransform:CGAffineTransformIdentity];
        _clearConfirmationSourceView = nil;
    }

    [[self favoritesTableView] setHidden:YES];
    [[self favoritesTableView] setAlpha:1];
    [[self favoritesTableView] setTransform:CGAffineTransformIdentity];
    [[self historyTableView] setHidden:NO];
    [[self historyTableView] setAlpha:1];
    [[self historyTableView] setTransform:CGAffineTransformIdentity];

    [[self backButton] setHidden:YES];
    [self updateClearButtonVisibility];

    [[self titleLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                       value:nil
                                                                                       table:@"Tweak"]];

    if ([self contentSegmentedControl]) {
        [[self contentSegmentedControl] setSelectedSegmentIndex:0];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // Keep shadow tight and aligned with the rounded top corners.
    UIBezierPath *shadowPath = [UIBezierPath bezierPathWithRoundedRect:[self bounds]
                                                    byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                          cornerRadii:CGSizeMake(kKayokoViewTopCornerRadius,
                                                                                 kKayokoViewTopCornerRadius)];
    [[self layer] setShadowPath:[shadowPath CGPath]];

    UIVisualEffectView *blurView = [self blurEffectView];
    if (!blurView) {
        return;
    }

    [blurView setClipsToBounds:YES];

    if (@available(iOS 11.0, *)) {
        [[blurView layer] setCornerRadius:kKayokoViewTopCornerRadius];
        [[blurView layer] setMaskedCorners:(kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner)];
        [[blurView layer] setMask:nil];

        if (@available(iOS 13.0, *)) {
            [[blurView layer] setCornerCurve:kCACornerCurveContinuous];
        }
    } else {
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:[blurView bounds]
                                                   byRoundingCorners:(UIRectCornerTopLeft | UIRectCornerTopRight)
                                                         cornerRadii:CGSizeMake(kKayokoViewTopCornerRadius,
                                                                                kKayokoViewTopCornerRadius)];
        CAShapeLayer *maskLayer = [CAShapeLayer layer];
        [maskLayer setFrame:[blurView bounds]];
        [maskLayer setPath:[path CGPath]];
        [[blurView layer] setMask:maskLayer];
    }
}

- (void)selectFavoritesAsActiveContentView {
    if (![[self previewView] isHidden]) {
        [[self previewView] setHidden:YES];
        [[self previewView] setAlpha:1];
        [[self previewView] setTransform:CGAffineTransformIdentity];
        [[self previewView] reset];
        _previewSourceTableView = nil;
    }

    if (![[self clearConfirmationView] isHidden]) {
        [[self clearConfirmationView] setHidden:YES];
        [[self clearConfirmationView] setAlpha:1];
        [[self clearConfirmationView] setTransform:CGAffineTransformIdentity];
        _clearConfirmationSourceView = nil;
    }

    [[self historyTableView] setHidden:YES];
    [[self historyTableView] setAlpha:1];
    [[self historyTableView] setTransform:CGAffineTransformIdentity];
    [[self favoritesTableView] setHidden:NO];
    [[self favoritesTableView] setAlpha:1];
    [[self favoritesTableView] setTransform:CGAffineTransformIdentity];

    [[self backButton] setHidden:YES];
    [self updateClearButtonVisibility];

    [[self titleLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                       value:nil
                                                                                       table:@"Tweak"]];

    if ([self contentSegmentedControl]) {
        [[self contentSegmentedControl] setSelectedSegmentIndex:1];
    }
}

/**
 * Initializes the main view.
 *
 * @param frame
 */
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        _pendingSegmentIndex = UISegmentedControlNoSegment;
        [self hide];

        // Allow the edge indicator to render slightly outside the panel.
        [self setClipsToBounds:NO];

        [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[self layer] setShadowOffset:CGSizeZero];
        [[self layer] setShadowRadius:kKayokoViewShadowRadius];
        [[self layer] setShadowOpacity:kKayokoViewShadowOpacity];

        [self setBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
        [self setBlurEffectView:[[UIVisualEffectView alloc] initWithEffect:[self blurEffect]]];
        [self addSubview:[self blurEffectView]];

        [[self blurEffectView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self blurEffectView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self blurEffectView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self blurEffectView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self blurEffectView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setEdgeIndicatorView:[[UIView alloc] init]];
        [[self edgeIndicatorView] setUserInteractionEnabled:NO];
        [[self edgeIndicatorView] setBackgroundColor:[[UIColor labelColor] colorWithAlphaComponent:0.32]];
        [[[self edgeIndicatorView] layer] setCornerRadius:(kKayokoEdgeIndicatorHeight / 2.0)];
        if (@available(iOS 13.0, *)) {
            [[[self edgeIndicatorView] layer] setCornerCurve:kCACornerCurveContinuous];
        }
        [self addSubview:[self edgeIndicatorView]];

        [[self edgeIndicatorView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self edgeIndicatorView] centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[[self edgeIndicatorView] bottomAnchor] constraintEqualToAnchor:[self topAnchor]
                                                                  constant:-kKayokoEdgeIndicatorOutsideOffset],
            [[[self edgeIndicatorView] widthAnchor] constraintEqualToConstant:kKayokoEdgeIndicatorWidth],
            [[[self edgeIndicatorView] heightAnchor] constraintEqualToConstant:kKayokoEdgeIndicatorHeight]
        ]];

        [self setHeaderView:[[UIView alloc] init]];
        [self addSubview:[self headerView]];

        [[self headerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setHeaderHeightConstraint:[[[self headerView] heightAnchor] constraintEqualToConstant:36]];
        [NSLayoutConstraint activateConstraints:@[
            [self headerHeightConstraint],
            [[[self headerView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self headerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self headerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]]
        ]];

        [self setPanGestureRecognizer:[[UIPanGestureRecognizer alloc]
                                          initWithTarget:self
                                                  action:@selector(handlePanGestureRecognizer:)]];
        [[self headerView] addGestureRecognizer:[self panGestureRecognizer]];

        [self setTapGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(handleBackButtonPressed)]];
        [[self headerView] addGestureRecognizer:[self tapGestureRecognizer]];

        NSArray *segmentItems = @[ [[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                   value:nil
                                                   table:@"Tweak"],
                       [[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                   value:nil
                                                   table:@"Tweak"] ];
        [self setContentSegmentedControl:[[UISegmentedControl alloc] initWithItems:segmentItems]];
        [[self contentSegmentedControl] addTarget:self
                                           action:@selector(handleContentSegmentedControlChanged:)
                                 forControlEvents:UIControlEventValueChanged];
        UILongPressGestureRecognizer *segmentedLongPressRecognizer =
            [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(handleContentSegmentedControlLongPress:)];
        [[self contentSegmentedControl] addGestureRecognizer:segmentedLongPressRecognizer];
        // 默认展示“历史”（索引 0），收藏在右侧（索引 1）
        [[self contentSegmentedControl] setSelectedSegmentIndex:0];
        [[self headerView] addSubview:[self contentSegmentedControl]];

        [[self contentSegmentedControl] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self contentSegmentedControl] centerXAnchor] constraintEqualToAnchor:[[self headerView] centerXAnchor]],
            [[[self contentSegmentedControl] centerYAnchor] constraintEqualToAnchor:[[self headerView] centerYAnchor]],
            [[[self contentSegmentedControl] heightAnchor] constraintEqualToConstant:32],
            [[[self contentSegmentedControl] widthAnchor] constraintEqualToAnchor:[[self headerView] widthAnchor]
                                                                       multiplier:kKayokoSegmentedMultiplier],
            [[[self contentSegmentedControl] leadingAnchor] constraintGreaterThanOrEqualToAnchor:[[self headerView] leadingAnchor]
                                                                                        constant:24],
            [[[self contentSegmentedControl] trailingAnchor] constraintLessThanOrEqualToAnchor:[[self headerView] trailingAnchor]
                                                                                       constant:-24]
        ]];

        [self setTitleLabel:[[UILabel alloc] init]];
        [[self titleLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                   value:nil
                                                   table:@"Tweak"]];
        [[self titleLabel] setFont:[UIFont systemFontOfSize:18 weight:UIFontWeightSemibold]];
        [[self titleLabel] setTextColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self titleLabel]];

        [[self titleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self titleLabel] centerYAnchor] constraintEqualToAnchor:[[self headerView] centerYAnchor]],
            [[[self titleLabel] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                              constant:76]
        ]];
        [[self titleLabel] setHidden:YES];

        [self setClearButton:[[UIButton alloc] init]];
        [[self clearButton] addTarget:self
                               action:@selector(handleClearButtonPressed)
                     forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self clearButton]
                           withImageName:@"trash.circle"
                            andImageSize:kClearButtonImageSize
                                                        andTintColor:[UIColor labelColor]
                                                    andImageWeight:UIImageSymbolWeightRegular];
                [[self clearButton] setAlpha:kKayokoSecondaryHeaderButtonAlpha];
        [[self headerView] addSubview:[self clearButton]];
        [[self clearButton] setHidden:YES];

        [[self clearButton] setTranslatesAutoresizingMaskIntoConstraints:NO];

        [NSLayoutConstraint activateConstraints:@[
            [[[self clearButton] centerYAnchor] constraintEqualToAnchor:[[self headerView] centerYAnchor]],
            [[[self clearButton] leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor] constant:kKayokoButtonAnchor]
        ]];

                [self setSortButton:[[UIButton alloc] init]];
                [[self sortButton] addTarget:self
                                                            action:@selector(handleSortButtonPressed)
                                        forControlEvents:UIControlEventTouchUpInside];
                [self updateStyleForHeaderButton:[self sortButton]
                                                     withImageName:@"equal.circle"
                                                        andImageSize:kClearButtonImageSize
                                                        andTintColor:[UIColor labelColor]
                                                    andImageWeight:UIImageSymbolWeightRegular];
                [[self sortButton] setAlpha:kKayokoSecondaryHeaderButtonAlpha];
                [[self headerView] addSubview:[self sortButton]];
                [[self sortButton] setHidden:YES];
                [[self sortButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
                [NSLayoutConstraint activateConstraints:@[
                        [[[self sortButton] centerYAnchor] constraintEqualToAnchor:[[self headerView] centerYAnchor]],
                        [[[self sortButton] leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor] constant:kKayokoButtonAnchor]
                ]];

        // Add a close button on the right top to close the view.
        [self setCloseButton:[[UIButton alloc] init]];
        [[self closeButton] addTarget:self action:@selector(handleCloseButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self closeButton]
                           withImageName:@"chevron.down.circle"
                            andImageSize:kClearButtonImageSize
                                                        andTintColor:[UIColor labelColor]
                                                    andImageWeight:UIImageSymbolWeightRegular];
                [[self closeButton] setAlpha:kKayokoSecondaryHeaderButtonAlpha];
        [[self headerView] addSubview:[self closeButton]];
        [[self closeButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self closeButton] centerYAnchor] constraintEqualToAnchor:[[self headerView] centerYAnchor]],
            [[[self closeButton] trailingAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                                 constant:-kKayokoButtonAnchor]
        ]];

        [self setBackButton:[[UIButton alloc] init]];
        [[self backButton] addTarget:self action:@selector(handleBackButtonPressed) forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self backButton]
                           withImageName:@"arrowshape.turn.up.backward.circle"
                            andImageSize:kBackButtonImageSize
                                                        andTintColor:[UIColor labelColor]
                                                    andImageWeight:UIImageSymbolWeightRegular];
                [[self backButton] setAlpha:kKayokoSecondaryHeaderButtonAlpha];
        [[self headerView] addSubview:[self backButton]];
        [[self backButton] setHidden:YES];

        [[self backButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self backButton] centerYAnchor] constraintEqualToAnchor:[[self headerView] centerYAnchor]],
            [[[self backButton] trailingAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                                 constant:-kKayokoButtonAnchor]
        ]];

        [self setHistoryTableView:[[KayokoHistoryTableView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                                                   localizedStringForKey:@"History"
                                                                                                   value:nil
                                                                                                   table:@"Tweak"]]];

        // Match header height to list item height.
        [[self headerHeightConstraint] setConstant:[[self historyTableView] rowHeight]];

        [self addSubview:[self historyTableView]];

        [[self historyTableView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self historyTableView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:0],
            [[[self historyTableView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self historyTableView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self historyTableView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self
            setFavoritesTableView:[[KayokoFavoritesTableView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                                                     localizedStringForKey:@"Favorites"
                                                                                                     value:nil
                                                                                                     table:@"Tweak"]]];
        // 默认展示历史：历史可见、收藏隐藏
        [[self favoritesTableView] setHidden:YES];
        [self addSubview:[self favoritesTableView]];

        NSArray *historyItems = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyHistory];
        [[self historyTableView] reloadDataWithItems:historyItems];

        [[self historyTableView] setHidden:NO];

        [[self favoritesTableView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesTableView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:0],
            [[[self favoritesTableView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self favoritesTableView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self favoritesTableView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setPreviewView:[[KayokoPreviewView alloc]
                                 initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                                      value:nil
                                                                                                      table:@"Tweak"]]];
        [[self previewView] setHidden:YES];
        [self addSubview:[self previewView]];

        [[self previewView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self previewView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:0],
            [[[self previewView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self previewView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self previewView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setClearConfirmationView:[[KayokoClearConfirmationView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                      localizedStringForKey:@"History"
                                                              value:nil
                                                              table:@"Tweak"]]];
        [[self clearConfirmationView] setHidden:YES];
        [self addSubview:[self clearConfirmationView]];

        [[self clearConfirmationView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearConfirmationView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:0],
            [[[self clearConfirmationView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self clearConfirmationView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self clearConfirmationView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [[[self clearConfirmationView] cancelButton] addTarget:self
                                                        action:@selector(handleClearConfirmationCancelPressed)
                                              forControlEvents:UIControlEventTouchUpInside];
        [[[self clearConfirmationView] confirmButton] addTarget:self
                                                         action:@selector(handleClearConfirmationConfirmPressed)
                                               forControlEvents:UIControlEventTouchUpInside];

        [self updateClearConfirmationCopy];

        [self updateClearButtonVisibility];
    }

    return self;
}

/**
 * Handles the drag on the top of the main view to close it.
 *
 * @param recognizer The pan gesture recognizer.
 */
- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    if (_isAnimating) {
        return;
    }

    CGPoint translation = [recognizer translationInView:self];
    NSUInteger const kMaxTranslation = 100;

    if ([recognizer state] == UIGestureRecognizerStateChanged) {
        if (translation.y < 0) {
            return;
        }

        CGFloat alpha = MIN(1.0, fabs(translation.y / kMaxTranslation));
        [self setTransform:CGAffineTransformMakeTranslation(0, translation.y)];
        [self setAlpha:1 - alpha];

        if (translation.y >= kMaxTranslation) {
            [self hide];
            return;
        }
    } else if ([recognizer state] == UIGestureRecognizerStateEnded ||
               [recognizer state] == UIGestureRecognizerStateCancelled ||
               [recognizer state] == UIGestureRecognizerStateFailed) {
        if (translation.y >= kMaxTranslation) {
            [self hide];
            return;
        }

        if (translation.y < kMaxTranslation) {
            [UIView animateWithDuration:0.4
                                  delay:0
                 usingSpringWithDamping:1
                  initialSpringVelocity:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                               [self setTransform:CGAffineTransformIdentity];
                               [self setAlpha:1];
                             }
                             completion:nil];
        }
    }
}

/**
 * Updates the style of the a header button.
 *
 * @param button The button to update.
 * @param imageName The name of the system image to use on the button.
 * @param color The color to use for the image.
 */
- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color {
        [self updateStyleForHeaderButton:button
                                             withImageName:imageName
                                                andImageSize:imageSize
                                                andTintColor:color
                                            andImageWeight:UIImageSymbolWeightMedium];
}

- (void)updateStyleForHeaderButton:(UIButton *)button
                                         withImageName:(NSString *)imageName
                                            andImageSize:(NSUInteger)imageSize
                                            andTintColor:(UIColor *)color
                                        andImageWeight:(UIImageSymbolWeight)imageWeight {
    UIImageSymbolConfiguration *configuration =
                [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:imageWeight];
    [button setImage:[[UIImage systemImageNamed:imageName] imageWithConfiguration:configuration]
            forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (void)handleContentSegmentedControlChanged:(UISegmentedControl *)control {
    if (_isAnimating) {
        // Queue the latest requested selection and apply it when the transition completes.
        _pendingSegmentIndex = [control selectedSegmentIndex];

        // Apply immediate visibility changes even while animating.
        if (_pendingSegmentIndex == 1) {
            [[self clearButton] setHidden:YES];
            [[self sortButton] setHidden:NO];
        } else {
            [[self clearButton] setHidden:NO];
            [[self sortButton] setHidden:YES];
        }
        return;
    }

    BOOL isPreviewVisible = ![[self previewView] isHidden];
    BOOL isClearConfirmationVisible = ![[self clearConfirmationView] isHidden];
    if (isPreviewVisible) {
        [[self previewView] reset];
        _previewSourceTableView = nil;
        [[self clearButton] setHidden:YES];
        [[self sortButton] setHidden:YES];
        [[self backButton] setHidden:YES];
    }

    if (isClearConfirmationVisible) {
        _clearConfirmationSourceView = nil;
        [[self clearButton] setHidden:YES];
        [[self sortButton] setHidden:YES];
        [[self backButton] setHidden:YES];
    }

    // Make the delete button react immediately to the user's selection.
    if ([control selectedSegmentIndex] == 1) {
        // 收藏：不显示清空按钮
        [[self clearButton] setHidden:YES];
        [[self sortButton] setHidden:(isPreviewVisible || isClearConfirmationVisible)];
    } else {
        // 历史：非预览状态下显示清空按钮
        [[self clearButton] setHidden:(isPreviewVisible || isClearConfirmationVisible)];
        [[self sortButton] setHidden:YES];
    }

    // 索引 0 = 历史，索引 1 = 收藏
    if ([control selectedSegmentIndex] == 0) {
        if (![[self historyTableView] isHidden]) {
            return;
        }

        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyHistory];
        [[self historyTableView] reloadDataWithItems:items];

        UIView *viewToHide = isPreviewVisible ? [self previewView] :
                             (isClearConfirmationVisible ? [self clearConfirmationView] : [self favoritesTableView]);
        [self showContentView:[self historyTableView] andHideContentView:viewToHide reverse:YES];
    } else {
        if (![[self favoritesTableView] isHidden]) {
            return;
        }

        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyFavorites];
        [[self favoritesTableView] reloadDataWithItems:items];

        UIView *viewToHide = isPreviewVisible ? [self previewView] :
                             (isClearConfirmationVisible ? [self clearConfirmationView] : [self historyTableView]);
        [self showContentView:[self favoritesTableView] andHideContentView:viewToHide reverse:NO];
    }

    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)handleContentSegmentedControlLongPress:(UILongPressGestureRecognizer *)recognizer {
    if ([recognizer state] != UIGestureRecognizerStateBegan) {
        return;
    }

    if (_isAnimating) {
        return;
    }

    BOOL isPreviewHidden = [[self previewView] isHidden];
    BOOL isHistoryActive = ([self contentSegmentedControl].selectedSegmentIndex == 0) &&
                           ![[self historyTableView] isHidden] && isPreviewHidden;
    BOOL isFavoritesActive = ([self contentSegmentedControl].selectedSegmentIndex == 1) &&
                             ![[self favoritesTableView] isHidden] && isPreviewHidden;
    if (!isHistoryActive && !isFavoritesActive) {
        return;
    }

    if (isHistoryActive) {
        [self setShowRecordedTimeInHistory:![self showRecordedTimeInHistory]];
        [[self historyTableView] setShowRecordedTime:[self showRecordedTimeInHistory]];

        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyHistory];
        [[self historyTableView] reloadDataWithItems:items];
    } else {
        [self setShowRecordedTimeInFavorites:![self showRecordedTimeInFavorites]];
        [[self favoritesTableView] setShowRecordedTime:[self showRecordedTimeInFavorites]];

        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyFavorites];
        [[self favoritesTableView] reloadDataWithItems:items];
    }

    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleSortButtonPressed {

    NSString *openUrl = [NSString stringWithFormat:@"prefs:root=Hello Kayoko&path=Favorites Sort Order"];
    openUrl = [openUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *url = [NSURL URLWithString:openUrl];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[UIApplication sharedApplication] openURL:url];
#pragma clang diagnostic pop


    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
    [self hide];

}

- (void)handleClearButtonPressed {
    if (_isAnimating || [[self clearConfirmationView] isHidden] == NO) {
        return;
    }

    [self showClearConfirmation];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
}

- (void)handleBackButtonPressed {
    if (![[self clearConfirmationView] isHidden]) {
        [self hideClearConfirmation];
        return;
    }

    [self hidePreview];
}


- (void)handleCloseButtonPressed {
    if (_isAnimating) {
        return;
    }

    [self hide];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

/**
 * Shows the preview view with a given item's contents.
 *
 * @param item The item to preview.
 */
- (void)showPreviewWithItem:(PasteboardItem *)item {
    if ([item hasLink]) {
        [[[self previewView] webView] loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[item content]]]];
        [[[self previewView] webView] setHidden:NO];
    } else if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString
                               stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
        [[[self previewView] imageView] setImage:[UIImage imageWithData:imageData]];
        [[[self previewView] imageView] setHidden:NO];
    } else {
        [[[self previewView] textView] setText:[item content]];
        [[[self previewView] textView] setHidden:NO];
    }

    _previewSourceTableView = [[self historyTableView] isHidden] ? [self favoritesTableView] : [self historyTableView];
    [self showContentView:[self previewView] andHideContentView:_previewSourceTableView reverse:NO];

    [[self clearButton] setHidden:YES];
    [[self sortButton] setHidden:YES];
    [[self backButton] setHidden:NO];
    [[self closeButton] setHidden:YES];

    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

/**
 * Hides the preview view.
 */
- (void)hidePreview {
    if ([[self previewView] isHidden] || _isAnimating) {
        return;
    }

    [self showContentView:_previewSourceTableView andHideContentView:[self previewView] reverse:YES];

    // Clear button visibility will be updated after the transition.
    BOOL isHistoryVisible = self.contentSegmentedControl.selectedSegmentIndex == 0;
    [[self clearButton] setHidden:isHistoryVisible ? NO : YES];
    [[self sortButton] setHidden:isHistoryVisible ? YES : NO];
    [[self backButton] setHidden:YES];
    [[self closeButton] setHidden:NO];

    [[self previewView] reset];
}

/**
 * Animates a view in and out.
 *
 * For example when switching between the history and favorites view.
 *
 * @param viewToShow The view that's to be shown.
 * @param viewToHide The view that's to be hidden.
 * @param reverse Whether the animation should play reversed for a mirrored effect.
 */
- (void)showContentView:(UIView *)viewToShow andHideContentView:(UIView *)viewToHide reverse:(BOOL)reverse {
    [UIView transitionWithView:[self titleLabel]
                      duration:0.1
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      [[self titleLabel] setText:[viewToShow valueForKey:@"_name"]];
                    }
                    completion:nil];

    CGFloat viewToShowTransform = reverse ? 10 : -10;
    [viewToShow setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToShowTransform)];
    [viewToShow setAlpha:0];
    [viewToShow setHidden:NO];

    _isAnimating = YES;
    [UIView animateWithDuration:0.3
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];

          CGFloat viewToHideTransform = reverse ? -10 : 10;
          [viewToHide setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToHideTransform)];
          [viewToHide setAlpha:0];
        }
        completion:^(BOOL finished) {
          [viewToHide setHidden:YES];
          _isAnimating = NO;
                    [self updateClearButtonVisibility];

                    if (_pendingSegmentIndex != UISegmentedControlNoSegment) {
                            NSInteger pending = _pendingSegmentIndex;
                            _pendingSegmentIndex = UISegmentedControlNoSegment;
                            [[self contentSegmentedControl] setSelectedSegmentIndex:pending];
                            [self handleContentSegmentedControlChanged:[self contentSegmentedControl]];
                            return;
                    }

                    if (viewToShow == [self favoritesTableView]) {
                            [[self contentSegmentedControl] setSelectedSegmentIndex:1];
                    } else if (viewToShow == [self historyTableView]) {
                            [[self contentSegmentedControl] setSelectedSegmentIndex:0];
                    }
        }];
}

/**
 * Triggers haptic feedback.
 *
 * @param style The feedback type/strength to use.
 */
- (void)triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    if (!self.shouldPlayFeedback) {
        return;
    }
    [self setFeedbackGenerator:[[UIImpactFeedbackGenerator alloc] initWithStyle:style]];
    [[self feedbackGenerator] prepare];
    [[self feedbackGenerator] impactOccurred];
    [self setFeedbackGenerator:nil];
}

/**
 * Reloads the active history view.
 */
- (void)reload {
    if (![[self historyTableView] isHidden]) {
        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyHistory];
        [[self historyTableView] reloadDataWithItems:items];
    } else {
        NSArray *items = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyFavorites];
        [[self favoritesTableView] reloadDataWithItems:items];
    }
}

- (void)resetPagedTableViewsToTop {
    NSArray<KayokoTableView *> *tableViews = @[ [self historyTableView], [self favoritesTableView] ];
    for (KayokoTableView *tableView in tableViews) {
        if (!tableView) {
            continue;
        }

        [tableView layoutIfNeeded];

        CGFloat targetOffsetY = -[tableView adjustedContentInset].top;
        UISearchBar *searchBar = [tableView searchBar];
        if (searchBar) {
            CGFloat searchBarHeight = [searchBar bounds].size.height;
            if (searchBarHeight > 0) {
                targetOffsetY = searchBarHeight;
            }
        }

        [tableView setContentOffset:CGPointMake(0, targetOffsetY) animated:NO];
    }
}

/**
 * Shows the main view.
 */
- (void)show {
    if (_isAnimating) {
        return;
    }

    UIWindow *hostWindow = [self window];
    if (hostWindow && !_didAdjustWindowLevel) {
        _adjustedWindow = hostWindow;
        _originalWindowLevel = [hostWindow windowLevel];
        [hostWindow setWindowLevel:(_originalWindowLevel + 10001)];
        _didAdjustWindowLevel = YES;
    }

    UIView *backdropView = [self backdropView];
    if (backdropView) {
        [backdropView setAlpha:0];
        [backdropView setHidden:NO];

        UIView *backdropSuperview = [backdropView superview];
        if (backdropSuperview) {
            [backdropSuperview bringSubviewToFront:backdropView];
        }

        UIView *selfSuperview = [self superview];
        if (selfSuperview) {
            [selfSuperview bringSubviewToFront:self];
        }
    }

    [self startEdgeIndicatorAnimation];

    [[self historyTableView] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesTableView] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self historyTableView] setShowRecordedTime:[self showRecordedTimeInHistory]];
    [[self favoritesTableView] setShowRecordedTime:[self showRecordedTimeInFavorites]];

    if (self.alwaysShowFavoritesOnShow && !self.cleaning) {
        [self selectFavoritesAsActiveContentView];
    }else {
        [self selectHistoryAsActiveContentView];
    }

    [self reload];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self resetPagedTableViewsToTop];
    });

    [self setTransform:CGAffineTransformMakeTranslation(0, [self bounds].size.height / 3)];
    [self setAlpha:0];
    [self setHidden:NO];

    _isAnimating = YES;
    [UIView animateWithDuration:0.33
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
                    [backdropView setAlpha:1];
          [self setTransform:CGAffineTransformIdentity];
          [self setAlpha:1];
        }
        completion:^(BOOL finished) {
          _isAnimating = NO;
        }];
}

/**
 * Hides the main view.
 */
- (void)hide {
    if (_isAnimating) {
        return;
    }

    [[self clearConfirmationView] setHidden:YES];
    [[self clearConfirmationView] setAlpha:1];
    [[self clearConfirmationView] setTransform:CGAffineTransformIdentity];
    _clearConfirmationSourceView = nil;

    // 失去焦点
    [[self historyTableView] endEditing:YES];
    [[self favoritesTableView] endEditing:YES];
    [[self previewView] endEditing:YES];

    UIView *backdropView = [self backdropView];
    CGFloat hiddenOffset = MAX([self bounds].size.height * kKayokoHideTranslationMultiplier, 1.0);
    CGAffineTransform hiddenTransform = CGAffineTransformMakeTranslation(0, hiddenOffset);

    _isAnimating = YES;
    [UIView animateWithDuration:kKayokoHideAnimationDuration
        delay:0
        options:(UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState)
        animations:^{
          [self setTransform:hiddenTransform];
        }
        completion:^(BOOL finished) {
          [backdropView setHidden:YES];
          [self setHidden:YES];
          [self setTransform:CGAffineTransformIdentity];
          [self setAlpha:1];
          if (_didAdjustWindowLevel) {
              UIWindow *hostWindow = _adjustedWindow ?: [self window];
              if (hostWindow) {
                  [hostWindow setWindowLevel:_originalWindowLevel];
              }
          }
          _adjustedWindow = nil;
          _didAdjustWindowLevel = NO;
          [self stopEdgeIndicatorAnimation];
          _isAnimating = NO;
        }
    ];
}

@end
