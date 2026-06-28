//
//  KayokoTableViewCell.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableViewCell.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import <substrate.h>

@interface KayokoTableViewCell ()
@property(nonatomic, assign) BOOL showRecordedTime;
@property(nonatomic, assign) BOOL itemHasImage;
@property(nonatomic, copy) NSString *itemContentText;
@property(nonatomic, assign) NSTimeInterval itemRecordedAt;
@property(nonatomic, strong) UILabel *iconTimeLabel;
@property(nonatomic, strong) NSLayoutConstraint *remarkWidthConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerTrailingToRemarkConstraint;
@property(nonatomic, strong) NSLayoutConstraint *headerTrailingToEdgeConstraint;
@property(nonatomic, strong) NSLayoutConstraint *contentTrailingToRemarkConstraint;
@property(nonatomic, strong) NSLayoutConstraint *contentTrailingToEdgeConstraint;
- (void)updateContentDisplayMode;
- (void)configureStaticSubviews;
- (UIImage *)cachedIconForBundleIdentifier:(NSString *)bundleIdentifier;
- (NSString *)formattedRecordedTime;
@end

@implementation KayokoTableViewCell

+ (NSCache *)iconCache {
    static NSCache *iconCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iconCache = [[NSCache alloc] init];
        [iconCache setCountLimit:128];
    });
    return iconCache;
}

