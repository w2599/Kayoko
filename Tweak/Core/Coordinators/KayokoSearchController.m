//
//  KayokoSearchController.m
//  Kayoko
//

#import "KayokoSearchController.h"

#import "KayokoHistoryListViewController.h"
#import "KayokoSearchPresentationController.h"
#import "KayokoSearchSuggestionDataSource.h"
#import "KayokoSearchTokenProvider.h"
#import "KayokoSearchViewController.h"
#import "KayokoHistoryListView.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchController () <UISearchBarDelegate, KayokoSearchSuggestionDataSourceDelegate>
@property(nonatomic, strong) KayokoSearchViewController *searchViewController;
@property(nonatomic, strong) KayokoSearchPresentationController *presentationController;
@property(nonatomic, strong) KayokoSearchTokenProvider *searchTokenProvider;
@property(nonatomic, strong) KayokoSearchSuggestionDataSource *suggestionDataSource;
@property(nonatomic, weak) UIView *headerView;
@property(nonatomic, weak) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, weak) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) UISearchBar *historySearchBar;
@property(nonatomic, strong) UISearchBar *favoritesSearchBar;
@property(nonatomic, strong) UITableView *suggestionTableView;
@property(nonatomic, assign, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign) BOOL isResettingSearch;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchController

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(UIView *)headerView
                 searchViewController:(KayokoSearchViewController *)searchViewController
             historyListViewController:(KayokoHistoryListViewController *)historyListViewController
           favoritesListViewController:(KayokoHistoryListViewController *)favoritesListViewController
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    self = [super init];
    if (self) {
        _headerView = headerView;
        _historyListViewController = historyListViewController;
        _favoritesListViewController = favoritesListViewController;
        _searchViewController = searchViewController;
        _suggestionTableView = [_searchViewController suggestionTableView];
        _historySearchBar = [self newSearchBar];
        _favoritesSearchBar = [self newSearchBar];

        _searchTokenProvider = [[KayokoSearchTokenProvider alloc] init];
        _suggestionDataSource = [[KayokoSearchSuggestionDataSource alloc] initWithSuggestionTableView:_suggestionTableView];
        [_suggestionDataSource setDelegate:self];
        _presentationController = [[KayokoSearchPresentationController alloc] initWithContainerView:containerView
                                                                                         headerView:headerView
                                                                                   historySearchBar:_historySearchBar
                                                                                 favoritesSearchBar:_favoritesSearchBar
                                                                                   historyTableView:[historyListViewController tableView]
                                                                                  favoritesTableView:[favoritesListViewController tableView]
                                                                                panGestureRecognizer:panGestureRecognizer];

        [self attachToListViewController:historyListViewController hidesSearchBar:YES];
    }
    return self;
}

