//
//  KayokoTableDataStore.m
//  Kayoko
//

#import "KayokoTableDataStore.h"

#import "PasteboardItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableDataStore ()
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *displayedItems;
@property(nonatomic, copy) NSArray<NSDictionary<NSString *, id> *> *availableAppTokenItems;
@property(nonatomic, copy) NSString *searchText;
@property(nonatomic, copy) NSArray<NSString *> *selectedBundleIdentifiers;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableDataStore

- (instancetype)init {
    self = [super init];
    if (self) {
        _items = @[];
        _displayedItems = @[];
        _availableAppTokenItems = @[];
        _searchText = @"";
        _selectedBundleIdentifiers = @[];
    }
    return self;
}

- (BOOL)hasActiveSearch {
    return [[self searchText] length] > 0 || [[self selectedBundleIdentifiers] count] > 0;
}

- (NSArray<NSString *> *)validBundleIdentifiersFromBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers {
    if ([bundleIdentifiers count] == 0) {
        return @[];
    }

    NSMutableSet<NSString *> *availableBundleIdentifiers = [[NSMutableSet alloc] init];
    for (NSDictionary<NSString *, id> *tokenItem in [self availableAppTokenItems]) {
        NSString *bundleIdentifier = tokenItem[@"bundleIdentifier"];
        if ([bundleIdentifier length] > 0) {
            [availableBundleIdentifiers addObject:bundleIdentifier];
        }
    }

    NSMutableArray<NSString *> *validBundleIdentifiers = [[NSMutableArray alloc] init];
    for (NSString *bundleIdentifier in bundleIdentifiers) {
        if ([bundleIdentifier length] == 0 || ![availableBundleIdentifiers containsObject:bundleIdentifier]) {
            continue;
        }
        if (![validBundleIdentifiers containsObject:bundleIdentifier]) {
            [validBundleIdentifiers addObject:bundleIdentifier];
        }
    }
    return validBundleIdentifiers;
}

- (void)refreshAvailableAppTokenItems {
    NSMutableArray<NSDictionary<NSString *, id> *> *tokenItems = [[NSMutableArray alloc] init];
    NSMutableSet<NSString *> *seenBundleIdentifiers = [[NSMutableSet alloc] init];
    for (NSDictionary<NSString *, id> *item in [self items] ?: @[]) {
        NSString *bundleIdentifier = item[kItemKeyBundleIdentifier];
        if ([bundleIdentifier length] == 0 || [seenBundleIdentifiers containsObject:bundleIdentifier]) {
            continue;
        }

        [seenBundleIdentifiers addObject:bundleIdentifier];
        [tokenItems addObject:@{ @"bundleIdentifier" : bundleIdentifier }];
    }
    [self setAvailableAppTokenItems:tokenItems];
    [self setSelectedBundleIdentifiers:[self validBundleIdentifiersFromBundleIdentifiers:[self selectedBundleIdentifiers]]];
}

- (void)refreshDisplayedItems {
    NSArray<NSDictionary<NSString *, id> *> *items = [self items] ?: @[];
    NSString *searchText = [[self searchText]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSArray<NSString *> *selectedBundleIdentifiers = [self selectedBundleIdentifiers] ?: @[];

    if ([searchText length] == 0 && [selectedBundleIdentifiers count] == 0) {
        [self setDisplayedItems:items];
        return;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *displayedItems = [[NSMutableArray alloc] init];
    for (NSDictionary<NSString *, id> *item in items) {
        NSString *bundleIdentifier = item[kItemKeyBundleIdentifier];
        if ([selectedBundleIdentifiers count] > 0 && ![selectedBundleIdentifiers containsObject:bundleIdentifier]) {
            continue;
        }

        if ([searchText length] > 0) {
            NSString *imageName = item[kItemKeyImageName];
            NSString *content = item[kItemKeyContent];
            if ([imageName length] > 0 ||
                [content rangeOfString:searchText
                               options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location ==
                    NSNotFound) {
                continue;
            }
        }

        [displayedItems addObject:item];
    }
    [self setDisplayedItems:displayedItems];
}

- (void)setItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    _items = [items copy] ?: @[];
    [self refreshAvailableAppTokenItems];
    [self refreshDisplayedItems];
}

- (void)applySearchText:(NSString *)searchText selectedBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers {
    _searchText = [searchText copy] ?: @"";
    _selectedBundleIdentifiers = [[self validBundleIdentifiersFromBundleIdentifiers:bundleIdentifiers] copy];
    [self refreshDisplayedItems];
}

- (NSUInteger)indexOfItemMatchingDictionary:(NSDictionary<NSString *, id> *)dictionary
                                    inItems:(NSArray<NSDictionary<NSString *, id> *> *)items {
    NSString *content = dictionary[kItemKeyContent];
    if ([content length] == 0) {
        return NSNotFound;
    }

    for (NSUInteger index = 0; index < [items count]; index++) {
        NSDictionary<NSString *, id> *item = items[index];
        if ([item[kItemKeyContent] isEqualToString:content]) {
            return index;
        }
    }
    return NSNotFound;
}

@end
