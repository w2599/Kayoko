//
//  PasteboardManager.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardManager.h"
#import "AlertUtil.h"
#import "ImageUtil.h"
#import "KayokoHistoryMigrator.h"
#import "KayokoHistoryStore.h"
#import "NotificationKeys.h"
#import "PasteboardItem.h"
#import "PreferenceKeys.h"
#import "StringUtil.h"

#import <roothide.h>

@implementation PasteboardManager {
    dispatch_queue_t _queue;
    BOOL _isPerformingDirectPaste;
    BOOL _didPrepareHistoryStore;
    KayokoHistoryStore *_historyStore;
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
      kHistoryPath = jbroot(@"/var/mobile/Library/com.82flex.kayoko/history.json");
    });
    return kHistoryPath;
}

+ (NSString *)historyImagesPath {
    static NSString *kHistoryImagesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kHistoryImagesPath = jbroot(@"/var/mobile/Library/com.82flex.kayoko/images/");
    });
    return kHistoryImagesPath;
}

+ (NSBundle *)localizationBundle {
    static NSBundle *kLocalizationBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kLocalizationBundle = [NSBundle bundleWithPath:jbroot(@"/Library/PreferenceBundles/KayokoPreferences.bundle")];
    });
    return kLocalizationBundle;
}

+ (NSString *)historyDatabasePath {
    return [KayokoHistoryStore defaultDatabasePath];
}

/**
 * Creates the manager using the shared instance.
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
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
    if (@available(iOS 16, *)) {
        _queue = dispatch_queue_create("com.82flex.kayoko.queue.pasteboard", DISPATCH_QUEUE_SERIAL);
    }
}

- (void)pullPasteboardChanges {
    if (@available(iOS 16, *)) {
        dispatch_async(_queue, ^{
          [self _reallyPullPasteboardChanges];
        });
    } else {
        [self _reallyPullPasteboardChanges];
    }
}

/**
 * Pulls new changes from the pasteboard.
 */