/**
 * Initializes the table view cell.
 *
 * @param style
 * @param item
 * @param reuseIdentifier
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
                      andItem:(PasteboardItem *)item
          showRecordedTime:(BOOL)showRecordedTime
              reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        [self configureStaticSubviews];
        [self configureWithItem:item showRecordedTime:showRecordedTime];
    }

    return self;
}

- (void)configureStaticSubviews {
    [self setBackgroundColor:[UIColor clearColor]];

    [self setIconImageView:[[UIImageView alloc] init]];
    [[self iconImageView] setContentMode:UIViewContentModeScaleAspectFit];
    [[self iconImageView] setClipsToBounds:YES];
    [[[self iconImageView] layer] setCornerRadius:10];
    [[self iconImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:[self iconImageView]];

    [self setIconTimeLabel:[[UILabel alloc] init]];
    [[self iconTimeLabel] setFont:[UIFont systemFontOfSize:9 weight:UIFontWeightSemibold]];
    [[self iconTimeLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.92]];
    [[self iconTimeLabel] setTextAlignment:NSTextAlignmentCenter];
    [[self iconTimeLabel] setNumberOfLines:2];
    [[self iconTimeLabel] setLineBreakMode:NSLineBreakByClipping];
    [[self iconTimeLabel] setAdjustsFontSizeToFitWidth:YES];
    [[self iconTimeLabel] setMinimumScaleFactor:0.6];
    [[self iconTimeLabel] setHidden:YES];
    [[self iconTimeLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:[self iconTimeLabel]];

    [self setRemarkContainer:[[UIView alloc] init]];
    [[self remarkContainer] setBackgroundColor:[[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.15]];
    [[[self remarkContainer] layer] setCornerRadius:6];
    [[[self remarkContainer] layer] setMasksToBounds:NO];
    [[[self remarkContainer] layer] setShadowColor:[[UIColor blackColor] colorWithAlphaComponent:0.12].CGColor];
    [[[self remarkContainer] layer] setShadowOffset:CGSizeMake(0, 0.5)];
    [[[self remarkContainer] layer] setShadowOpacity:0.25];
    [[[self remarkContainer] layer] setShadowRadius:1.0];
    [[self remarkContainer] setHidden:YES];
    [[self remarkContainer] setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:[self remarkContainer]];

    [self setRemarkLabel:[[UILabel alloc] init]];
    [[self remarkLabel] setFont:[UIFont systemFontOfSize:12]];
    [[self remarkLabel] setNumberOfLines:2];
    [[self remarkLabel] setTextAlignment:NSTextAlignmentCenter];
    [[self remarkLabel] setBackgroundColor:[UIColor clearColor]];
    [[self remarkLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
    [[self remarkContainer] addSubview:[self remarkLabel]];

    [self setContentImageView:[[UIImageView alloc] init]];
    [[self contentImageView] setContentMode:UIViewContentModeScaleAspectFill];
    [[self contentImageView] setClipsToBounds:YES];
    [[[self contentImageView] layer] setCornerRadius:4];
    [[self contentImageView] setHidden:YES];
    [[self contentImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:[self contentImageView]];

    [self setHeaderLabel:[[UILabel alloc] init]];
    [[self headerLabel] setFont:[UIFont systemFontOfSize:14]];
    [[self headerLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.9]];
    [[self headerLabel] setNumberOfLines:2];
    [[self headerLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
    [[self headerLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
    [self addSubview:[self headerLabel]];

    [self setRemarkWidthConstraint:[[[self remarkContainer] widthAnchor] constraintEqualToConstant:0]];
    [self setHeaderTrailingToRemarkConstraint:[[[self headerLabel] trailingAnchor] constraintEqualToAnchor:[[self remarkContainer] leadingAnchor]
                                                                                                 constant:-12]];
    [self setHeaderTrailingToEdgeConstraint:[[[self headerLabel] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                                                               constant:-16]];
    [self setContentTrailingToRemarkConstraint:[[[self contentImageView] trailingAnchor] constraintEqualToAnchor:[[self remarkContainer] leadingAnchor]
                                                                                                           constant:-12]];
    [self setContentTrailingToEdgeConstraint:[[[self contentImageView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                                                                         constant:-16]];

    [NSLayoutConstraint activateConstraints:@[
        [[[self iconImageView] widthAnchor] constraintEqualToConstant:40],
        [[[self iconImageView] heightAnchor] constraintEqualToConstant:40],
        [[[self iconImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self iconImageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:24],

        [[[self iconTimeLabel] widthAnchor] constraintEqualToConstant:52],
        [[[self iconTimeLabel] heightAnchor] constraintEqualToAnchor:[[self iconImageView] heightAnchor]],
        [[[self iconTimeLabel] centerYAnchor] constraintEqualToAnchor:[[self iconImageView] centerYAnchor]],
        [[[self iconTimeLabel] centerXAnchor] constraintEqualToAnchor:[[self iconImageView] centerXAnchor]],

        [self remarkWidthConstraint],
        [[[self remarkContainer] heightAnchor] constraintEqualToConstant:40],
        [[[self remarkContainer] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self remarkContainer] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-24],

        [[[self remarkLabel] topAnchor] constraintEqualToAnchor:[[self remarkContainer] topAnchor] constant:4],
        [[[self remarkLabel] bottomAnchor] constraintEqualToAnchor:[[self remarkContainer] bottomAnchor] constant:-4],
        [[[self remarkLabel] leadingAnchor] constraintEqualToAnchor:[[self remarkContainer] leadingAnchor] constant:4],
        [[[self remarkLabel] trailingAnchor] constraintEqualToAnchor:[[self remarkContainer] trailingAnchor] constant:-4],

        [[[self headerLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self headerLabel] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor] constant:12],

        [[[self contentImageView] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor] constant:12],
        [[[self contentImageView] topAnchor] constraintEqualToAnchor:[self topAnchor] constant:8],
        [[[self contentImageView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor] constant:-8]
    ]];

    [[self headerTrailingToEdgeConstraint] setActive:YES];
    [[self contentTrailingToEdgeConstraint] setActive:YES];
}

- (void)configureWithItem:(PasteboardItem *)item showRecordedTime:(BOOL)showRecordedTime {
    NSString *bundleIdentifier = [item bundleIdentifier] ?: @"com.apple.WebSheet";
    UIImage *icon = [self cachedIconForBundleIdentifier:bundleIdentifier];
    [[self iconImageView] setImage:icon];

    NSString *remark = [item remark] ?: @"";
    BOOL hasRemark = [remark length] > 0;
    NSString *imageName = [item imageName] ?: @"";
    BOOL hasImage = [imageName length] > 0;

    [self setItemHasImage:hasImage];
    [self setItemContentText:[item content] ?: @""];
    [self setItemRecordedAt:[item recordedAt]];
    [self setShowRecordedTime:showRecordedTime];

    [[self remarkLabel] setText:remark];
    [[self remarkContainer] setHidden:!hasRemark];
    [[self remarkWidthConstraint] setConstant:hasRemark ? 70 : 0];
    [[self headerTrailingToRemarkConstraint] setActive:hasRemark];
    [[self headerTrailingToEdgeConstraint] setActive:!hasRemark];
    [[self contentTrailingToRemarkConstraint] setActive:hasRemark];
    [[self contentTrailingToEdgeConstraint] setActive:!hasRemark];

    if (hasImage) {
        UIImage *image = [[PasteboardManager sharedInstance] getImageForItem:item];
        [[self contentImageView] setImage:image];
    } else {
        [[self contentImageView] setImage:nil];
    }

    [self updateContentDisplayMode];
}

- (UIImage *)cachedIconForBundleIdentifier:(NSString *)bundleIdentifier {
    NSString *resolvedBundleIdentifier = [bundleIdentifier length] ? bundleIdentifier : @"com.apple.WebSheet";
    NSCache *iconCache = [[self class] iconCache];
    UIImage *icon = [iconCache objectForKey:resolvedBundleIdentifier];
    if (icon) {
        return icon;
    }

    if ([resolvedBundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        BOOL isPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        icon = [UIImage imageNamed:isPad ? @"HLS_iPad_Universal" : @"HLS_iPhone_Universal"
                                 inBundle:[PasteboardManager localizationBundle]
            compatibleWithTraitCollection:nil];
    } else {
        icon = [UIImage _applicationIconImageForBundleIdentifier:resolvedBundleIdentifier
                                                          format:2
                                                           scale:[[UIScreen mainScreen] scale]];
    }

    if (!icon) {
        NSString *fallbackBundleIdentifier = @"com.apple.WebSheet";
        icon = [iconCache objectForKey:fallbackBundleIdentifier];
        if (!icon) {
            icon = [UIImage _applicationIconImageForBundleIdentifier:fallbackBundleIdentifier
                                                              format:2
                                                               scale:[[UIScreen mainScreen] scale]];
            if (icon) {
                [iconCache setObject:icon forKey:fallbackBundleIdentifier];
            }
        }
    }

    if (icon) {
        [iconCache setObject:icon forKey:resolvedBundleIdentifier];
    }

    return icon;
}

- (void)prepareForReuse {
    [super prepareForReuse];
    [[self headerLabel] setText:@""];
    [[self remarkLabel] setText:@""];
    [[self contentImageView] setImage:nil];
    [[self iconTimeLabel] setText:nil];
}

- (void)updateContentDisplayMode {
    if ([self itemHasImage]) {
        [[self headerLabel] setHidden:YES];
        [[self headerLabel] setText:@""];
        if ([self contentImageView]) {
            [[self contentImageView] setHidden:NO];
        }
    } else {
        [[self headerLabel] setHidden:NO];
        [[self headerLabel] setNumberOfLines:2];
        [[self headerLabel] setText:[self itemContentText]];
    }

    BOOL hasRecordedTime = [self itemRecordedAt] > 0;
    if ([self showRecordedTime] && hasRecordedTime) {
        [[self iconImageView] setHidden:YES];
        [[self iconTimeLabel] setHidden:NO];
        [[self iconTimeLabel] setText:[self formattedRecordedTime]];
    } else {
        [[self iconTimeLabel] setHidden:YES];
        [[self iconImageView] setHidden:NO];
    }
}

- (NSString *)formattedRecordedTime {
    if ([self itemRecordedAt] <= 0) {
        return @"--/--\n--:--";
    }

    static NSDateFormatter *dayMonthFormatter;
    static NSDateFormatter *timeFormatter;
    static NSCalendar *calendar;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dayMonthFormatter = [[NSDateFormatter alloc] init];
        [dayMonthFormatter setDateFormat:@"dd-MM"];

        timeFormatter = [[NSDateFormatter alloc] init];
        [timeFormatter setDateFormat:@"HH:mm"];

        calendar = [NSCalendar currentCalendar];
    });

    NSDate *date = [NSDate dateWithTimeIntervalSince1970:[self itemRecordedAt]];
    NSString *timeText = [timeFormatter stringFromDate:date] ?: @"--:--";

    if ([calendar isDateInToday:date]) {
        return timeText;
    }

    NSString *dayMonthText = [dayMonthFormatter stringFromDate:date] ?: @"--/--";
    return [NSString stringWithFormat:@"%@\n%@", dayMonthText, timeText];
}

@end
