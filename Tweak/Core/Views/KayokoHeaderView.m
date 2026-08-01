//
//  KayokoHeaderView.m
//  Kayoko
//

#import "KayokoHeaderView.h"

#import "KayokoGrabberView.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoPasteboardManager.h"

static CGFloat const kKayokoHeaderHeight = 60;
static CGFloat const kKayokoTitleTapControlHeight = 44;
static CGFloat const kKayokoTitleTapControlTrailingSpacing = 8;
static CGFloat const kKayokoTrailingHeaderButtonCenterSpacing = 44;
static CGFloat const kKayokoGrabberTopSpacing = 5;
static CGFloat const kKayokoHeaderControlsBottomSpacing = 9;

@interface KayokoHeaderView ()

@property(nonatomic, strong, readwrite) KayokoGrabberView *grabber;
@property(nonatomic, strong, readwrite) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) UIControl *titleTapControl;
@property(nonatomic, strong, readwrite) UIButton *leadingButton;
@property(nonatomic, strong, readwrite) UIButton *trailingButton;
@property(nonatomic, strong, readwrite) UIButton *alternateTrailingButton;

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
        _historySegmentedControl = [[UISegmentedControl alloc]
            initWithItems:@[ historySegmentTitle, favoritesSegmentTitle ]];
        [_historySegmentedControl setSelectedSegmentIndex:0];
        [_historySegmentedControl setApportionsSegmentWidthsByContent:NO];
        [_historySegmentedControl setSelectedSegmentTintColor:[UIColor tertiarySystemFillColor]];
        [_historySegmentedControl setTitleTextAttributes:@{
            NSFontAttributeName : [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold],
            NSForegroundColorAttributeName : [UIColor labelColor]
        } forState:UIControlStateNormal];
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

        [NSLayoutConstraint activateConstraints:@[
            [[_grabber topAnchor] constraintEqualToAnchor:[self topAnchor] constant:kKayokoGrabberTopSpacing],
            [[_grabber centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_leadingButton bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]
                                                            constant:-kKayokoHeaderControlsBottomSpacing],
            [[_leadingButton centerXAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                           constant:kKayokoLeadingHeaderButtonCenterXInset],
            [[_titleLabel centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_titleLabel leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                        constant:kKayokoTitleLabelLeadingInset],
            [[_historySegmentedControl centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]],
            [[_historySegmentedControl centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_historySegmentedControl widthAnchor] constraintEqualToConstant:196],
            [[_historySegmentedControl heightAnchor] constraintEqualToConstant:32],
            [[_trailingButton centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
            [[_trailingButton centerXAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                            constant:-kKayokoTrailingHeaderButtonCenterXInset],
            [[_alternateTrailingButton centerYAnchor] constraintEqualToAnchor:[_leadingButton centerYAnchor]],
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
                         imageSize:kKayokoFavoritesButtonImageSize
                         tintColor:[UIColor labelColor]];
        [self updateStyleForButton:_trailingButton
                     withImageName:@"xmark.circle"
                         imageSize:kKayokoClearButtonImageSize
                         tintColor:[UIColor labelColor]];
    }
    return self;
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
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

@end
