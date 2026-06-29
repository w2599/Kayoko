//
//  KayokoView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoView.h"
#import "KayokoClearConfirmationView.h"
#import "KayokoEmptyStateView.h"
#import "KayokoFavoritesTableView.h"
#import "KayokoHistoryTableView.h"
#import "KayokoPreviewView.h"
#import "KayokoWordSelectionView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"
#import <objc/runtime.h>

static CGFloat const kKayokoSearchHeaderHeight = 56;
static CGFloat const kKayokoAppTokenSuggestionRowHeight = 44;
static CGFloat const kKayokoAppTokenSuggestionMaximumHeight = 220;

@interface UIImage (KayokoPrivate)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleIdentifier
                                                  format:(int)format
                                                   scale:(CGFloat)scale;
@end

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@property(nonatomic, copy, readonly) NSString *displayName;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface KayokoView () <UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource>
- (void)hideWithCompletion:(void (^)(void))completion;
- (void)restorePreviewSourceAfterAction;
@end

@implementation KayokoView
{
    NSMutableSet<NSString *> *_loadedHistoryKeys;
    NSMutableSet<NSString *> *_dirtyHistoryKeys;
    NSUInteger _pendingLocalHistoryChangeNotificationCount;
    UISearchBar *_searchBar;
    UITableView *_appTokenSuggestionTableView;
    NSArray<NSDictionary *> *_appTokenSuggestionItems;
    CGRect _normalFrameBeforeSearch;
    BOOL _hasNormalFrameBeforeSearch;
    BOOL _isSearchActive;
    BOOL _isResettingSearch;
    CGFloat _keyboardBottomInset;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        _activeHistoryKey = kHistoryKeyHistory;
        _loadedHistoryKeys = [[NSMutableSet alloc] init];
        _dirtyHistoryKeys = [NSMutableSet setWithObjects:kHistoryKeyHistory, kHistoryKeyFavorites, nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleLocalHistoryChangeNotification:)
                                                     name:kPasteboardManagerHistoryDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillChangeFrameNotification:)
                                                     name:UIKeyboardWillChangeFrameNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleKeyboardWillHideNotification:)
                                                     name:UIKeyboardWillHideNotification
                                                   object:nil];

        [self hide];

        [[self layer] setShadowColor:[[UIColor blackColor] CGColor]];
        [[self layer] setShadowOffset:CGSizeMake(0, -4)];
        [[self layer] setShadowRadius:18];
        [[self layer] setShadowOpacity:0.18];

        [self setBlurEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        [self setBlurEffectView:[[UIVisualEffectView alloc] initWithEffect:[self blurEffect]]];
        [self addSubview:[self blurEffectView]];

        [[self blurEffectView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self blurEffectView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self blurEffectView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self blurEffectView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self blurEffectView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setHeaderView:[[UIView alloc] init]];
        [self addSubview:[self headerView]];

        [[self headerView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self headerView] heightAnchor] constraintEqualToConstant:60],
            [[[self headerView] topAnchor] constraintEqualToAnchor:[self topAnchor]],
            [[[self headerView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self headerView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]]
        ]];

        [self setPanGestureRecognizer:[[UIPanGestureRecognizer alloc]
                                          initWithTarget:self
                                                  action:@selector(handlePanGestureRecognizer:)]];
        [[self headerView] addGestureRecognizer:[self panGestureRecognizer]];

        [self setGrabber:[[_UIGrabber alloc] init]];
        [[self headerView] addSubview:[self grabber]];

        [[self grabber] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self grabber] topAnchor] constraintEqualToAnchor:[[self headerView] topAnchor] constant:12],
            [[[self grabber] centerXAnchor] constraintEqualToAnchor:[[self headerView] centerXAnchor]]
        ]];

        [self setFavoritesButton:[[UIButton alloc] init]];
        [[self favoritesButton] addTarget:self
                                   action:@selector(handleFavoritesButtonPressed)
                         forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self favoritesButton]];

        [[self favoritesButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesButton] bottomAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                                  constant:-2],
            [[[self favoritesButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                                   constant:kLeadingHeaderButtonCenterXInset]
        ]];

        [self setTitleLabel:[[UILabel alloc] init]];
        [[self titleLabel] setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"History"
                                                                                           value:nil
                                                                                           table:@"Tweak"]];
        [[self titleLabel] setFont:[UIFont systemFontOfSize:26 weight:UIFontWeightSemibold]];
        [[self titleLabel] setTextColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self titleLabel]];

        [[self titleLabel] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self titleLabel] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self titleLabel] leadingAnchor] constraintEqualToAnchor:[[self headerView] leadingAnchor]
                                                              constant:kTitleLabelLeadingInset]
        ]];

        [self setClearButton:[[UIButton alloc] init]];
        [[self clearButton] addTarget:self
                               action:@selector(handleClearButtonPressed)
                     forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self clearButton]
                           withImageName:@"trash"
                            andImageSize:kClearButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self clearButton]];
        [[self clearButton] setHidden:NO];

        [[self clearButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self clearButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                               constant:-kTrailingHeaderButtonCenterXInset]
        ]];

        [self setBackButton:[[UIButton alloc] init]];
        [[self backButton] addTarget:self
                              action:@selector(handlePreviewActionButtonPressed)
                    forControlEvents:UIControlEventTouchUpInside];
        [self updateStyleForHeaderButton:[self backButton]
                           withImageName:@"arrowshape.turn.up.backward"
                            andImageSize:kBackButtonImageSize
                            andTintColor:[UIColor labelColor]];
        [[self headerView] addSubview:[self backButton]];
        [[self backButton] setHidden:YES];

        [[self backButton] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self backButton] centerYAnchor] constraintEqualToAnchor:[[self favoritesButton] centerYAnchor]],
            [[[self backButton] centerXAnchor] constraintEqualToAnchor:[[self headerView] trailingAnchor]
                                                              constant:-kTrailingHeaderButtonCenterXInset]
        ]];

        [self setHistoryTableView:[[KayokoHistoryTableView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                                                   localizedStringForKey:@"History"
                                                                                                   value:nil
                                                                                                   table:@"Tweak"]]];
        [self addSubview:[self historyTableView]];

        [[self historyTableView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self historyTableView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self historyTableView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self historyTableView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self historyTableView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self
            setFavoritesTableView:[[KayokoFavoritesTableView alloc] initWithName:[[PasteboardManager localizationBundle]
                                                                                     localizedStringForKey:@"Favorites"
                                                                                                     value:nil
                                                                                                     table:@"Tweak"]]];
        [[self favoritesTableView] setHistoryKey:kHistoryKeyFavorites];
        [[self favoritesTableView] setHidden:YES];
        [self addSubview:[self favoritesTableView]];

        [[self favoritesTableView] reloadDataWithItems:nil];

        [[self favoritesTableView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self favoritesTableView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self favoritesTableView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self favoritesTableView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self favoritesTableView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setClearConfirmationView:[[KayokoClearConfirmationView alloc] init]];
        [[self clearConfirmationView] setHidden:YES];
        [self addSubview:[self clearConfirmationView]];

        [[self clearConfirmationView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self clearConfirmationView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor]
                                                                     constant:8],
            [[[self clearConfirmationView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self clearConfirmationView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self clearConfirmationView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [[[self clearConfirmationView] cancelButton] addTarget:self
                                                        action:@selector(handleClearConfirmationCancelButtonPressed)
                                              forControlEvents:UIControlEventTouchUpInside];
        [[[self clearConfirmationView] confirmButton] addTarget:self
                                                         action:@selector(handleClearConfirmationConfirmButtonPressed)
                                               forControlEvents:UIControlEventTouchUpInside];

        [self setEmptyStateView:[[KayokoEmptyStateView alloc] init]];
        [[self emptyStateView] setHidden:YES];
        [self addSubview:[self emptyStateView]];

        [[self emptyStateView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self emptyStateView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self emptyStateView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self emptyStateView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self emptyStateView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        [self setPreviewView:[[KayokoPreviewView alloc]
                                 initWithName:[[PasteboardManager localizationBundle] localizedStringForKey:@"Preview"
                                                                                                      value:nil
                                                                                                      table:@"Tweak"]]];
        __weak typeof(self) weakSelf = self;
        [[[self previewView] wordSelectionView] setSelectionChangedHandler:^{
          [weakSelf updatePreviewActionButtonState];
        }];
        [[self previewView] setHidden:YES];
        [self addSubview:[self previewView]];

        [[self previewView] setTranslatesAutoresizingMaskIntoConstraints:NO];
        [NSLayoutConstraint activateConstraints:@[
            [[[self previewView] topAnchor] constraintEqualToAnchor:[[self headerView] bottomAnchor] constant:8],
            [[[self previewView] leadingAnchor] constraintEqualToAnchor:[self leadingAnchor]],
            [[[self previewView] trailingAnchor] constraintEqualToAnchor:[self trailingAnchor]],
            [[[self previewView] bottomAnchor] constraintEqualToAnchor:[self bottomAnchor]]
        ]];

        _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth([self bounds]),
                                                                   kKayokoSearchHeaderHeight)];
        [_searchBar setDelegate:self];
        [_searchBar setPlaceholder:[[PasteboardManager localizationBundle] localizedStringForKey:@"Search"
                                                                                           value:nil
                                                                                           table:@"Tweak"]];
        [_searchBar setSearchBarStyle:UISearchBarStyleMinimal];
        [_searchBar setBackgroundImage:[[UIImage alloc] init]];
        if (@available(iOS 13.0, *)) {
            [[_searchBar searchTextField] addTarget:self
                                             action:@selector(handleSearchTextFieldEditingChanged)
                                   forControlEvents:UIControlEventEditingChanged];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(handleSearchTextFieldTextDidChangeNotification:)
                                                         name:UITextFieldTextDidChangeNotification
                                                       object:[_searchBar searchTextField]];
        }
        [self attachSearchBarToTableView:[self historyTableView] hidesSearchBar:YES];

        _appTokenSuggestionItems = @[];
        _appTokenSuggestionTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        [_appTokenSuggestionTableView setDelegate:self];
        [_appTokenSuggestionTableView setDataSource:self];
        [_appTokenSuggestionTableView setRowHeight:kKayokoAppTokenSuggestionRowHeight];
        [_appTokenSuggestionTableView setBackgroundColor:[UIColor clearColor]];
        [_appTokenSuggestionTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [_appTokenSuggestionTableView setHidden:YES];
        [_appTokenSuggestionTableView setClipsToBounds:YES];
        [[_appTokenSuggestionTableView layer] setCornerRadius:12];
        [self addSubview:_appTokenSuggestionTableView];
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    [self layoutSearchBarForTableView:[self historyTableView]];
    [self layoutSearchBarForTableView:[self favoritesTableView]];
    [self layoutAppTokenSuggestionTableView];
}

- (KayokoTableView *)activeTableView {
    return [self tableViewForHistoryKey:[self activeHistoryKey]];
}

- (CGFloat)searchHeaderHeight {
    return CGRectGetHeight([_searchBar frame]) ?: kKayokoSearchHeaderHeight;
}

- (void)layoutSearchBarForTableView:(KayokoTableView *)tableView {
    if ([tableView tableHeaderView] != _searchBar) {
        return;
    }

    CGFloat width = CGRectGetWidth([tableView bounds]);
    CGRect frame = CGRectMake(0, 0, width, kKayokoSearchHeaderHeight);
    if (!CGRectEqualToRect([_searchBar frame], frame)) {
        [_searchBar setFrame:frame];
        [tableView setTableHeaderView:_searchBar];
    }
}

- (void)attachSearchBarToTableView:(KayokoTableView *)tableView hidesSearchBar:(BOOL)hidesSearchBar {
    if (!tableView || [tableView tableHeaderView] == _searchBar) {
        if (hidesSearchBar && !_isSearchActive) {
            [self hideSearchBarInTableView:tableView animated:NO];
        }
        return;
    }

    [[self historyTableView] setTableHeaderView:nil];
    [[self favoritesTableView] setTableHeaderView:nil];
    [_searchBar setFrame:CGRectMake(0, 0, CGRectGetWidth([tableView bounds]), kKayokoSearchHeaderHeight)];
    [tableView setTableHeaderView:_searchBar];
    if (hidesSearchBar && !_isSearchActive) {
        [self hideSearchBarInTableView:tableView animated:NO];
    }
}

- (void)hideSearchBarInTableView:(KayokoTableView *)tableView animated:(BOOL)animated {
    if (!tableView || [tableView tableHeaderView] != _searchBar || _isSearchActive) {
        return;
    }

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = [self searchHeaderHeight];
    [tableView setContentOffset:contentOffset animated:animated];
}

- (void)revealSearchBarInTableView:(KayokoTableView *)tableView animated:(BOOL)animated {
    if (!tableView || [tableView tableHeaderView] != _searchBar) {
        return;
    }

    CGPoint contentOffset = [tableView contentOffset];
    contentOffset.y = 0;
    [tableView setContentOffset:contentOffset animated:animated];
}

- (NSString *)displayNameForBundleIdentifier:(NSString *)bundleIdentifier {
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        return [[PasteboardManager localizationBundle] localizedStringForKey:@"SpringBoard" value:nil table:@"Tweak"];
    }

    NSString *displayName = [[[objc_getClass("SBApplicationController") sharedInstance]
        applicationWithBundleIdentifier:bundleIdentifier] displayName];
    return [displayName length] > 0 ? displayName : bundleIdentifier;
}

- (UIImage *)iconForBundleIdentifier:(NSString *)bundleIdentifier {
    UIImage *icon = nil;
    if ([bundleIdentifier isEqualToString:@"com.apple.springboard"]) {
        BOOL isPad = [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad;
        icon = [UIImage imageNamed:isPad ? @"HLS_iPad_Universal" : @"HLS_iPhone_Universal"
                           inBundle:[PasteboardManager localizationBundle]
      compatibleWithTraitCollection:nil];
    } else {
        icon = [UIImage _applicationIconImageForBundleIdentifier:bundleIdentifier
                                                          format:2
                                                           scale:[[UIScreen mainScreen] scale]];
    }
    if (!icon) {
        icon = [UIImage _applicationIconImageForBundleIdentifier:@"com.apple.WebSheet"
                                                          format:2
                                                           scale:[[UIScreen mainScreen] scale]];
    }
    return icon;
}

- (NSArray<NSDictionary *> *)appTokenItemsForTableView:(KayokoTableView *)tableView {
    NSMutableArray *items = [[NSMutableArray alloc] init];
    for (NSDictionary *tokenItem in [tableView availableAppTokenItems]) {
        NSString *bundleIdentifier = tokenItem[@"bundleIdentifier"];
        if ([bundleIdentifier length] == 0) {
            continue;
        }

        UIImage *icon = [self iconForBundleIdentifier:bundleIdentifier];
        NSMutableDictionary *item = [@{
            @"bundleIdentifier" : bundleIdentifier,
            @"displayName" : [self displayNameForBundleIdentifier:bundleIdentifier]
        } mutableCopy];
        if (icon) {
            item[@"icon"] = icon;
        }
        [items addObject:item];
    }
    return items;
}

- (NSArray<NSString *> *)selectedSearchBundleIdentifiers {
    if (@available(iOS 13.0, *)) {
        NSMutableArray *bundleIdentifiers = [[NSMutableArray alloc] init];
        for (UISearchToken *token in [[_searchBar searchTextField] tokens]) {
            NSString *bundleIdentifier = [token representedObject];
            if ([bundleIdentifier length] > 0 && ![bundleIdentifiers containsObject:bundleIdentifier]) {
                [bundleIdentifiers addObject:bundleIdentifier];
            }
        }
        return bundleIdentifiers;
    }
    return @[];
}

- (NSArray<NSDictionary *> *)unselectedAppTokenSuggestionItemsForTableView:(KayokoTableView *)tableView {
    NSArray<NSString *> *selectedBundleIdentifiers = [self selectedSearchBundleIdentifiers];
    NSMutableArray *suggestionItems = [[NSMutableArray alloc] init];
    for (NSDictionary *item in [self appTokenItemsForTableView:tableView]) {
        NSString *bundleIdentifier = item[@"bundleIdentifier"];
        if (![selectedBundleIdentifiers containsObject:bundleIdentifier]) {
            [suggestionItems addObject:item];
        }
    }
    return suggestionItems;
}

- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                forTableView:(KayokoTableView *)tableView {
    if (@available(iOS 13.0, *)) {
        NSMutableDictionary *itemsByBundleIdentifier = [[NSMutableDictionary alloc] init];
        for (NSDictionary *item in [self appTokenItemsForTableView:tableView]) {
            NSString *bundleIdentifier = item[@"bundleIdentifier"];
            if ([bundleIdentifier length] > 0) {
                itemsByBundleIdentifier[bundleIdentifier] = item;
            }
        }

        NSMutableArray<UISearchToken *> *tokens = [[NSMutableArray alloc] init];
        for (NSString *bundleIdentifier in bundleIdentifiers) {
            NSDictionary *item = itemsByBundleIdentifier[bundleIdentifier];
            if (!item) {
                continue;
            }

            UISearchToken *token = [UISearchToken tokenWithIcon:item[@"icon"] text:item[@"displayName"]];
            [token setRepresentedObject:bundleIdentifier];
            [tokens addObject:token];
        }
        [[_searchBar searchTextField] setTokens:tokens];
    }
}

- (void)applySearchToActiveTableView {
    KayokoTableView *tableView = [self activeTableView];
    NSArray<NSString *> *selectedBundleIdentifiers = [self selectedSearchBundleIdentifiers];
    [tableView applySearchText:[_searchBar text] selectedBundleIdentifiers:selectedBundleIdentifiers];

    NSArray<NSString *> *validBundleIdentifiers = [tableView selectedBundleIdentifiers] ?: @[];
    if (![validBundleIdentifiers isEqualToArray:selectedBundleIdentifiers]) {
        [self setSearchTokensWithBundleIdentifiers:validBundleIdentifiers forTableView:tableView];
    }

    [self refreshAppTokenSuggestions];
}

- (void)refreshSearchForActiveTableView {
    KayokoTableView *tableView = [self activeTableView];
    [self attachSearchBarToTableView:tableView hidesSearchBar:!_isSearchActive];
    [self setSearchTokensWithBundleIdentifiers:[self selectedSearchBundleIdentifiers] forTableView:tableView];
    [self applySearchToActiveTableView];
}

- (void)refreshAppTokenSuggestions {
    KayokoTableView *tableView = [self activeTableView];
    _appTokenSuggestionItems = [self unselectedAppTokenSuggestionItemsForTableView:tableView];
    [_appTokenSuggestionTableView reloadData];
    [self layoutAppTokenSuggestionTableView];
    [_appTokenSuggestionTableView setHidden:!_isSearchActive || [_appTokenSuggestionItems count] == 0];
}

- (void)layoutAppTokenSuggestionTableView {
    CGFloat height = MIN([_appTokenSuggestionItems count] * kKayokoAppTokenSuggestionRowHeight,
                         kKayokoAppTokenSuggestionMaximumHeight);
    if (height <= 0 || !_isSearchActive) {
        [_appTokenSuggestionTableView setFrame:CGRectZero];
        return;
    }

    CGFloat y = CGRectGetMaxY([[self headerView] frame]) + 8 + [self searchHeaderHeight];
    CGRect frame = CGRectMake(16, y, MAX(CGRectGetWidth([self bounds]) - 32, 0), height);
    [_appTokenSuggestionTableView setFrame:frame];
    [self bringSubviewToFront:_appTokenSuggestionTableView];
}

- (void)beginSearchIfNeeded {
    if (_isSearchActive || _isAnimating) {
        return;
    }

    _isSearchActive = YES;
    _normalFrameBeforeSearch = [self frame];
    _hasNormalFrameBeforeSearch = YES;
    [[self panGestureRecognizer] setEnabled:NO];
    [_searchBar setShowsCancelButton:YES animated:YES];
    [self revealSearchBarInTableView:[self activeTableView] animated:YES];
    [self refreshAppTokenSuggestions];

    UIView *superview = [self superview];
    if (!superview) {
        return;
    }

    CGRect bounds = [superview bounds];
    CGRect safeBounds = UIEdgeInsetsInsetRect(bounds, [superview safeAreaInsets]);
    _isAnimating = YES;
    [UIView animateWithDuration:0.28
        delay:0
        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
        animations:^{
          [self setTransform:CGAffineTransformIdentity];
          [self setFrame:safeBounds];
          [self setNeedsLayout];
          [self layoutIfNeeded];
        }
        completion:^(__unused BOOL finished) {
          _isAnimating = NO;
          [self finishOutsideDismissOverlayShow];
        }];
}

- (void)endSearchRestoringFrame:(BOOL)restoresFrame clearsSearch:(BOOL)clearsSearch {
    if (!_isSearchActive && !clearsSearch) {
        return;
    }

    _isResettingSearch = YES;
    _isSearchActive = NO;
    [_searchBar resignFirstResponder];
    [_searchBar setShowsCancelButton:NO animated:YES];
    if (clearsSearch) {
        [_searchBar setText:@""];
        [self setSearchTokensWithBundleIdentifiers:@[] forTableView:[self activeTableView]];
    }
    _keyboardBottomInset = 0;
    [self applyKeyboardBottomInsetToTableViews];
    [self applySearchToActiveTableView];
    [_appTokenSuggestionTableView setHidden:YES];
    [[self panGestureRecognizer] setEnabled:YES];

    CGRect targetFrame = _hasNormalFrameBeforeSearch ? _normalFrameBeforeSearch : [self frame];
    _hasNormalFrameBeforeSearch = NO;
    _isResettingSearch = NO;

    if (restoresFrame && !CGRectEqualToRect([self frame], targetFrame)) {
        _isAnimating = YES;
        [UIView animateWithDuration:0.28
            delay:0
            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
            animations:^{
              [self setFrame:targetFrame];
              [self setNeedsLayout];
              [self layoutIfNeeded];
            }
            completion:^(__unused BOOL finished) {
              _isAnimating = NO;
              [self hideSearchBarInTableView:[self activeTableView] animated:YES];
              [self finishOutsideDismissOverlayShow];
            }];
    } else {
        [self setFrame:targetFrame];
        [self hideSearchBarInTableView:[self activeTableView] animated:NO];
    }
}

- (void)resetSearchBeforeHide {
    if (!_isSearchActive && [[_searchBar text] length] == 0 && [[self selectedSearchBundleIdentifiers] count] == 0) {
        return;
    }

    [self endSearchRestoringFrame:NO clearsSearch:YES];
}

- (void)applyKeyboardBottomInsetToTableView:(KayokoTableView *)tableView {
    UIEdgeInsets contentInset = [tableView contentInset];
    contentInset.bottom = _keyboardBottomInset;
    [tableView setContentInset:contentInset];

    UIEdgeInsets indicatorInsets = UIEdgeInsetsMake(0, 0, _keyboardBottomInset, 0);
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

- (void)handleKeyboardWillChangeFrameNotification:(NSNotification *)notification {
    if (!_isSearchActive) {
        return;
    }

    CGRect keyboardEndFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardFrameInView = [self convertRect:keyboardEndFrame fromView:nil];
    _keyboardBottomInset = MAX(CGRectGetMaxY([self bounds]) - CGRectGetMinY(keyboardFrameInView), 0);
    [self applyKeyboardBottomInsetToTableViews];
}

- (void)handleKeyboardWillHideNotification:(NSNotification *)notification {
    if (!_isSearchActive) {
        return;
    }

    _keyboardBottomInset = 0;
    [self applyKeyboardBottomInsetToTableViews];
}

- (void)handleSearchTextFieldEditingChanged {
    if (_isResettingSearch) {
        return;
    }
    [self applySearchToActiveTableView];
}

- (void)handleSearchTextFieldTextDidChangeNotification:(NSNotification *)notification {
    if (_isResettingSearch) {
        return;
    }
    [self applySearchToActiveTableView];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [self beginSearchIfNeeded];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (_isResettingSearch) {
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView != _appTokenSuggestionTableView) {
        return 0;
    }
    return [_appTokenSuggestionItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KayokoAppTokenSuggestionCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"KayokoAppTokenSuggestionCell"];
        [cell setBackgroundColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
          if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
              return [UIColor colorWithWhite:0.12 alpha:0.92];
          }
          return [UIColor colorWithWhite:1 alpha:0.94];
        }]];
        [[cell textLabel] setFont:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium]];
        [[cell imageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[[cell imageView] layer] setCornerRadius:6];
        [[cell imageView] setClipsToBounds:YES];
    }

    NSDictionary *item = _appTokenSuggestionItems[[indexPath row]];
    [[cell textLabel] setText:item[@"displayName"]];
    [[cell imageView] setImage:item[@"icon"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != _appTokenSuggestionTableView) {
        return;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = _appTokenSuggestionItems[[indexPath row]];
    NSString *bundleIdentifier = item[@"bundleIdentifier"];
    if ([bundleIdentifier length] == 0) {
        return;
    }

    if (@available(iOS 13.0, *)) {
        NSMutableArray *bundleIdentifiers = [[self selectedSearchBundleIdentifiers] mutableCopy];
        if (![bundleIdentifiers containsObject:bundleIdentifier]) {
            [bundleIdentifiers addObject:bundleIdentifier];
        }
        [self setSearchTokensWithBundleIdentifiers:bundleIdentifiers forTableView:[self activeTableView]];
        [self applySearchToActiveTableView];
        [_searchBar becomeFirstResponder];
    }
}

- (void)setOutsideDismissOverlayView:(UIControl *)outsideDismissOverlayView {
    if (_outsideDismissOverlayView == outsideDismissOverlayView) {
        return;
    }

    [_outsideDismissOverlayView removeTarget:self
                                      action:@selector(handleOutsideDismissOverlayTouchDown)
                            forControlEvents:UIControlEventTouchDown];

    _outsideDismissOverlayView = outsideDismissOverlayView;
    [_outsideDismissOverlayView addTarget:self
                                   action:@selector(handleOutsideDismissOverlayTouchDown)
                         forControlEvents:UIControlEventTouchDown];
    if ([self dismissOnOutsideTouch] && ![self isHidden]) {
        [self prepareOutsideDismissOverlayForShow];
        [[self outsideDismissOverlayView] setAlpha:1.0];
        [self finishOutsideDismissOverlayShow];
    } else {
        [self hideOutsideDismissOverlay];
    }
}

- (void)setDismissOnOutsideTouch:(BOOL)dismissOnOutsideTouch {
    _dismissOnOutsideTouch = dismissOnOutsideTouch;
    if (dismissOnOutsideTouch && ![self isHidden]) {
        [self prepareOutsideDismissOverlayForShow];
        [[self outsideDismissOverlayView] setAlpha:1.0];
        [self finishOutsideDismissOverlayShow];
    } else {
        [self hideOutsideDismissOverlay];
    }
}

- (void)handleOutsideDismissOverlayTouchDown {
    if ([self dismissOnOutsideTouch] && ![self isHidden]) {
        [self hide];
    }
}

- (void)layoutOutsideDismissOverlayView {
    UIView *superview = [[self outsideDismissOverlayView] superview];
    if (!superview) {
        return;
    }

    [[self outsideDismissOverlayView] setFrame:[superview bounds]];
}

- (void)prepareOutsideDismissOverlayForShow {
    UIControl *overlayView = [self outsideDismissOverlayView];
    if (!overlayView || ![self dismissOnOutsideTouch]) {
        return;
    }

    [self layoutOutsideDismissOverlayView];
    [overlayView setHidden:NO];
    [overlayView setUserInteractionEnabled:NO];
    [overlayView setAlpha:0];
    [[self superview] bringSubviewToFront:overlayView];
    [[self superview] bringSubviewToFront:self];
}

- (void)finishOutsideDismissOverlayShow {
    BOOL enabled = [self dismissOnOutsideTouch] && ![self isHidden] && !_isAnimating;
    [[self outsideDismissOverlayView] setUserInteractionEnabled:enabled];
}

- (void)hideOutsideDismissOverlay {
    [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    [[self outsideDismissOverlayView] setAlpha:0];
    [[self outsideDismissOverlayView] setHidden:YES];
}

- (void)handlePanGestureRecognizer:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:self];
    CGFloat const kFadeOutDistance = 100;

    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        _panGestureDidReachZeroAlpha = NO;
        [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    } else if ([recognizer state] == UIGestureRecognizerStateChanged) {
        [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];

        if (translation.y < 0 && !_panGestureDidReachZeroAlpha) {
            return;
        }

        CGFloat fadeProgress = MIN(MAX(translation.y / kFadeOutDistance, 0), 1);
        if (_panGestureDidReachZeroAlpha || fadeProgress >= 1) {
            _panGestureDidReachZeroAlpha = YES;
            fadeProgress = 1;
            translation.y = MAX(translation.y, kFadeOutDistance);
        }

        [UIView animateWithDuration:0.1
                              delay:0
             usingSpringWithDamping:0.7
              initialSpringVelocity:0
                            options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                           [self setTransform:CGAffineTransformMakeTranslation(0, translation.y)];
                           [self setAlpha:1 - fadeProgress];
                         }
                         completion:nil];
    } else if ([recognizer state] == UIGestureRecognizerStateEnded ||
               [recognizer state] == UIGestureRecognizerStateCancelled ||
               [recognizer state] == UIGestureRecognizerStateFailed) {
        if (!_panGestureDidReachZeroAlpha) {
            [UIView animateWithDuration:0.4
                delay:0
                usingSpringWithDamping:1
                initialSpringVelocity:0
                options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState
                animations:^{
                  [self setTransform:CGAffineTransformIdentity];
                  [self setAlpha:1];
                }
                completion:^(BOOL finished) {
                  [self finishOutsideDismissOverlayShow];
                }];
        } else {
            [self hide];
        }
    }
}

- (void)updateStyleForHeaderButton:(UIButton *)button
                     withImageName:(NSString *)imageName
                      andImageSize:(NSUInteger)imageSize
                      andTintColor:(UIColor *)color {
    UIImageSymbolConfiguration *configuration =
        [UIImageSymbolConfiguration configurationWithPointSize:imageSize weight:UIImageSymbolWeightMedium];
    UIImage *image = [UIImage systemImageNamed:imageName];
    if (!image) {
        image = [UIImage systemImageNamed:@"doc.on.doc"];
    }
    [button setImage:[image imageWithConfiguration:configuration] forState:UIControlStateNormal];
    [button setTintColor:color];
}

- (NSString *)activeHistoryKey {
    if (_clearConfirmationHistoryKey) {
        return _clearConfirmationHistoryKey;
    }

    return _activeHistoryKey ?: kHistoryKeyHistory;
}

- (KayokoTableView *)tableViewForHistoryKey:(NSString *)key {
    return [key isEqualToString:kHistoryKeyFavorites] ? [self favoritesTableView] : [self historyTableView];
}

- (UIView *)contentViewForHistoryKey:(NSString *)key {
    KayokoTableView *tableView = [self tableViewForHistoryKey:key];
    if ([[tableView items] count] > 0) {
        return tableView;
    }

    [[self emptyStateView] updateWithHistoryKey:key];
    return [self emptyStateView];
}

- (UIView *)activeHistoryContentView {
    if (![[self historyTableView] isHidden]) {
        return [self historyTableView];
    }

    if (![[self favoritesTableView] isHidden]) {
        return [self favoritesTableView];
    }

    return [self emptyStateView];
}

- (void)setHistoryContentVisibleForKey:(NSString *)key {
    _activeHistoryKey = key;
    UIView *contentView = [self contentViewForHistoryKey:key];
    [self attachSearchBarToTableView:[self tableViewForHistoryKey:key] hidesSearchBar:!_isSearchActive];
    [self refreshSearchForActiveTableView];
    [[self historyTableView] setHidden:contentView != [self historyTableView]];
    [[self favoritesTableView] setHidden:contentView != [self favoritesTableView]];
    [[self emptyStateView] setHidden:contentView != [self emptyStateView]];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];
    [[self titleLabel] setText:[self titleForContentView:contentView]];
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [self clearConfirmationView]) {
        return [[self titleLabel] text];
    }

    if ([view respondsToSelector:@selector(name)]) {
        return [view valueForKey:@"name"];
    }

    return nil;
}

