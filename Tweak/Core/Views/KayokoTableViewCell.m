//
//  KayokoTableViewCell.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableViewCell.h"
#import "ImageUtil.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import <substrate.h>

@interface KayokoTableViewCell ()
@property(nonatomic, assign) BOOL showRecordedTime;
@property(nonatomic, assign) BOOL itemHasImage;
@property(nonatomic, copy) NSString *itemContentText;
@property(nonatomic, assign) NSTimeInterval itemRecordedAt;
@property(nonatomic, strong) UILabel *iconTimeLabel;
- (void)updateContentDisplayMode;
- (NSString *)formattedRecordedTime;
@end

@implementation KayokoTableViewCell

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
        [self setBackgroundColor:[UIColor clearColor]];

        [self setIconImageView:[[UIImageView alloc] init]];

        UIImage *icon = nil;
        if ([[item bundleIdentifier] isEqualToString:@"com.apple.springboard"]) {
            BOOL isPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
            icon = [UIImage imageNamed:isPad ? @"HLS_iPad_Universal" : @"HLS_iPhone_Universal"
                                     inBundle:[PasteboardManager localizationBundle]
                compatibleWithTraitCollection:nil];
        } else {
            icon = [UIImage _applicationIconImageForBundleIdentifier:[item bundleIdentifier]
                                                              format:2
                                                               scale:[[UIScreen mainScreen] scale]];
        }
        // Use the default app icon if no icon exists for the item's bundle identifier.
        if (!icon) {
            icon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet"
                                                              format:2
                                                               scale:[[UIScreen mainScreen] scale]];
        }
        [[self iconImageView] setImage:icon];

        [[self iconImageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[self iconImageView] setClipsToBounds:YES];
        [[[self iconImageView] layer] setCornerRadius:10];
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
        [self addSubview:[self iconTimeLabel]];

        [[self iconImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [[self iconTimeLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self iconImageView] widthAnchor] constraintEqualToConstant:40],
            [[[self iconImageView] heightAnchor] constraintEqualToConstant:40],
            [[[self iconImageView] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
            [[[self iconImageView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:24],

            [[[self iconTimeLabel] widthAnchor] constraintEqualToConstant:52],
            [[[self iconTimeLabel] heightAnchor] constraintEqualToAnchor:[[self iconImageView] heightAnchor]],
            [[[self iconTimeLabel] centerYAnchor] constraintEqualToAnchor:[[self iconImageView] centerYAnchor]],
            [[[self iconTimeLabel] centerXAnchor] constraintEqualToAnchor:[[self iconImageView] centerXAnchor]]
        ]];

        NSString *remark = [item remark];
        BOOL hasRemark = (remark && ![remark isEqualToString:@""]);
        NSString *imageName = [item imageName] ?: @"";
        BOOL hasImage = ![imageName isEqualToString:@""];
        [self setItemHasImage:hasImage];
        [self setItemContentText:[item content] ?: @""];
        [self setItemRecordedAt:[item recordedAt]];
        [self setShowRecordedTime:showRecordedTime];

        // Right-side block: show `remark` text when available.
        if (hasRemark) {
            // Create a container view to hold the remark label so the container can have
            // a background and shadow (shadows don't show when masksToBounds=YES).
            [self setRemarkContainer:[[UIView alloc] init]];
            UIView *container = [self remarkContainer];
                container.backgroundColor = [[UIColor secondarySystemBackgroundColor] colorWithAlphaComponent:0.15]; // 背景透明度
                container.layer.cornerRadius = 6;
                container.layer.masksToBounds = NO;
                container.layer.shadowColor = [[UIColor blackColor] colorWithAlphaComponent:0.12].CGColor;
                container.layer.shadowOffset = CGSizeMake(0, 0.5);
                container.layer.shadowOpacity = 0.25;
                container.layer.shadowRadius = 1.0;
            [self addSubview:container];

            [self setRemarkLabel:[[UILabel alloc] init]];
            [[self remarkLabel] setFont:[UIFont systemFontOfSize:12]];
            
            [[self remarkLabel] setNumberOfLines:2];
            [[self remarkLabel] setTextAlignment:NSTextAlignmentCenter];
            [[self remarkLabel] setText:remark];
            [[self remarkLabel] setBackgroundColor:[UIColor clearColor]];
            [container addSubview:[self remarkLabel]];

            // Layout container and label with padding
            [container setTranslatesAutoresizingMaskIntoConstraints:NO];
            [[self remarkLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
            [NSLayoutConstraint activateConstraints:@[
                [[container widthAnchor] constraintEqualToConstant:70],
                [[container heightAnchor] constraintEqualToConstant:40],
                [[container centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]],
                [[container trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-24],

                [[[self remarkLabel] topAnchor] constraintEqualToAnchor:[container topAnchor] constant:4],
                [[[self remarkLabel] bottomAnchor] constraintEqualToAnchor:[container bottomAnchor] constant:-4],
                [[[self remarkLabel] leadingAnchor] constraintEqualToAnchor:[container leadingAnchor] constant:4],
                [[[self remarkLabel] trailingAnchor] constraintEqualToAnchor:[container trailingAnchor] constant:-4]
            ]];
        }

        // Show image in the text area when the item is an image.
        if (hasImage) {
            [self setContentImageView:[[UIImageView alloc] init]];

            UIImage *originalImage = [[PasteboardManager sharedInstance] getImageForItem:item];
            // Save memory by scaling the image down in the history view.
            UIImage *scaledImage =
                [ImageUtil getImageWithImage:originalImage
                                scaledToSize:CGSizeMake(originalImage.size.width / 4, originalImage.size.height / 4)];
            [[self contentImageView] setImage:scaledImage];

            [[self contentImageView] setContentMode:UIViewContentModeScaleAspectFill];
            [[self contentImageView] setClipsToBounds:YES];
            [[[self contentImageView] layer] setCornerRadius:4];
            [self addSubview:[self contentImageView]];

            [[self contentImageView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        }

        [self setHeaderLabel:[[UILabel alloc] init]];
        // Use headerLabel to display the description (allow three lines)
        [[self headerLabel] setText:hasImage ? @"" : [self itemContentText]];
        [[self headerLabel] setFont:[UIFont systemFontOfSize:14]];
        [[self headerLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.9]];
        [[self headerLabel] setNumberOfLines:2];
        [[self headerLabel] setLineBreakMode:NSLineBreakByTruncatingTail];
        [[self headerLabel] setHidden:hasImage];
        [self addSubview:[self headerLabel]];

        [[self headerLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        NSLayoutXAxisAnchor *textTrailingAnchor = hasRemark ? [[self remarkContainer] leadingAnchor] : [self trailingAnchor];
        CGFloat textTrailingConstant = hasRemark ? -12 : -16;

        // Position headerLabel in text area.
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor] constant:0],
            [[[self headerLabel] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor]
                                                               constant:12],
            [[[self headerLabel] trailingAnchor] constraintEqualToAnchor:textTrailingAnchor
                                                               constant:textTrailingConstant]
        ]];

        if (hasImage) {
            [NSLayoutConstraint activateConstraints:@[
                [[[self contentImageView] leadingAnchor] constraintEqualToAnchor:[[self iconImageView] trailingAnchor]
                                                                   constant:12],
                [[[self contentImageView] trailingAnchor] constraintEqualToAnchor:textTrailingAnchor
                                                                    constant:textTrailingConstant],
                [[[self contentImageView] topAnchor] constraintEqualToAnchor:[self topAnchor] constant:8],
                [[[self contentImageView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor] constant:-8]
            ]];
        }

        [self updateContentDisplayMode];
    }

    return self;
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
