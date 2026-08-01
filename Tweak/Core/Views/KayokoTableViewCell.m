//
//  KayokoTableViewCell.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableViewCell.h"
#import "KayokoTableViewCellContent.h"
#import "KayokoTagColorFormatter.h"

static CGFloat const kKayokoTableViewCellTagDotSize = 7;
static CGFloat const kKayokoTableViewCellContentImageWidth = 70;
static CGFloat const kKayokoTableViewCellContentImageSingleLineHeight = 48;
static CGFloat const kKayokoTableViewCellContentImageAdditionalLineHeight = 16;
static CGFloat const kKayokoTableViewCellColumnWidth = 70;
static CGFloat const kKayokoTableViewCellNoteWidth = kKayokoTableViewCellColumnWidth;
static CGFloat const kKayokoTableViewCellNoteHeight = 40;
static CGFloat const kKayokoTableViewCellNoteCornerRadius = 8;
static CGFloat const kKayokoTableViewCellContentImageCornerRadius = 8;
static CGFloat const kKayokoTableViewCellContentColumnSpacing = 16;
static CGFloat const kKayokoTableViewCellVerticalContentInset = 8;
static NSUInteger const kKayokoTableViewCellMaximumPreviewLineCount = 3;

@interface KayokoTableViewCellPreviewLabel : UILabel
@end

@implementation KayokoTableViewCellPreviewLabel

- (void)drawTextInRect:(CGRect)rect {
    CGRect textRect = [self textRectForBounds:rect limitedToNumberOfLines:[self numberOfLines]];
    textRect.size.width = rect.size.width;
    textRect.origin.x = rect.origin.x;
    textRect.origin.y = rect.origin.y + (rect.size.height - textRect.size.height) / 2.0;
    [super drawTextInRect:textRect];
}

@end

@interface KayokoTableViewCell ()
@property(nonatomic, copy, nullable) NSString *representedImageName;
@property(nonatomic, strong, nullable) NSLayoutConstraint *iconHeightConstraint;
@property(nonatomic, strong, nullable) NSLayoutConstraint *iconWidthConstraint;
@property(nonatomic, strong, nullable) NSLayoutConstraint *contentImageHeightConstraint;
@property(nonatomic, strong, nullable) NSLayoutConstraint *noteHeightConstraint;
@property(nonatomic, strong, nullable) NSLayoutConstraint *contentLabelHeightConstraint;
@property(nonatomic, assign) CGFloat preferredContentLabelHeight;
@end

@implementation KayokoTableViewCell

+ (NSString *)reuseIdentifierForContent:(KayokoTableViewCellContent *)content {
    NSUInteger lineCount = MIN(MAX([content previewLineCount], 2), kKayokoTableViewCellMaximumPreviewLineCount);
    BOOL hasContentImageSlot = [content contentImage] || [[content thumbnailImageName] length] > 0;
    BOOL hasTagDot = [[content tagHexColor] length] > 0;
    BOOL hasContentText = [[content contentText] length] > 0;
    BOOL hasNote = [[content noteText] length] > 0;
    return [NSString stringWithFormat:@"KayokoTableViewCell-%lu-%d-%d-%d-%d", (unsigned long)lineCount,
                                      hasContentImageSlot, hasTagDot, hasContentText, hasNote];
}

+ (CGSize)contentImageViewSizeForPreviewLineCount:(NSUInteger)previewLineCount {
    NSUInteger lineCount = MIN(MAX(previewLineCount, 2), kKayokoTableViewCellMaximumPreviewLineCount);
    CGFloat height = kKayokoTableViewCellContentImageSingleLineHeight +
                     (lineCount - 1) * kKayokoTableViewCellContentImageAdditionalLineHeight;
    return CGSizeMake(kKayokoTableViewCellContentImageWidth, height);
}

