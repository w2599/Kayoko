//
//  KayokoSearchController.m
//  Kayoko
//

#import "KayokoSearchController.h"

#import "KayokoAppTokenController.h"
#import "KayokoSearchPresentationController.h"
#import "KayokoSearchSuggestionController.h"
#import "KayokoSearchViewController.h"
#import "KayokoTableView.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchController () <UISearchBarDelegate, KayokoSearchSuggestionControllerDelegate>
@property(nonatomic, strong) KayokoSearchViewController *searchViewController;
@property(nonatomic, strong) KayokoSearchPresentationController *presentationController;
@property(nonatomic, strong) KayokoAppTokenController *appTokenController;
@property(nonatomic, strong) KayokoSearchSuggestionController *suggestionController;
@property(nonatomic, weak) UIView *headerView;
@property(nonatomic, weak) KayokoTableView *historyTableView;
@property(nonatomic, weak) KayokoTableView *favoritesTableView;
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
                     historyTableView:(KayokoTableView *)historyTableView
                    favoritesTableView:(KayokoTableView *)favoritesTableView
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    self = [super init];
    if (self) {
        _headerView = headerView;
        _historyTableView = historyTableView;
        _favoritesTableView = favoritesTableView;
        _searchViewController = [[KayokoSearchViewController alloc] initWithContainerView:containerView];
        _suggestionTableView = [_searchViewController suggestionTableView];
        _historySearchBar = [self newSearchBar];
        _favoritesSearchBar = [self newSearchBar];

        _appTokenController = [[KayokoAppTokenController alloc] init];
        _suggestionController = [[KayokoSearchSuggestionController alloc] initWithSuggestionTableView:_suggestionTableView];
        [_suggestionController setDelegate:self];
        _presentationController = [[KayokoSearchPresentationController alloc] initWithContainerView:containerView
                                                                                         headerView:headerView
                                                                                   historySearchBar:_historySearchBar
                                                                                 favoritesSearchBar:_favoritesSearchBar
                                                                                   historyTableView:historyTableView
                                                                                  favoritesTableView:favoritesTableView
                                                                                panGestureRecognizer:panGestureRecognizer];

        [self attachToTableView:historyTableView hidesSearchBar:YES];
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

- (KayokoTableView *)activeTableView {
    return [[self delegate] activeTableViewForSearchController:self];
}

- (CGFloat)searchHeaderHeight {
    return [[self presentationController] searchHeaderHeight];
}

- (UISearchBar *)searchBarForTableView:(KayokoTableView *)tableView {
    return tableView == [self favoritesTableView] ? [self favoritesSearchBar] : [self historySearchBar];
}

- (KayokoTableView *)tableViewForSearchBar:(UISearchBar *)searchBar {
    return searchBar == [self favoritesSearchBar] ? [self favoritesTableView] : [self historyTableView];
}

- (UISearchBar *)activeSearchBar {
    return [self searchBarForTableView:[self activeTableView]];
}

- (void)layout {
    [[self presentationController] layout];
    [self layoutSuggestionTableView];
}

- (void)attachToTableView:(KayokoTableView *)tableView hidesSearchBar:(BOOL)hidesSearchBar {
    [[self presentationController] attachToTableView:tableView hidesSearchBar:hidesSearchBar];
}

- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                forTableView:(KayokoTableView *)tableView {
    [[self appTokenController] setSearchTokensWithBundleIdentifiers:bundleIdentifiers
                                                        inSearchBar:[self searchBarForTableView:tableView]
                                                       forTableView:tableView];
}

- (void)applySearchFromSearchBar:(UISearchBar *)searchBar {
    KayokoTableView *tableView = [self tableViewForSearchBar:searchBar];
    NSArray<NSString *> *selectedBundleIdentifiers =
        [[self appTokenController] selectedBundleIdentifiersInSearchBar:searchBar];
    [tableView applySearchText:[searchBar text] selectedBundleIdentifiers:selectedBundleIdentifiers];

    NSArray<NSString *> *validBundleIdentifiers = [tableView selectedBundleIdentifiers] ?: @[];
    if (![validBundleIdentifiers isEqualToArray:selectedBundleIdentifiers]) {
        [self setSearchTokensWithBundleIdentifiers:validBundleIdentifiers forTableView:tableView];
    }

    if (tableView == [self activeTableView]) {
        [self refreshSuggestions];
    }
}

- (void)applySearchToActiveTableView {
    [self applySearchFromSearchBar:[self activeSearchBar]];
}

- (void)syncSearchBarForTableView:(KayokoTableView *)tableView {
    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:[tableView searchText]];
    [self setSearchTokensWithBundleIdentifiers:[tableView selectedBundleIdentifiers] ?: @[] forTableView:tableView];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)refreshForTableView:(KayokoTableView *)tableView {
    [self attachToTableView:tableView hidesSearchBar:![self isSearchActive]];
    [self syncSearchBarForTableView:tableView];
    [self applySearchFromSearchBar:[self searchBarForTableView:tableView]];
    if ([self isSearchActive] && tableView == [self activeTableView]) {
        [[self historySearchBar] setShowsCancelButton:NO animated:NO];
        [[self favoritesSearchBar] setShowsCancelButton:NO animated:NO];
        [[self activeSearchBar] setShowsCancelButton:YES animated:NO];
        [[self activeSearchBar] becomeFirstResponder];
    }
}