- (UISearchBar *)newSearchBar {
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    [searchBar setPlaceholder:[[PasteboardManager localizationBundle] localizedStringForKey:@"Search"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];
    [searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [searchBar setBackgroundImage:[[UIImage alloc] init]];
    [searchBar setDelegate:self];
    if (@available(iOS 13.0, *)) {
        [[searchBar searchTextField] addTarget:self
                                        action:@selector(handleSearchTextFieldEditingChanged:)
                              forControlEvents:UIControlEventEditingChanged];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleSearchTextFieldTextDidChangeNotification:)
                                                     name:UITextFieldTextDidChangeNotification
                                                   object:[searchBar searchTextField]];
    }
    return searchBar;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (KayokoHistoryListViewController *)activeListViewController {
    return [[self delegate] activeListViewControllerForSearchController:self];
}

- (KayokoHistoryListView *)activeTableView {
    return [[self activeListViewController] tableView];
}

- (CGFloat)searchHeaderHeight {
    return [[self presentationController] searchHeaderHeight];
}

- (UISearchBar *)searchBarForTableView:(KayokoHistoryListView *)tableView {
    return tableView == [[self favoritesListViewController] tableView] ? [self favoritesSearchBar] : [self historySearchBar];
}

- (KayokoHistoryListViewController *)listViewControllerForSearchBar:(UISearchBar *)searchBar {
    return searchBar == [self favoritesSearchBar] ? [self favoritesListViewController] : [self historyListViewController];
}

- (UISearchBar *)activeSearchBar {
    return [self searchBarForTableView:[self activeTableView]];
}

- (void)layout {
    [[self presentationController] layout];
    [self layoutSuggestionTableView];
}

- (void)attachToListViewController:(KayokoHistoryListViewController *)listViewController
                     hidesSearchBar:(BOOL)hidesSearchBar {
    [[self presentationController] attachToTableView:[listViewController tableView] hidesSearchBar:hidesSearchBar];
}

- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                       forListViewController:(KayokoHistoryListViewController *)listViewController {
    [[self searchTokenProvider] setSearchTokensWithBundleIdentifiers:bundleIdentifiers
                                                         inSearchBar:[self searchBarForTableView:[listViewController tableView]]
                                                      availableItems:[listViewController availableAppTokenItems]];
}

- (void)applySearchFromSearchBar:(UISearchBar *)searchBar {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForSearchBar:searchBar];
    NSArray<NSString *> *selectedBundleIdentifiers =
        [[self searchTokenProvider] selectedBundleIdentifiersInSearchBar:searchBar];
    [listViewController applySearchText:[searchBar text] selectedBundleIdentifiers:selectedBundleIdentifiers];

    NSArray<NSString *> *validBundleIdentifiers = [listViewController selectedBundleIdentifiers] ?: @[];
    if (![validBundleIdentifiers isEqualToArray:selectedBundleIdentifiers]) {
        [self setSearchTokensWithBundleIdentifiers:validBundleIdentifiers forListViewController:listViewController];
    }

    if (listViewController == [self activeListViewController]) {
        [self refreshSuggestions];
    }
}

- (void)applySearchToActiveTableView {
    [self applySearchFromSearchBar:[self activeSearchBar]];
}

