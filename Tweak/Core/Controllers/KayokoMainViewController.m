//
//  KayokoMainViewController.m
//  Kayoko
//

#import "KayokoMainViewController.h"

#import "KayokoClearConfirmationView.h"
#import "KayokoClearConfirmationViewController.h"
#import "KayokoEmptyStateView.h"
#import "KayokoFavoritesTableView.h"
#import "KayokoHistoryController.h"
#import "KayokoHeaderButtonStyle.h"
#import "KayokoHistoryTableView.h"
#import "KayokoPanelPresentationController.h"
#import "KayokoPreviewView.h"
#import "KayokoPreviewViewController.h"
#import "KayokoSearchController.h"
#import "KayokoTableView.h"
#import "KayokoTableViewController.h"
#import "KayokoView.h"
#import "KayokoWordSelectionView.h"
#import "KayokoWordSelectionViewController.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoMainViewController () <KayokoClearConfirmationViewControllerDelegate,
                                        KayokoHistoryControllerDelegate, KayokoPreviewViewControllerDelegate,
                                        KayokoPanelPresentationControllerDelegate, KayokoSearchControllerDelegate,
                                        KayokoTableViewControllerDelegate>
@property(nonatomic, strong) KayokoView *panelView;
@property(nonatomic, copy, nullable) NSString *clearConfirmationHistoryKey;
@property(nonatomic, strong) KayokoHistoryController *historyController;
@property(nonatomic, strong) KayokoTableViewController *tableViewController;
@property(nonatomic, strong) KayokoPanelPresentationController *panelPresentationController;
@property(nonatomic, strong) KayokoClearConfirmationViewController *clearConfirmationViewController;
@property(nonatomic, strong) KayokoPreviewViewController *previewViewController;
@property(nonatomic, strong) KayokoSearchController *searchController;
@property(nonatomic, strong) KayokoWordSelectionViewController *wordSelectionViewController;
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
    self = [super init];
    if (self) {
        _panelView = [[KayokoView alloc] initWithFrame:frame];
        _historyController = [[KayokoHistoryController alloc] initWithHistoryTableView:[_panelView historyTableView]
                                                                    favoritesTableView:[_panelView favoritesTableView]
                                                                        emptyStateView:[_panelView emptyStateView]];
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

        _tableViewController = [[KayokoTableViewController alloc]
            initWithTableViews:@[ [_panelView historyTableView], [_panelView favoritesTableView] ]];
        [_tableViewController setDelegate:self];

        _clearConfirmationViewController =
            [[KayokoClearConfirmationViewController alloc] initWithView:[_panelView clearConfirmationView]];
        [_clearConfirmationViewController setDelegate:self];

        _previewViewController = [[KayokoPreviewViewController alloc] initWithPreviewView:[_panelView previewView]
                                                                          favoritesButton:[_panelView favoritesButton]
                                                                               backButton:[_panelView backButton]
                                                                              clearButton:[_panelView clearButton]];
        [_previewViewController setDelegate:self];

        _wordSelectionViewController =
            [[KayokoWordSelectionViewController alloc] initWithWordSelectionView:[[_panelView previewView] wordSelectionView]];
        [_wordSelectionViewController setSelectionChangedHandler:^{
          [weakSelf updatePreviewActionButtonState];
        }];

        _searchController = [[KayokoSearchController alloc] initWithContainerView:_panelView
                                                                       headerView:[_panelView headerView]
                                                                 historyTableView:[_panelView historyTableView]
                                                                favoritesTableView:[_panelView favoritesTableView]
                                                              panGestureRecognizer:[_panelPresentationController panGestureRecognizer]];
        [_searchController setDelegate:self];

    }
    return self;
}

- (UIView *)view {
    return [self panelView];
}

- (BOOL)isHidden {
    return [[self panelView] isHidden];
}

- (CGRect)frame {
    return [[self panelView] frame];
}

- (void)setFrame:(CGRect)frame {
    [[self panelView] setFrame:frame];
}

- (CGAffineTransform)transform {
    return [[self panelView] transform];
}

- (void)setTransform:(CGAffineTransform)transform {
    [[self panelView] setTransform:transform];
}

- (void)setNeedsLayout {
    [[self panelView] setNeedsLayout];
}

- (UIView *)superview {
    return [[self panelView] superview];
}

- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)style {
    [[self panelView] setOverrideUserInterfaceStyle:style];
}

- (void)setOutsideDismissOverlayView:(UIControl *)outsideDismissOverlayView {
    [[self panelPresentationController] setOutsideDismissOverlayView:outsideDismissOverlayView];
}

- (void)setDismissOnOutsideTouch:(BOOL)dismissOnOutsideTouch {
    _dismissOnOutsideTouch = dismissOnOutsideTouch;
    [[self panelPresentationController] setDismissOnOutsideTouch:dismissOnOutsideTouch];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    _previewLineCount = previewLineCount;
    [[[self panelView] historyTableView] setPreviewLineCount:previewLineCount];
    [[[self panelView] favoritesTableView] setPreviewLineCount:previewLineCount];
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

- (KayokoTableView *)activeTableViewForSearchController:(KayokoSearchController *)searchController {
    return [self activeTableView];
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

- (void)tableViewControllerDidRequestHide:(KayokoTableViewController *)controller {
    [self hide];
}

- (void)tableViewController:(KayokoTableViewController *)controller didRequestPreviewForItem:(PasteboardItem *)item {
    [self showPreviewWithItem:item];
}

- (void)tableViewController:(KayokoTableViewController *)controller
    didChangeContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility {
    [self updateContentStateMaintainingSearchBarVisibility:maintainsSearchBarVisibility];
}

- (void)tableViewController:(KayokoTableViewController *)controller
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
    return [[self historyController] contentViewForHistoryKey:historyKey];
}

- (UIView *)activeHistoryContentView {
    return [[self historyController] activeHistoryContentView];
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [[self panelView] clearConfirmationView]) {
        return [[[[self panelView] titleLabel] text] copy];
    }

    if (view == [[self panelView] previewView]) {
        return [[[self panelView] previewView] name];
    }

    return [[self historyController] titleForContentView:view];
}

