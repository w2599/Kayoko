//
//  KayokoMainView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoMainView.h"

#import "KayokoHeaderButtonStyle.h"
#import "PasteboardManager.h"

@implementation KayokoMainView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        [self setHidden:YES];

        [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[self layer] setShadowOffset:CGSizeMake(0, -4)];
        [[self layer] setShadowRadius:18];
        [[self layer] setShadowOpacity:0.18];

        [self setBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        [self setBlurEffectView:[[UIVisualEffectView alloc] initWithEffect:[self blurEffect]]];
        [self addSubview:[self blurEffectView]];

        [[self blurEffectView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self blurEffectView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self blurEffectView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self blurEffectView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self blurEffectView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setHeaderView:[[UIView alloc] init]];
        [self addSubview:[self headerView]];

        [[self headerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerView] heightAnchor] constraintEqualToConstant:60],
            [[[self headerView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self headerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self headerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]]
        ]];

        [self setGrabber:[[_UIGrabber alloc] init]];
        [[self headerView] addSubview:[self grabber]];

        [[self grabber] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self grabber] topAnchor] constraintEqualToAnchor:[[self headerView] topAnchor] constant:12],
            [[[self grabber] centerXAnchor] constraintEqualToAnchor:[[self headerView] centerXAnchor]]
        ]];

        [self setFavoritesButton:[[UIButton alloc] init]];
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self favoritesButton]];

        [[self favoritesButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesButton] bottomAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                                  constant:-2],
            [[[self favoritesButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                                   constant:kLeadingHeaderButtonCenterXInset]
        ]];

        [self setTitleLabel:[[UILabel alloc] init]];
        [[self titleLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                           value:nil
                                                                                           table:@"Tweak"]];
        [[self titleLabel] setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [[self titleLabel] setTextColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self titleLabel]];

        [[self titleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self titleLabel] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self titleLabel] leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                              constant:kTitleLabelLeadingInset]
        ]];

        [self setClearButton:[[UIButton alloc] init]];
        [self updateStyleForHeaderButton:[self clearButton]
                           withImageName:@"trash"
                            andImageSize:kClearButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self clearButton]];

        [[self clearButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self clearButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                               constant:-kTrailingHeaderButtonCenterXInset]
        ]];

        [self setBackButton:[[UIButton alloc] init]];
        [self updateStyleForHeaderButton:[self backButton]
                           withImageName:@"arrowshape.turn.up.backward"
                            andImageSize:kBackButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self backButton]];
        [[self backButton] setHidden:YES];

        [[self backButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self backButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self backButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                              constant:-kTrailingHeaderButtonCenterXInset]
        ]];

    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if ([self layoutHandler]) {
        [self layoutHandler]();
    }
}

- (void)constrainContentView:(UIView *)contentView {
    [contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [NSLayoutConstraint activateConstraints:@[
        [[contentView topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
        [[contentView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
        [[contentView trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
        [[contentView bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
    ]];
}

- (void)installContentView:(UIView *)contentView hidden:(BOOL)hidden {
    [contentView setHidden:hidden];
    [self addSubview:contentView];
    [self constrainContentView:contentView];
}

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName] ?: [UIImage systemImageNamed:@"doc.on.doc"];
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (void)setTitleText:(NSString *)title {
    if ([title length] > 0) {
        [[self titleLabel] setText:title];
    }
}

- (void)setClearButtonEnabledForItemCount:(NSUInteger)itemCount {
    BOOL enabled = itemCount > 0;
    [[self clearButton] setEnabled:enabled];
    [[self clearButton] setAlpha:enabled ? 1.0 : 0.35];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
                reverse:(BOOL)reverse {
    [self showContentView:viewToShow hideContentView:viewToHide title:title reverse:reverse completion:nil];
}

- (void)showContentView:(UIView *)viewToShow
        hideContentView:(UIView *)viewToHide
                  title:(NSString *)title
                reverse:(BOOL)reverse
             completion:(void (^)(void))completion {
    [UIView transitionWithView:[self titleLabel]
                      duration:0.1
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      [self setTitleText:title];
                    }
                    completion:nil];

    CGFloat viewToShowTransform = reverse ? 10 : -10;
    [viewToShow setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToShowTransform)];
    [viewToShow setAlpha:0];
    [viewToShow setHidden:NO];

    [self setAnimating:YES];
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
        completion:^(__unused BOOL finished) {
          [viewToHide setHidden:YES];
          [self setAnimating:NO];
          if (completion) {
              completion();
          }
        }];
}

@end
