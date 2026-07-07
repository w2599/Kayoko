//
//  KayokoSearchTokenCollectionView.m
//  Kayoko
//

#import "KayokoSearchTokenCollectionView.h"

@implementation KayokoSearchTokenCollectionView

- (instancetype)initWithItemSize:(CGSize)itemSize
                     itemSpacing:(CGFloat)itemSpacing
          horizontalContentInset:(CGFloat)horizontalContentInset {
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    [layout setScrollDirection:UICollectionViewScrollDirectionHorizontal];
    [layout setItemSize:itemSize];
    [layout setMinimumInteritemSpacing:itemSpacing];
    [layout setMinimumLineSpacing:itemSpacing];

    self = [super initWithFrame:CGRectZero collectionViewLayout:layout];
    if (self) {
        _horizontalScrollingLayout = YES;

        [self setBackgroundColor:[UIColor clearColor]];
        [self setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
        [self setContentInset:UIEdgeInsetsMake(0, horizontalContentInset, 0, horizontalContentInset)];
        [self setEdgeFadeAxis:KayokoEdgeFadeAxisHorizontal];
        [self setEdgeFadeWidth:horizontalContentInset];
        [self setEdgeFadeEnabled:YES];
        [self setScrollEnabled:YES];
        [self setShowsHorizontalScrollIndicator:NO];
        [self setShowsVerticalScrollIndicator:NO];
    }
    return self;
}

- (void)setHorizontalScrollingLayout:(BOOL)horizontalScrollingLayout {
    if (_horizontalScrollingLayout == horizontalScrollingLayout) {
        return;
    }

    _horizontalScrollingLayout = horizontalScrollingLayout;
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)[self collectionViewLayout];
    [layout setScrollDirection:horizontalScrollingLayout ? UICollectionViewScrollDirectionHorizontal
                                                         : UICollectionViewScrollDirectionVertical];
    [layout invalidateLayout];
    [self setScrollEnabled:horizontalScrollingLayout];
    [self setEdgeFadeAxis:KayokoEdgeFadeAxisHorizontal];
    [self setEdgeFadeEnabled:horizontalScrollingLayout];
    [self resetContentOffsetToLeadingEdge];
    [self updateEdgeFadeMask];
}

- (void)resetContentOffsetToLeadingEdge {
    [self layoutIfNeeded];
    UIEdgeInsets adjustedInset = [self adjustedContentInset];
    CGPoint contentOffset = [self contentOffset];
    contentOffset.x = -adjustedInset.left;
    contentOffset.y = -adjustedInset.top;
    [self setContentOffset:contentOffset animated:NO];
    [self updateEdgeFadeMask];
}

@end
