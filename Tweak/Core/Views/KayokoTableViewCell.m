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

@interface KayokoTableViewCell () {
    CGFloat _rowHeight;
}
@property(nonatomic, assign) BOOL showRecordedTime;
@property(nonatomic, assign) BOOL itemHasImage;
@property(nonatomic, copy) NSString *itemContentText;
@property(nonatomic, assign) NSTimeInterval itemRecordedAt;
@property(nonatomic, strong) PasteboardItem *pendingImageItem;
@property(nonatomic, copy) NSString *pendingImageHistoryKey;
@property(nonatomic, assign) BOOL didRequestImage;
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
               historyKey:(NSString *)historyKey
              reuseIdentifier:(NSString *)reuseIdentifier
              rowHeight:(CGFloat)rowHeight {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];

    if (self) {
        _rowHeight = rowHeight;
        [self configureStaticSubviews];
        [self configureWithItem:item showRecordedTime:showRecordedTime historyKey:historyKey];
    }

    return self;
}

- (void)configureStaticSubviews {
    [self setBackgroundColor:[UIColor clearColor]];

    [self setIconImageView:[[UIImageView alloc] init]];
    [[self iconImageView] setContentMode:UIViewContentModeScaleAspectFit];
    [[self iconImageView] setClipsToBounds:YES];
    [[[self iconImageView] layer] setCornerRadius:kKayokoCornerRadius];
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
    [[[self remarkContainer] layer] setCornerRadius:kKayokoCornerRadius];
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
    [[[self contentImageView] layer] setCornerRadius:kKayokoCornerRadius - 2.0];
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
                                                                                                 constant:-kKayokoMargin]];
    [self setHeaderTrailingToEdgeConstraint:[[[self headerLabel] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                                                               constant:-kKayokoMargin]];
    [self setContentTrailingToRemarkConstraint:[[[self contentImageView] trailingAnchor] constraintEqualToAnchor:[[self remarkContainer] leadingAnchor]
                                                                                                           constant:-kKayokoMargin]];
    [self setContentTrailingToEdgeConstraint:[[[self contentImageView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]
                                                                                                         constant:-kKayokoMargin]];

    CGFloat KayokoHeightAnchor = _rowHeight - 4.0; // Adjust for top and bottom padding
    [NSLayoutConstraint activateConstraints:@[
        [[[self iconImageView] widthAnchor] constraintEqualToConstant:KayokoHeightAnchor],
        [[[self iconImageView] heightAnchor] constraintEqualToConstant:KayokoHeightAnchor],
        [[[self iconImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self iconImageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:kKayokoMargin],

        [[[self iconTimeLabel] widthAnchor] constraintEqualToConstant:_rowHeight],
        [[[self iconTimeLabel] heightAnchor] constraintEqualToConstant:KayokoHeightAnchor],
        [[[self iconTimeLabel] centerYAnchor] constraintEqualToAnchor:[[self iconImageView] centerYAnchor]],
        [[[self iconTimeLabel] centerXAnchor] constraintEqualToAnchor:[[self iconImageView] centerXAnchor]],

        [self remarkWidthConstraint],
        [[[self remarkContainer] heightAnchor] constraintEqualToConstant:KayokoHeightAnchor],
        [[[self remarkContainer] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self remarkContainer] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-kKayokoMargin],

        [[[self remarkLabel] topAnchor] constraintEqualToAnchor:[[self remarkContainer] topAnchor] constant:4],
        [[[self remarkLabel] bottomAnchor] constraintEqualToAnchor:[[self remarkContainer] bottomAnchor] constant:-4],
        [[[self remarkLabel] leadingAnchor] constraintEqualToAnchor:[[self remarkContainer] leadingAnchor] constant:4],
        [[[self remarkLabel] trailingAnchor] constraintEqualToAnchor:[[self remarkContainer] trailingAnchor] constant:-4],

        [[[self headerLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self headerLabel] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor] constant:kKayokoMargin],

        [[[self contentImageView] heightAnchor] constraintEqualToConstant:KayokoHeightAnchor],
        [[[self contentImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
        [[[self contentImageView] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor] constant:kKayokoMargin],
        [[[self contentImageView] topAnchor] constraintEqualToAnchor:[self topAnchor] constant:4],
        [[[self contentImageView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor] constant:-4]
    ]];

    [[self headerTrailingToEdgeConstraint] setActive:YES];
    [[self contentTrailingToEdgeConstraint] setActive:YES];
}

- (void)configureWithItem:(PasteboardItem *)item showRecordedTime:(BOOL)showRecordedTime historyKey:(NSString *)historyKey {
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
        [self setPendingImageItem:item];
        [self setPendingImageHistoryKey:historyKey];
        [self setDidRequestImage:NO];
        [self setContentImage:nil];
    } else {
        [self setPendingImageItem:nil];
        [self setPendingImageHistoryKey:nil];
        [self setDidRequestImage:NO];
        [self setContentImage:nil];
    }

    [self updateContentDisplayMode];
}

/**
 * 在 cell 即将展示给用户时才真正去请求图片缩略图（并写入对应列表的图片缓存）。
 * 避免在后台预热整个列表时就把所有行都拉图，挤掉首屏（包括刚刚新复制的）的缓存额度。
 */
- (void)loadImageIfNeeded {
    if ([self didRequestImage] || ![self itemHasImage]) {
        return;
    }
    [self setDidRequestImage:YES];

    PasteboardItem *item = [self pendingImageItem];
    NSString *historyKey = [self pendingImageHistoryKey];
    if (!item) {
        return;
    }

    [[PasteboardManager sharedInstance] getImageForItem:item
                                      fromHistoryWithKey:historyKey
                                              completion:^(UIImage *image) {
        [self setContentImage:image];
    }];
}

- (void)setContentImage:(UIImage *)image {
    UIImageView *imageView = [self contentImageView];

    if (!image) {
        imageView.image = nil;
        return;
    }

    imageView.image = image;
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
    [self setContentImage:nil];
    [[self iconTimeLabel] setText:nil];
    [self setPendingImageItem:nil];
    [self setPendingImageHistoryKey:nil];
    [self setDidRequestImage:NO];
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
        [dayMonthFormatter setDateFormat:@"MM-dd"];

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
