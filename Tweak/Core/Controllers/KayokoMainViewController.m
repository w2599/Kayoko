//
//  KayokoMainViewController.m
//  Kayoko
//

#import "KayokoMainViewController.h"

#import "KayokoClearConfirmationView.h"
#import "KayokoClearConfirmationViewController.h"
#import "KayokoEmptyStateView.h"
#import "KayokoHistoryController.h"
#import "KayokoHistoryListViewController.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoPanelPresentationController.h"
#import "KayokoPreviewView.h"
#import "KayokoPreviewViewController.h"
#import "KayokoSearchController.h"
#import "KayokoSearchViewController.h"
#import "KayokoTableView.h"
#import "KayokoView.h"
#import "KayokoWordSelectionView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController () <KayokoClearConfirmationViewControllerDelegate,
                                        KayokoHistoryControllerDelegate, KayokoPreviewViewControllerDelegate,
                                        KayokoPanelPresentationControllerDelegate, KayokoSearchControllerDelegate,
                                        KayokoHistoryListViewControllerDelegate>
@property(nonatomic, strong) KayokoView *panelView;
@property(nonatomic, copy, nullable) NSString *clearConfirmationHistoryKey;
@property(nonatomic, strong) KayokoHistoryController *historyController;
@property(nonatomic, strong) KayokoHistoryListViewController *historyListViewController;
@property(nonatomic, strong) KayokoHistoryListViewController *favoritesListViewController;
@property(nonatomic, strong) KayokoEmptyStateView *emptyStateView;
@property(nonatomic, strong) KayokoPanelPresentationController *panelPresentationController;
@property(nonatomic, strong) KayokoClearConfirmationViewController *clearConfirmationViewController;
@property(nonatomic, strong) KayokoPreviewViewController *previewViewController;
@property(nonatomic, strong) KayokoSearchViewController *searchViewController;
@property(nonatomic, strong) KayokoSearchController *searchController;
@property(nonatomic, assign) BOOL preparingToShow;
@property(nonatomic, assign) NSUInteger showRequestIdentifier;

- (void)showPreviewWithItem:(PasteboardItem *)item;
- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                           toHistoryKey:(NSString *)destinationHistoryKey;
- (void)updateContentState;
- (void)updateContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoMainViewController

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _panelView = [[KayokoView alloc] initWithFrame:frame];
        [self setView:_panelView];
        _historyListViewController =
            [[KayokoHistoryListViewController alloc]
                initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                     value:nil
                                                                                     table:@"Tweak"]
                  historyKey:kHistoryKeyHistory];
        [_historyListViewController setDelegate:self];
        [self addChildViewController:_historyListViewController];
        [_panelView installContentView:[_historyListViewController tableView] hidden:NO];
        [_historyListViewController didMoveToParentViewController:self];

        _favoritesListViewController =
            [[KayokoHistoryListViewController alloc]
                initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                     value:nil
                                                                                     table:@"Tweak"]
                  historyKey:kHistoryKeyFavorites];
        [_favoritesListViewController setDelegate:self];
        [self addChildViewController:_favoritesListViewController];
        [_panelView installContentView:[_favoritesListViewController tableView] hidden:YES];
        [_favoritesListViewController didMoveToParentViewController:self];

        _historyController =
            [[KayokoHistoryController alloc] initWithHistoryListViewController:_historyListViewController
                                                   favoritesListViewController:_favoritesListViewController];
        [_historyController setDelegate:self];

        __weak typeof(self) weakSelf = self;
        [_panelView setLayoutHandler:^{
          [weakSelf handleViewLayout];
        }];
        [[_panelView favoritesButton] addTarget:self
                                         action:@selector(handleFavoritesButtonPressed)
                               forControlEvents:UIControlEventTouchUpInside];
        [[_panelView clearButton] addTarget:self
                                     action:@selector(handleClearButtonPressed)
                           forControlEvents:UIControlEventTouchUpInside];
        [[_panelView backButton] addTarget:self
                                    action:@selector(handlePreviewActionButtonPressed)
                          forControlEvents:UIControlEventTouchUpInside];

        _panelPresentationController = [[KayokoPanelPresentationController alloc] initWithPanelView:_panelView];
        [_panelPresentationController setDelegate:self];

        _clearConfirmationViewController = [[KayokoClearConfirmationViewController alloc] init];
        [_clearConfirmationViewController setDelegate:self];
        [self addChildViewController:_clearConfirmationViewController];
        [_panelView installContentView:[_clearConfirmationViewController confirmationView] hidden:YES];
        [_clearConfirmationViewController didMoveToParentViewController:self];

        _emptyStateView = [[KayokoEmptyStateView alloc] init];
        [_panelView installContentView:_emptyStateView hidden:YES];

        _previewViewController = [[KayokoPreviewViewController alloc] initWithFavoritesButton:[_panelView favoritesButton]
                                                                                  backButton:[_panelView backButton]
                                                                                 clearButton:[_panelView clearButton]];
        [_previewViewController setDelegate:self];
        [self addChildViewController:_previewViewController];
        [_panelView installContentView:[_previewViewController previewView] hidden:YES];
        [_previewViewController didMoveToParentViewController:self];

        _searchViewController = [[KayokoSearchViewController alloc] initWithContainerView:_panelView];
        [self addChildViewController:_searchViewController];
        [_panelView addSubview:[_searchViewController view]];
        [_searchViewController didMoveToParentViewController:self];

        _searchController = [[KayokoSearchController alloc] initWithContainerView:_panelView
                                                                       headerView:[_panelView headerView]
                                                           searchViewController:_searchViewController
                                                     historyListViewController:_historyListViewController
                                                   favoritesListViewController:_favoritesListViewController
                                                              panGestureRecognizer:[_panelPresentationController panGestureRecognizer]];
        [_searchController setDelegate:self];

    }
    return self;
}

