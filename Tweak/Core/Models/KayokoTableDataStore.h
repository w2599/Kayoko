//
//  KayokoTableDataStore.h
//  Kayoko
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableDataStore : NSObject

@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *items;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *availableAppTokenItems;
@property(nonatomic, copy, readonly) NSString *searchText;
@property(nonatomic, copy, readonly) NSArray<NSString *> *selectedBundleIdentifiers;
@property(nonatomic, assign, readonly) BOOL hasActiveSearch;

- (void)applySearchText:(NSString *)searchText selectedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers;
- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    inItems:(NSArray<NSDictionary<NSString *, id> *> *)items;

@end

NS_ASSUME_NONNULL_END