- (void)updateClearConfirmationTextForHistoryKey:(NSString *)key {
    [[self clearConfirmationView] updateWithHistoryKey:key];
}

- (BOOL)hasLoadedHistoryKey:(NSString *)key {
    return [_loadedHistoryKeys containsObject:key];
}

- (BOOL)needsReloadForHistoryKey:(NSString *)key {
    return ![self hasLoadedHistoryKey:key] || [_dirtyHistoryKeys containsObject:key];
}

- (void)markHistoryKeyLoaded:(NSString *)key {
    if ([key length] == 0) {
        return;
    }
    [_loadedHistoryKeys addObject:key];
    [_dirtyHistoryKeys removeObject:key];
}

- (void)markHistoryKeyDirty:(NSString *)key {
    if ([key length] == 0) {
        return;
    }
    [_dirtyHistoryKeys addObject:key];
}

- (void)markAllHistoryKeysDirty {
    [self markHistoryKeyDirty:kHistoryKeyHistory];
    [self markHistoryKeyDirty:kHistoryKeyFavorites];
}

- (NSUInteger)limitForHistoryKey:(NSString *)key {
    if ([key isEqualToString:kHistoryKeyFavorites]) {
        return NSUIntegerMax;
    }
    return [[PasteboardManager sharedInstance] maximumHistoryAmount];
}

