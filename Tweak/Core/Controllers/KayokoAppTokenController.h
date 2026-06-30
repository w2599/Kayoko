//
//  KayokoAppTokenController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableView;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoAppTokenController : NSObject

- (NSArray<NSDictionary<NSString *, id> *> *)appTokenItemsForTableView:(KayokoTableView *)tableView;
- (NSArray<NSString *> *)selectedBundleIdentifiersInSearchBar:(UISearchBar *)searchBar;
- (NSArray<NSDictionary<NSString *, id> *> *)unselectedAppTokenSuggestionItemsForTableView:(KayokoTableView *)tableView
                                                                                  searchBar:(UISearchBar *)searchBar;
- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                 inSearchBar:(UISearchBar *)searchBar
                                forTableView:(KayokoTableView *)tableView;

@end

NS_ASSUME_NONNULL_END
