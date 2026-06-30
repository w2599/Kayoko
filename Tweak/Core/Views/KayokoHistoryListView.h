//
//  KayokoHistoryListView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryListView : UITableView

@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) NSUInteger previewLineCount;

- (instancetype)initWithName:(NSString *)name;
- (void)setShowsNoSearchResultsBackground:(BOOL)showsNoSearchResultsBackground;
- (BOOL)isSearchHeaderExposedAtContentOffset:(CGPoint)contentOffset;
- (BOOL)isContentOffsetAtHiddenSearchHeaderBoundary:(CGPoint)contentOffset;
- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction;
- (void)prepareHiddenHeaderInsetsForRemovingRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)scrollToTopAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
