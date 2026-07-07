//
//  KayokoEdgeFadeMaskController.m
//  Kayoko
//

#import "KayokoEdgeFadeMaskController.h"

#import <QuartzCore/QuartzCore.h>

@interface KayokoEdgeFadeMaskController ()
@property(nonatomic, weak) UIScrollView *scrollView;
@property(nonatomic, strong) CAGradientLayer *maskLayer;
@end

@implementation KayokoEdgeFadeMaskController

- (instancetype)initWithScrollView:(UIScrollView *)scrollView {
    self = [super init];
    if (self) {
        _scrollView = scrollView;
        _enabled = YES;
        _maskLayer = [self newMaskLayer];
        [[scrollView layer] setMask:_maskLayer];
    }
    return self;
}

- (CAGradientLayer *)newMaskLayer {
    CAGradientLayer *gradientLayer = [CAGradientLayer layer];
    [gradientLayer setStartPoint:CGPointMake(0, 0.5)];
    [gradientLayer setEndPoint:CGPointMake(1, 0.5)];

    UIColor *opaqueColor = [UIColor colorWithWhite:0 alpha:1];
    [gradientLayer setColors:@[ (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor] ]];
    [gradientLayer setLocations:@[ @0, @1 ]];
    return gradientLayer;
}

- (void)setFadeWidth:(CGFloat)fadeWidth {
    CGFloat normalizedFadeWidth = MAX(fadeWidth, 0.0);
    if (fabs(_fadeWidth - normalizedFadeWidth) < 0.5) {
        return;
    }

    _fadeWidth = normalizedFadeWidth;
    [self updateMask];
}

- (void)setEnabled:(BOOL)enabled {
    if (_enabled == enabled) {
        return;
    }

    _enabled = enabled;
    [self updateMask];
}

- (void)updateMask {
    UIScrollView *scrollView = [self scrollView];
    CAGradientLayer *maskLayer = [self maskLayer];
    if (!scrollView || !maskLayer) {
        return;
    }

    CGFloat width = CGRectGetWidth([scrollView bounds]);
    CGFloat height = CGRectGetHeight([scrollView bounds]);
    if (width <= 0 || height <= 0) {
        return;
    }

    CGPoint contentOffset = [scrollView contentOffset];
    UIColor *opaqueColor = [UIColor colorWithWhite:0 alpha:1];
    UIColor *transparentColor = [UIColor colorWithWhite:0 alpha:0];
    NSArray *colors = @[ (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor] ];
    NSArray<NSNumber *> *locations = @[ @0, @1 ];

    if ([self isEnabled] && [self fadeWidth] > 0.5) {
        UIEdgeInsets adjustedInset = [scrollView adjustedContentInset];
        CGFloat leadingScrolledWidth = contentOffset.x + adjustedInset.left;
        CGFloat leadingFadeWidth = MIN([self fadeWidth], MAX(leadingScrolledWidth, 0));

        CGFloat visibleMaxX = contentOffset.x + width;
        CGFloat remainingWidth = [scrollView contentSize].width + adjustedInset.right - visibleMaxX;
        CGFloat trailingFadeWidth = MIN([self fadeWidth], MAX(remainingWidth, 0));

        BOOL showsLeadingFade = leadingFadeWidth > 0.5;
        BOOL showsTrailingFade = trailingFadeWidth > 0.5;
        if (showsLeadingFade && showsTrailingFade) {
            CGFloat leadingEndLocation = MIN(leadingFadeWidth / width, 1);
            CGFloat trailingStartLocation = MAX((width - trailingFadeWidth) / width, 0);
            if (leadingEndLocation > trailingStartLocation) {
                CGFloat midpoint = (leadingEndLocation + trailingStartLocation) / 2.0;
                leadingEndLocation = midpoint;
                trailingStartLocation = midpoint;
            }
            colors = @[
                (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                (__bridge id)[opaqueColor CGColor], (__bridge id)[transparentColor CGColor]
            ];
            locations = @[ @0, @(leadingEndLocation), @(trailingStartLocation), @1 ];
        } else if (showsLeadingFade) {
            CGFloat leadingEndLocation = MIN(leadingFadeWidth / width, 1);
            colors = @[
                (__bridge id)[transparentColor CGColor], (__bridge id)[opaqueColor CGColor],
                (__bridge id)[opaqueColor CGColor]
            ];
            locations = @[ @0, @(leadingEndLocation), @1 ];
        } else if (showsTrailingFade) {
            CGFloat trailingStartLocation = MAX((width - trailingFadeWidth) / width, 0);
            colors = @[
                (__bridge id)[opaqueColor CGColor], (__bridge id)[opaqueColor CGColor],
                (__bridge id)[transparentColor CGColor]
            ];
            locations = @[ @0, @(trailingStartLocation), @1 ];
        }
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [maskLayer setFrame:CGRectMake(contentOffset.x, contentOffset.y, width, height)];
    [maskLayer setColors:colors];
    [maskLayer setLocations:locations];
    [CATransaction commit];
}

@end