- (BOOL)isHidden {
    return [[self panelView] isHidden];
}

- (void)setOutsideDismissOverlayView:(UIControl *)outsideDismissOverlayView {
    [[self panelPresentationController] setOutsideDismissOverlayView:outsideDismissOverlayView];
}

- (void)applyUserInterfaceStyle:(UIUserInterfaceStyle)style {
    [self setOverrideUserInterfaceStyle:style];
    [[self view] setOverrideUserInterfaceStyle:style];

    for (UIViewController *childViewController in [self childViewControllers]) {
        [childViewController setOverrideUserInterfaceStyle:style];
        [[childViewController view] setOverrideUserInterfaceStyle:style];
    }

    [[self emptyStateView] setOverrideUserInterfaceStyle:style];
}

- (void)setDismissOnOutsideTouch:(BOOL)dismissOnOutsideTouch {
    _dismissOnOutsideTouch = dismissOnOutsideTouch;
    [[self panelPresentationController] setDismissOnOutsideTouch:dismissOnOutsideTouch];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    _previewLineCount = previewLineCount;
    [[self historyListViewController] setPreviewLineCount:previewLineCount];
    [[self favoritesListViewController] setPreviewLineCount:previewLineCount];
}

- (void)setShouldPlayFeedback:(BOOL)shouldPlayFeedback {
    _shouldPlayFeedback = shouldPlayFeedback;
    [[self panelPresentationController] setShouldPlayFeedback:shouldPlayFeedback];
}

- (void)handleViewLayout {
    [[self searchController] layout];
}

- (NSString *)effectiveActiveHistoryKey {
    return [[self historyController] effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:[self clearConfirmationHistoryKey]];
}

- (KayokoTableView *)activeTableView {
    return [[self historyController] activeTableViewWithClearConfirmationHistoryKey:[self clearConfirmationHistoryKey]];
}

- (KayokoHistoryListViewController *)activeListViewController {
    return [[self historyController] listViewControllerForHistoryKey:[self effectiveActiveHistoryKey]];
}

- (KayokoHistoryListViewController *)listViewControllerForHistoryKey:(NSString *)historyKey {
    return [[self historyController] listViewControllerForHistoryKey:historyKey];
}