- (void)refreshSuggestions {
    KayokoTableView *tableView = [self activeTableView];
    NSArray<NSDictionary<NSString *, id> *> *suggestionItems =
        [[self appTokenController] unselectedAppTokenSuggestionItemsForTableView:tableView searchBar:[self activeSearchBar]];
    [[self suggestionController] updateSuggestionItems:suggestionItems];
    [self layoutSuggestionTableView];
    [[self suggestionController] setHidden:![self isSearchActive] || [[self suggestionController] numberOfSuggestions] == 0];
}

- (void)suspendSuggestions {
    [[self activeSearchBar] resignFirstResponder];
    [[self suggestionController] setHidden:YES];
}

- (void)layoutSuggestionTableView {
    [[self searchViewController] layoutSuggestionTableViewWithHeaderView:[self headerView]
                                                               itemCount:[[self suggestionController] numberOfSuggestions]
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
    [[self presentationController] beginSearchWithActiveTableView:[self activeTableView]
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
        [self clearSearchForTableView:[self activeTableView]];
    }
    [[self presentationController] resetKeyboardInsets];
    [self applySearchToActiveTableView];
    [[self suggestionController] setHidden:YES];
    [self setIsResettingSearch:NO];

    [[self delegate] searchControllerWillAnimateSearchState:self];
    [[self presentationController] endSearchRestoringFrame:restoresFrame
                                           activeTableView:[self activeTableView]
                                                completion:^{
                                                  [[self delegate] searchControllerDidFinishAnimatingSearchState:self];
                                                }];
}

- (void)resetBeforeHide {
    BOOL hasSearch = [[self historyTableView] hasActiveSearch] || [[self favoritesTableView] hasActiveSearch];
    if (![self isSearchActive] && !hasSearch) {
        return;
    }

    [self clearSearchForTableView:[self historyTableView]];
    [self clearSearchForTableView:[self favoritesTableView]];
    [self endSearchRestoringFrame:NO clearsSearch:NO];
}

- (void)clearSearchForTableView:(KayokoTableView *)tableView {
    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    BOOL wasResettingSearch = [self isResettingSearch];
    [self setIsResettingSearch:YES];
    [searchBar setText:@""];
    [self setSearchTokensWithBundleIdentifiers:@[] forTableView:tableView];
    [tableView applySearchText:@"" selectedBundleIdentifiers:@[]];
    [self setIsResettingSearch:wasResettingSearch];
}

- (void)maintainSearchBarVisibilityForTableView:(KayokoTableView *)tableView {
    [[self presentationController] maintainSearchBarVisibilityForTableView:tableView];
}

- (void)handleSearchTextFieldEditingChanged:(UITextField *)textField {
    if ([self isResettingSearch]) {
        return;
    }
    UISearchBar *searchBar =
        textField == [[self favoritesSearchBar] searchTextField] ? [self favoritesSearchBar] : [self historySearchBar];
    if ([self tableViewForSearchBar:searchBar] != [self activeTableView]) {
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
    if ([self tableViewForSearchBar:searchBar] != [self activeTableView]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    if ([self tableViewForSearchBar:searchBar] != [self activeTableView]) {
        return;
    }
    [self beginSearchIfNeeded];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self isResettingSearch]) {
        return;
    }
    if ([self tableViewForSearchBar:searchBar] != [self activeTableView]) {
        return;
    }
    [self applySearchFromSearchBar:searchBar];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    if ([self tableViewForSearchBar:searchBar] != [self activeTableView]) {
        return;
    }
    [self endSearchRestoringFrame:YES clearsSearch:YES];
}

- (void)searchSuggestionController:(KayokoSearchSuggestionController *)controller
        didSelectBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier length] == 0) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        UISearchBar *searchBar = [self activeSearchBar];
        NSMutableArray<NSString *> *bundleIdentifiers =
            [[[self appTokenController] selectedBundleIdentifiersInSearchBar:searchBar] mutableCopy];
        if (![bundleIdentifiers containsObject:bundleIdentifier]) {
            [bundleIdentifiers addObject:bundleIdentifier];
        }
        [self setSearchTokensWithBundleIdentifiers:bundleIdentifiers forTableView:[self activeTableView]];
        [self applySearchToActiveTableView];
        [searchBar becomeFirstResponder];
    }
}

@end
