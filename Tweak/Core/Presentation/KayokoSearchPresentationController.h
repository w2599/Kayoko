//
//  KayokoSearchPresentationController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoHistoryListView;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchPresentationController : NSObject

@property(nonatomic, assign, readonly, getter=isSearchActive) BOOL searchActive;

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(UIView *)headerView
                      historySearchBar:(UISearchBar *)historySearchBar
                    favoritesSearchBar:(UISearchBar *)favoritesSearchBar
                     historyTableView:(KayokoHistoryListView *)historyTableView
                    favoritesTableView:(KayokoHistoryListView *)favoritesTableView
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer;

- (CGFloat)searchHeaderHeight;
- (void)layout;
- (void)attachToTableView:(KayokoHistoryListView *)tableView hidesSearchBar:(BOOL)hidesSearchBar;
- (void)maintainSearchBarVisibilityForTableView:(KayokoHistoryListView *)tableView;
- (void)hideSearchBarInTableView:(nullable KayokoHistoryListView *)tableView animated:(BOOL)animated;
- (void)revealSearchBarInTableView:(nullable KayokoHistoryListView *)tableView animated:(BOOL)animated;
- (void)beginSearchWithActiveTableView:(KayokoHistoryListView *)activeTableView
                            completion:(nullable void (^)(void))completion;
- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                 activeTableView:(KayokoHistoryListView *)activeTableView
                      completion:(nullable void (^)(void))completion;
- (void)resetKeyboardInsets;

@end

NS_ASSUME_NONNULL_END