- (KayokoHistoryListViewController *)activeListViewControllerForSearchController:(KayokoSearchController *)searchController {
    return [self activeListViewController];
}

- (void)searchControllerWillAnimateSearchState:(KayokoSearchController *)searchController {
    [[self panelView] setAnimating:YES];
    [[self panelPresentationController] finishOutsideDismissOverlayShow];
}

- (void)searchControllerDidFinishAnimatingSearchState:(KayokoSearchController *)searchController {
    [[self panelView] setAnimating:NO];
    [[self panelPresentationController] finishOutsideDismissOverlayShow];
}

- (void)panelPresentationControllerDidRequestDismiss:(KayokoPanelPresentationController *)controller {
    [self hide];
}

- (BOOL)historyControllerIsPanelVisible:(KayokoHistoryController *)controller {
    return ![self isHidden];
}

- (void)historyControllerNeedsVisibleReload:(KayokoHistoryController *)controller {
    [self reload];
}

- (void)historyController:(KayokoHistoryController *)controller didUpdateActiveTableView:(KayokoTableView *)tableView {
    [self updateActiveTableViewState:tableView];
}

- (void)historyListViewControllerDidRequestHide:(KayokoHistoryListViewController *)controller {
    [self hide];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
          didRequestPreviewForItem:(PasteboardItem *)item {
    [self showPreviewWithItem:item];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
    didChangeContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility {
    [self updateContentStateMaintainingSearchBarVisibility:maintainsSearchBarVisibility];
}

- (void)historyListViewController:(KayokoHistoryListViewController *)controller
            didMoveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
               fromHistoryWithKey:(NSString *)sourceHistoryKey
                 toHistoryWithKey:(NSString *)destinationHistoryKey {
    [self handlePasteboardItemDictionary:dictionary
                     movedFromHistoryKey:sourceHistoryKey
                             toHistoryKey:destinationHistoryKey];
}

- (KayokoTableView *)tableViewForHistoryKey:(NSString *)historyKey {
    return [[self historyController] tableViewForHistoryKey:historyKey];
}

- (UIView *)contentViewForHistoryKey:(NSString *)historyKey {
    KayokoHistoryListViewController *listViewController = [self listViewControllerForHistoryKey:historyKey];
    if ([[listViewController items] count] > 0) {
        return [listViewController tableView];
    }

    [[self emptyStateView] updateWithHistoryKey:historyKey];
    return [self emptyStateView];
}

- (UIView *)activeHistoryContentView {
    if (![[[self historyListViewController] tableView] isHidden]) {
        return [[self historyListViewController] tableView];
    }

    if (![[[self favoritesListViewController] tableView] isHidden]) {
        return [[self favoritesListViewController] tableView];
    }

    return [self emptyStateView];
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [[self clearConfirmationViewController] confirmationView]) {
        return [[[[self panelView] titleLabel] text] copy];
    }

    if (view == [[self previewViewController] previewView]) {
        return [[[self previewViewController] previewView] name];
    }

    if (view == [[self historyListViewController] tableView]) {
        return [[self historyListViewController] name];
    }

    if (view == [[self favoritesListViewController] tableView]) {
        return [[self favoritesListViewController] name];
    }

    if (view == [self emptyStateView]) {
        return [[self emptyStateView] name];
    }

    return nil;
}

- (void)setHistoryContentVisibleForKey:(NSString *)historyKey {
    [[self historyController] setActiveHistoryKey:historyKey];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [[[self historyListViewController] tableView] setHidden:contentView != [[self historyListViewController] tableView]];
    [[[self favoritesListViewController] tableView] setHidden:contentView != [[self favoritesListViewController] tableView]];
    [[self emptyStateView] setHidden:contentView != [self emptyStateView]];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];
    [[self searchController] attachToListViewController:[self listViewControllerForHistoryKey:historyKey]
                                         hidesSearchBar:![[self searchController] isSearchActive]];
    [[self searchController] refreshForListViewController:[self activeListViewController]];
    [[self panelView] setTitleText:[self titleForContentView:contentView]];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    [[self historyController] markHistoryKeyLoaded:historyKey];
}

