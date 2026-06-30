//
//  KayokoSearchTokenProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenProvider : NSObject

- (NSArray<NSDictionary<NSString *, id> *> *)appTokenItemsWithAvailableItems:
    (NSArray<NSDictionary<NSString *, id> *> *)availableItems;
- (NSArray<NSString *> *)selectedBundleIdentifiersInSearchBar:(UISearchBar *)searchBar;
- (NSArray<NSDictionary<NSString *, id> *> *)unselectedAppTokenSuggestionItemsWithAvailableItems:
                                            (NSArray<NSDictionary<NSString *, id> *> *)availableItems
                                                                                        searchBar:(UISearchBar *)searchBar;
- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                 inSearchBar:(UISearchBar *)searchBar
                              availableItems:(NSArray<NSDictionary<NSString *, id> *> *)availableItems;

@end

NS_ASSUME_NONNULL_END