- (void)updateCachedTableViewForHistoryKey:(NSString *)key
                                changeType:(NSString *)changeType
                            itemDictionary:(NSDictionary *)dictionary
                                     limit:(NSUInteger)limit {
    KayokoTableView *tableView = [self tableViewForHistoryKey:key];
    if (![self hasLoadedHistoryKey:key]) {
        [self markHistoryKeyDirty:key];
        if (![self isHidden] && [[self activeHistoryKey] isEqualToString:key]) {
            [self reload];
        }
        return;
    }

    if ([changeType isEqualToString:kPasteboardManagerHistoryChangeTypeClear]) {
        [tableView clearItems];
    } else if ([changeType isEqualToString:kPasteboardManagerHistoryChangeTypeUpsertTop]) {
        [tableView upsertItemDictionaryAtTop:dictionary limit:(limit ?: [self limitForHistoryKey:key])];
    } else if ([changeType isEqualToString:kPasteboardManagerHistoryChangeTypeRemove]) {
        [tableView removeItemDictionary:dictionary];
    } else {
        [self markHistoryKeyDirty:key];
        return;
    }

    [self markHistoryKeyLoaded:key];
    if ([[self activeHistoryKey] isEqualToString:key]) {
        [self refreshSearchForActiveTableView];
        [self updateClearButtonStateForTableView:tableView];
    }
}

