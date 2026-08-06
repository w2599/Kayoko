//
//  KayokoClearConfirmationView.m
//  Kayoko
//

#import "KayokoClearConfirmationView.h"
#import "KayokoPasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoClearConfirmationView ()
@property(nonatomic, strong) UILabel *confirmationLabel;
@property(nonatomic, copy) NSString *confirmationHistoryKey;
@property(nonatomic, strong, readwrite) UIButton *cancelButton;
@property(nonatomic, strong, readwrite) UIButton *confirmButton;
@property(nonatomic, strong, readwrite) UISegmentedControl *contentTypeControl;
@property(nonatomic, strong) NSLayoutConstraint *stackViewCenterYConstraint;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoClearConfirmationView

- (instancetype)init {
    self = [super init];

    if (self) {
        UIStackView *stackView = [[UIStackView alloc] init];
        [stackView setAxis:UILayoutConstraintAxisVertical];
        [stackView setAlignment:UIStackViewAlignmentCenter];
        [stackView setSpacing:18];
        [self addSubview:stackView];

        [stackView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setStackViewCenterYConstraint:[[stackView centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]];
        [NSLayoutConstraint activateConstraints:@[
            [[stackView centerXAnchor] constraintEqualToAnchor:[self centerXAnchor]], [self stackViewCenterYConstraint],
            [[stackView leadingAnchor] constraintGreaterThanOrEqualToAnchor:[self leadingAnchor] constant:24],
            [[stackView trailingAnchor] constraintLessThanOrEqualToAnchor:[self trailingAnchor] constant:-24]
        ]];

        [self setConfirmationLabel:[[UILabel alloc] init]];
        [[self confirmationLabel] setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
        [[self confirmationLabel] setTextColor:[UIColor secondaryLabelColor]];
        [[self confirmationLabel] setTextAlignment:NSTextAlignmentCenter];
        [[self confirmationLabel] setNumberOfLines:0];
        [stackView addArrangedSubview:[self confirmationLabel]];

        [[self confirmationLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[ [[[self confirmationLabel] widthAnchor]
                                                    constraintLessThanOrEqualToAnchor:[self widthAnchor]
                                                                             constant:-48] ]];

        NSBundle *localizationBundle = [KayokoPasteboardManager localizationBundle];
        NSString *imagesTitle = [localizationBundle localizedStringForKey:@"Images" value:@"Images" table:@"Tweak"];
        NSString *textTitle = [localizationBundle localizedStringForKey:@"Text" value:@"Text" table:@"Tweak"];
        [self setContentTypeControl:[[UISegmentedControl alloc] initWithItems:@[ imagesTitle, textTitle ]]];
        [[self contentTypeControl] setSelectedSegmentIndex:0];
        [[self contentTypeControl] addTarget:self
                          action:@selector(handleContentTypeChanged)
                    forControlEvents:UIControlEventValueChanged];
        [stackView addArrangedSubview:[self contentTypeControl]];
        [[self contentTypeControl] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self contentTypeControl] widthAnchor] constraintEqualToConstant:184],
            [[[self contentTypeControl] heightAnchor] constraintEqualToConstant:32]
        ]];

        UIStackView *buttonStackView = [[UIStackView alloc] init];
        [buttonStackView setAxis:UILayoutConstraintAxisHorizontal];
        [buttonStackView setAlignment:UIStackViewAlignmentCenter];
        [buttonStackView setDistribution:UIStackViewDistributionFillEqually];
        [buttonStackView setSpacing:12];
        [stackView addArrangedSubview:buttonStackView];

        [buttonStackView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[buttonStackView widthAnchor] constraintEqualToConstant:184],
            [[buttonStackView heightAnchor] constraintEqualToConstant:36]
        ]];

        [self setCancelButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self cancelButton] setTitle:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Cancel"
                                                                                                    value:nil
                                                                                                    table:@"Tweak"]
                             forState:UIControlStateNormal];
        [[self cancelButton] setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        [[[self cancelButton] titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
        [[self cancelButton] setBackgroundColor:[UIColor tertiarySystemFillColor]];
        [[[self cancelButton] layer] setCornerRadius:8];
        [[self cancelButton] setClipsToBounds:YES];
        [buttonStackView addArrangedSubview:[self cancelButton]];

        [self setConfirmButton:[UIButton buttonWithType:UIButtonTypeSystem]];
        [[self confirmButton] setTitle:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:@"Clear"
                                                                                                     value:nil
                                                                                                     table:@"Tweak"]
                              forState:UIControlStateNormal];
        [[self confirmButton] setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        [[[self confirmButton] titleLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]];
        [[self confirmButton] setBackgroundColor:[[UIColor systemRedColor] colorWithAlphaComponent:0.14]];
        [[[self confirmButton] layer] setCornerRadius:8];
        [[self confirmButton] setClipsToBounds:YES];
        [buttonStackView addArrangedSubview:[self confirmButton]];
    }

    return self;
}

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (_keyboardBottomInset == keyboardBottomInset) {
        return;
    }

    _keyboardBottomInset = keyboardBottomInset;
    [[self stackViewCenterYConstraint] setConstant:-keyboardBottomInset / 2.0];
    [self setNeedsLayout];
}

- (void)updateWithHistoryKey:(NSString *)historyKey {
    [self updateWithHistoryKey:historyKey contentType:0];
}

- (void)handleContentTypeChanged {
    [self updateWithHistoryKey:[self confirmationHistoryKey]
                    contentType:(NSUInteger)[[self contentTypeControl] selectedSegmentIndex]];
}

- (void)updateWithHistoryKey:(NSString *)historyKey contentType:(NSUInteger)contentType {
    [self setConfirmationHistoryKey:historyKey];
    NSString *localizationKey = [historyKey isEqualToString:kKayokoHistoryKeyFavorites]
                                    ? (contentType == 1 ? @"Clear Favorites Text Confirmation" : @"Clear Favorites Images Confirmation")
                                    : (contentType == 1 ? @"Clear History Text Confirmation" : @"Clear History Images Confirmation");
    [[self confirmationLabel]
        setText:[[KayokoPasteboardManager localizationBundle] localizedStringForKey:localizationKey
                                                                              value:nil
                                                                              table:@"Tweak"]];
    [[self contentTypeControl] setSelectedSegmentIndex:contentType == 1 ? 1 : 0];
}

@end
