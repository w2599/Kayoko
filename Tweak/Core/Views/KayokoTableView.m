//
//  KayokoTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableView.h"

#import "KayokoTableDataStore.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

static CGFloat const kKayokoTableViewBaseRowHeight = 65;
static CGFloat const kKayokoTableViewAdditionalPreviewLineHeight = 18;
static NSUInteger const kKayokoTableViewMaximumPreviewLineCount = 3;

@implementation KayokoTableView
{
    KayokoTableDataStore *_dataStore;
}

- (BOOL)hasActiveSearch {
    return [_dataStore hasActiveSearch];
}

- (NSArray<NSDictionary<NSString *, id> *> *)items {
    return [_dataStore items];
}

- (NSArray<NSDictionary<NSString *, id> *> *)displayedItems {
    return [_dataStore displayedItems];
}

- (NSArray<NSDictionary<NSString *, id> *> *)availableAppTokenItems {
    return [_dataStore availableAppTokenItems];
}

- (NSString *)searchText {
    return [_dataStore searchText];
}

- (NSArray<NSString *> *)selectedBundleIdentifiers {
    return [_dataStore selectedBundleIdentifiers];
}

- (NSDictionary<NSString *, id> *)itemDictionaryAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<NSDictionary<NSString *, id> *> *displayedItems = [self displayedItems];
    if ([indexPath row] >= [displayedItems count]) {
        return nil;
    }
    return displayedItems[[indexPath row]];
}

- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    [_dataStore setItems:items];
}

- (void)setSearchText:(NSString *)searchText {
    [self applySearchText:searchText selectedBundleIdentifiers:[self selectedBundleIdentifiers]];
}

- (void)setSelectedBundleIdentifiers:(NSArray<NSString *> *)selectedBundleIdentifiers {
    [self applySearchText:[self searchText] selectedBundleIdentifiers:selectedBundleIdentifiers];
}

- (void)updateSearchBackgroundView {
    if (![self hasActiveSearch] || [[self items] count] == 0 || [[self displayedItems] count] > 0) {
        [self setBackgroundView:nil];
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    [label setFont:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium]];
    [label setTextColor:[UIColor secondaryLabelColor]];
    [label setTextAlignment:NSTextAlignmentCenter];
    [label setNumberOfLines:0];
    [label setText:[[PasteboardManager localizationBundle] localizedStringForKey:@"No Search Results"
                                                                           value:nil
                                                                           table:@"Tweak"]];
    [self setBackgroundView:label];
}

- (void)reloadData {
    [super reloadData];
    [self updateSearchBackgroundView];
}

- (NSArray<NSIndexPath *> *)indexPathsFromRow:(NSUInteger)startRow count:(NSUInteger)count {
    NSMutableArray<NSIndexPath *> *indexPaths = [[NSMutableArray alloc] initWithCapacity:count];
    for (NSUInteger row = startRow; row < startRow + count; row++) {
        [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
    }
    return indexPaths;
}

- (BOOL)canUpdateFromItems:(NSArray<NSDictionary<NSString *, id> *> *)oldItems
                   toItems:(NSArray<NSDictionary<NSString *, id> *> *)newItems
      withTopInsertedCount:(NSUInteger *)insertedCount
        bottomRemovedCount:(NSUInteger *)removedCount {
    NSUInteger oldCount = [oldItems count];
    NSUInteger newCount = [newItems count];

    if (newCount == 0 || [oldItems isEqualToArray:newItems]) {
        return NO;
    }

    if (oldCount == 0) {
        if (insertedCount) {
            *insertedCount = newCount;
        }
        if (removedCount) {
            *removedCount = 0;
        }
        return YES;
    }

    for (NSUInteger candidateInsertedCount = 1; candidateInsertedCount <= newCount; candidateInsertedCount++) {
        NSUInteger retainedCount = MIN(oldCount, newCount - candidateInsertedCount);
        if (retainedCount == 0 || candidateInsertedCount + retainedCount != newCount) {
            continue;
        }

        NSArray<NSDictionary<NSString *, id> *> *newRetainedItems =
            [newItems subarrayWithRange:NSMakeRange(candidateInsertedCount, retainedCount)];
        NSArray<NSDictionary<NSString *, id> *> *oldRetainedItems =
            [oldItems subarrayWithRange:NSMakeRange(0, retainedCount)];
        if (![newRetainedItems isEqualToArray:oldRetainedItems]) {
            continue;
        }

        if (insertedCount) {
            *insertedCount = candidateInsertedCount;
        }
        if (removedCount) {
            *removedCount = oldCount - retainedCount;
        }
        return YES;
    }

    return NO;
}

- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    inItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    return [_dataStore indexOfItemMatchingDictionary:dictionary inItems:items];
}

