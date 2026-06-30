//
//  KayokoSearchPresentationController.m
//  Kayoko
//

#import "KayokoSearchPresentationController.h"

#import "KayokoHistoryListView.h"
#import "KayokoMainView.h"
#import "KayokoSearchBar.h"

static CGFloat const kKayokoSearchHeaderHeight = 56;
static CGFloat const kKayokoSearchBarHorizontalInset = 16;
static NSTimeInterval const kKayokoSearchFullscreenAnimationDuration = 0.34;
static CGFloat const kKayokoSearchFullscreenAnimationDamping = 0.86;

static CGRect KayokoStatusBarFrameForWindow(UIWindow *window) {
    CGRect statusBarFrame = CGRectZero;
    if (@available(iOS 13.0, *)) {
        UIWindowScene *windowScene = [window windowScene];
        if (windowScene) {
            statusBarFrame = [[windowScene statusBarManager] statusBarFrame];
        }
    }

    if (CGRectIsEmpty(statusBarFrame)) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
#pragma clang diagnostic pop
    }

    return statusBarFrame;
}

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
@property(nonatomic, assign, readwrite) CGFloat keyboardBottomInset;
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
    [tableView updateNoSearchResultsPlaceholderLayout];

    UISearchBar *searchBar = [self searchBarForTableView:tableView];
    if ([tableView tableHeaderView] != searchBar) {
        return;
    }

    CGRect fullWidthFrame = CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight);
    CGRect frame = CGRectInset(fullWidthFrame, kKayokoSearchBarHorizontalInset, 0);
    if (!CGRectEqualToRect([searchBar frame], frame)) {
        [searchBar setFrame:fullWidthFrame];
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

    if ([searchBar respondsToSelector:@selector(setKayokoHorizontalFrameInset:)]) {
        [(KayokoSearchBar *)searchBar setKayokoHorizontalFrameInset:kKayokoSearchBarHorizontalInset];
    }
    [searchBar setFrame:CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight)];
    [tableView setTableHeaderView:searchBar];
    [self layoutSearchBarForTableView:tableView];
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

- (UIEdgeInsets)contentSafeAreaAdditionalInsetsForFullscreenSuperview:(UIView *)superview {
    UIView *containerView = [self containerView];
    UIEdgeInsets safeAreaInsets = [superview safeAreaInsets];
    UIEdgeInsets additionalInsets = UIEdgeInsetsZero;
    if (safeAreaInsets.top > 0) {
        return additionalInsets;
    }

    CGRect statusBarFrame = KayokoStatusBarFrameForWindow([containerView window]);
    if (CGRectIsEmpty(statusBarFrame)) {
        return additionalInsets;
    }

    CGRect statusBarFrameInSuperview = [superview convertRect:statusBarFrame fromView:nil];
    CGFloat statusBarBottom = CGRectGetMaxY(statusBarFrameInSuperview) - CGRectGetMinY([superview bounds]);
    additionalInsets.top = ceil(MAX(statusBarBottom, 0));
    return additionalInsets;
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

    UIView *containerView = [self containerView];
    [containerView layoutIfNeeded];
    if ([containerView isKindOfClass:[KayokoMainView class]]) {
        KayokoMainView *mainView = (KayokoMainView *)containerView;
        [mainView
            setContentSafeAreaAdditionalInsets:[self contentSafeAreaAdditionalInsetsForFullscreenSuperview:superview]];
        [mainView setContentRespectsSafeArea:YES];
    }

    CGRect fullscreenBounds = [superview bounds];
    [UIView animateWithDuration:kKayokoSearchFullscreenAnimationDuration
        delay:0
        usingSpringWithDamping:kKayokoSearchFullscreenAnimationDamping
        initialSpringVelocity:0
        options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
        animations:^{
          [containerView setTransform:CGAffineTransformIdentity];
          [containerView setFrame:fullscreenBounds];
          [containerView setNeedsLayout];
          [containerView layoutIfNeeded];
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

    CGRect targetFrame =
        [self hasNormalFrameBeforeSearch] ? [self normalFrameBeforeSearch] : [[self containerView] frame];
    [self setHasNormalFrameBeforeSearch:NO];

    UIView *containerView = [self containerView];
    [containerView layoutIfNeeded];
    if ([containerView isKindOfClass:[KayokoMainView class]]) {
        KayokoMainView *mainView = (KayokoMainView *)containerView;
        [mainView setContentRespectsSafeArea:NO];
        [mainView setContentSafeAreaAdditionalInsets:UIEdgeInsetsZero];
    }

    if (restoresFrame && !CGRectEqualToRect([[self containerView] frame], targetFrame)) {
        [UIView animateWithDuration:kKayokoSearchFullscreenAnimationDuration
            delay:0
            usingSpringWithDamping:kKayokoSearchFullscreenAnimationDamping
            initialSpringVelocity:0
            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
            animations:^{
              [containerView setFrame:targetFrame];
              [containerView setNeedsLayout];
              [containerView layoutIfNeeded];
              [self hideSearchBarInTableView:activeTableView animated:NO];
            }
            completion:^(__unused BOOL finished) {
              if (completion) {
                  completion();
              }
            }];
    } else {
        [containerView setFrame:targetFrame];
        [containerView setNeedsLayout];
        [containerView layoutIfNeeded];
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
    [tableView setKeyboardBottomInset:[self keyboardBottomInset]];
    [tableView updateNoSearchResultsPlaceholderLayout];

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

- (void)setKeyboardBottomInset:(CGFloat)keyboardBottomInset {
    keyboardBottomInset = MAX(keyboardBottomInset, 0);
    if (_keyboardBottomInset == keyboardBottomInset) {
        return;
    }

    _keyboardBottomInset = keyboardBottomInset;
    [[self delegate] searchPresentationController:self didUpdateKeyboardBottomInset:keyboardBottomInset];
}

- (void)resetKeyboardInsets {
    [self setKeyboardBottomInset:0];
    [self applyBottomInsetsToTableViews];
}

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    BOOL isLocal = [notification.userInfo[UIKeyboardIsLocalUserInfoKey] boolValue];
    if (!isLocal) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [[self containerView] convertRect:keyboardEndFrame fromView:nil];
    [self setKeyboardBottomInset:MAX(CGRectGetMaxY([[self containerView] bounds]) - CGRectGetMinY(keyboardFrameInView),
                                     0)];
    [self applyBottomInsetsToTableViews];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    [self resetKeyboardInsets];
}

@end
