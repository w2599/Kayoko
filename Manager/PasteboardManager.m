//
//  PasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardManager.h"
#import "AlertUtil.h"
#import "ImageUtil.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PreferenceKeys.h"
#import "StringUtil.h"

#import <roothide.h>

@implementation PasteboardManager {
    dispatch_queue_t _queue;
    BOOL _didEnsureResourcesExist;
}

/**
 * Creates the shared instance.
 */
+ (instancetype)sharedInstance {
    static PasteboardManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      sharedInstance = [[PasteboardManager alloc] init];
    });
    return sharedInstance;
}

+ (NSString *)historyPath {
    static NSString *kHistoryPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
            kHistoryPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/history.plist");
    });
    return kHistoryPath;
}

+ (NSString *)favoritesPath {
        static NSString *kFavoritesPath = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kFavoritesPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/favorites.plist");
        });
        return kFavoritesPath;
}

+ (NSString *)historyImagesPath {
    static NSString *kHistoryImagesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kHistoryImagesPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/images/");
    });
    return kHistoryImagesPath;
}

+ (NSBundle *)localizationBundle {
    static NSBundle *kLocalizationBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kLocalizationBundle =
          [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    });
    return kLocalizationBundle;
}

- (void)logDebugInfo {
    NSArray *pasteboardTypes = [_pasteboard pasteboardTypes];
    for (NSString *type in pasteboardTypes) {
        NSLog(@"[----]type: %@", type);
    }
    NSLog(@"[----] ");

    NSArray *items = [_pasteboard items];
    for (id item in items) {
        NSLog(@"[----]item: %@", item);
    }
    NSLog(@"[----] ");
    NSLog(@"[----] hasURLs: %@ ", [_pasteboard hasURLs] ? @"YES" : @"NO");
    NSLog(@"[----] hasStrings: %@ ", [_pasteboard hasStrings] ? @"YES" : @"NO");
    NSLog(@"[----] hasImages: %@ \n\n", [_pasteboard hasImages] ? @"YES" : @"NO");
}

/**
 * Creates the manager using the shared instance.
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        _didEnsureResourcesExist = NO;
        if (@available(iOS 15, *)) {
            [self prepareGeneralPasteboard];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
              [self prepareGeneralPasteboard];
            });
        }
    }
    return self;
}

- (void)prepareGeneralPasteboard {
    _pasteboard = [UIPasteboard generalPasteboard];
    _lastChangeCount = [_pasteboard changeCount];
}

- (void)preparePasteboardQueue {
    _queue = dispatch_queue_create("codes.aurora.kayoko.queue.pasteboard", DISPATCH_QUEUE_SERIAL);
}

/**
 * Pulls new changes from the pasteboard.
 */
- (void)pullPasteboardChangesWithCompletion:(void (^)(BOOL didSaveAnyItem))completion {

    NSInteger currentCount = [_pasteboard changeCount];
    if (currentCount == _lastChangeCount) {
        if (completion) {
            completion(NO);
        }
        return;
    }
    _lastChangeCount = currentCount;

    BOOL didSaveText = [self saveText] && ![_pasteboard hasImages] && [_pasteboard hasStrings];
    BOOL didSaveImages = [self saveImages] && [_pasteboard hasImages];

    if (!didSaveText && !didSaveImages) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [self ensureResourcesExist];
    dispatch_async(_queue, ^{
        NSArray *strings = didSaveText ? [[_pasteboard strings] copy] : nil;
        NSArray *images = didSaveImages ? [[_pasteboard images] copy] : nil;

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *bundleIdentifier = [[[UIApplication sharedApplication] _accessibilityFrontMostApplication] bundleIdentifier] ?: @"com.apple.springboard";
            BOOL didSaveAnyItem = NO;
            for (NSString *string in strings) {
                @autoreleasepool {
                    PasteboardItem *item = [[PasteboardItem alloc] initWithBundleIdentifier:bundleIdentifier
                                                                                 andContent:string
                                                                             withImageNamed:nil
                                                                                     remark:nil];
                    if ([self addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory]) {
                        didSaveAnyItem = YES;
                    }
                }
            }
            for (UIImage *image in images) {
                @autoreleasepool {
                    NSString *imageName = [StringUtil getRandomStringWithLength:32];

                    // Only save as PNG if the image has an alpha channel to save storage space.
                    if ([ImageUtil imageHasAlpha:image]) {
                        imageName = [imageName stringByAppendingString:@".png"];
                        NSString *filePath = [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                        [UIImagePNGRepresentation([ImageUtil getRotatedImageFromImage:image]) writeToFile:filePath atomically:YES];
                    } else {
                        imageName = [imageName stringByAppendingString:@".jpg"];
                        NSString *filePath = [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                        [UIImageJPEGRepresentation(image, 1) writeToFile:filePath atomically:YES];
                    }

                    PasteboardItem *item = [[PasteboardItem alloc] initWithBundleIdentifier:bundleIdentifier
                                                                                 andContent:imageName
                                                                             withImageNamed:imageName
                                                                                     remark:nil];
                    if ([self addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory]) {
                        didSaveAnyItem = YES;
                    }
                }
            }
            if (completion) {
                completion(didSaveAnyItem);
            }
        });
    });
}

