//
//  KayokoSearchController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoSearchController;
@class KayokoHistoryListViewController;
@class KayokoSearchViewController;
@class KayokoHistoryListView;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchControllerDelegate <NSObject>

- (KayokoHistoryListViewController *)activeListViewControllerForSearchController:(KayokoSearchController *)searchController;
- (void)searchControllerWillAnimateSearchState:(KayokoSearchController *)searchController;
- (void)searchControllerDidFinishAnimatingSearchState:(KayokoSearchController *)searchController;

@end

@interface KayokoSearchController : NSObject

@property(nonatomic, weak, nullable) id<KayokoSearchControllerDelegate> delegate;
@property(nonatomic, assign, readonly, getter=isSearchActive) BOOL searchActive;

- (instancetype)initWithContainerView:(UIView *)containerView
                            headerView:(UIView *)headerView
                 searchViewController:(KayokoSearchViewController *)searchViewController
             historyListViewController:(KayokoHistoryListViewController *)historyListViewController
           favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer;

- (void)layout;
- (void)attachToListViewController:(KayokoHistoryListViewController *)listViewController
                     hidesSearchBar:(BOOL)hidesSearchBar;
- (void)refreshForListViewController:(KayokoHistoryListViewController *)listViewController;
- (void)maintainSearchBarVisibilityForListViewController:(KayokoHistoryListViewController *)listViewController;
- (void)suspendSuggestions;
- (void)resetBeforeHide;

@end

NS_ASSUME_NONNULL_END
