//
//  KayokoEdgeFadingScrollView.m
//  Kayoko
//

#import "KayokoEdgeFadingScrollView.h"

#import "KayokoEdgeFadeMaskController.h"

@interface KayokoEdgeFadingScrollView ()
@property(nonatomic, strong) KayokoEdgeFadeMaskController *edgeFadeMaskController;
@end

@implementation KayokoEdgeFadingScrollView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    [self setEdgeFadeMaskController:[[KayokoEdgeFadeMaskController alloc] initWithScrollView:self]];
}

- (CGFloat)edgeFadeWidth {
    return [[self edgeFadeMaskController] fadeWidth];
}

- (void)setEdgeFadeWidth:(CGFloat)edgeFadeWidth {
    [[self edgeFadeMaskController] setFadeWidth:edgeFadeWidth];
}

- (BOOL)isEdgeFadeEnabled {
    return [[self edgeFadeMaskController] isEnabled];
}

- (void)setEdgeFadeEnabled:(BOOL)edgeFadeEnabled {
    [[self edgeFadeMaskController] setEnabled:edgeFadeEnabled];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self updateEdgeFadeMask];
}

- (void)setContentOffset:(CGPoint)contentOffset {
    [super setContentOffset:contentOffset];
    [self updateEdgeFadeMask];
}

- (void)setContentSize:(CGSize)contentSize {
    [super setContentSize:contentSize];
    [self updateEdgeFadeMask];
}

- (void)setContentInset:(UIEdgeInsets)contentInset {
    [super setContentInset:contentInset];
    [self updateEdgeFadeMask];
}

- (void)updateEdgeFadeMask {
    [[self edgeFadeMaskController] updateMask];
}

@end