- (NSUInteger)normalizedLimit:(NSUInteger)limit {
    return limit == 0 ? NSUIntegerMax : limit;
}

- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        _dataStore = [[KayokoTableDataStore alloc] init];
        [self setName:name];
        [self setHistoryKey:kHistoryKeyHistory];
        [self setBackgroundColor:[UIColor clearColor]];
        [self setAlwaysBounceVertical:YES];
        [self setPreviewLineCount:1];
    }

    return self;
}

- (void)setPreviewLineCount:(NSUInteger)previewLineCount {
    NSUInteger lineCount = MIN(MAX(previewLineCount, 1), kKayokoTableViewMaximumPreviewLineCount);
    _previewLineCount = lineCount;
    [self setRowHeight:kKayokoTableViewBaseRowHeight + (lineCount - 1) * kKayokoTableViewAdditionalPreviewLineHeight];
    [self reloadData];
}

- (void)reloadDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    [self updateDataWithItems:items animatingTopInsertions:NO];
}

- (void)updateDataWithItems:(NSArray<NSDictionary<NSString *, id> *> *)items
     animatingTopInsertions:(BOOL)animatingTopInsertions {
    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    NSArray<NSDictionary<NSString *, id> *> *newItems = items ?: @[];
    if ([oldItems isEqualToArray:newItems] && [self numberOfRowsInSection:0] == [oldItems count]) {
        return;
    }

    NSUInteger insertedCount = 0;
    NSUInteger removedCount = 0;
    BOOL canAnimateTopInsertion = ![self hasActiveSearch] && animatingTopInsertions &&
                                  [self numberOfRowsInSection:0] == [oldItems count] &&
                                  [self canUpdateFromItems:oldItems
                                                   toItems:newItems
                                      withTopInsertedCount:&insertedCount
                                        bottomRemovedCount:&removedCount];

    if (!canAnimateTopInsertion) {
        [self setItems:newItems];
        [self reloadData];
        return;
    }

    NSArray<NSIndexPath *> *insertedIndexPaths = [self indexPathsFromRow:0 count:insertedCount];
    NSArray<NSIndexPath *> *removedIndexPaths = [self indexPathsFromRow:[oldItems count] - removedCount count:removedCount];

    [self
        performBatchUpdates:^{
          [self setItems:newItems];
          if ([insertedIndexPaths count] > 0) {
              [self insertRowsAtIndexPaths:insertedIndexPaths withRowAnimation:UITableViewRowAnimationTop];
          }
          if ([removedIndexPaths count] > 0) {
              [self deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
          }
        }
                 completion:nil];
}

- (void)applySearchText:(NSString *)searchText selectedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers {
    [_dataStore applySearchText:searchText selectedBundleIdentifiers:bundleIdentifiers];
    [self reloadData];
}

- (void)clearItems {
    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    if ([oldItems count] == 0) {
        return;
    }

    [self setItems:@[]];
    [self reloadData];
}

- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary limit:(NSUInteger)limit {
    [self upsertItemDictionaryAtTop:dictionary limit:limit animating:YES];
}

- (void)upsertItemDictionaryAtTop:(NSDictionary<NSString *, id> *)dictionary
                             limit:(NSUInteger)limit
                         animating:(BOOL)animating {
    if (!dictionary || [dictionary[kItemKeyContent] length] == 0) {
        return;
    }

    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    NSMutableArray<NSDictionary<NSString *, id> *> *newItems = [oldItems mutableCopy];
    NSUInteger existingIndex = [self indexOfItemMatchingDictionary:dictionary inItems:newItems];
    NSUInteger normalizedLimit = [self normalizedLimit:limit];

    if (existingIndex != NSNotFound) {
        [newItems removeObjectAtIndex:existingIndex];
    }
    [newItems insertObject:dictionary atIndex:0];
    while ([newItems count] > normalizedLimit) {
        [newItems removeLastObject];
    }

    if ([oldItems isEqualToArray:newItems] && [self numberOfRowsInSection:0] == [[self displayedItems] count]) {
        return;
    }

    if (!animating) {
        [self updateDataWithItems:newItems animatingTopInsertions:NO];
        return;
    }

    if ([self hasActiveSearch] || [self numberOfRowsInSection:0] != [oldItems count]) {
        [self updateDataWithItems:newItems animatingTopInsertions:YES];
        return;
    }

    if (existingIndex == 0) {
        [self setItems:newItems];
        [self reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
                     withRowAnimation:UITableViewRowAnimationNone];
        return;
    }

    if (existingIndex != NSNotFound && existingIndex < [oldItems count] && [newItems count] == [oldItems count]) {
        [self
            performBatchUpdates:^{
              [self setItems:newItems];
              [self moveRowAtIndexPath:[NSIndexPath indexPathForRow:existingIndex inSection:0]
                            toIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }
            completion:^(__unused BOOL finished) {
            }];
        return;
    }

    NSUInteger removedCount = [oldItems count] + 1 > [newItems count] ? [oldItems count] + 1 - [newItems count] : 0;
    NSMutableArray<NSIndexPath *> *removedIndexPaths = [[NSMutableArray alloc] initWithCapacity:removedCount];
    for (NSUInteger row = [oldItems count] - removedCount; row < [oldItems count]; row++) {
        [removedIndexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
    }

    [self
        performBatchUpdates:^{
          [self setItems:newItems];
          [self insertRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:0 inSection:0] ]
                      withRowAnimation:UITableViewRowAnimationTop];
          if ([removedIndexPaths count] > 0) {
              [self deleteRowsAtIndexPaths:removedIndexPaths withRowAnimation:UITableViewRowAnimationFade];
          }
        }
        completion:^(__unused BOOL finished) {
        }];
}

- (void)removeItemDictionary:(NSDictionary<NSString *, id> *)dictionary {
    NSArray<NSDictionary<NSString *, id> *> *oldItems = [self items] ?: @[];
    NSUInteger existingIndex = [self indexOfItemMatchingDictionary:dictionary inItems:oldItems];
    if (existingIndex == NSNotFound) {
        return;
    }

    [self removeItemAtIndexPath:[NSIndexPath indexPathForRow:existingIndex inSection:0] completion:nil];
}

- (void)removeItemAtIndexPath:(NSIndexPath *)indexPath completion:(void (^)(BOOL success))completion {
    NSDictionary<NSString *, id> *dictionary = [self itemDictionaryAtIndexPath:indexPath];
    NSUInteger existingIndex = [self indexOfItemMatchingDictionary:dictionary inItems:[self items] ?: @[]];
    if (!dictionary || existingIndex == NSNotFound) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [self
        performBatchUpdates:^{
          NSMutableArray<NSDictionary<NSString *, id> *> *items = [[self items] mutableCopy];
          [items removeObjectAtIndex:existingIndex];
          [self setItems:items];
          [self deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        completion:^(__unused BOOL finished) {
          if (completion) {
              completion(YES);
          }
        }];
}

@end
