//
//  KayokoTagTableViewCell.m
//  Kayoko
//

#import "KayokoTagTableViewCell.h"
#import "KayokoTag.h"

static UIColor *KayokoTagCellColorFromHex(NSString *hexColor);

@interface KayokoTagTableViewCell ()
@property(nonatomic, strong) UIView *colorSwatchView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UILabel *hexColorLabel;
@end

static UIColor *KayokoTagCellColorFromHex(NSString *hexColor) {
    NSString *candidate = [KayokoTag normalizedHexColorFromString:hexColor] ?: @"#00000000";
    NSString *valueString = [candidate substringFromIndex:1];
    unsigned long long value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:valueString];
    [scanner scanHexLongLong:&value];

    CGFloat red = (CGFloat)((value >> 24) & 0xFF) / 255.0;
    CGFloat green = (CGFloat)((value >> 16) & 0xFF) / 255.0;
    CGFloat blue = (CGFloat)((value >> 8) & 0xFF) / 255.0;
    CGFloat alpha = (CGFloat)(value & 0xFF) / 255.0;
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@implementation KayokoTagTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        [self configureSubviews];
    }
    return self;
}

- (void)configureSubviews {
    [self setSelectionStyle:UITableViewCellSelectionStyleDefault];
    [[self contentView] setPreservesSuperviewLayoutMargins:YES];

    _colorSwatchView = [[UIView alloc] init];
    [_colorSwatchView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[_colorSwatchView layer] setCornerRadius:8.0];
    [[_colorSwatchView layer] setBorderWidth:1.0];
    [[_colorSwatchView layer] setBorderColor:[[[UIColor labelColor] colorWithAlphaComponent:0.18] CGColor]];
    [[self contentView] addSubview:_colorSwatchView];

    _titleLabel = [[UILabel alloc] init];
    [_titleLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_titleLabel setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightRegular]];
    [_titleLabel setTextColor:[UIColor labelColor]];
    [_titleLabel setNumberOfLines:1];
    [[self contentView] addSubview:_titleLabel];

    _hexColorLabel = [[UILabel alloc] init];
    [_hexColorLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_hexColorLabel setFont:[UIFont systemFontOfSize:12 weight:UIFontWeightRegular]];
    [_hexColorLabel setTextColor:[UIColor secondaryLabelColor]];
    [_hexColorLabel setNumberOfLines:1];
    [[self contentView] addSubview:_hexColorLabel];

    UILayoutGuide *margins = [[self contentView] layoutMarginsGuide];
    [NSLayoutConstraint activateConstraints:@[
        [[_colorSwatchView leadingAnchor] constraintEqualToAnchor:[margins leadingAnchor]],
        [[_colorSwatchView centerYAnchor] constraintEqualToAnchor:[[self contentView] centerYAnchor]],
        [[_colorSwatchView widthAnchor] constraintEqualToConstant:28.0],
        [[_colorSwatchView heightAnchor] constraintEqualToConstant:28.0],

        [[_titleLabel leadingAnchor] constraintEqualToAnchor:[_colorSwatchView trailingAnchor] constant:13.0],
        [[_titleLabel trailingAnchor] constraintEqualToAnchor:[margins trailingAnchor]],
        [[_titleLabel topAnchor] constraintEqualToAnchor:[[self contentView] topAnchor] constant:9.0],

        [[_hexColorLabel leadingAnchor] constraintEqualToAnchor:[_titleLabel leadingAnchor]],
        [[_hexColorLabel trailingAnchor] constraintEqualToAnchor:[_titleLabel trailingAnchor]],
        [[_hexColorLabel topAnchor] constraintEqualToAnchor:[_titleLabel bottomAnchor] constant:2.0],
        [[_hexColorLabel bottomAnchor] constraintLessThanOrEqualToAnchor:[[self contentView] bottomAnchor]
                                                                 constant:-8.0]
    ]];
}

- (void)configureWithTag:(KayokoTag *)tag editing:(BOOL)editing {
    [[self titleLabel] setText:[tag title]];
    [[self hexColorLabel] setText:[tag hexColor]];
    [[self colorSwatchView] setBackgroundColor:KayokoTagCellColorFromHex([tag hexColor])];
    [self setAccessoryType:editing ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [self setAccessoryType:editing ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator];
}

@end
