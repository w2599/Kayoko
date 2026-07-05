//
//  KayokoSliderCell.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoSliderCell.h"

#import <Preferences/PSViewController.h>

@interface KayokoSliderCell ()
@property(nonatomic, assign) float minimumValue;
@property(nonatomic, assign) float maximumValue;
@property(nonatomic, assign) NSInteger segmentCount;
@property(nonatomic, assign) BOOL isContinuous;
@end

@implementation KayokoSliderCell

/**
 * Initializes the slider cell.
 *
 * @param style
 * @param reuseIdentifier
 * @param specifier
 *
 * @return The cell.
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        [self setSelectionStyle:UITableViewCellSelectionStyleNone];

        [self setMinimumValue:[[specifier propertyForKey:@"min"] floatValue]];
        [self setMaximumValue:[[specifier propertyForKey:@"max"] floatValue]];
        [self setSegmentCount:[[specifier propertyForKey:@"segmentCount"] integerValue]];
        [self setIsContinuous:[[specifier propertyForKey:@"isContinuous"] boolValue]];

        [self setValueLabel:[[UILabel alloc] init]];
        [[self valueLabel] setFont:[UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular]];
        [[self valueLabel] setTextColor:[UIColor secondaryLabelColor]];
        [[self valueLabel] setTextAlignment:NSTextAlignmentRight];
        [[self valueLabel] setAdjustsFontSizeToFitWidth:YES];
        [[self valueLabel] setMinimumScaleFactor:0.8];
        [self addSubview:[self valueLabel]];

        // Reserve enough width for the largest possible value so it never gets clipped.
        NSString *widestValueString = [NSString stringWithFormat:@"%d", (int)[self maximumValue]];
        CGFloat labelWidth = ceil([widestValueString sizeWithAttributes:@{
                                    NSFontAttributeName : [[self valueLabel] font]
                                  }].width) + 6;

        [[self valueLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self valueLabel] widthAnchor] constraintGreaterThanOrEqualToConstant:labelWidth],
            [[[self valueLabel] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-16],
            [[[self valueLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]
        ]];

        [self setSlider:[[UISlider alloc] init]];
        [[self slider] setMinimumValue:[self minimumValue]];
        [[self slider] setMaximumValue:[self maximumValue]];
        [[self slider] setContinuous:YES];
        [[self slider] addTarget:self
                           action:@selector(sliderValueChanged:)
                 forControlEvents:UIControlEventValueChanged];
        [[self slider] addTarget:self
                           action:@selector(sliderInteractionEnded:)
                 forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                   UIControlEventTouchCancel];
        [self addSubview:[self slider]];

        [[self slider] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self slider] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:16],
            [[[self slider] trailingAnchor] constraintEqualToAnchor:[[self valueLabel] leadingAnchor] constant:-12],
            [[[self slider] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor]]
        ]];

        [self refreshCellContentsWithSpecifier:specifier];
    }

    return self;
}

/**
 * Rounds a raw slider value to the nearest segment step, if segmented.
 *
 * @param rawValue The raw, unsnapped slider value.
 *
 * @return The snapped value.
 */
- (float)snappedValue:(float)rawValue {
    if ([self segmentCount] <= 1) {
        return rawValue;
    }

    float step = ([self maximumValue] - [self minimumValue]) / ([self segmentCount] - 1);
    if (step <= 0) {
        return rawValue;
    }

    float steppedIndex = roundf((rawValue - [self minimumValue]) / step);
    return [self minimumValue] + (steppedIndex * step);
}

/**
 * Updates the value label to reflect the slider's current value.
 */
- (void)updateValueLabel {
    [[self valueLabel] setText:[NSString stringWithFormat:@"%d", (int)roundf([[self slider] value])]];
}

/**
 * Persists the current slider value via the specifier's target.
 */
- (void)commitValue {
    id target = [[self specifier] target];
    NSNumber *value = @(roundf([[self slider] value]));
    if ([target respondsToSelector:@selector(setPreferenceValue:specifier:)]) {
        [target setPreferenceValue:value specifier:[self specifier]];
    }
}

/**
 * Handles live slider dragging.
 *
 * @param sender The slider.
 */
- (void)sliderValueChanged:(UISlider *)sender {
    float snapped = [self snappedValue:[sender value]];
    if (snapped != [sender value]) {
        [sender setValue:snapped animated:NO];
    }

    [self updateValueLabel];

    if ([self isContinuous]) {
        [self commitValue];
    }
}

/**
 * Handles the end of a slider drag/tap interaction, persisting the final value.
 *
 * @param sender The slider.
 */
- (void)sliderInteractionEnded:(UISlider *)sender {
    [self commitValue];
}

/**
 * Refreshes the slider and value label from the current preference value.
 *
 * @param specifier The specifier.
 */
- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];

    id target = [specifier target];
    id value = nil;
    if ([target respondsToSelector:@selector(readPreferenceValue:)]) {
        value = [target readPreferenceValue:specifier];
    }
    if (!value) {
        value = [specifier propertyForKey:@"default"];
    }

    [[self slider] setValue:[value floatValue] animated:NO];
    [self updateValueLabel];
}

@end
