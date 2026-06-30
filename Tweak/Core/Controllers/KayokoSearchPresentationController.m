//
//  KayokoSearchPresentationController.m
//  Kayoko
//

#import "KayokoSearchPresentationController.h"

#import "KayokoTableView.h"

static CGFloat const kKayokoSearchHeaderHeight = 56;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchPresentationController ()
@property(nonatomic, weak) UIView *containerView;
@property(nonatomic, weak) UIView *headerView;
@property(nonatomic, weak) UISearchBar *searchBar;
@property(nonatomic, weak) KayokoTableView *historyTableView;
@property(nonatomic, weak) KayokoTableView *favoritesTableView;
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
                            searchBar:(UISearchBar *)searchBar
                     historyTableView:(KayokoTableView *)historyTableView
                    favoritesTableView:(KayokoTableView *)favoritesTableView
                  panGestureRecognizer:(UIPanGestureRecognizer *)panGestureRecognizer {
    self = [super init];
    if (self) {
        _containerView = containerView;
        _headerView = headerView;
        _searchBar = searchBar;
        _historyTableView = historyTableView;
        _favoritesTableView = favoritesTableView;
        _panGestureRecognizer = panGestureRecognizer;

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
    return CGRectGetHeight([[self searchBar] frame]) ?: kKayokoSearchHeaderHeight;
}

- (void)layout {
    [self layoutSearchBarForTableView:[self historyTableView]];
    [self layoutSearchBarForTableView:[self favoritesTableView]];
}

- (void)layoutSearchBarForTableView:(KayokoTableView *)tableView {
    if ([tableView tableHeaderView] != [self searchBar]) {
        return;
    }

    CGRect frame = CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight);
    if (!CGRectEqualToRect([[self searchBar] frame], frame)) {
        [[self searchBar] setFrame:frame];
        [tableView setTableHeaderView:[self searchBar]];
    }
}

- (void)attachToTableView:(KayokoTableView *)tableView hidesSearchBar:(BOOL)hidesSearchBar {
    if (!tableView || [tableView tableHeaderView] == [self searchBar]) {
        if (hidesSearchBar && ![self isSearchActive]) {
            [self hideSearchBarInTableView:tableView animated:NO];
        }
        return;
    }

    [[self historyTableView] setTableHeaderView:nil];
    [[self favoritesTableView] setTableHeaderView:nil];
    [[self searchBar] setFrame:CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight)];
    [tableView setTableHeaderView:[self searchBar]];
    if (hidesSearchBar && ![self isSearchActive]) {
        [self hideSearchBarInTableView:tableView animated:NO];
    }
}

- (void)hideSearchBarInTableView:(KayokoTableView *)tableView animated:(BOOL)animated {
    if (!tableView || [tableView tableHeaderView] != [self searchBar] || [self isSearchActive]) {
        return;
    }

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = [self searchHeaderHeight];
    [tableView setContentOffset:contentOffset animated:animated];
}

- (void)revealSearchBarInTableView:(KayokoTableView *)tableView animated:(BOOL)animated {
    if (!tableView || [tableView tableHeaderView] != [self searchBar]) {
        return;
    }

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = 0;
    [tableView setContentOffset:contentOffset animated:animated];
}

- (void)beginSearchWithActiveTableView:(KayokoTableView *)activeTableView completion:(void (^)(void))completion {
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
                 activeTableView:(KayokoTableView *)activeTableView
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

- (void)applyKeyboardBottomInsetToTableView:(KayokoTableView *)tableView {
    UIEdgeInsets contentInset = [tableView contentInset];
    contentInset.bottom = [self keyboardBottomInset];
    [tableView setContentInset:contentInset];

    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, [self keyboardBottomInset], 0);
    if (@available(iOS 13.0, *)) {
        [tableView setVerticalScrollIndicatorInsets:indicatorInsets];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [tableView setScrollIndicatorInsets:indicatorInsets];
#pragma clang diagnostic pop
    }
}

- (void)applyKeyboardBottomInsetToTableViews {
    [self applyKeyboardBottomInsetToTableView:[self historyTableView]];
    [self applyKeyboardBottomInsetToTableView:[self favoritesTableView]];
}

- (void)resetKeyboardInsets {
    [self setKeyboardBottomInset:0];
    [self applyKeyboardBottomInsetToTableViews];
}

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [[self containerView] convertRect:keyboardEndFrame fromView:nil];
    [self setKeyboardBottomInset:MAX(CGRectGetMaxY([[self containerView] bounds]) - CGRectGetMinY(keyboardFrameInView), 0)];
    [self applyKeyboardBottomInsetToTableViews];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (![self isSearchActive]) {
        return;
    }

    [self resetKeyboardInsets];
}

@end
