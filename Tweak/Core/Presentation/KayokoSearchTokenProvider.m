//
//  KayokoSearchTokenProvider.m
//  Kayoko
//

#import "KayokoSearchTokenProvider.h"

#import "KayokoApplicationMetadataProvider.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchTokenProvider ()
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchTokenProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
    }
    return self;
}

- (NSArray<NSDictionary<NSString *, id> *> *)appTokenItemsWithAvailableItems:
    (NSArray<NSDictionary<NSString *, id> *> *)availableItems {
    NSMutableArray<NSDictionary<NSString *, id> *> *items = [[NSMutableArray alloc] init];
    for (NSDictionary<NSString *, id> *tokenItem in availableItems) {
        NSString *bundleIdentifier = tokenItem[@"bundleIdentifier"];
        if ([bundleIdentifier length] == 0) {
            continue;
        }

        UIImage *icon = [[self metadataProvider] iconForBundleIdentifier:bundleIdentifier];
        NSMutableDictionary<NSString *, id> *item = [@{
            @"bundleIdentifier" : bundleIdentifier,
            @"displayName" : [[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier]
        } mutableCopy];
        if (icon) {
            item[@"icon"] = icon;
        }
        [items addObject:item];
    }
    return items;
}

- (NSArray<NSString *> *)selectedBundleIdentifiersInSearchBar:(UISearchBar *)searchBar {
    if (@available(iOS 13.0, *)) {
        NSMutableArray<NSString *> *bundleIdentifiers = [[NSMutableArray alloc] init];
        for (UISearchToken *token in [[searchBar searchTextField] tokens]) {
            NSString *bundleIdentifier = [token representedObject];
            if ([bundleIdentifier length] > 0 && ![bundleIdentifiers containsObject:bundleIdentifier]) {
                [bundleIdentifiers addObject:bundleIdentifier];
            }
        }
        return bundleIdentifiers;
    }
    return @[];
}

- (NSArray<NSDictionary<NSString *, id> *> *)
    unselectedAppTokenSuggestionItemsWithAvailableItems:(NSArray<NSDictionary<NSString *, id> *> *)availableItems
                                              searchBar:(UISearchBar *)searchBar {
    NSArray<NSString *> *selectedBundleIdentifiers = [self selectedBundleIdentifiersInSearchBar:searchBar];
    NSMutableArray<NSDictionary<NSString *, id> *> *suggestionItems = [[NSMutableArray alloc] init];
    for (NSDictionary<NSString *, id> *item in [self appTokenItemsWithAvailableItems:availableItems]) {
        NSString *bundleIdentifier = item[@"bundleIdentifier"];
        if (![selectedBundleIdentifiers containsObject:bundleIdentifier]) {
            [suggestionItems addObject:item];
        }
    }
    return suggestionItems;
}

- (void)setSearchTokensWithBundleIdentifiers:(NSArray<NSString *> *)bundleIdentifiers
                                 inSearchBar:(UISearchBar *)searchBar
                              availableItems:(NSArray<NSDictionary<NSString *, id> *> *)availableItems {
    if (@available(iOS 13.0, *)) {
        NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *itemsByBundleIdentifier =
            [[NSMutableDictionary alloc] init];
        for (NSDictionary<NSString *, id> *item in [self appTokenItemsWithAvailableItems:availableItems]) {
            NSString *bundleIdentifier = item[@"bundleIdentifier"];
            if ([bundleIdentifier length] > 0) {
                itemsByBundleIdentifier[bundleIdentifier] = item;
            }
        }

        NSMutableArray<UISearchToken *> *tokens = [[NSMutableArray alloc] init];
        for (NSString *bundleIdentifier in bundleIdentifiers) {
            NSDictionary<NSString *, id> *item = itemsByBundleIdentifier[bundleIdentifier];
            if (!item) {
                continue;
            }

            UISearchToken *token = [UISearchToken tokenWithIcon:item[@"icon"] text:item[@"displayName"]];
            [token setRepresentedObject:bundleIdentifier];
            [tokens addObject:token];
        }
        [[searchBar searchTextField] setTokens:tokens];
    }
}

@end
