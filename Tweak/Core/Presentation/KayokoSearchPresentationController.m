//
//  KayokoSearchPresentationController.m
//  Kayoko
//

#import "KayokoSearchPresentationController.h"

#import "KayokoHistoryListView.h"

static CGFloat const kKayokoSearchHeaderHeight = 56;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchPresentationController ()
@property(nonatomic, weak) UIView *containerView;
@property(nonatomic, weak) UIView *headerView;
@property(nonatomic, weak) UISearchBar *historySearchBar;
@property(nonatomic, weak) UISearchBar *favoritesSearchBar;
@property(nonatomic, weak) KayokoHistoryListView *historyTableView;
@property(nonatomic, weak) KayokoHistoryListView *favoritesTableView;
@property(nonatomic, weak) UIPanGestureRecognizer *panGestureRecognizer;
@property(nonatomic, assign, getter=isSearchActive) BOOL searchActive;
@property(nonatomic, assign) CGRect normalFrameBeforeSearch;
@property(nonatomic, assign) BOOL hasNormalFrameBeforeSearch;
@property(nonatomic, assign) CGFloat keyboardBottomInset;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchPresentationController

- (instancetype)initWithContainerView:(UIView *)containerView
                           headerView:(UIView *)headerView
                      historySearchBar:(UISearchBar *)historySearchBar
                    favoritesSearchBar:(UISearchBar *)favoritesSearchBar
                     historyTableView:(KayokoHistoryListView *)historyTableView
                    favoritesTableView:(KayokoHistoryListView *)favoritesTableView
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    self = [super init];
    if (self) {
        _containerView = containerView;
        _headerView = headerView;
        _historySearchBar = historySearchBar;
        _favoritesSearchBar = favoritesSearchBar;
        _historyTableView = historyTableView;
        _favoritesTableView = favoritesTableView;
        _panGestureRecognizer = panGestureRecognizer;
        [self installSearchBarForTableView:historyTableView];
        [self installSearchBarForTableView:favoritesTableView];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillChangeFrameNotification:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillHideNotification:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (CGFloat)searchHeaderHeight {
    return kKayokoSearchHeaderHeight;
}

- (void)layout {
    [self layoutSearchBarForTableView:[self historyTableView]];
    [self layoutSearchBarForTableView:[self favoritesTableView]];
    [self applyBottomInsetsToTableViews];
}

- (void)layoutSearchBarForTableView:(KayokoHistoryListView *)tableView {
    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    if ([tableView tableHeaderView] != searchBar) {
        return;
    }

    CGRect frame = CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight);
    if (!CGRectEqualToRect([searchBar frame], frame)) {
        [searchBar setFrame:frame];
        [tableView setTableHeaderView:searchBar];
    }
}

- (UISearchBar *)searchBarForTableView:(KayokoHistoryListView *)tableView {
    return tableView == [self favoritesTableView] ? [self favoritesSearchBar] : [self historySearchBar];
}

- (void)installSearchBarForTableView:(KayokoHistoryListView *)tableView {
    if (!tableView) {
        return;
    }

    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    if ([tableView tableHeaderView] == searchBar) {
        return;
    }

    [searchBar setFrame:CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight)];
    [tableView setTableHeaderView:searchBar];
}

- (void)attachToTableView:(KayokoHistoryListView *)tableView hidesSearchBar:(BOOL)hidesSearchBar {
    [self installSearchBarForTableView:[self historyTableView]];
    [self installSearchBarForTableView:[self favoritesTableView]];
    [self layout];

    if (!tableView) {
        return;
    }

    if (hidesSearchBar && ![self isSearchActive]) {
        [self hideSearchBarInTableView:tableView animated:NO];
    } else if ([self isSearchActive]) {
        [self revealSearchBarInTableView:tableView animated:NO];
    }
}

- (void)hideSearchBarInTableView:(KayokoHistoryListView *)tableView animated:(BOOL)animated {
    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    if (!tableView || [tableView tableHeaderView] != searchBar || [self isSearchActive]) {
        return;
    }

    [self applyBottomInsetToTableView:tableView];

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = [self searchHeaderHeight];
    [tableView setContentOffset:contentOffset animated:animated];
}

