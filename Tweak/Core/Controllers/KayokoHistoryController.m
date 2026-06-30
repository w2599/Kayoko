//
//  KayokoHistoryController.m
//  Kayoko
//

#import "KayokoHistoryController.h"

#import "KayokoEmptyStateView.h"
#import "KayokoFavoritesTableView.h"
#import "KayokoHistoryTableView.h"
#import "KayokoTableView.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoHistoryController ()
@property(nonatomic, strong) NSMutableSet<NSString *> *loadedHistoryKeys;
@property(nonatomic, strong) NSMutableSet<NSString *> *dirtyHistoryKeys;
@property(nonatomic, assign) NSUInteger pendingLocalHistoryChangeNotificationCount;
@property(nonatomic, weak) KayokoHistoryTableView *historyTableView;
@property(nonatomic, weak) KayokoFavoritesTableView *favoritesTableView;
@property(nonatomic, weak) KayokoEmptyStateView *emptyStateView;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoHistoryController

- (instancetype)initWithHistoryTableView:(KayokoHistoryTableView *)historyTableView
                      favoritesTableView:(KayokoFavoritesTableView *)favoritesTableView
                          emptyStateView:(KayokoEmptyStateView *)emptyStateView {
    self = [super init];
    if (self) {
        _activeHistoryKey = kHistoryKeyHistory;
        _loadedHistoryKeys = [[NSMutableSet alloc] init];
        _dirtyHistoryKeys = [NSMutableSet setWithObjects:kHistoryKeyHistory, kHistoryKeyFavorites, nil];
        _historyTableView = historyTableView;
        _favoritesTableView = favoritesTableView;
        _emptyStateView = emptyStateView;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleLocalHistoryChangeNotification:)
                                                     name:kPasteboardManagerHistoryDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:(NSString *)clearConfirmationHistoryKey {
    return clearConfirmationHistoryKey ?: [self activeHistoryKey] ?: kHistoryKeyHistory;
}

- (KayokoTableView *)tableViewForHistoryKey:(NSString *)historyKey {
    return [historyKey isEqualToString:kHistoryKeyFavorites] ? [self favoritesTableView] : [self historyTableView];
}

- (KayokoTableView *)activeTableViewWithClearConfirmationHistoryKey:(NSString *)clearConfirmationHistoryKey {
    return [self tableViewForHistoryKey:[self effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:clearConfirmationHistoryKey]];
}

- (UIView *)contentViewForHistoryKey:(NSString *)historyKey {
    KayokoTableView *tableView = [self tableViewForHistoryKey:historyKey];
    if ([[tableView items] count] > 0) {
        return tableView;
    }

    [[self emptyStateView] updateWithHistoryKey:historyKey];
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

- (UIView *)setHistoryContentVisibleForKey:(NSString *)historyKey {
    [self setActiveHistoryKey:historyKey];
    UIView *contentView = [self contentViewForHistoryKey:historyKey];
    [[self historyTableView] setHidden:contentView != [self historyTableView]];
    [[self favoritesTableView] setHidden:contentView != [self favoritesTableView]];
    [[self emptyStateView] setHidden:contentView != [self emptyStateView]];
    [contentView setAlpha:1];
    [contentView setTransform:CGAffineTransformIdentity];
    [[self delegate] historyController:self didUpdateActiveTableView:[self tableViewForHistoryKey:historyKey]];
    return contentView;
}

- (NSString *)titleForContentView:(UIView *)view {
    if (view == [self historyTableView]) {
        return [[self historyTableView] name];
    }

    if (view == [self favoritesTableView]) {
        return [[self favoritesTableView] name];
    }

    if (view == [self emptyStateView]) {
        return [[self emptyStateView] name];
    }

    return nil;
}

- (BOOL)hasLoadedHistoryKey:(NSString *)historyKey {
    return [[self loadedHistoryKeys] containsObject:historyKey];
}

- (BOOL)needsReloadForHistoryKey:(NSString *)historyKey {
    return ![self hasLoadedHistoryKey:historyKey] || [[self dirtyHistoryKeys] containsObject:historyKey];
}

- (void)markHistoryKeyLoaded:(NSString *)historyKey {
    if ([historyKey length] == 0) {
        return;
    }
    [[self loadedHistoryKeys] addObject:historyKey];
    [[self dirtyHistoryKeys] removeObject:historyKey];
}

- (void)markHistoryKeyDirty:(NSString *)historyKey {
    if ([historyKey length] == 0) {
        return;
    }
    [[self dirtyHistoryKeys] addObject:historyKey];
}

- (void)markAllHistoryKeysDirty {
    [self markHistoryKeyDirty:kHistoryKeyHistory];
    [self markHistoryKeyDirty:kHistoryKeyFavorites];
}

- (NSUInteger)limitForHistoryKey:(NSString *)historyKey {
    if ([historyKey isEqualToString:kHistoryKeyFavorites]) {
        return NSUIntegerMax;
    }
    return [[PasteboardManager sharedInstance] maximumHistoryAmount];
}

- (void)updateCachedTableViewForHistoryKey:(NSString *)historyKey
                                changeType:(NSString *)changeType
                            itemDictionary:(NSDictionary<NSString *, id> *)dictionary
                                     limit:(NSUInteger)limit {
    KayokoTableView *tableView = [self tableViewForHistoryKey:historyKey];
    if (![self hasLoadedHistoryKey:historyKey]) {
        [self markHistoryKeyDirty:historyKey];
        if ([[self delegate] historyControllerIsPanelVisible:self] &&
            [[self activeHistoryKey] isEqualToString:historyKey]) {
            [[self delegate] historyControllerNeedsVisibleReload:self];
        }
        return;
    }

    if ([changeType isEqualToString:kPasteboardManagerHistoryChangeTypeClear]) {
        [tableView clearItems];
    } else if ([changeType isEqualToString:kPasteboardManagerHistoryChangeTypeUpsertTop]) {
        [tableView upsertItemDictionaryAtTop:dictionary limit:(limit ?: [self limitForHistoryKey:historyKey])];
    } else if ([changeType isEqualToString:kPasteboardManagerHistoryChangeTypeRemove]) {
        [tableView removeItemDictionary:dictionary];
    } else {
        [self markHistoryKeyDirty:historyKey];
        return;
    }

    [self markHistoryKeyLoaded:historyKey];
    if ([[self activeHistoryKey] isEqualToString:historyKey]) {
        [[self delegate] historyController:self didUpdateActiveTableView:tableView];
    }
}

- (void)handleLocalHistoryChangeNotification:(NSNotification *)notification {
    [self setPendingLocalHistoryChangeNotificationCount:[self pendingLocalHistoryChangeNotificationCount] + 1];
    NSDictionary<NSString *, id> *userInfo = [notification userInfo];
    NSString *historyKey = userInfo[kPasteboardManagerHistoryChangeHistoryKeyKey];
    NSString *changeType = userInfo[kPasteboardManagerHistoryChangeTypeKey] ?: kPasteboardManagerHistoryChangeTypeReload;
    NSDictionary<NSString *, id> *dictionary = userInfo[kPasteboardManagerHistoryChangeItemKey];
    NSUInteger limit = [userInfo[kPasteboardManagerHistoryChangeLimitKey] unsignedIntegerValue];

    if ([historyKey length] == 0 || [changeType isEqualToString:kPasteboardManagerHistoryChangeTypeReload]) {
        [self markAllHistoryKeysDirty];
        if ([[self delegate] historyControllerIsPanelVisible:self]) {
            [[self delegate] historyControllerNeedsVisibleReload:self];
        }
        return;
    }

    [self updateCachedTableViewForHistoryKey:historyKey
                                  changeType:changeType
                              itemDictionary:dictionary
                                       limit:limit];
}

- (void)handleHistoryChanged {
    if ([self pendingLocalHistoryChangeNotificationCount] > 0) {
        [self setPendingLocalHistoryChangeNotificationCount:[self pendingLocalHistoryChangeNotificationCount] - 1];
        return;
    }

    [self markAllHistoryKeysDirty];
    if ([[self delegate] historyControllerIsPanelVisible:self]) {
        [[self delegate] historyControllerNeedsVisibleReload:self];
    }
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                           completion:(void (^)(KayokoTableView *tableView))completion {
    KayokoTableView *tableView = [self tableViewForHistoryKey:historyKey];
    if (![self needsReloadForHistoryKey:historyKey]) {
        if (completion) {
            completion(tableView);
        }
        return;
    }

    [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:historyKey
                                                        completion:^(NSMutableArray<NSDictionary<NSString *, id> *> *items) {
                                                          [tableView updateDataWithItems:items
                                                                  animatingTopInsertions:animatingTopInsertions];
                                                          [self markHistoryKeyLoaded:historyKey];
                                                          if ([[self activeHistoryKey] isEqualToString:historyKey]) {
                                                              [[self delegate] historyController:self
                                                                           didUpdateActiveTableView:tableView];
                                                          }
                                                          if (completion) {
                                                              completion(tableView);
                                                          }
                                                        }];
}

- (void)reloadTableViewForHistoryKey:(NSString *)historyKey completion:(void (^)(KayokoTableView *tableView))completion {
    [self reloadTableViewForHistoryKey:historyKey animatingTopInsertions:NO completion:completion];
}

- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                           toHistoryKey:(NSString *)destinationHistoryKey {
    if ([destinationHistoryKey length] == 0) {
        return;
    }

    if ([self hasLoadedHistoryKey:destinationHistoryKey]) {
        [[self tableViewForHistoryKey:destinationHistoryKey] upsertItemDictionaryAtTop:dictionary
                                                                                 limit:[self limitForHistoryKey:destinationHistoryKey]];
        [self markHistoryKeyLoaded:destinationHistoryKey];
        if ([[self activeHistoryKey] isEqualToString:destinationHistoryKey]) {
            [[self delegate] historyController:self didUpdateActiveTableView:[self tableViewForHistoryKey:destinationHistoryKey]];
        }
    } else {
        [self markHistoryKeyDirty:destinationHistoryKey];
    }
}

@end