- (void)handleLocalHistoryChangeNotification:(NSNotification *)notification {
    _pendingLocalHistoryChangeNotificationCount++;
    NSDictionary *userInfo = [notification userInfo];
    NSString *key = userInfo[kPasteboardManagerHistoryChangeHistoryKeyKey];
    NSString *changeType = userInfo[kPasteboardManagerHistoryChangeTypeKey] ?: kPasteboardManagerHistoryChangeTypeReload;
    NSDictionary *dictionary = userInfo[kPasteboardManagerHistoryChangeItemKey];
    NSUInteger limit = [userInfo[kPasteboardManagerHistoryChangeLimitKey] unsignedIntegerValue];

    if ([key length] == 0 || [changeType isEqualToString:kPasteboardManagerHistoryChangeTypeReload]) {
        [self markAllHistoryKeysDirty];
        if (![self isHidden]) {
            [self reload];
        }
        return;
    }

    [self updateCachedTableViewForHistoryKey:key changeType:changeType itemDictionary:dictionary limit:limit];
}

- (void)handleHistoryChanged {
    if (_pendingLocalHistoryChangeNotificationCount > 0) {
        _pendingLocalHistoryChangeNotificationCount--;
        return;
    }

    [self markAllHistoryKeysDirty];
    if (![self isHidden]) {
        [self reload];
    }
}