/**
 * Adds an item to a specified history.
 *
 * @param item The item to save.
 * @param historyKey The key for the history which to save to.
 */
- (BOOL)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    NSString *content = [item content] ?: @"";
    NSString *imageName = [item imageName] ?: @"";
    NSString *trimmedContent = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (imageName.length < 1 && trimmedContent.length < 1) {
        return NO;
    }

    // Remove duplicates.
    [self removePasteboardItem:item fromHistoryWithKey:historyKey shouldRemoveImage:NO];

    NSMutableArray *history = [self getItemsFromHistoryWithKey:historyKey];

    [history insertObject:@{
        kItemKeyBundleIdentifier : [item bundleIdentifier] ?: @"com.apple.springboard",
        kItemKeyContent : [item content] ?: @"",
        kItemKeyImageName : [item imageName] ?: @"",
        kItemKeyRemark : [item remark] ?: @"",
        kItemKeyHasLink : @([item hasLink]),
        kItemKeyRecordedAt : @([item recordedAt] > 0 ? [item recordedAt] : [[NSDate date] timeIntervalSince1970])
    }
                  atIndex:0];

    // Truncate the history corresponding the set limit.
    while ([history count] > [self maximumHistoryAmount]) {
        [history removeLastObject];
    }

    [self setItems:history forHistoryWithKey:historyKey];

    return YES;
}

/**
 * Removes an item from a specified history.
 *
 * @param item The item to remove.
 * @param historyKey The key for the history from which to remove from.
 * @param shouldRemoveImage Whether to remove the item's corresponding image or not.
 */
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage {
    NSMutableArray *history = [self getItemsFromHistoryWithKey:historyKey];

    for (NSDictionary *dictionary in history) {
        @autoreleasepool {
            PasteboardItem *historyItem = [PasteboardItem itemFromDictionary:dictionary];

            if ([[historyItem content] isEqualToString:[item content]]) {
                [history removeObject:dictionary];

                if (![[item imageName] isEqualToString:@""] && shouldRemoveImage) {
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
                    [_fileManager removeItemAtPath:filePath error:nil];
                }

                break;
            }
        }
    }

    [self setItems:history forHistoryWithKey:historyKey];
}

- (void)updateRemark:(NSString *)remark
             forItem:(PasteboardItem *)item
      inHistoryWithKey:(NSString *)historyKey {
        NSMutableArray *history = [self getItemsFromHistoryWithKey:historyKey];

    if (!history || !item) {
        return;
    }

    NSString *safeRemark = remark ?: @"";

    for (NSUInteger index = 0; index < [history count]; index++) {
        NSDictionary *dictionary = history[index];
        PasteboardItem *historyItem = [PasteboardItem itemFromDictionary:dictionary];

        if ([[historyItem content] isEqualToString:[item content]]) {
            NSMutableDictionary *updatedDictionary = [dictionary mutableCopy];
            updatedDictionary[kItemKeyRemark] = safeRemark;
            history[index] = updatedDictionary;
            [item setRemark:safeRemark];
            break;
        }
    }

    [self setItems:history forHistoryWithKey:historyKey];
}

- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (@available(iOS 16, *)) {
        dispatch_async(_queue, ^{
          [self _reallyUpdatePasteboardWithItem:item fromHistoryWithKey:historyKey shouldAutoPaste:shouldAutoPaste];
        });
    } else {
        [self _reallyUpdatePasteboardWithItem:item fromHistoryWithKey:historyKey shouldAutoPaste:shouldAutoPaste];
    }
}

/**
 * Updates the pasteboard with an item's content.
 *
 * @param item The item from which to set the content from.
 * @param historyKey The key for the history which the item is from.
 * @param shouldAutoPaste Whether the helper should automatically paste the new content.
 */
- (void)_reallyUpdatePasteboardWithItem:(PasteboardItem *)item
                     fromHistoryWithKey:(NSString *)historyKey
                        shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (![[item imageName] isEqualToString:@""]) {
        NSString *filePath =
            [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        [_pasteboard setImage:image];
    } else {
        [_pasteboard setString:[item content]];
    }

    NSUInteger newChangeCount = [_pasteboard changeCount];
    _lastChangeCount = newChangeCount;

    if ([historyKey isEqualToString:kHistoryKeyHistory]) {
        SBApplication *frontMostApplication = [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
        PasteboardItem *updatedItem = [[PasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                              andContent:[item content]
                                                              withImageNamed:[item imageName]
                                                              remark:[item remark]];
        [self removePasteboardItem:item fromHistoryWithKey:historyKey shouldRemoveImage:NO];
        [self addPasteboardItem:updatedItem toHistoryWithKey:historyKey];
    }

    // Automatic paste should not occur for asynchronous operations.
    if ([self automaticallyPaste] && shouldAutoPaste) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyHelperPaste, nil, nil, NO);
    }
}

/**
 * Returns all items from a specified history.
 *
 * @param historyKey The key for the history from which to get the items from.
 *
 * @return The history's items.
 */
- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey {
    [self ensureResourcesExist];

    NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
    NSData *plistData = [NSData dataWithContentsOfFile:[self pathForHistoryWithKey:historyKey]];
    NSMutableArray *items = [NSPropertyListSerialization propertyListWithData:plistData
                                                                      options:NSPropertyListMutableContainers
                                                                       format:&format
                                                                        error:nil];
    if (![items isKindOfClass:[NSMutableArray class]]) {
        items = [[NSMutableArray alloc] init];
    }

    return items;
}

- (NSString *)pathForHistoryWithKey:(NSString *)historyKey {
    if ([historyKey isEqualToString:kHistoryKeyFavorites]) {
        return [PasteboardManager favoritesPath];
    }

    return [PasteboardManager historyPath];
}

- (void)setItems:(NSArray *)items forHistoryWithKey:(NSString *)historyKey {
    NSArray *safeItems = items ?: @[];

    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:safeItems
                                                                    format:NSPropertyListBinaryFormat_v1_0
                                                                   options:0
                                                                     error:nil];
    [plistData writeToFile:[self pathForHistoryWithKey:historyKey] atomically:YES];

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreReload, nil, nil, YES);
}

/**
 * Returns the latest item from the default history.
 *
 * @return The item.
 */
- (PasteboardItem *)getLatestHistoryItem {
    NSArray *history = [self getItemsFromHistoryWithKey:kHistoryKeyHistory];
    return [PasteboardItem itemFromDictionary:[history firstObject] ?: nil];
}

/**
 * Returns the image for an item.
 *
 * @param item The item from which to get the image from.
 *
 * @return The image.
 */
- (UIImage *)getImageForItem:(PasteboardItem *)item {
    NSData *imageData = [_fileManager
        contentsAtPath:[NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]]];
    return [UIImage imageWithData:imageData];
}

/**
 * Creates the plists for the histories and path for the images.
 */
