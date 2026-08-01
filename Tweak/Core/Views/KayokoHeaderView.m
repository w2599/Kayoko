//
//  KayokoHeaderView.m
//  Kayoko
//

#import "KayokoHeaderView.h"

#import "KayokoGrabberView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoPasteboardManager.h"

static CGFloat const kKayokoHeaderHeight = 48; // 标题视图的高度。
static CGFloat const kKayokoTitleTapControlHeight = 44; // 标题标签的点击区域高度。
static CGFloat const kKayokoTitleTapControlTrailingSpacing = 8; // 标题标签点击区域与历史分段控件之间的间距。
static CGFloat const kKayokoTrailingHeaderButtonCenterSpacing = 44; // 右侧按钮之间的间距。
static CGFloat const kKayokoGrabberTopSpacing = -2; // 抓取条与标题视图顶部之间的间距。
static CGFloat const kKayokoHeaderButtonTouchSize = 44; // 标题视图中按钮的触控区域大小。
static CGFloat const kKayokoHeaderControlsVerticalOffset = 2; // 控件相对 Header 几何中心的视觉补偿。
static CGFloat const kKayokoTableViewCellIconLeadingInset = 16;
static CGFloat const kKayokoTableViewCellVerticalContentInset = 8;
static CGFloat const kKayokoTableViewCellDefaultRowHeight = 65;

@interface KayokoHeaderView ()

@property(nonatomic, strong, readwrite) KayokoGrabberView *grabber;
@property(nonatomic, strong, readwrite) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) UIControl *titleTapControl;
@property(nonatomic, strong, readwrite) UIButton *leadingButton;
@property(nonatomic, strong, readwrite) UIButton *trailingButton;
@property(nonatomic, strong, readwrite) UIButton *alternateTrailingButton;
@property(nonatomic, strong) NSLayoutConstraint *leadingButtonCenterXConstraint;
@property(nonatomic, strong) NSLayoutConstraint *trailingButtonCenterXConstraint;

@end

@implementation KayokoHeaderView

+ (CGFloat)preferredHeight {
    return kKayokoHeaderHeight;
}

