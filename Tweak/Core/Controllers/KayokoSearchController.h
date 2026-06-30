//
//  KayokoSearchController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoSearchController;
@class KayokoTableView;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchControllerDelegate <NSObject>

- (KayokoTableView *)activeTableViewForSearchController:(KayokoSearchController *)searchController;
- (void)searchControllerWillAnimateSearchState:(KayokoSearchController *)searchController;
- (void)searchControllerDidFinishAnimatingSearchState:(KayokoSearchController *)searchController;

@end

@interface KayokoSearchController : NSObject

@property(nonatomic, weak, nullable) id<KayokoSearchControllerDelegate> delegate;
@property(nonatomic, assign, readonly, getter=isSearchActive) BOOL searchActive;

- (instancetype)initWithContainerView:(UIView *)containerView
                            headerView:(UIView *)headerView
                     historyTableView:(KayokoTableView *)historyTableView
                    favoritesTableView:(KayokoTableView *)favoritesTableView
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer;

- (void)layout;
- (void)attachToTableView:(KayokoTableView *)tableView hidesSearchBar:(BOOL)hidesSearchBar;
- (void)refreshForTableView:(KayokoTableView *)tableView;
- (void)suspendSuggestions;
- (void)resetBeforeHide;

@end

NS_ASSUME_NONNULL_END