- (void)ensureResourcesExist {
    if (_didEnsureResourcesExist) {
        return;
    }

    BOOL isDirectory;
    if (![_fileManager fileExistsAtPath:[PasteboardManager historyImagesPath] isDirectory:&isDirectory]) {
        [_fileManager createDirectoryAtPath:[PasteboardManager historyImagesPath]
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:nil];
    }

    NSString *historyPath = [PasteboardManager historyPath];
    NSString *favoritesPath = [PasteboardManager favoritesPath];
    NSString *legacyHistoryJsonPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/history.json");
    NSString *legacyFavoritesJsonPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/favorites.json");

    BOOL historyExists = [_fileManager fileExistsAtPath:historyPath];
    BOOL favoritesExists = [_fileManager fileExistsAtPath:favoritesPath];

    // Migrate legacy JSON formats:
    // 1) history.json: { "history": [...], "favorites": [...] }
    // 2) history.json: [...] and favorites.json: [...]
    if (!historyExists || !favoritesExists) {
        NSArray *legacyHistory = nil;
        NSArray *legacyFavorites = nil;

        if ([_fileManager fileExistsAtPath:legacyHistoryJsonPath]) {
            NSData *legacyHistoryData = [NSData dataWithContentsOfFile:legacyHistoryJsonPath];
            id legacyHistoryJson = [NSJSONSerialization JSONObjectWithData:legacyHistoryData options:0 error:nil];

            if ([legacyHistoryJson isKindOfClass:[NSDictionary class]]) {
                NSDictionary *legacyDictionary = (NSDictionary *)legacyHistoryJson;
                id historyObject = legacyDictionary[kHistoryKeyHistory];
                id favoritesObject = legacyDictionary[kHistoryKeyFavorites];

                if ([historyObject isKindOfClass:[NSArray class]]) {
                    legacyHistory = historyObject;
                }
                if ([favoritesObject isKindOfClass:[NSArray class]]) {
                    legacyFavorites = favoritesObject;
                }
            } else if ([legacyHistoryJson isKindOfClass:[NSArray class]]) {
                legacyHistory = legacyHistoryJson;
            }
        }

        if ([_fileManager fileExistsAtPath:legacyFavoritesJsonPath]) {
            NSData *legacyFavoritesData = [NSData dataWithContentsOfFile:legacyFavoritesJsonPath];
            id legacyFavoritesJson = [NSJSONSerialization JSONObjectWithData:legacyFavoritesData options:0 error:nil];
            if ([legacyFavoritesJson isKindOfClass:[NSArray class]]) {
                legacyFavorites = legacyFavoritesJson;
            }
        }

        if (!historyExists && legacyHistory) {
            NSData *historyPlistData = [NSPropertyListSerialization dataWithPropertyList:legacyHistory
                                                                                   format:NSPropertyListBinaryFormat_v1_0
                                                                                  options:0
                                                                                    error:nil];
            [historyPlistData writeToFile:historyPath options:NSDataWritingAtomic error:nil];
            historyExists = YES;
        }

        if (!favoritesExists && legacyFavorites) {
            NSData *favoritesPlistData = [NSPropertyListSerialization dataWithPropertyList:legacyFavorites
                                                                                     format:NSPropertyListBinaryFormat_v1_0
                                                                                    options:0
                                                                                      error:nil];
            [favoritesPlistData writeToFile:favoritesPath options:NSDataWritingAtomic error:nil];
            favoritesExists = YES;
        }
    }

    if (!historyExists) {
        NSData *historyPlistData = [NSPropertyListSerialization dataWithPropertyList:@[]
                                                                               format:NSPropertyListBinaryFormat_v1_0
                                                                              options:0
                                                                                error:nil];
        [historyPlistData writeToFile:historyPath options:NSDataWritingAtomic error:nil];
    }

    if (!favoritesExists) {
        NSData *favoritesPlistData = [NSPropertyListSerialization dataWithPropertyList:@[]
                                                                                 format:NSPropertyListBinaryFormat_v1_0
                                                                                options:0
                                                                                  error:nil];
        [favoritesPlistData writeToFile:favoritesPath options:NSDataWritingAtomic error:nil];
    }

    _didEnsureResourcesExist = YES;
}

@end
