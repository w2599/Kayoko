//
//  KayokoSearchPresentationController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableView;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchPresentationController : NSObject

@property(nonatomic, assign, readonly, getter=isSearchActive) BOOL searchActive;

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(UIView *)headerView
                      historySearchBar:(UISearchBar *)historySearchBar
                    favoritesSearchBar:(UISearchBar *)favoritesSearchBar
                     historyTableView:(KayokoTableView *)historyTableView
                    favoritesTableView:(KayokoTableView *)favoritesTableView
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer;

- (CGFloat)searchHeaderHeight;
- (void)layout;
- (void)attachToTableView:(KayokoTableView *)tableView hidesSearchBar:(BOOL)hidesSearchBar;
- (void)maintainSearchBarVisibilityForTableView:(KayokoTableView *)tableView;
- (void)hideSearchBarInTableView:(nullable KayokoTableView *)tableView animated:(BOOL)animated;
- (void)revealSearchBarInTableView:(nullable KayokoTableView *)tableView animated:(BOOL)animated;
- (void)beginSearchWithActiveTableView:(KayokoTableView *)activeTableView
                            completion:(nullable void (^)(void))completion;
- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                 activeTableView:(KayokoTableView *)activeTableView
                      completion:(nullable void (^)(void))completion;
- (void)resetKeyboardInsets;

@end

NS_ASSUME_NONNULL_END