- (void)setHistoryContentVisibleForKey:(NSString *)historyKey {
    UIView *contentView = [[self historyController] setHistoryContentVisibleForKey:historyKey];
    [[self searchController] attachToTableView:[self tableViewForHistoryKey:historyKey]
                                hidesSearchBar:![[self searchController] isSearchActive]];
    [[self searchController] refreshForTableView:[self activeTableView]];
    [[self panelView] setTitleText:[self titleForContentView:contentView]];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    [[self historyController] markHistoryKeyLoaded:historyKey];
}

- (void)updateActiveTableViewState:(KayokoTableView *)tableView {
    if (tableView == [self activeTableView]) {
        [[self searchController] refreshForTableView:tableView];
        [[self panelView] setClearButtonEnabledForTableView:tableView];
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

    [[self panelView] showContentView:[[self panelView] clearConfirmationView]
                 hideContentView:[self activeHistoryContentView]
                           title:[self titleForContentView:[[self panelView] clearConfirmationView]]
                         reverse:NO];
}

- (void)finishHidingClearConfirmationForHistoryKey:(NSString *)historyKey {
    [self setClearConfirmationHistoryKey:nil];
    [[[self panelView] clearButton] setHidden:NO];
    [[self panelView] setClearButtonEnabledForTableView:[self tableViewForHistoryKey:historyKey]];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [[self panelView] showContentView:contentView
                 hideContentView:[[self panelView] clearConfirmationView]
                           title:[self titleForContentView:contentView]
                         reverse:YES];
}

- (void)hideClearConfirmationWithReload:(BOOL)reload {
    if ([[[self panelView] clearConfirmationView] isHidden] || ![self clearConfirmationHistoryKey]) {
        return;
    }

    NSString *historyKey = [self clearConfirmationHistoryKey];
    if (reload) {
        [[self tableViewForHistoryKey:historyKey] clearItems];
        [self markHistoryKeyLoaded:historyKey];
        if ([[self effectiveActiveHistoryKey] isEqualToString:historyKey]) {
            [[self searchController] refreshForTableView:[self activeTableView]];
        }
    }
    [self finishHidingClearConfirmationForHistoryKey:historyKey];
}

- (void)resetClearConfirmationIfNeeded {
    if (![self clearConfirmationHistoryKey]) {
        return;
    }

    [[[self panelView] clearConfirmationView] setHidden:YES];
    [[[self panelView] clearConfirmationView] setAlpha:1];
    [[[self panelView] clearConfirmationView] setTransform:CGAffineTransformIdentity];
    [self setHistoryContentVisibleForKey:[self clearConfirmationHistoryKey]];
    [[[self panelView] clearButton] setHidden:NO];
    [self setClearConfirmationHistoryKey:nil];
    [self updateClearButtonState];
}

- (BOOL)isShowingClearConfirmation {
    return [self clearConfirmationHistoryKey] && ![[[self panelView] clearConfirmationView] isHidden];
}

- (void)updateClearButtonState {
    [[self panelView] setClearButtonEnabledForTableView:[self tableViewForHistoryKey:[self effectiveActiveHistoryKey]]];
}

- (void)updateContentState {
    [self updateContentStateMaintainingSearchBarVisibility:YES];
}

- (void)updateContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility {
    if (![self isShowingClearConfirmation] && [[[self panelView] previewView] isHidden]) {
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
        [[self searchController] maintainSearchBarVisibilityForTableView:[self activeTableView]];
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

    if (![[[self panelView] previewView] isHidden]) {
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
                              [[self searchController] attachToTableView:targetTableView
                                                           hidesSearchBar:![[self searchController] isSearchActive]];
                              [[self searchController] refreshForTableView:[self activeTableView]];
                              [[self panelView] setClearButtonEnabledForTableView:targetTableView];

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
    if ([[self panelPresentationController] isAnimating] || ![[[self panelView] previewView] isHidden] ||
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
                                 enablesWordSelection:[self swipeToSelectWords]
                                   automaticallyPaste:[self automaticallyPaste]];
}

- (void)hidePreview {
    if ([[[self panelView] previewView] isHidden] || [[self panelPresentationController] isAnimating]) {
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
        [[self searchController] refreshForTableView:[self activeTableView]];
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
                              if ([self isShowingClearConfirmation] || ![[[self panelView] previewView] isHidden]) {
                                  return;
                              }
                              [self setHistoryContentVisibleForKey:historyKey];
                              [[self searchController] refreshForTableView:[self activeTableView]];
                              [[self panelView] setClearButtonEnabledForTableView:tableView];
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

    [[[self panelView] historyTableView] setAutomaticallyPaste:[self automaticallyPaste]];
    [[[self panelView] favoritesTableView] setAutomaticallyPaste:[self automaticallyPaste]];

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
                              [[self searchController] attachToTableView:[self activeTableView] hidesSearchBar:YES];
                              [[self panelView] setClearButtonEnabledForTableView:tableView];
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
    [[self panelPresentationController] hidePanelWithCompletion:completion];
}

@end