- (void)revealSearchBarInTableView:(KayokoHistoryListView *)tableView animated:(BOOL)animated {
    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    if (!tableView || [tableView tableHeaderView] != searchBar) {
        return;
    }

    [self applyBottomInsetToTableView:tableView];

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = 0;
    [tableView setContentOffset:contentOffset animated:animated];
}

- (void)maintainSearchBarVisibilityForTableView:(KayokoHistoryListView *)tableView {
    if ([self isSearchActive]) {
        [self revealSearchBarInTableView:tableView animated:NO];
    } else {
        [self hideSearchBarInTableView:tableView animated:NO];
    }
}

- (void)beginSearchWithActiveTableView:(KayokoHistoryListView *)activeTableView completion:(void (^)(void))completion {
    if ([self isSearchActive]) {
        return;
    }

    [self setSearchActive:YES];
    [self setNormalFrameBeforeSearch:[[self containerView] frame]];
    [self setHasNormalFrameBeforeSearch:YES];
    [[self panGestureRecognizer] setEnabled:NO];
    [self revealSearchBarInTableView:activeTableView animated:YES];

    UIView *superview = [[self containerView] superview];
    if (!superview) {
        if (completion) {
            completion();
        }
        return;
    }

    CGRect safeBounds = UIEdgeInsetsInsetRect([superview bounds], [superview safeAreaInsets]);
    [UIView animateWithDuration:0.28
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [[self containerView] setTransform:CGAffineTransformIdentity];
          [[self containerView] setFrame:safeBounds];
          [[self containerView] setNeedsLayout];
          [[self containerView] layoutIfNeeded];
        }
        completion:^(__unused BOOL finished) {
          if (completion) {
              completion();
          }
        }];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame
                 activeTableView:(KayokoHistoryListView *)activeTableView
                      completion:(void (^)(void))completion {
    [self setSearchActive:NO];
    [self resetKeyboardInsets];
    [[self panGestureRecognizer] setEnabled:YES];

    CGRect targetFrame = [self hasNormalFrameBeforeSearch] ? [self normalFrameBeforeSearch] : [[self containerView] frame];
    [self setHasNormalFrameBeforeSearch:NO];

    if (restoresFrame && !CGRectEqualToRect([[self containerView] frame], targetFrame)) {
        [UIView animateWithDuration:0.28
            delay:0
            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
            animations:^{
              [[self containerView] setFrame:targetFrame];
              [[self containerView] setNeedsLayout];
              [[self containerView] layoutIfNeeded];
            }
            completion:^(__unused BOOL finished) {
              [self hideSearchBarInTableView:activeTableView animated:YES];
              if (completion) {
                  completion();
              }
            }];
    } else {
        [[self containerView] setFrame:targetFrame];
        [self hideSearchBarInTableView:activeTableView animated:NO];
        if (completion) {
            completion();
        }
    }
}

- (CGFloat)hiddenSearchBottomInsetForTableView:(KayokoHistoryListView *)tableView {
    if ([self isSearchActive]) {
        return 0;
    }

    return [tableView minimumBottomInsetForMaintainingHiddenHeaderWithAdditionalContentHeightReduction:0];
}

- (void)applyBottomInsetToTableView:(KayokoHistoryListView *)tableView {
    UIEdgeInsets contentInset = [tableView contentInset];
    CGFloat bottomInset = [self keyboardBottomInset] + [self hiddenSearchBottomInsetForTableView:tableView];
    contentInset.bottom = bottomInset;
    [tableView setContentInset:contentInset];

    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    if (@available(iOS 13.0, *)) {
        [tableView setVerticalScrollIndicatorInsets:indicatorInsets];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [tableView setScrollIndicatorInsets:indicatorInsets];
#pragma clang diagnostic pop
    }
}

- (void)applyBottomInsetsToTableViews {
    [self applyBottomInsetToTableView:[self historyTableView]];
    [self applyBottomInsetToTableView:[self favoritesTableView]];
}

- (void)resetKeyboardInsets {
    [self setKeyboardBottomInset:0];
    [self applyBottomInsetsToTableViews];
}

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [[self containerView] convertRect:keyboardEndFrame fromView:nil];
    [self setKeyboardBottomInset:MAX(CGRectGetMaxY([[self containerView] bounds]) - CGRectGetMinY(keyboardFrameInView), 0)];
    [self applyBottomInsetsToTableViews];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    [self resetKeyboardInsets];
}

@end
