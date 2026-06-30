//
//  KayokoHistoryListView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHistoryListView.h"

#import "PasteboardManager.h"

static CGFloat const kKayokoHistoryListViewBaseRowHeight = 65;
static CGFloat const kKayokoHistoryListViewAdditionalPreviewLineHeight = 18;
static NSUInteger const kKayokoHistoryListViewMaximumPreviewLineCount = 3;
static CGFloat const kKayokoHistoryListViewHiddenHeaderInsetPadding = 1;

@implementation KayokoHistoryListView

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
    return height > 0 ? height : kKayokoHistoryListViewBaseRowHeight;
}

- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction {
    CGFloat hiddenHeaderOffsetY = [self hiddenHeaderOffsetY];
    if (hiddenHeaderOffsetY <= 0) {
        return 0;
    }

    [self layoutIfNeeded];

    CGFloat projectedContentHeight = MAX([self contentSize].height - heightReduction, 0);
    CGFloat requiredContentHeight =
        CGRectGetHeight([self bounds]) + hiddenHeaderOffsetY + kKayokoHistoryListViewHiddenHeaderInsetPadding;
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
    NSUInteger lineCount = MIN(MAX(previewLineCount, 1), kKayokoHistoryListViewMaximumPreviewLineCount);
    _previewLineCount = lineCount;
    [self setRowHeight:kKayokoHistoryListViewBaseRowHeight + (lineCount - 1) * kKayokoHistoryListViewAdditionalPreviewLineHeight];
    [self reloadData];
}

@end