- (void)_reallyPullPasteboardChanges {
    // Return if the pasteboard is empty.
    if ([_pasteboard changeCount] == _lastChangeCount || (![_pasteboard hasStrings] && ![_pasteboard hasImages])) {
        return;
    }

    [self ensureResourcesExist];

    if ([self saveText]) {
        // Don't pull strings if the pasteboard contains images.
        // For example: When copying an image from the web we only want the image, without the string.
        if (!([_pasteboard hasStrings] && [_pasteboard hasImages])) {
            for (NSString *string in [_pasteboard strings]) {
                @autoreleasepool {
                    // The core only runs on the SpringBoard process, thus we can't use mainbundle to get the process'
                    // bundle identifier. However, we can get it by using UIApplication/SpringBoard
                    // front-most-application.
                    SBApplication *frontMostApplication =
                        [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
                    PasteboardItem *item =
                        [[PasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                              andContent:string
                                                          withImageNamed:nil];
                    [self addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory];
                }
            }
        }
    }

    if ([self saveImages]) {
        for (UIImage *image in [_pasteboard images]) {
            @autoreleasepool {
                NSString *imageName = [StringUtil getRandomStringWithLength:32];

                // Only save as PNG if the image has an alpha channel to save storage space.
                if ([ImageUtil imageHasAlpha:image]) {
                    imageName = [imageName stringByAppendingString:@".png"];
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                    [UIImagePNGRepresentation([ImageUtil getRotatedImageFromImage:image]) writeToFile:filePath
                                                                                           atomically:YES];
                } else {
                    imageName = [imageName stringByAppendingString:@".jpg"];
                    NSString *filePath =
                        [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
                    [UIImageJPEGRepresentation(image, 1) writeToFile:filePath atomically:YES];
                }

                // See the above loop.
                SBApplication *frontMostApplication =
                    [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
                PasteboardItem *item =
                    [[PasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                          andContent:imageName
                                                      withImageNamed:imageName];
                [self addPasteboardItem:item toHistoryWithKey:kHistoryKeyHistory];
            }
        }
    }

    _lastChangeCount = [_pasteboard changeCount];
}

/**
 * Adds an item to a specified history.
 *
 * @param item The item to save.
 * @param historyKey The key for the history which to save to.
 */
- (void)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    if ([[item content] isEqualToString:@""]) {
        return;
    }

    NSError *error = nil;
    BOOL success = [[self historyStore] addItemDictionary:[self dictionaryForPasteboardItem:item]
                                             toHistoryKey:historyKey
                                                    limit:[self maximumHistoryAmount]
                                                    error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to add history item: %@", error);
        return;
    }

    [self postHistoryChangedNotification];
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
    NSError *error = nil;
    BOOL success = [[self historyStore] removeItemDictionary:[self dictionaryForPasteboardItem:item]
                                              fromHistoryKey:historyKey
                                           shouldRemoveImage:shouldRemoveImage
                                                       error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to remove history item: %@", error);
        return;
    }

    [self postHistoryChangedNotification];
}

- (void)performDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                 historyItem:(PasteboardItem *)historyItem
                          fromHistoryWithKey:(NSString *)historyKey
                             shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (@available(iOS 16, *)) {
        if (_queue) {
            dispatch_async(_queue, ^{
              [self _reallyPerformDirectPasteWithPasteboardItem:pasteboardItem
                                                    historyItem:historyItem
                                             fromHistoryWithKey:historyKey
                                                shouldAutoPaste:shouldAutoPaste];
            });
            return;
        }
    }

    [self _reallyPerformDirectPasteWithPasteboardItem:pasteboardItem
                                          historyItem:historyItem
                                   fromHistoryWithKey:historyKey
                                      shouldAutoPaste:shouldAutoPaste];
}

- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste {
    [self performDirectPasteWithPasteboardItem:item
                                   historyItem:item
                            fromHistoryWithKey:historyKey
                               shouldAutoPaste:shouldAutoPaste];
}

/**
 * Performs a direct paste transaction with explicit history promotion.
 *
 * @param pasteboardItem The item from which to set the pasteboard content.
 * @param historyItem The original item that should be moved to the top of its history.
 * @param historyKey The key for the history which the item is from.
 * @param shouldAutoPaste Whether the helper should automatically paste the new content.
 */
- (void)_reallyPerformDirectPasteWithPasteboardItem:(PasteboardItem *)pasteboardItem
                                        historyItem:(PasteboardItem *)historyItem
                                 fromHistoryWithKey:(NSString *)historyKey
                                    shouldAutoPaste:(BOOL)shouldAutoPaste {
    if (_isPerformingDirectPaste) {
        return;
    }

    _isPerformingDirectPaste = YES;

    BOOL didUpdatePasteboard = [self setPasteboardContentFromItem:pasteboardItem];
    if (didUpdatePasteboard) {
        _lastChangeCount = [_pasteboard changeCount];
        [self movePasteboardItemToTop:historyItem inHistoryWithKey:historyKey];
    }

    if (didUpdatePasteboard && [self automaticallyPaste] && shouldAutoPaste) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyHelperPaste, nil, nil, NO);
    }

    _isPerformingDirectPaste = NO;
}

- (BOOL)setPasteboardContentFromItem:(PasteboardItem *)item {
    if (!item) {
        return NO;
    }

    if ([[item imageName] length] > 0) {
        NSString *filePath =
            [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
        UIImage *image = [UIImage imageWithContentsOfFile:filePath];
        if (!image) {
            return NO;
        }

        [_pasteboard setImage:image];
        return YES;
    }

    if ([[item content] length] == 0) {
        return NO;
    }

    [_pasteboard setString:[item content]];
    return YES;
}

- (void)movePasteboardItemToTop:(PasteboardItem *)item inHistoryWithKey:(NSString *)historyKey {
    if (!item || [[item content] length] == 0 || [[historyKey description] length] == 0) {
        return;
    }

    NSError *error = nil;
    BOOL success = [[self historyStore] moveItemDictionaryToTop:[self dictionaryForPasteboardItem:item]
                                                   inHistoryKey:historyKey
                                                          limit:[self maximumHistoryAmount]
                                                          error:&error];
    if (!success) {
        NSLog(@"Kayoko: Failed to promote history item: %@", error);
        return;
    }

    [self postHistoryChangedNotification];
}

/**
 * Returns all items from a specified history.
 *
 * @param historyKey The key for the history from which to get the items from.
 *
 * @return The history's items.
 */
- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey {
    NSError *error = nil;
    NSMutableArray *history = [[self historyStore] itemsForHistoryKey:historyKey error:&error];
    if (error) {
        NSLog(@"Kayoko: Failed to load history items: %@", error);
    }
    return history ?: [[NSMutableArray alloc] init];
}

/**
 * Returns the latest item from the default history.
 *
 * @return The item.
 */
- (PasteboardItem *)getLatestHistoryItem {
    NSError *error = nil;
    NSDictionary *dictionary = [[self historyStore] latestItemForHistoryKey:kHistoryKeyHistory error:&error];
    if (error) {
        NSLog(@"Kayoko: Failed to load latest history item: %@", error);
    }
    return [PasteboardItem itemFromDictionary:dictionary];
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

- (NSDictionary *)dictionaryForPasteboardItem:(PasteboardItem *)item {
    return @{
        kItemKeyBundleIdentifier : [item bundleIdentifier] ?: @"com.apple.springboard",
        kItemKeyContent : [item content] ?: @"",
        kItemKeyImageName : [item imageName] ?: @"",
        kItemKeyHasLink : @([item hasLink])
    };
}

- (void)postHistoryChangedNotification {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreReload, nil, nil, YES);
}

- (KayokoHistoryStore *)historyStore {
    if (!_historyStore) {
        _historyStore = [[KayokoHistoryStore alloc] initWithDatabasePath:[PasteboardManager historyDatabasePath]
                                                              imagesPath:[PasteboardManager historyImagesPath]];
    }
    [self ensureResourcesExist];
    return _historyStore;
}

/**
 * Creates the v4 history database and path for the images.
 */
- (void)ensureResourcesExist {
    if (_didPrepareHistoryStore) {
        return;
    }

    if (!_historyStore) {
        _historyStore = [[KayokoHistoryStore alloc] initWithDatabasePath:[PasteboardManager historyDatabasePath]
                                                              imagesPath:[PasteboardManager historyImagesPath]];
    }

    NSError *error = nil;
    KayokoHistoryMigrator *migrator =
        [[KayokoHistoryMigrator alloc] initWithHistoryStore:_historyStore
                                           migrationSources:[KayokoHistoryMigrator defaultMigrationSources]];
    if (![migrator migrateIfNeededWithError:&error]) {
        NSLog(@"Kayoko: Failed to prepare v4 history store: %@", error);
    }
    _didPrepareHistoryStore = YES;
}

@end
