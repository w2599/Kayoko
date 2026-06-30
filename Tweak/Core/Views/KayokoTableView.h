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
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy) NSString *searchText;
@property(nonatomic, copy) NSArray<NSString *> *selectedBundleIdentifiers;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *availableAppTokenItems;
@property(nonatomic, assign, readonly) BOOL hasActiveSearch;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) NSUInteger previewLineCount;
@property(nonatomic, copy) NSString *historyKey;

- (instancetype)initWithName:(NSString *)name;
- (void)reloadDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items;
- (void)updateDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items
     animatingTopInsertions:(BOOL)animatingTopInsertions;
- (void)applySearchText:(NSString *)searchText selectedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers;
- (nullable NSDictionary<NSString *, id> *)itemDictionaryAtIndexPath:(NSIndexPath *)indexPath;
- (void)clearItems;
- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary limit:(NSUInteger)limit;
- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary
                             limit:(NSUInteger)limit
                         animating:(BOOL)animating;
- (CGFloat)minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:(CGFloat)heightReduction;
- (void)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary;
- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath completion:(nullable void (^)(BOOL success))completion;

@end

NS_ASSUME_NONNULL_END