- (instancetype)initWithTitle:(NSString *)title {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self setClipsToBounds:YES];

        _grabber = [[KayokoGrabberView alloc] init];
        [self addSubview:_grabber];
        [_grabber setTranslatesAutoresizingMaskIntoConstraints:NO];

        _leadingButton = [[UIButton alloc] init];
        [self addSubview:_leadingButton];
        [_leadingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _titleLabel = [[UILabel alloc] init];
        [_titleLabel setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [_titleLabel setTextColor:[UIColor labelColor]];
        [_titleLabel setHidden:YES];
        [self addSubview:_titleLabel];
        [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];

        NSBundle *localizationBundle = [KayokoPasteboardManager localizationBundle];
        NSString *historySegmentTitle = [localizationBundle localizedStringForKey:@"History"
                                                                              value:@"History"
                                                                              table:@"Tweak"];
        NSString *favoritesSegmentTitle = [localizationBundle localizedStringForKey:@"Favorites"
                                                                                 value:@"Favorites"
                                                                                 table:@"Tweak"];
        _historySegmentedControl = [[UISegmentedControl alloc] initWithItems:@[ historySegmentTitle, favoritesSegmentTitle ]];
        [_historySegmentedControl setSelectedSegmentIndex:0];
        [_historySegmentedControl setApportionsSegmentWidthsByContent:NO];

        [_historySegmentedControl setBackgroundColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
            if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                return [UIColor secondarySystemBackgroundColor];
            }
            return [[UIColor systemBackgroundColor] colorWithAlphaComponent:0.36];
        }]];
        [self addSubview:_historySegmentedControl];
        [_historySegmentedControl setTranslatesAutoresizingMaskIntoConstraints:NO];

        _trailingButton = [[UIButton alloc] init];
        [self addSubview:_trailingButton];
        [_trailingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _alternateTrailingButton = [[UIButton alloc] init];
        [_alternateTrailingButton setHidden:YES];
        [self addSubview:_alternateTrailingButton];
        [_alternateTrailingButton setTranslatesAutoresizingMaskIntoConstraints:NO];

        _titleTapControl = [[UIControl alloc] init];
        [_titleTapControl setBackgroundColor:[UIColor clearColor]];
        [_titleTapControl setAccessibilityTraits:[_titleTapControl accessibilityTraits] | UIAccessibilityTraitButton];
        [self addSubview:_titleTapControl];
        [_titleTapControl setTranslatesAutoresizingMaskIntoConstraints:NO];

        _leadingButtonCenterXConstraint = [[_leadingButton centerXAnchor]
            constraintEqualToAnchor:[self leadingAnchor]
                           constant:kKayokoTableViewCellIconLeadingInset +
                                    (kKayokoTableViewCellDefaultRowHeight - kKayokoTableViewCellVerticalContentInset) / 2.0];
        _trailingButtonCenterXConstraint = [[_trailingButton centerXAnchor]
            constraintEqualToAnchor:[self trailingAnchor]
                           constant:-(kKayokoTableViewCellIconLeadingInset +
                                      (kKayokoTableViewCellDefaultRowHeight - kKayokoTableViewCellVerticalContentInset) / 2.0)];

        [NSLayoutConstraint activateConstraints:@[
            [[_grabber topAnchor] constraintEqualToAnchor:[self topAnchor] constant:kKayokoGrabberTopSpacing],
            [[_grabber centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_leadingButton widthAnchor] constraintEqualToConstant:kKayokoHeaderButtonTouchSize],
            [[_leadingButton heightAnchor] constraintEqualToConstant:kKayokoHeaderButtonTouchSize],
            [[_leadingButton centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]
                                                            constant:kKayokoHeaderControlsVerticalOffset],
            [self leadingButtonCenterXConstraint],
            [[_titleLabel centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_titleLabel leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                        constant:kKayokoTitleLabelLeadingInset],
            [[_historySegmentedControl centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_historySegmentedControl centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_historySegmentedControl widthAnchor] constraintEqualToConstant:180],
            [[_historySegmentedControl heightAnchor] constraintEqualToConstant:32],
            [[_trailingButton centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_trailingButton widthAnchor] constraintEqualToConstant:kKayokoHeaderButtonTouchSize],
            [[_trailingButton heightAnchor] constraintEqualToConstant:kKayokoHeaderButtonTouchSize],
            [self trailingButtonCenterXConstraint],
            [[_alternateTrailingButton centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_alternateTrailingButton widthAnchor] constraintEqualToConstant:kKayokoHeaderButtonTouchSize],
            [[_alternateTrailingButton heightAnchor] constraintEqualToConstant:kKayokoHeaderButtonTouchSize],
            [[_alternateTrailingButton centerXAnchor]
                constraintEqualToAnchor:[_trailingButton centerXAnchor]
                               constant:-kKayokoTrailingHeaderButtonCenterSpacing],
            [[_titleTapControl leadingAnchor] constraintEqualToAnchor:[_titleLabel leadingAnchor]],
            [[_titleTapControl trailingAnchor] constraintEqualToAnchor:[_historySegmentedControl leadingAnchor]
                                                              constant:-kKayokoTitleTapControlTrailingSpacing],
            [[_titleTapControl centerYAnchor] constraintEqualToAnchor:[_titleLabel centerYAnchor]],
            [[_titleTapControl heightAnchor] constraintEqualToConstant:kKayokoTitleTapControlHeight]
        ]];

        [self setTitleText:title];

        [self updateStyleForButton:_leadingButton
                     withImageName:@"trash.circle"
                         imageSize:kKayokoClearButtonImageSize
                         tintColor:[UIColor labelColor]];
        [self updateStyleForButton:_trailingButton
                     withImageName:@"xmark.circle"
                         imageSize:kKayokoClearButtonImageSize
                         tintColor:[UIColor labelColor]];
    }

    return self;
}

- (void)setListRowHeight:(CGFloat)rowHeight {
    rowHeight = rowHeight > 0 ? rowHeight : kKayokoTableViewCellDefaultRowHeight;
    CGFloat iconSize = MAX(rowHeight - kKayokoTableViewCellVerticalContentInset, 1);
    CGFloat iconCenterX = kKayokoTableViewCellIconLeadingInset + iconSize / 2.0;
    [[self leadingButtonCenterXConstraint] setConstant:iconCenterX];
    [[self trailingButtonCenterXConstraint] setConstant:-iconCenterX];
}

- (void)setTitleText:(NSString *)title {
    if ([title length] == 0) {
        return;
    }

    [[self titleLabel] setText:title];
    [[self titleTapControl] setAccessibilityLabel:title];
}

- (void)setSelectedHistorySegmentIndex:(NSInteger)index {
    [[self historySegmentedControl] setSelectedSegmentIndex:index];
}

- (void)setGrabberFoldProgress:(CGFloat)progress {
    _grabberFoldProgress = MIN(MAX(progress, 0), 1);
    [[self grabber] setFoldProgress:_grabberFoldProgress];
}

- (void)updateStyleForButton:(UIButton *)button
               withImageName:(NSString *)imageName
                   imageSize:(NSUInteger)imageSize
                   tintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightRegular];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

@end
