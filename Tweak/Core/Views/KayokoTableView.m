//
//  KayokoTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableView.h"

#import "PasteboardManager.h"

static CGFloat const kKayokoTableViewBaseRowHeight = 65;
static CGFloat const kKayokoTableViewAdditionalPreviewLineHeight = 18;
static NSUInteger const kKayokoTableViewMaximumPreviewLineCount = 3;
static CGFloat const kKayokoTableViewHiddenHeaderInsetPadding = 1;

@implementation KayokoTableView

- (void)setShowsNoSearchResultsBackground:(BOOL)showsNoSearchResultsBackground {
    if (!showsNoSearchResultsBackground) {
        [self setBackgroundView:nil];
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    [label setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
    [label setTextColor:[UIColor secondaryLabelColor]];
    [label setTextAlignment:NSTextAlignmentCenter];
    [label setNumberOfLines:0];
    [label setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"No Search Results"
                                                                           value:nil
                                                                           table:@"Tweak"]];
    [self setBackgroundView:label];
}

- (CGFloat)hiddenHeaderOffsetY {
    UIView *headerView = [self tableHeaderView];
    return headerView ? CGRectGetHeight([headerView frame]) : 0;
}

- (CGFloat)heightForRowRemovalAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat height = CGRectGetHeight([self rectForRowAtIndexPath:indexPath]);
    if (height > 0) {
        return height;
    }

    height = [self rowHeight];
    return height > 0 ? height : kKayokoTableViewBaseRowHeight;
}

- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction {
    CGFloat hiddenHeaderOffsetY = [self hiddenHeaderOffsetY];
    if (hiddenHeaderOffsetY <= 0) {
        return 0;
    }

    [self layoutIfNeeded];

    CGFloat projectedContentHeight = MAX([self contentSize].height - heightReduction, 0);
    CGFloat requiredContentHeight =
        CGRectGetHeight([self bounds]) + hiddenHeaderOffsetY + kKayokoTableViewHiddenHeaderInsetPadding;
    return ceil(MAX(requiredContentHeight - projectedContentHeight, 0));
}

- (void)prepareHiddenHeaderInsetsForRemovingRowAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat hiddenHeaderOffsetY = [self hiddenHeaderOffsetY];
    if (hiddenHeaderOffsetY <= 0) {
        return;
    }

    UIEdgeInsets contentInset = [self contentInset];
    CGFloat requiredBottomInset = [self minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:
                                            [self heightForRowRemovalAtIndexPath:indexPath]];
    if (contentInset.bottom >= requiredBottomInset) {
        return;
    }

    contentInset.bottom = requiredBottomInset;
    [self setContentInset:contentInset];
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];
        [self setBackgroundColor:[UIColor clearColor]];
        [self setAlwaysBounceVertical:YES];
        [self setPreviewLineCount:1];
    }

    return self;
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    NSUInteger lineCount = MIN(MAX(previewLineCount, 1), kKayokoTableViewMaximumPreviewLineCount);
    _previewLineCount = lineCount;
    [self setRowHeight:kKayokoTableViewBaseRowHeight + (lineCount - 1) * kKayokoTableViewAdditionalPreviewLineHeight];
    [self reloadData];
}

@end