+ (CGSize)contentImageThumbnailSize {
    CGSize maximumViewSize = [self contentImageViewSizeForPreviewLineCount:kKayokoTableViewCellMaximumPreviewLineCount];
    CGFloat sideLength = MAX(maximumViewSize.width, maximumViewSize.height);
    return CGSizeMake(sideLength, sideLength);
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      content:(KayokoTableViewCellContent *)content
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        NSUInteger lineCount = MIN(MAX([content previewLineCount], 2), kKayokoTableViewCellMaximumPreviewLineCount);
        CGSize contentImageViewSize = [[self class] contentImageViewSizeForPreviewLineCount:lineCount];
        BOOL hasContentText = [[content contentText] length] > 0;
        BOOL hasNote = [[content noteText] length] > 0;
        [self setBackgroundColor:[UIColor clearColor]];
        [self setClipsToBounds:YES];
        UIView *selectedBackgroundView = [[UIView alloc] init];
        UIColor *selectedBackgroundColor =
            [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
              if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
                  return [UIColor colorWithWhite:1 alpha:0.08];
              }

              return [UIColor colorWithWhite:0 alpha:0.055];
            }];
        [selectedBackgroundView setBackgroundColor:selectedBackgroundColor];
        [self setSelectedBackgroundView:selectedBackgroundView];

        [self setIconImageView:[[UIImageView alloc] init]];
        [[self iconImageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[self iconImageView] setClipsToBounds:YES];
        [[[self iconImageView] layer] setCornerRadius:10];
        [self addSubview:[self iconImageView]];

        [[self iconImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self setIconHeightConstraint:[[[self iconImageView] heightAnchor] constraintEqualToConstant:40]];
        [self setIconWidthConstraint:[[[self iconImageView] widthAnchor] constraintEqualToConstant:40]];
        [NSLayoutConstraint activateConstraints:@[
            [self iconWidthConstraint],
            [self iconHeightConstraint],
            [[[self iconImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[[self iconImageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:24]
        ]];

        UIImage *contentImage = [content contentImage];
        NSString *thumbnailImageName = [content thumbnailImageName];
        BOOL hasContentImageSlot = contentImage || [thumbnailImageName length] > 0;
        NSLayoutConstraint *contentImageTrailingConstraint = nil;
        [self setRepresentedImageName:thumbnailImageName];
        if (hasContentImageSlot) {
            [self setContentImageView:[[UIImageView alloc] init]];
            [[self contentImageView] setImage:contentImage];

            [[self contentImageView] setContentMode:UIViewContentModeScaleAspectFill];
            [[self contentImageView] setClipsToBounds:YES];
            [[self contentImageView]
                setBackgroundColor:contentImage ? [UIColor clearColor] : [UIColor tertiarySystemFillColor]];
            [[[self contentImageView] layer] setCornerRadius:kKayokoTableViewCellContentImageCornerRadius];
            [self addSubview:[self contentImageView]];

            [[self contentImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
            [self setContentImageHeightConstraint:[[[self contentImageView] heightAnchor]
                                                      constraintEqualToConstant:contentImageViewSize.height]];
                contentImageTrailingConstraint = [[[self contentImageView] trailingAnchor]
                     constraintEqualToAnchor:[self trailingAnchor]
                                         constant:hasNote
                                                      ? -(kKayokoTableViewCellNoteWidth +
                                                          kKayokoTableViewCellContentColumnSpacing + 24)
                                                      : -24];
            [NSLayoutConstraint activateConstraints:@[
                [self contentImageHeightConstraint],
                [[[self contentImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
                [[[self contentImageView] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor]
                                                                          constant:16],
                contentImageTrailingConstraint
            ]];
        }

        if (hasNote) {
            [self setNoteLabel:[[UILabel alloc] init]];
            [[self noteLabel] setFont:[UIFont systemFontOfSize:14 weight:UIFontWeightMedium]];
            [[self noteLabel] setTextColor:[UIColor labelColor]];
            [[self noteLabel] setTextAlignment:NSTextAlignmentCenter];
            [[self noteLabel] setNumberOfLines:2];
            [[self noteLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
            [[self noteLabel] setBackgroundColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
                if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithWhite:1 alpha:0.10];
                }
                return [UIColor colorWithWhite:0 alpha:0.055];
            }]];
            [[[self noteLabel] layer] setCornerRadius:kKayokoTableViewCellNoteCornerRadius];
            [[[self noteLabel] layer] setCornerCurve:kCACornerCurveContinuous];
            [[self noteLabel] setClipsToBounds:YES];
            [self addSubview:[self noteLabel]];
            [[self noteLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
            [self setNoteHeightConstraint:[[[self noteLabel] heightAnchor]
                                              constraintEqualToConstant:kKayokoTableViewCellNoteHeight]];
            [NSLayoutConstraint activateConstraints:@[
                [[[self noteLabel] widthAnchor] constraintEqualToConstant:kKayokoTableViewCellColumnWidth],
                [self noteHeightConstraint],
                [[[self noteLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
                [[[self noteLabel] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-24]
            ]];

            if (contentImageTrailingConstraint) {
                [contentImageTrailingConstraint setActive:NO];
                contentImageTrailingConstraint = [[[self contentImageView] trailingAnchor]
                    constraintEqualToAnchor:[[self noteLabel] leadingAnchor]
                                   constant:-kKayokoTableViewCellContentColumnSpacing];
                [contentImageTrailingConstraint setActive:YES];
            }
        }

        [self setHeaderLabel:[[UILabel alloc] init]];
        [[self headerLabel] setFont:[UIFont systemFontOfSize:16 weight:UIFontWeightMedium]];
        [[self headerLabel] setTextColor:[UIColor labelColor]];
        [[self headerLabel] setHidden:hasContentImageSlot || hasContentText];
        [[self headerLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
        [[self headerLabel] setContentHuggingPriority:UILayoutPriorityDefaultHigh
                                              forAxis:UILayoutConstraintAxisHorizontal];
        [[self headerLabel] setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                            forAxis:UILayoutConstraintAxisHorizontal];
        [self addSubview:[self headerLabel]];

        [[self headerLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        NSLayoutXAxisAnchor *headerLeadingAnchor = [self contentImageView]
                                ? [[self contentImageView] trailingAnchor]
                                : [[self iconImageView] trailingAnchor];
        CGFloat headerLeadingConstant = [self contentImageView] ? 24 : 16;
        [NSLayoutConstraint activateConstraints:@[ [[[self headerLabel] leadingAnchor]
                                constraintEqualToAnchor:headerLeadingAnchor
                                       constant:headerLeadingConstant] ]];
        if (hasNote && !hasContentImageSlot) {
            [NSLayoutConstraint activateConstraints:@[
                [[[self headerLabel] widthAnchor] constraintEqualToConstant:kKayokoTableViewCellColumnWidth]
            ]];
        }

        NSLayoutXAxisAnchor *textTrailingAnchor = [self noteLabel] ? [[self noteLabel] leadingAnchor] : [self trailingAnchor];
        CGFloat textTrailingConstant = [self noteLabel] ? -kKayokoTableViewCellContentColumnSpacing : -24;

        if ([[content tagHexColor] length] > 0) {
            [self setTagDotView:[[UIView alloc] init]];
            [[[self tagDotView] layer] setCornerRadius:kKayokoTableViewCellTagDotSize / 2.0];
            [self addSubview:[self tagDotView]];
            [[self tagDotView] setTranslatesAutoresizingMaskIntoConstraints:NO];
            [NSLayoutConstraint activateConstraints:@[
                [[[self tagDotView] leadingAnchor] constraintEqualToAnchor:[[self headerLabel] trailingAnchor]
                                                                  constant:6],
                [[[self tagDotView] widthAnchor] constraintEqualToConstant:kKayokoTableViewCellTagDotSize],
                [[[self tagDotView] heightAnchor] constraintEqualToConstant:kKayokoTableViewCellTagDotSize],
                [[[self tagDotView] centerYAnchor] constraintEqualToAnchor:[[self headerLabel] centerYAnchor]],
                [[[self tagDotView] trailingAnchor] constraintLessThanOrEqualToAnchor:textTrailingAnchor
                                                                             constant:textTrailingConstant]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[ [[[self headerLabel] trailingAnchor]
                                                        constraintEqualToAnchor:textTrailingAnchor
                                                                       constant:textTrailingConstant] ]];
        }

        if (hasContentText) {
            [self setContentLabel:[[KayokoTableViewCellPreviewLabel alloc] init]];
            [[self contentLabel] setFont:[UIFont systemFontOfSize:14]];
            [[self contentLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.8]];
            [[self contentLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
            [[self contentLabel] setNumberOfLines:lineCount];
            [self addSubview:[self contentLabel]];
            [[self contentLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
            CGFloat previewLabelHeight = ceil([[[self contentLabel] font] lineHeight] * lineCount);
            [self setContentLabelHeightConstraint:[[[self contentLabel] heightAnchor]
                                                      constraintEqualToConstant:previewLabelHeight]];
            [self setPreferredContentLabelHeight:previewLabelHeight];
            [NSLayoutConstraint activateConstraints:@[
                [[[self contentLabel] leadingAnchor] constraintEqualToAnchor:[[self headerLabel] leadingAnchor]],
                [[[self contentLabel] trailingAnchor] constraintEqualToAnchor:textTrailingAnchor
                                                                     constant:textTrailingConstant],
                [self contentLabelHeightConstraint]
            ]];
        }

        if (hasContentText) {
            [NSLayoutConstraint activateConstraints:@[
                [[[self contentLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]
            ]];
        } else {
            [NSLayoutConstraint activateConstraints:@[ [[[self headerLabel] centerYAnchor]
                                                        constraintEqualToAnchor:[self centerYAnchor]] ]];
        }

        [self applyContent:content];
    }

    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat availableHeight = MAX(CGRectGetHeight([self bounds]) - kKayokoTableViewCellVerticalContentInset, 1);
    CGFloat iconHeight = availableHeight;
    CGFloat adaptiveCornerRadius = availableHeight / 4.0;
    [[self iconHeightConstraint] setConstant:iconHeight];
    [[self iconWidthConstraint] setConstant:iconHeight];
    [[self contentImageHeightConstraint] setConstant:availableHeight];
    [[self noteHeightConstraint] setConstant:availableHeight];
    [[[self iconImageView] layer] setCornerRadius:adaptiveCornerRadius];
    [[[self contentImageView] layer] setCornerRadius:adaptiveCornerRadius];
    [[[self noteLabel] layer] setCornerRadius:adaptiveCornerRadius];

    if ([self contentLabelHeightConstraint]) {
        CGFloat maximumPreviewHeight = MAX(CGRectGetHeight([self bounds]) - kKayokoTableViewCellVerticalContentInset, 1);
        [[self contentLabelHeightConstraint] setConstant:MIN([self preferredContentLabelHeight], maximumPreviewHeight)];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [self setHidden:NO];
    [self setRepresentedImageName:nil];
    [[self iconImageView] setImage:nil];
    [[self headerLabel] setAttributedText:nil];
    [[self headerLabel] setText:nil];
    [[self tagDotView] setBackgroundColor:nil];
    [[self contentLabel] setAttributedText:nil];
    [[self contentLabel] setText:nil];
    [[self noteLabel] setText:nil];
    [[self noteLabel] setHidden:YES];
    [[self contentImageView] setImage:nil];
    [[self contentImageView] setBackgroundColor:[UIColor tertiarySystemFillColor]];
}

- (void)applyContent:(KayokoTableViewCellContent *)content {
    [[self iconImageView] setImage:[content icon]];

    if ([content attributedDisplayName]) {
        NSMutableAttributedString *attributedDisplayName = [[content attributedDisplayName] mutableCopy];
        NSRange fullRange = NSMakeRange(0, [attributedDisplayName length]);
        [attributedDisplayName addAttribute:NSFontAttributeName value:[[self headerLabel] font] range:fullRange];
        [attributedDisplayName addAttribute:NSForegroundColorAttributeName
                                      value:[[self headerLabel] textColor]
                                      range:fullRange];
        [[self headerLabel] setAttributedText:attributedDisplayName];
    } else {
        [[self headerLabel] setAttributedText:nil];
        [[self headerLabel] setText:[content displayName]];
    }

    [[self noteLabel] setText:[content noteText]];
    [[self noteLabel] setHidden:[[content noteText] length] == 0];

    if ([self tagDotView]) {
        [[self tagDotView] setBackgroundColor:[KayokoTagColorFormatter visibleColorFromHexColor:[content tagHexColor]]];
    }

    NSUInteger lineCount = MIN(MAX([content previewLineCount], 1), kKayokoTableViewCellMaximumPreviewLineCount);
    [[self contentLabel] setNumberOfLines:lineCount];
    if ([content attributedContentText]) {
        NSMutableAttributedString *attributedText = [[content attributedContentText] mutableCopy];
        NSRange fullRange = NSMakeRange(0, [attributedText length]);
        [attributedText addAttribute:NSFontAttributeName value:[[self contentLabel] font] range:fullRange];
        [attributedText addAttribute:NSForegroundColorAttributeName
                               value:[[self contentLabel] textColor]
                               range:fullRange];
        [[self contentLabel] setAttributedText:attributedText];
    } else {
        [[self contentLabel] setAttributedText:nil];
        [[self contentLabel] setText:[content contentText] ?: @""];
    }
    UIImage *contentImage = [content contentImage];
    [self setRepresentedImageName:[content thumbnailImageName]];
    [[self contentImageView] setImage:contentImage];
    [[self contentImageView]
        setBackgroundColor:contentImage ? [UIColor clearColor] : [UIColor tertiarySystemFillColor]];
}

- (void)setContentImage:(UIImage *)image forImageName:(NSString *)imageName {
    if ([[self representedImageName] length] == 0 || ![[self representedImageName] isEqualToString:imageName]) {
        return;
    }

    if (![self contentImageView]) {
        return;
    }

    [[self contentImageView] setImage:image];
    [[self contentImageView] setBackgroundColor:image ? [UIColor clearColor] : [UIColor tertiarySystemFillColor]];
}

@end