- (void)syncSearchBarForListViewController:(KayokoHistoryListViewController *)listViewController {
    UISearchBar *searchBar = [self searchBarForTableView:[listViewController tableView]];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:[listViewController searchText]];
    [self setSearchTokensWithBundleIdentifiers:[listViewController selectedBundleIdentifiers] ?: @[]
                         forListViewController:listViewController];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)refreshForListViewController:(KayokoHistoryListViewController *)listViewController {
    [self attachToListViewController:listViewController hidesSearchBar:![self isSearchActive]];
    [self syncSearchBarForListViewController:listViewController];
    [self applySearchFromSearchBar:[self searchBarForTableView:[listViewController tableView]]];
    if ([self isSearchActive] && listViewController == [self activeListViewController]) {
        [[self historySearchBar] setShowsCancelButton:NO animated:NO];
        [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
        [[self activeSearchBar] setShowsCancelButton:YES animated:NO];
        [[self activeSearchBar] becomeFirstResponder];
    }
}

- (void)refreshSuggestions {
    KayokoHistoryListViewController *listViewController = [self activeListViewController];
    NSArray<NSDictionary<NSString *, id> *> *suggestionItems =
        [[self searchTokenProvider] unselectedAppTokenSuggestionItemsWithAvailableItems:[listViewController availableAppTokenItems]
                                                                             searchBar:[self activeSearchBar]];
    [[self suggestionDataSource] updateSuggestionItems:suggestionItems];
    [self layoutSuggestionTableView];
    [[self suggestionDataSource] setHidden:![self isSearchActive] || [[self suggestionDataSource] numberOfSuggestions] == 0];
}

- (void)suspendSuggestions {
    [[self activeSearchBar] resignFirstResponder];
    [[self suggestionDataSource] setHidden:YES];
}

- (void)layoutSuggestionTableView {
    [[self searchViewController] layoutSuggestionTableViewWithHeaderView:[self headerView]
                                                               itemCount:[[self suggestionDataSource] numberOfSuggestions]
                                                            searchActive:[self isSearchActive]
                                                      searchHeaderHeight:[self searchHeaderHeight]];
}

- (void)beginSearchIfNeeded {
    if ([self isSearchActive]) {
        return;
    }

    [self setSearchActive:YES];
    [[self historySearchBar] setShowsCancelButton:NO animated:NO];
    [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
    [[self activeSearchBar] setShowsCancelButton:YES animated:YES];
    [self refreshSuggestions];
    [[self delegate] searchControllerWillAnimateSearchState:self];
    [[self presentationController] beginSearchWithActiveTableView:[[self activeListViewController] tableView]
                                                       completion:^{
                                                         [[self delegate] searchControllerDidFinishAnimatingSearchState:self];
                                                       }];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame clearsSearch:(BOOL)clearsSearch {
    if (![self isSearchActive] && !clearsSearch) {
        return;
    }

    [self setIsResettingSearch:YES];
    [self setSearchActive:NO];
    UISearchBar *activeSearchBar = [self activeSearchBar];
    [activeSearchBar resignFirstResponder];
    [[self historySearchBar] setShowsCancelButton:NO animated:YES];
    [[self favoritesSearchBar] setShowsCancelButton:NO animated:YES];
    if (clearsSearch) {
        [self clearSearchForListViewController:[self activeListViewController]];
    }
    [[self presentationController] resetKeyboardInsets];
    [self applySearchToActiveTableView];
    [[self suggestionDataSource] setHidden:YES];
    [self setIsResettingSearch:NO];

    [[self delegate] searchControllerWillAnimateSearchState:self];
    [[self presentationController] endSearchRestoringFrame:restoresFrame
                                           activeTableView:[[self activeListViewController] tableView]
                                                completion:^{
                                                  [[self delegate] searchControllerDidFinishAnimatingSearchState:self];
                                                }];
}

- (void)resetBeforeHide {
    BOOL hasSearch = [[self historyListViewController] hasActiveSearch] || [[self favoritesListViewController] hasActiveSearch];
    if (![self isSearchActive] && !hasSearch) {
        return;
    }

    [self clearSearchForListViewController:[self historyListViewController]];
    [self clearSearchForListViewController:[self favoritesListViewController]];
    [self endSearchRestoringFrame:NO clearsSearch:NO];
}

- (void)clearSearchForListViewController:(KayokoHistoryListViewController *)listViewController {
    UISearchBar *searchBar = [self searchBarForTableView:[listViewController tableView]];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:@""];
    [self setSearchTokensWithBundleIdentifiers:@[] forListViewController:listViewController];
    [listViewController applySearchText:@"" selectedBundleIdentifiers:@[]];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)maintainSearchBarVisibilityForListViewController:(KayokoHistoryListViewController *)listViewController {
    [[self presentationController] maintainSearchBarVisibilityForTableView:[listViewController tableView]];
}

- (void)handleSearchTextFieldEditingChanged:(UITextField *)textField {
    if ([self isResettingSearch]) {
        return;
    }
    UISearchBar *searchBar =
        textField == [[self favoritesSearchBar] searchTextField] ? [self favoritesSearchBar] : [self historySearchBar];
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)handleSearchTextFieldTextDidChangeNotification:(NSNotification *)notification {
    if ([self isResettingSearch]) {
        return;
    }
    UITextField *textField = [notification object];
    UISearchBar *searchBar =
        textField == [[self favoritesSearchBar] searchTextField] ? [self favoritesSearchBar] : [self historySearchBar];
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self beginSearchIfNeeded];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self isResettingSearch]) {
        return;
    }
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    if ([self listViewControllerForSearchBar:searchBar] != [self activeListViewController]) {
        return;
    }
    [self endSearchRestoringFrame:YES clearsSearch:YES];
}

- (void)searchSuggestionDataSource:(KayokoSearchSuggestionDataSource *)controller
        didSelectBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier length] == 0) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        UISearchBar *searchBar = [self activeSearchBar];
        NSMutableArray<NSString *> *bundleIdentifiers =
            [[[self searchTokenProvider] selectedBundleIdentifiersInSearchBar:searchBar] mutableCopy];
        if (![bundleIdentifiers containsObject:bundleIdentifier]) {
            [bundleIdentifiers addObject:bundleIdentifier];
        }
        [self setSearchTokensWithBundleIdentifiers:bundleIdentifiers
                             forListViewController:[self activeListViewController]];
        [self applySearchToActiveTableView];
        [searchBar becomeFirstResponder];
    }
}

@end