- (void)updateActiveTableViewState:(KayokoTableView *)tableView {
    if (tableView == [self activeTableView]) {
        [[self searchController] refreshForListViewController:[self activeListViewController]];
        [[self panelView] setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
        [self updateContentState];
    }
}

- (void)handleHistoryChanged {
    [[self historyController] handleHistoryChanged];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                           completion:(void (^)(KayokoTableView *tableView))completion {
    [[self historyController] reloadTableViewForHistoryKey:historyKey
                                    animatingTopInsertions:animatingTopInsertions
                                                 completion:completion];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey completion:(void (^)(KayokoTableView *tableView))completion {
    [[self historyController] reloadTableViewForHistoryKey:historyKey completion:completion];
}

- (void)showClearConfirmationForHistoryKey:(NSString *)historyKey {
    [[self historyController] setActiveHistoryKey:historyKey];
    [self setClearConfirmationHistoryKey:historyKey];
    [[self clearConfirmationViewController] beginWithHistoryKey:historyKey];
    [[[self panelView] clearButton] setHidden:YES];

    [[self panelView] showContentView:[[self clearConfirmationViewController] confirmationView]
                 hideContentView:[self activeHistoryContentView]
                           title:[self titleForContentView:[[self clearConfirmationViewController] confirmationView]]
                         reverse:NO];
}

- (void)finishHidingClearConfirmationForHistoryKey:(NSString *)historyKey {
    [self setClearConfirmationHistoryKey:nil];
    [[[self panelView] clearButton] setHidden:NO];
    [[self panelView] setClearButtonEnabledForItemCount:[[[self listViewControllerForHistoryKey:historyKey] items] count]];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [[self panelView] showContentView:contentView
                 hideContentView:[[self clearConfirmationViewController] confirmationView]
                           title:[self titleForContentView:contentView]
                         reverse:YES];
}

- (void)hideClearConfirmationWithReload:(BOOL)reload {
    if ([[[self clearConfirmationViewController] confirmationView] isHidden] || ![self clearConfirmationHistoryKey]) {
        return;
    }

    NSString *historyKey = [self clearConfirmationHistoryKey];
    if (reload) {
        [[self listViewControllerForHistoryKey:historyKey] clearItems];
        [self markHistoryKeyLoaded:historyKey];
        if ([[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
            [[self searchController] refreshForListViewController:[self activeListViewController]];
        }
    }
    [self finishHidingClearConfirmationForHistoryKey:historyKey];
}

- (void)resetClearConfirmationIfNeeded {
    if (![self clearConfirmationHistoryKey]) {
        return;
    }

    [[[self clearConfirmationViewController] confirmationView] setHidden:YES];
    [[[self clearConfirmationViewController] confirmationView] setAlpha:1];
    [[[self clearConfirmationViewController] confirmationView] setTransform:CGAffineTransformIdentity];
    [self setHistoryContentVisibleForKey:[self clearConfirmationHistoryKey]];
    [[[self panelView] clearButton] setHidden:NO];
    [self setClearConfirmationHistoryKey:nil];
    [self updateClearButtonState];
}

- (BOOL)isShowingClearConfirmation {
    return [self clearConfirmationHistoryKey] && ![[[self clearConfirmationViewController] confirmationView] isHidden];
}

- (void)updateClearButtonState {
    [[self panelView] setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
}

- (void)updateContentState {
    [self updateContentStateMaintainingSearchBarVisibility:YES];
}

- (void)updateContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility {
    if (![self isShowingClearConfirmation] && [[[self previewViewController] previewView] isHidden]) {
        UIView *viewToHide = [self activeHistoryContentView];
        UIView *viewToShow = [self contentViewForHistoryKey:[self effectiveActiveHistoryKey]];

        if (viewToShow != viewToHide) {
            [[self panelView] showContentView:viewToShow
                         hideContentView:viewToHide
                                   title:[self titleForContentView:viewToShow]
                                 reverse:NO];
        } else {
            [[self panelView] setTitleText:[self titleForContentView:viewToShow]];
        }
    }

    [self updateClearButtonState];
    if (maintainsSearchBarVisibility) {
        [[self searchController] maintainSearchBarVisibilityForListViewController:[self activeListViewController]];
    }
}

- (void)handleFavoritesButtonPressed {
    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    if ([self isShowingClearConfirmation]) {
        [self hideClearConfirmationWithReload:NO];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    if (![[[self previewViewController] previewView] isHidden]) {
        [self hidePreview];
        [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    NSString *historyKey = [self effectiveActiveHistoryKey];
    BOOL showingFavorites = [historyKey isEqualToString:kHistoryKeyFavorites];
    NSString *targetKey = showingFavorites ? kHistoryKeyHistory : kHistoryKeyFavorites;
    UIView *viewToHide = [self activeHistoryContentView];
    BOOL reverse = showingFavorites;
    NSString *imageName = showingFavorites ? @"heart" : @"heart.fill";
    UIColor *tintColor = showingFavorites ? [UIColor labelColor] : [UIColor systemPinkColor];

    [self reloadTableViewForHistoryKey:targetKey
                            completion:^(KayokoTableView *targetTableView) {
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey] ||
                                  [[self panelPresentationController] isAnimating]) {
                                  return;
                              }

                              [[self historyController] setActiveHistoryKey:targetKey];
                              [[self searchController] attachToListViewController:[self listViewControllerForHistoryKey:targetKey]
                                                                   hidesSearchBar:![[self searchController] isSearchActive]];
                              [[self searchController] refreshForListViewController:[self activeListViewController]];
                              [[self panelView]
                                  setClearButtonEnabledForItemCount:[[[self listViewControllerForHistoryKey:targetKey] items] count]];

                              UIView *viewToShow = [self contentViewForHistoryKey:targetKey];
                              if (viewToShow != viewToHide) {
                                  [[self panelView] showContentView:viewToShow
                                               hideContentView:viewToHide
                                                         title:[self titleForContentView:viewToShow]
                                                       reverse:reverse];
                              } else {
                                  [[self panelView] setTitleText:[self titleForContentView:viewToShow]];
                              }

                              [[self panelView] updateStyleForHeaderButton:[[self panelView] favoritesButton]
                                                         withImageName:imageName
                                                          andImageSize:kFavoritesButtonImageSize
                                                          andTintColor:tintColor];
                              [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
                            }];
}

- (void)handlePreviewActionButtonPressed {
    [[self previewViewController] handleActionButtonWithAutomaticallyPaste:[self automaticallyPaste]];
}

- (void)updatePreviewActionButtonState {
    [[self previewViewController] updateActionButtonState];
}

- (void)handleClearButtonPressed {
    if ([[self panelPresentationController] isAnimating] || ![[[self previewViewController] previewView] isHidden] ||
        [self isShowingClearConfirmation]) {
        return;
    }

    [self showClearConfirmationForHistoryKey:[self effectiveActiveHistoryKey]];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                           toHistoryKey:(NSString *)destinationHistoryKey {
    [[self historyController] handlePasteboardItemDictionary:dictionary
                                         movedFromHistoryKey:sourceHistoryKey
                                                 toHistoryKey:destinationHistoryKey];
}

- (void)showPreviewWithItem:(PasteboardItem *)item {
    [[self searchController] suspendSuggestions];
    [[self previewViewController] showPreviewWithItem:item
                                      sourceTableView:[self tableViewForHistoryKey:[self effectiveActiveHistoryKey]]
                                    sourceHistoryKey:[self effectiveActiveHistoryKey]
                                 enablesWordSelection:[self swipeToSelectWords]
                                   automaticallyPaste:[self automaticallyPaste]];
}

- (void)hidePreview {
    if ([[[self previewViewController] previewView] isHidden] || [[self panelPresentationController] isAnimating]) {
        return;
    }

    [[self previewViewController] hidePreview];
}

- (void)clearConfirmationViewControllerDidCancel:(KayokoClearConfirmationViewController *)controller {
    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    [self hideClearConfirmationWithReload:NO];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)clearConfirmationViewControllerDidClearHistoryKey:(NSString *)historyKey {
    [self hideClearConfirmationWithReload:YES];
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
}

- (void)clearConfirmationViewController:(KayokoClearConfirmationViewController *)controller
                 didFailClearingHistoryKey:(NSString *)historyKey {
}

- (void)previewViewController:(KayokoPreviewViewController *)controller
                     showView:(UIView *)viewToShow
                     hideView:(UIView *)viewToHide
                      reverse:(BOOL)reverse {
    [[self panelView] showContentView:viewToShow
                 hideContentView:viewToHide
                           title:[self titleForContentView:viewToShow]
                         reverse:reverse];
}

- (void)previewViewController:(KayokoPreviewViewController *)controller
    hideContainerWithCompletion:(void (^)(void))completion {
    [self hideWithCompletion:completion];
}

- (void)previewViewController:(KayokoPreviewViewController *)controller
    triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    [[self panelPresentationController] triggerHapticFeedbackWithStyle:style];
}

- (void)previewViewControllerDidEndPreview:(KayokoPreviewViewController *)controller {
    if ([[self searchController] isSearchActive]) {
        [[self searchController] refreshForListViewController:[self activeListViewController]];
    }
}

- (void)reload {
    NSString *historyKey = [self effectiveActiveHistoryKey];
    [self reloadTableViewForHistoryKey:historyKey
                animatingTopInsertions:![self isHidden] && [historyKey isEqualToString:kHistoryKeyHistory]
                            completion:^(KayokoTableView *tableView) {
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
                                  return;
                              }
                              if ([self isShowingClearConfirmation] || ![[[self previewViewController] previewView] isHidden]) {
                                  return;
                              }
                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] refreshForListViewController:[self activeListViewController]];
                              [[self panelView]
                                  setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
                            }];
}

- (void)preloadHistoryIfNeeded {
    [[self historyController] preloadHistoryWithCompletion:nil];
}

- (void)show {
    if ([[self panelPresentationController] isAnimating] || [self preparingToShow]) {
        return;
    }

    [self setPreparingToShow:YES];
    NSUInteger showRequestIdentifier = [self showRequestIdentifier] + 1;
    [self setShowRequestIdentifier:showRequestIdentifier];
    [self resetClearConfirmationIfNeeded];

    [[self historyListViewController] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesListViewController] setAutomaticallyPaste:[self automaticallyPaste]];

    NSString *historyKey = [self effectiveActiveHistoryKey];
    [self reloadTableViewForHistoryKey:historyKey
                animatingTopInsertions:NO
                            completion:^(KayokoTableView *tableView) {
                              if ([self showRequestIdentifier] != showRequestIdentifier) {
                                  return;
                              }
                              [self setPreparingToShow:NO];
                              if (![[self effectiveActiveHistoryKey] isEqualToString:historyKey] ||
                                  ![self isHidden] || [[self panelPresentationController] isAnimating]) {
                                  return;
                              }

                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] attachToListViewController:[self activeListViewController]
                                                                   hidesSearchBar:YES];
                              [[self panelView]
                                  setClearButtonEnabledForItemCount:[[[self activeListViewController] items] count]];
                              [[self panelPresentationController] showPanelWithCompletion:nil];
                            }];
}

- (void)hide {
    [self hideWithCompletion:nil];
}

- (void)hideWithCompletion:(void (^)(void))completion {
    [self setShowRequestIdentifier:[self showRequestIdentifier] + 1];
    [self setPreparingToShow:NO];

    if ([[self panelPresentationController] isAnimating]) {
        return;
    }

    [[self searchController] resetBeforeHide];
    [[self panelPresentationController] hidePanelWithCompletion:^{
      [[self previewViewController] resetPreviewState];
      if (completion) {
          completion();
      }
    }];
}

@end
