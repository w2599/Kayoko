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

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchController () <UISearchBarDelegate, KayokoSearchSuggestionControllerDelegate>
@property(nonatomic, strong) KayokoSearchViewController *searchViewController;
@property(nonatomic, strong) KayokoSearchPresentationController *presentationController;
@property(nonatomic, strong) KayokoAppTokenController *appTokenController;
@property(nonatomic, strong) KayokoSearchSuggestionController *suggestionController;
@property(nonatomic, weak) UIView *headerView;
@property(nonatomic, strong) UISearchBar *searchBar;
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
        _searchViewController = [[KayokoSearchViewController alloc] initWithContainerView:containerView];
        _searchBar = [_searchViewController searchBar];
        _suggestionTableView = [_searchViewController suggestionTableView];
        [_searchBar setDelegate:self];
        if (@available(iOS 13.0, *)) {
            [[_searchBar searchTextField] addTarget:self
                                             action:@selector(handleSearchTextFieldEditingChanged)
                                   forControlEvents:UIControlEventEditingChanged];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleSearchTextFieldTextDidChangeNotification:)
                                                         name:UITextFieldTextDidChangeNotification
                                                       object:[_searchBar searchTextField]];
        }

        _appTokenController = [[KayokoAppTokenController alloc] init];
        _suggestionController = [[KayokoSearchSuggestionController alloc] initWithSuggestionTableView:_suggestionTableView];
        [_suggestionController setDelegate:self];
        _presentationController = [[KayokoSearchPresentationController alloc] initWithContainerView:containerView
                                                                                         headerView:headerView
                                                                                          searchBar:_searchBar
                                                                                   historyTableView:historyTableView
                                                                                  favoritesTableView:favoritesTableView
                                                                                panGestureRecognizer:panGestureRecognizer];

        [self attachToTableView:historyTableView hidesSearchBar:YES];
    }
    return self;
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

- (void)layout {
    [[self presentationController] layout];
    [self layoutSuggestionTableView];
}

- (void)attachToTableView:(KayokoTableView *)tableView hidesSearchBar:(BOOL)hidesSearchBar {
    [[self presentationController] attachToTableView:tableView hidesSearchBar:hidesSearchBar];
}

- (NSArray<NSString *> *)selectedBundleIdentifiers {
    return [[self appTokenController] selectedBundleIdentifiersInSearchBar:[self searchBar]];
}

- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                forTableView:(KayokoTableView *)tableView {
    [[self appTokenController] setSearchTokensWithBundleIdentifiers:bundleIdentifiers
                                                        inSearchBar:[self searchBar]
                                                       forTableView:tableView];
}

- (void)applySearchToActiveTableView {
    KayokoTableView *tableView = [self activeTableView];
    NSArray<NSString *> *selectedBundleIdentifiers = [self selectedBundleIdentifiers];
    [tableView applySearchText:[[self searchBar] text] selectedBundleIdentifiers:selectedBundleIdentifiers];

    NSArray<NSString *> *validBundleIdentifiers = [tableView selectedBundleIdentifiers] ?: @[];
    if (![validBundleIdentifiers isEqualToArray:selectedBundleIdentifiers]) {
        [self setSearchTokensWithBundleIdentifiers:validBundleIdentifiers forTableView:tableView];
    }

    [self refreshSuggestions];
}

- (void)refreshForTableView:(KayokoTableView *)tableView {
    [self attachToTableView:tableView hidesSearchBar:![self isSearchActive]];
    [self setSearchTokensWithBundleIdentifiers:[self selectedBundleIdentifiers] forTableView:tableView];
    [self applySearchToActiveTableView];
}

- (void)refreshSuggestions {
    KayokoTableView *tableView = [self activeTableView];
    NSArray<NSDictionary<NSString *, id> *> *suggestionItems =
        [[self appTokenController] unselectedAppTokenSuggestionItemsForTableView:tableView searchBar:[self searchBar]];
    [[self suggestionController] updateSuggestionItems:suggestionItems];
    [self layoutSuggestionTableView];
    [[self suggestionController] setHidden:![self isSearchActive] || [[self suggestionController] numberOfSuggestions] == 0];
}

- (void)suspendSuggestions {
    [[self searchBar] resignFirstResponder];
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
    [[self searchBar] setShowsCancelButton:YES animated:YES];
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
    [[self searchBar] resignFirstResponder];
    [[self searchBar] setShowsCancelButton:NO animated:YES];
    if (clearsSearch) {
        [[self searchBar] setText:@""];
        [self setSearchTokensWithBundleIdentifiers:@[] forTableView:[self activeTableView]];
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
    if (![self isSearchActive] && [[[self searchBar] text] length] == 0 && [[self selectedBundleIdentifiers] count] == 0) {
        return;
    }

    [self endSearchRestoringFrame:NO clearsSearch:YES];
}

- (void)handleSearchTextFieldEditingChanged {
    if ([self isResettingSearch]) {
        return;
    }
    [self applySearchToActiveTableView];
}

- (void)handleSearchTextFieldTextDidChangeNotification:(NSNotification *)notification {
    if ([self isResettingSearch]) {
        return;
    }
    [self applySearchToActiveTableView];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self beginSearchIfNeeded];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([self isResettingSearch]) {
        return;
    }
    [self applySearchToActiveTableView];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [self endSearchRestoringFrame:YES clearsSearch:YES];
}

- (void)searchSuggestionController:(KayokoSearchSuggestionController *)controller
        didSelectBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier length] == 0) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        NSMutableArray<NSString *> *bundleIdentifiers = [[self selectedBundleIdentifiers] mutableCopy];
        if (![bundleIdentifiers containsObject:bundleIdentifier]) {
            [bundleIdentifiers addObject:bundleIdentifier];
        }
        [self setSearchTokensWithBundleIdentifiers:bundleIdentifiers forTableView:[self activeTableView]];
        [self applySearchToActiveTableView];
        [[self searchBar] becomeFirstResponder];
    }
}

@end
