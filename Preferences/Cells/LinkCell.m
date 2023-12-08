//
//  LinkCell.m
//  UNDRESSD Utils
//
//  Created by Alexandra Aurora Göttlicher
//

#import "LinkCell.h"

@implementation LinkCell
/**
 * Initializes the link cell.
 *
 * @param style
 * @param reuseIdentifier
 * @param specifier
 */
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];

    if (self) {
        [self setTitle:[specifier properties][@"label"]];
        [self setSubtitle:[specifier properties][@"subtitle"]];
        [self setUrl:[specifier properties][@"url"]];


        [self setLabel:[[UILabel alloc] init]];
        [[self label] setText:[self title]];
        [[self label] setFont:[UIFont systemFontOfSize:17]];
        [[self label] setTextColor:[UIColor systemBlueColor]];
        [self addSubview:[self label]];

        [[self label] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self label] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor] constant:-10],
            [[[self label] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:16],
            [[[self label] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-16]
        ]];


        [self setSubtitleLabel:[[UILabel alloc] init]];
        [[self subtitleLabel] setText:[NSString stringWithFormat:@"%@", [self subtitle]]];
        [[self subtitleLabel] setFont:[UIFont systemFontOfSize:11]];
        [[self subtitleLabel] setTextColor:[[UIColor labelColor] colorWithAlphaComponent:0.6]];
        [self addSubview:[self subtitleLabel]];

        [[self subtitleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self subtitleLabel] centerYAnchor] constraintEqualToAnchor:[self centerYAnchor] constant:10],
            [[[self subtitleLabel] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor] constant:16],
            [[[self subtitleLabel] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor] constant:-16]
        ]];


        [self setTapRecognizerView:[[UIView alloc] init]];
        [self addSubview:[self tapRecognizerView]];

        [[self tapRecognizerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self tapRecognizerView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self tapRecognizerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self tapRecognizerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self tapRecognizerView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];


        [self setTap:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openUrl)]];
        [[self tapRecognizerView] addGestureRecognizer:[self tap]];
    }

    return self;
}

/**
 * Opens the specified url.
 */
- (void)openUrl {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[self url]] options:@{} completionHandler:nil];
}
@end