- (void)reloadTableViewForHistoryKey:(NSString *)key
              animatingTopInsertions:(BOOL)animatingTopInsertions
                          completion:(void (^)(KayokoTableView *tableView))completion {
    KayokoTableView *tableView = [self tableViewForHistoryKey:key];
    if (![self needsReloadForHistoryKey:key]) {
        if (completion) {
            completion(tableView);
        }
        return;
    }

    [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:key
                                                        completion:^(NSMutableArray *items) {
                                                          [tableView updateDataWithItems:items
                                                                  animatingTopInsertions:animatingTopInsertions];
                                                          [self markHistoryKeyLoaded:key];
                                                          if ([[self activeHistoryKey] isEqualToString:key]) {
                                                              [self refreshSearchForActiveTableView];
                                                          }
                                                          if (completion) {
                                                              completion(tableView);
                                                          }
                                                        }];
}

- (void)reloadTableViewForHistoryKey:(NSString *)key completion:(void (^)(KayokoTableView *tableView))completion {
    [self reloadTableViewForHistoryKey:key animatingTopInsertions:NO completion:completion];
}

- (void)showClearConfirmationForHistoryKey:(NSString *)key {
    _activeHistoryKey = key;
    _clearConfirmationHistoryKey = key;
    [self updateClearConfirmationTextForHistoryKey:key];
    [[self clearButton] setHidden:YES];
    [[[self clearConfirmationView] cancelButton] setEnabled:YES];
    [[[self clearConfirmationView] confirmButton] setEnabled:YES];

    [self showContentView:[self clearConfirmationView] andHideContentView:[self activeHistoryContentView] reverse:NO];
}

