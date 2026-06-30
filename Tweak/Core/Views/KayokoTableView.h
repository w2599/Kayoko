//
//  KayokoTableView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableView : UITableView

@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) NSUInteger previewLineCount;

- (instancetype)initWithName:(NSString *)name;
- (void)setShowsNoSearchResultsBackground:(BOOL)showsNoSearchResultsBackground;
- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction;
- (void)prepareHiddenHeaderInsetsForRemovingRowAtIndexPath:(NSIndexPath *)indexPath;

@end

NS_ASSUME_NONNULL_END
