//
//  KayokoClearConfirmationView.m
//  Kayoko
//

#import "KayokoClearConfirmationView.h"

static CGFloat const kKayokoClearConfirmationHorizontalInset = 24.0;
static CGFloat const kKayokoClearConfirmationVerticalInset = 22.0;
static CGFloat const kKayokoClearConfirmationButtonHeight = 44.0;

@interface KayokoClearConfirmationView ()
@property(nonatomic, strong, readwrite) UILabel *titleLabel;
@property(nonatomic, strong, readwrite) UILabel *messageLabel;
@property(nonatomic, strong, readwrite) UIButton *cancelButton;
@property(nonatomic, strong, readwrite) UIButton *confirmButton;
@end

@implementation KayokoClearConfirmationView

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];
        [self setBackgroundColor:[UIColor clearColor]];

        UIStackView *confirmationStackView = [[UIStackView alloc] init];
        [confirmationStackView setAxis:UILayoutConstraintAxisVertical];
        [confirmationStackView setSpacing:14];
        [self addSubview:confirmationStackView];

        [confirmationStackView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[confirmationStackView centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[confirmationStackView leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]
                                                                   constant:kKayokoClearConfirmationHorizontalInset],
            [[confirmationStackView trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                                    constant:-kKayokoClearConfirmationHorizontalInset],
            [[confirmationStackView topAnchor] constraintGreaterThanOrEqualToAnchor:[self topAnchor]
                                                                            constant:kKayokoClearConfirmationVerticalInset],
            [[confirmationStackView bottomAnchor] constraintLessThanOrEqualToAnchor:[self bottomAnchor]
                                                                             constant:-kKayokoClearConfirmationVerticalInset]
        ]];

        [self setTitleLabel:[[UILabel alloc] init]];
        [[self titleLabel] setFont:[UIFont systemFontOfSize:28 weight:UIFontWeightSemibold]];
        [[self titleLabel] setTextColor:[UIColor labelColor]];
        [[self titleLabel] setTextAlignment:NSTextAlignmentCenter];
        [[self titleLabel] setNumberOfLines:0];
        [confirmationStackView addArrangedSubview:[self titleLabel]];

        [self setMessageLabel:[[UILabel alloc] init]];
        [[self messageLabel] setFont:[UIFont systemFontOfSize:15 weight:UIFontWeightRegular]];
        [[self messageLabel] setTextColor:[[UIColor secondaryLabelColor] colorWithAlphaComponent:0.95]];
        [[self messageLabel] setNumberOfLines:0];
        [[self messageLabel] setTextAlignment:NSTextAlignmentCenter];
        [confirmationStackView addArrangedSubview:[self messageLabel]];

        UIStackView *confirmationButtonsStackView = [[UIStackView alloc] init];
        [confirmationButtonsStackView setAxis:UILayoutConstraintAxisHorizontal];
        [confirmationButtonsStackView setDistribution:UIStackViewDistributionFillEqually];
        [confirmationButtonsStackView setSpacing:12];
        [confirmationStackView addArrangedSubview:confirmationButtonsStackView];

        [self setCancelButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self cancelButton] setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        [[self cancelButton] setBackgroundColor:[[UIColor tertiarySystemFillColor] colorWithAlphaComponent:0.75]];
        [[[self cancelButton] titleLabel] setFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]];
        [[[self cancelButton] layer] setCornerRadius:14];
        [confirmationButtonsStackView addArrangedSubview:[self cancelButton]];

        [self setConfirmButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self confirmButton] setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [[self confirmButton] setBackgroundColor:[UIColor systemRedColor]];
        [[[self confirmButton] titleLabel] setFont:[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]];
        [[[self confirmButton] layer] setCornerRadius:14];
        [confirmationButtonsStackView addArrangedSubview:[self confirmButton]];

        [NSLayoutConstraint activateConstraints:@[
            [[[self cancelButton] heightAnchor] constraintEqualToConstant:kKayokoClearConfirmationButtonHeight],
            [[[self confirmButton] heightAnchor] constraintEqualToConstant:kKayokoClearConfirmationButtonHeight]
        ]];
    }

    return self;
}

@end