- (void)finishHidingClearConfirmationForHistoryKey:(NSString *)key {
    _clearConfirmationHistoryKey = nil;
    [[self clearButton] setHidden:NO];
    [self updateClearButtonStateForTableView:[self tableViewForHistoryKey:key]];
    [self showContentView:[self contentViewForHistoryKey:key]
        andHideContentView:[self clearConfirmationView]
                   reverse:YES];
}

- (void)hideClearConfirmationWithReload:(BOOL)reload {
    if ([[self clearConfirmationView] isHidden] || !_clearConfirmationHistoryKey) {
        return;
    }

    NSString *key = _clearConfirmationHistoryKey;
    if (reload) {
        [[self tableViewForHistoryKey:key] clearItems];
        [self markHistoryKeyLoaded:key];
        if ([[self activeHistoryKey] isEqualToString:key]) {
            [self refreshSearchForActiveTableView];
        }
        [self finishHidingClearConfirmationForHistoryKey:key];
        return;
    }

    [self finishHidingClearConfirmationForHistoryKey:key];
}

- (void)resetClearConfirmationIfNeeded {
    if (!_clearConfirmationHistoryKey) {
        return;
    }

    [[self clearConfirmationView] setHidden:YES];
    [[self clearConfirmationView] setAlpha:1];
    [[self clearConfirmationView] setTransform:CGAffineTransformIdentity];
    [self setHistoryContentVisibleForKey:_clearConfirmationHistoryKey];
    [[self clearButton] setHidden:NO];
    _clearConfirmationHistoryKey = nil;
    [self updateClearButtonState];
}

- (BOOL)isShowingClearConfirmation {
    return _clearConfirmationHistoryKey && ![[self clearConfirmationView] isHidden];
}

- (void)updateClearButtonState {
    KayokoTableView *tableView = [self tableViewForHistoryKey:[self activeHistoryKey]];
    [self updateClearButtonStateForTableView:tableView];
}

