//
//  KayokoTagDotView.m
//  Kayoko
//

#import "KayokoTagDotView.h"

#import <QuartzCore/QuartzCore.h>

static CGFloat const kKayokoTagDotDefaultDiameter = 14.0;
static CGFloat const kKayokoTagDotDefaultBorderWidth = 1.25;

@interface KayokoTagDotView ()
@property(nonatomic, strong) CAShapeLayer *dotLayer;
@property(nonatomic, strong) CAShapeLayer *noTagRingLayer;
@property(nonatomic, strong) CAShapeLayer *noTagSlashLayer;
@end

@implementation KayokoTagDotView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setUserInteractionEnabled:NO];
        [self setClipsToBounds:NO];
        _dotDiameter = kKayokoTagDotDefaultDiameter;
        _borderWidth = kKayokoTagDotDefaultBorderWidth;

        _dotLayer = [CAShapeLayer layer];
        [_dotLayer setContentsScale:[UIScreen mainScreen].scale];
        [[self layer] addSublayer:_dotLayer];

        _noTagRingLayer = [CAShapeLayer layer];
        [_noTagRingLayer setContentsScale:[UIScreen mainScreen].scale];
        [_noTagRingLayer setFillColor:[[UIColor clearColor] CGColor]];
        [[self layer] addSublayer:_noTagRingLayer];

        _noTagSlashLayer = [CAShapeLayer layer];
        [_noTagSlashLayer setContentsScale:[UIScreen mainScreen].scale];
        [_noTagSlashLayer setFillColor:[[UIColor clearColor] CGColor]];
        [_noTagSlashLayer setLineCap:kCALineCapRound];
        [[self layer] addSublayer:_noTagSlashLayer];

        [self configureWithFillColor:nil borderColor:nil];
    }
    return self;
}

- (void)configureWithFillColor:(nullable UIColor *)fillColor borderColor:(nullable UIColor *)borderColor {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self dotLayer] setHidden:fillColor == nil];
    [[self dotLayer] setFillColor:[fillColor CGColor]];
    [[self dotLayer] setStrokeColor:[borderColor CGColor]];
    [[self noTagRingLayer] setHidden:YES];
    [[self noTagSlashLayer] setHidden:YES];
    [CATransaction commit];
    [self setNeedsLayout];
}

- (void)configureNoTagWithTintColor:(UIColor *)tintColor {
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self dotLayer] setHidden:YES];
    [[self noTagRingLayer] setHidden:NO];
    [[self noTagRingLayer] setStrokeColor:[tintColor CGColor]];
    [[self noTagSlashLayer] setHidden:NO];
    [[self noTagSlashLayer] setStrokeColor:[tintColor CGColor]];
    [CATransaction commit];
    [self setNeedsLayout];
}

- (void)setDotDiameter:(CGFloat)dotDiameter {
    _dotDiameter = MAX(dotDiameter, 1.0);
    [self setNeedsLayout];
}

- (void)setBorderWidth:(CGFloat)borderWidth {
    _borderWidth = MAX(borderWidth, 0.0);
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateLayerPaths];
}

- (void)updateLayerPaths {
    CGRect bounds = [self bounds];
    if (CGRectIsEmpty(bounds)) {
        return;
    }

    CGFloat dotX = floor((CGRectGetWidth(bounds) - [self dotDiameter]) / 2.0);
    CGFloat dotY = floor((CGRectGetHeight(bounds) - [self dotDiameter]) / 2.0);
    CGRect dotRect = CGRectMake(dotX, dotY, [self dotDiameter], [self dotDiameter]);
    CGFloat strokeWidth = [self borderWidth];
    CGRect pathRect = CGRectInset(dotRect, strokeWidth / 2.0, strokeWidth / 2.0);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [[self dotLayer] setFrame:bounds];
    [[self dotLayer] setLineWidth:strokeWidth];
    [[self dotLayer] setPath:[[UIBezierPath bezierPathWithOvalInRect:pathRect] CGPath]];

    [[self noTagRingLayer] setFrame:bounds];
    [[self noTagRingLayer] setLineWidth:strokeWidth];
    [[self noTagRingLayer] setPath:[[UIBezierPath bezierPathWithOvalInRect:pathRect] CGPath]];

    CGFloat slashInset = round([self dotDiameter] * 0.29);
    UIBezierPath *slashPath = [UIBezierPath bezierPath];
    [slashPath moveToPoint:CGPointMake(CGRectGetMinX(dotRect) + slashInset, CGRectGetMaxY(dotRect) - slashInset)];
    [slashPath addLineToPoint:CGPointMake(CGRectGetMaxX(dotRect) - slashInset, CGRectGetMinY(dotRect) + slashInset)];
    [[self noTagSlashLayer] setFrame:bounds];
    [[self noTagSlashLayer] setLineWidth:strokeWidth];
    [[self noTagSlashLayer] setPath:[slashPath CGPath]];
    [CATransaction commit];
}

@end