- (void)updateClearButtonStateForTableView:(KayokoTableView *)tableView {
    BOOL enabled = [[tableView items] count] > 0;
    [[self clearButton] setEnabled:enabled];
    [[self clearButton] setAlpha:enabled ? 1.0 : 0.35];
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    _previewLineCount = previewLineCount;
    [[self historyTableView] setPreviewLineCount:previewLineCount];
    [[self favoritesTableView] setPreviewLineCount:previewLineCount];
}

- (void)updateContentState {
    if (![self isShowingClearConfirmation] && [[self previewView] isHidden]) {
        UIView *viewToHide = [self activeHistoryContentView];
        UIView *viewToShow = [self contentViewForHistoryKey:[self activeHistoryKey]];

        if (viewToShow != viewToHide) {
            [self showContentView:viewToShow andHideContentView:viewToHide reverse:NO];
        } else {
            [[self titleLabel] setText:[self titleForContentView:viewToShow]];
        }
    }

    [self updateClearButtonState];
}

- (void)handleFavoritesButtonPressed {
    if (_isAnimating) {
        return;
    }

    if ([self isShowingClearConfirmation]) {
        [self hideClearConfirmationWithReload:NO];
        [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    if (![[self previewView] isHidden]) {
        [self hidePreview];
        [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
        return;
    }

    NSString *key = [self activeHistoryKey];
    BOOL showingFavorites = [key isEqualToString:kHistoryKeyFavorites];
    NSString *targetKey = showingFavorites ? kHistoryKeyHistory : kHistoryKeyFavorites;
    UIView *viewToHide = [self activeHistoryContentView];
    BOOL reverse = showingFavorites;
    NSString *imageName = showingFavorites ? @"heart" : @"heart.fill";
    UIColor *tintColor = showingFavorites ? [UIColor labelColor] : [UIColor systemPinkColor];

    [self reloadTableViewForHistoryKey:targetKey
                            completion:^(KayokoTableView *targetTableView) {
                              if (![[self activeHistoryKey] isEqualToString:key] || _isAnimating) {
                                  return;
                              }

                              _activeHistoryKey = targetKey;
                              [self attachSearchBarToTableView:targetTableView hidesSearchBar:!_isSearchActive];
                              [self refreshSearchForActiveTableView];
                              [self updateClearButtonStateForTableView:targetTableView];

                              UIView *viewToShow = [self contentViewForHistoryKey:targetKey];
                              if (viewToShow != viewToHide) {
                                  [self showContentView:viewToShow andHideContentView:viewToHide reverse:reverse];
                              } else {
                                  [[self titleLabel] setText:[self titleForContentView:viewToShow]];
                              }

                              [self updateStyleForHeaderButton:[self favoritesButton]
                                                 withImageName:imageName
                                                  andImageSize:kFavoritesButtonImageSize
                                                  andTintColor:tintColor];
                              [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
                            }];
}

- (void)handlePreviewActionButtonPressed {
    if (!_previewItem || [[self previewView] isHidden] || ![[self previewView] showingWordSelection] ||
        ![[self previewView] hasSelectedText]) {
        return;
    }

    NSString *text = [[self previewView] selectedText];
    PasteboardItem *selectedItem = [[PasteboardItem alloc] initWithBundleIdentifier:[_previewItem bundleIdentifier]
                                                                         andContent:text
                                                                     withImageNamed:@""];

    if ([self automaticallyPaste]) {
        NSString *historyKey =
            _previewSourceTableView == [self favoritesTableView] ? kHistoryKeyFavorites : kHistoryKeyHistory;
        [[PasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:selectedItem
                                                                     historyItem:_previewItem
                                                              fromHistoryWithKey:historyKey
                                                                 shouldAutoPaste:YES];
    } else {
        PasteboardManager *pasteboardManager = [PasteboardManager sharedInstance];
        if ([pasteboardManager copyPasteboardItemToPasteboard:selectedItem]) {
            [pasteboardManager addPasteboardItem:selectedItem toHistoryWithKey:kHistoryKeyHistory];
        }
    }

    [self hideWithCompletion:^{
      [self restorePreviewSourceAfterAction];
    }];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)restorePreviewSourceAfterAction {
    [[self previewView] reset];
    [[self previewView] setHidden:YES];
    [_previewSourceTableView setHidden:NO];
    [_previewSourceTableView setAlpha:1];
    [_previewSourceTableView setTransform:CGAffineTransformIdentity];
    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    if (_previewSourceTableView == [self favoritesTableView]) {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart.fill"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor systemPinkColor]];
    } else {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
    }
    _previewItem = nil;
}

- (void)updatePreviewActionButtonState {
    BOOL enabled = [[self previewView] showingWordSelection] && [[self previewView] hasSelectedText];
    [[self backButton] setEnabled:enabled];
    [[self backButton] setAlpha:enabled ? 1.0 : 0.35];
}

- (void)handleClearButtonPressed {
    if (_isAnimating || ![[self previewView] isHidden] || [self isShowingClearConfirmation]) {
        return;
    }

    [self showClearConfirmationForHistoryKey:[self activeHistoryKey]];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)handleClearConfirmationCancelButtonPressed {
    if (_isAnimating) {
        return;
    }

    [self hideClearConfirmationWithReload:NO];
    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleSoft];
}

- (void)handleClearConfirmationConfirmButtonPressed {
    if (_isAnimating || !_clearConfirmationHistoryKey) {
        return;
    }

    NSString *key = _clearConfirmationHistoryKey;
    [[[self clearConfirmationView] cancelButton] setEnabled:NO];
    [[[self clearConfirmationView] confirmButton] setEnabled:NO];
    [[PasteboardManager sharedInstance]
        removeAllPasteboardItemsFromHistoryWithKey:key
                                shouldRemoveImages:YES
                           postsChangeNotification:NO
                                        completion:^(BOOL success) {
                                          if (!success) {
                                              [[[self clearConfirmationView] cancelButton] setEnabled:YES];
                                              [[[self clearConfirmationView] confirmButton] setEnabled:YES];
                                              return;
                                          }
                                          [self hideClearConfirmationWithReload:YES];
                                          [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleHeavy];
                                        }];
}

- (void)handlePasteboardItemDictionary:(NSDictionary *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                           toHistoryKey:(NSString *)destinationHistoryKey {
    if ([destinationHistoryKey length] == 0) {
        return;
    }

    if ([self hasLoadedHistoryKey:destinationHistoryKey]) {
        [[self tableViewForHistoryKey:destinationHistoryKey] upsertItemDictionaryAtTop:dictionary
                                                                                 limit:[self limitForHistoryKey:destinationHistoryKey]];
        [self markHistoryKeyLoaded:destinationHistoryKey];
    } else {
        [self markHistoryKeyDirty:destinationHistoryKey];
    }
}

- (void)showPreviewWithItem:(PasteboardItem *)item {
    [_searchBar resignFirstResponder];
    [_appTokenSuggestionTableView setHidden:YES];
    _previewItem = item;

    if (![[item imageName] isEqualToString:@""]) {
        NSData *imageData = [[NSFileManager defaultManager]
            contentsAtPath:[NSString
                               stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
        [[[self previewView] imageView] setImage:[UIImage imageWithData:imageData]];
        [[[self previewView] imageView] setHidden:NO];
    } else {
        [[self previewView] showText:[item content] enablesWordSelection:[self swipeToSelectWords]];
    }

    _previewSourceTableView = [self tableViewForHistoryKey:[self activeHistoryKey]];
    [self showContentView:[self previewView] andHideContentView:_previewSourceTableView reverse:NO];

    [self updateStyleForHeaderButton:[self favoritesButton]
                       withImageName:@"arrowshape.turn.up.backward"
                        andImageSize:kFavoritesButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [self updateStyleForHeaderButton:[self backButton]
                       withImageName:([self automaticallyPaste] ? @"doc.on.clipboard" : @"doc.on.doc.fill")andImageSize
                                    :kBackButtonImageSize
                        andTintColor:[UIColor labelColor]];
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Back"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];
    [[self backButton] setAccessibilityLabel:[[PasteboardManager localizationBundle]
                                                 localizedStringForKey:([self automaticallyPaste] ? @"Paste" : @"Copy")
                                                                 value:nil
                                                                 table:@"Tweak"]];
    [[self clearButton] setHidden:YES];
    [[self backButton] setHidden:![[self previewView] showingWordSelection]];
    [self updatePreviewActionButtonState];

    [self triggerHapticFeedbackWithStyle:UIImpactFeedbackStyleMedium];
}

- (void)hidePreview {
    if ([[self previewView] isHidden] || _isAnimating) {
        return;
    }

    [self showContentView:_previewSourceTableView andHideContentView:[self previewView] reverse:YES];

    [[self clearButton] setHidden:NO];
    [[self backButton] setHidden:YES];
    [[self backButton] setEnabled:YES];
    [[self backButton] setAlpha:1.0];
    _previewItem = nil;

    if (_previewSourceTableView == [self favoritesTableView]) {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart.fill"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor systemPinkColor]];
    } else {
        [self updateStyleForHeaderButton:[self favoritesButton]
                           withImageName:@"heart"
                            andImageSize:kFavoritesButtonImageSize
                            andTintColor:[UIColor labelColor]];
    }
    [[self favoritesButton]
        setAccessibilityLabel:[[PasteboardManager localizationBundle] localizedStringForKey:@"Favorites"
                                                                                      value:nil
                                                                                      table:@"Tweak"]];

    [[self previewView] reset];
    if (_isSearchActive) {
        [self refreshAppTokenSuggestions];
    }
}

- (void)showContentView:(UIView *)viewToShow andHideContentView:(UIView *)viewToHide reverse:(BOOL)reverse {
    [UIView transitionWithView:[self titleLabel]
                      duration:0.1
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{
                      NSString *title = [self titleForContentView:viewToShow];
                      if (title) {
                          [[self titleLabel] setText:title];
                      }
                    }
                    completion:nil];

    CGFloat viewToShowTransform = reverse ? 10 : -10;
    [viewToShow setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToShowTransform)];
    [viewToShow setAlpha:0];
    [viewToShow setHidden:NO];

    _isAnimating = YES;
    [UIView animateWithDuration:0.3
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [viewToShow setTransform:CGAffineTransformIdentity];
          [viewToShow setAlpha:1];

          CGFloat viewToHideTransform = reverse ? -10 : 10;
          [viewToHide setTransform:CGAffineTransformTranslate(viewToShow.transform, 0, viewToHideTransform)];
          [viewToHide setAlpha:0];
        }
        completion:^(BOOL finished) {
          [viewToHide setHidden:YES];
          _isAnimating = NO;
        }];
}

- (void)triggerHapticFeedbackWithStyle:(UIImpactFeedbackStyle)style {
    if (!self.shouldPlayFeedback) {
        return;
    }
    [self setFeedbackGenerator:[[UIImpactFeedbackGenerator alloc] initWithStyle:style]];
    [[self feedbackGenerator] prepare];
    [[self feedbackGenerator] impactOccurred];
    [self setFeedbackGenerator:nil];
}

- (void)reload {
    NSString *key = [self activeHistoryKey];
    [self reloadTableViewForHistoryKey:key
                animatingTopInsertions:![self isHidden] && [key isEqualToString:kHistoryKeyHistory]
                            completion:^(KayokoTableView *tableView) {
                              if (![[self activeHistoryKey] isEqualToString:key]) {
                                  return;
                              }
                              if ([self isShowingClearConfirmation] || ![[self previewView] isHidden]) {
                                  return;
                              }
                              [self setHistoryContentVisibleForKey:key];
                              [self refreshSearchForActiveTableView];
                              [self updateClearButtonStateForTableView:tableView];
                            }];
}

- (void)show {
    if (_isAnimating) {
        return;
    }

    [self resetClearConfirmationIfNeeded];

    [[self historyTableView] setAutomaticallyPaste:[self automaticallyPaste]];
    [[self favoritesTableView] setAutomaticallyPaste:[self automaticallyPaste]];

    [self reload];
    [self attachSearchBarToTableView:[self activeTableView] hidesSearchBar:YES];

    [self setTransform:CGAffineTransformMakeTranslation(0, [self bounds].size.height / 3)];
    [self setAlpha:0];
    [self setHidden:NO];
    [self prepareOutsideDismissOverlayForShow];

    _isAnimating = YES;
    [UIView animateWithDuration:0.33
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [self setTransform:CGAffineTransformIdentity];
          [self setAlpha:1];
          [[self outsideDismissOverlayView] setAlpha:1];
        }
        completion:^(BOOL finished) {
          _isAnimating = NO;
          [self finishOutsideDismissOverlayShow];
        }];
}

- (void)hide {
    [self hideWithCompletion:nil];
}

- (void)hideWithCompletion:(void (^)(void))completion {
    if (_isAnimating) {
        return;
    }

    [self resetSearchBeforeHide];
    [[self outsideDismissOverlayView] setUserInteractionEnabled:NO];
    _isAnimating = YES;
    [UIView animateWithDuration:0.33
        delay:0
        usingSpringWithDamping:1
        initialSpringVelocity:0
        options:UIViewAnimationOptionCurveEaseOut
        animations:^{
          [self setAlpha:0];
          [[self outsideDismissOverlayView] setAlpha:0];
        }
        completion:^(BOOL finished) {
          [self setHidden:YES];
          [self hideOutsideDismissOverlay];
          _isAnimating = NO;
          if (completion) {
              completion();
          }
        }];
}

@end
