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
#import <sqlite3.h>

// 每个列表（历史/收藏）各自只缓存“第一页”这么多张缩略图。
static NSUInteger kKayokoImageCacheLimit = 15;

@implementation PasteboardManager {
    dispatch_queue_t _queue;
    BOOL _didEnsureResourcesExist;
    NSCache *_historyImageCache;
    NSCache *_favoritesImageCache;
    sqlite3 *_database;
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

+ (NSString *)databasePath {
    static NSString *kDatabasePath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      kDatabasePath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/kayoko.sqlite3");
    });
    return kDatabasePath;
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
        _historyImageCache = [[NSCache alloc] init];
        [_historyImageCache setCountLimit:kKayokoImageCacheLimit];
        _favoritesImageCache = [[NSCache alloc] init];
        [_favoritesImageCache setCountLimit:kKayokoImageCacheLimit];
        [self preparePasteboardQueue];
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

    [self ensureResourcesExist];

    // Remove duplicates.
    [self deleteItemsWithContent:content fromListKey:historyKey];

    NSTimeInterval recordedAt = [item recordedAt] > 0 ? [item recordedAt] : [[NSDate date] timeIntervalSince1970];
    [self insertItemAtFrontWithBundleIdentifier:[item bundleIdentifier] ?: @"com.apple.springboard"
                                        content:content
                                      imageName:imageName
                                         remark:[item remark] ?: @""
                                        hasLink:[item hasLink]
                                     recordedAt:recordedAt
                                    intoListKey:historyKey];

    // Truncate the history corresponding the set limit.
    [self truncateListKey:historyKey toMaximumCount:[self maximumHistoryAmount]];

    [self notifyReload];

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
    [self ensureResourcesExist];

    NSString *content = [item content] ?: @"";
    BOOL didDelete = [self deleteItemsWithContent:content fromListKey:historyKey];

    if (didDelete && ![[item imageName] isEqualToString:@""]) {
        // 无论是否需要删除磁盘文件，该条目已不在这个列表中，对应的缓存项都应该从这个列表的缓存中清除。
        [[self imageCacheForHistoryKey:historyKey] removeObjectForKey:[item imageName]];

        if (shouldRemoveImage) {
            NSString *filePath = [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];
            [_fileManager removeItemAtPath:filePath error:nil];
        }
    }

    [self notifyReload];
}

- (void)updateRemark:(NSString *)remark
             forItem:(PasteboardItem *)item
      inHistoryWithKey:(NSString *)historyKey {
    if (!item) {
        return;
    }

    [self ensureResourcesExist];

    NSString *safeRemark = remark ?: @"";
    NSString *content = [item content] ?: @"";

    sqlite3_stmt *statement = NULL;
    const char *sql = "UPDATE items SET remark = ? WHERE list_key = ? AND content = ?;";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [safeRemark UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 2, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 3, [content UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_step(statement);
    }
    sqlite3_finalize(statement);

    [item setRemark:safeRemark];

    [self notifyReload];
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

    if ([self automaticallyPaste] && shouldAutoPaste) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             (CFStringRef)kNotificationKeyHelperPaste, nil, nil, YES);
    }

    if ([historyKey isEqualToString:kHistoryKeyHistory]) {
        SBApplication *frontMostApplication = [[UIApplication sharedApplication] _accessibilityFrontMostApplication];
        PasteboardItem *updatedItem = [[PasteboardItem alloc] initWithBundleIdentifier:[frontMostApplication bundleIdentifier]
                                                              andContent:[item content]
                                                              withImageNamed:[item imageName]
                                                              remark:[item remark]];
        [self moveItemToFront:updatedItem inHistoryWithKey:historyKey];
    }
}

/**
    * 将某个条目移至指定历史记录的最前面，并替换内容相同的已有条目。
    *
    * @param item 要移至最前面的条目。
    * @param historyKey 要更新的历史记录的键。
 */
- (void)moveItemToFront:(PasteboardItem *)item inHistoryWithKey:(NSString *)historyKey {
    [self ensureResourcesExist];

    NSString *content = [item content] ?: @"";
    [self deleteItemsWithContent:content fromListKey:historyKey];

    NSTimeInterval recordedAt = [item recordedAt] > 0 ? [item recordedAt] : [[NSDate date] timeIntervalSince1970];
    [self insertItemAtFrontWithBundleIdentifier:[item bundleIdentifier] ?: @"com.apple.springboard"
                                        content:content
                                      imageName:[item imageName] ?: @""
                                         remark:[item remark] ?: @""
                                        hasLink:[item hasLink]
                                     recordedAt:recordedAt
                                    intoListKey:historyKey];

    [self truncateListKey:historyKey toMaximumCount:[self maximumHistoryAmount]];

    [self notifyReload];
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

    NSMutableArray *items = [[NSMutableArray alloc] init];

    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT bundle_identifier, content, image_name, remark, has_link, recorded_at "
                       "FROM items WHERE list_key = ? ORDER BY position ASC;";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
        while (sqlite3_step(statement) == SQLITE_ROW) {
            [items addObject:[self dictionaryFromRowStatement:statement]];
        }
    }
    sqlite3_finalize(statement);

    return items;
}

- (void)setItems:(NSArray *)items forHistoryWithKey:(NSString *)historyKey {
    NSArray *safeItems = items ?: @[];

    [self ensureResourcesExist];

    sqlite3_exec(_database, "BEGIN IMMEDIATE TRANSACTION;", NULL, NULL, NULL);

    sqlite3_stmt *deleteStatement = NULL;
    if (sqlite3_prepare_v2(_database, "DELETE FROM items WHERE list_key = ?;", -1, &deleteStatement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(deleteStatement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_step(deleteStatement);
    }
    sqlite3_finalize(deleteStatement);

    sqlite3_stmt *insertStatement = NULL;
    const char *insertSQL = "INSERT INTO items (list_key, position, bundle_identifier, content, image_name, remark, has_link, recorded_at) "
                             "VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
    if (sqlite3_prepare_v2(_database, insertSQL, -1, &insertStatement, NULL) == SQLITE_OK) {
        sqlite3_int64 position = 0;
        for (NSDictionary *dictionary in safeItems) {
            @autoreleasepool {
                NSString *bundleIdentifier = dictionary[kItemKeyBundleIdentifier] ?: @"com.apple.springboard";
                NSString *content = dictionary[kItemKeyContent] ?: @"";
                NSString *imageName = dictionary[kItemKeyImageName] ?: @"";
                NSString *remark = dictionary[kItemKeyRemark] ?: @"";
                BOOL hasLink = [dictionary[kItemKeyHasLink] boolValue];
                NSTimeInterval recordedAt = [dictionary[kItemKeyRecordedAt] doubleValue];
                if (recordedAt <= 0) {
                    recordedAt = [[NSDate date] timeIntervalSince1970];
                }

                sqlite3_bind_text(insertStatement, 1, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_int64(insertStatement, 2, position);
                sqlite3_bind_text(insertStatement, 3, [bundleIdentifier UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(insertStatement, 4, [content UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(insertStatement, 5, [imageName UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_text(insertStatement, 6, [remark UTF8String], -1, SQLITE_TRANSIENT);
                sqlite3_bind_int(insertStatement, 7, hasLink ? 1 : 0);
                sqlite3_bind_double(insertStatement, 8, recordedAt);

                sqlite3_step(insertStatement);
                sqlite3_reset(insertStatement);
                position++;
            }
        }
    }
    sqlite3_finalize(insertStatement);

    sqlite3_exec(_database, "COMMIT TRANSACTION;", NULL, NULL, NULL);

    [self notifyReload];
}

/**
 * Inserts a new row for the given list at the very front (i.e. before every existing row).
 */
- (void)insertItemAtFrontWithBundleIdentifier:(NSString *)bundleIdentifier
                                       content:(NSString *)content
                                     imageName:(NSString *)imageName
                                        remark:(NSString *)remark
                                       hasLink:(BOOL)hasLink
                                    recordedAt:(NSTimeInterval)recordedAt
                                   intoListKey:(NSString *)listKey {
    sqlite3_int64 nextPosition = (sqlite3_int64)[self minimumPositionForListKey:listKey] - 1;

    sqlite3_stmt *statement = NULL;
    const char *sql = "INSERT INTO items (list_key, position, bundle_identifier, content, image_name, remark, has_link, recorded_at) "
                       "VALUES (?, ?, ?, ?, ?, ?, ?, ?);";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(statement, 2, nextPosition);
        sqlite3_bind_text(statement, 3, [bundleIdentifier UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 4, [content UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 5, [imageName UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 6, [remark UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(statement, 7, hasLink ? 1 : 0);
        sqlite3_bind_double(statement, 8, recordedAt);
        sqlite3_step(statement);
    }
    sqlite3_finalize(statement);
}

- (NSInteger)minimumPositionForListKey:(NSString *)listKey {
    NSInteger minimumPosition = 0;

    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT MIN(position) FROM items WHERE list_key = ?;";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        if (sqlite3_step(statement) == SQLITE_ROW && sqlite3_column_type(statement, 0) != SQLITE_NULL) {
            minimumPosition = (NSInteger)sqlite3_column_int64(statement, 0);
        }
    }
    sqlite3_finalize(statement);

    return minimumPosition;
}

/**
 * Deletes every row matching the given content within a list.
 *
 * @return Whether any row was actually deleted.
 */
- (BOOL)deleteItemsWithContent:(NSString *)content fromListKey:(NSString *)listKey {
    sqlite3_stmt *statement = NULL;
    const char *sql = "DELETE FROM items WHERE list_key = ? AND content = ?;";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 2, [content UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_step(statement);
    }
    sqlite3_finalize(statement);

    return sqlite3_changes(_database) > 0;
}

/**
 * Removes overflow rows so at most maximumCount rows remain for the given list, oldest first.
 */
- (void)truncateListKey:(NSString *)listKey toMaximumCount:(NSUInteger)maximumCount {
    NSMutableArray *overflowImageNames = [[NSMutableArray alloc] init];

    sqlite3_stmt *selectStatement = NULL;
    const char *selectSQL = "SELECT image_name FROM items WHERE list_key = ? AND id NOT IN "
                             "(SELECT id FROM items WHERE list_key = ? ORDER BY position ASC LIMIT ?) "
                             "AND image_name IS NOT NULL AND image_name != '';";
    if (sqlite3_prepare_v2(_database, selectSQL, -1, &selectStatement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(selectStatement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(selectStatement, 2, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(selectStatement, 3, (sqlite3_int64)maximumCount);
        while (sqlite3_step(selectStatement) == SQLITE_ROW) {
            const char *imageNameText = (const char *)sqlite3_column_text(selectStatement, 0);
            if (imageNameText) {
                [overflowImageNames addObject:[NSString stringWithUTF8String:imageNameText]];
            }
        }
    }
    sqlite3_finalize(selectStatement);

    sqlite3_stmt *statement = NULL;
    const char *sql = "DELETE FROM items WHERE list_key = ? AND id NOT IN "
                       "(SELECT id FROM items WHERE list_key = ? ORDER BY position ASC LIMIT ?);";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 2, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(statement, 3, (sqlite3_int64)maximumCount);
        sqlite3_step(statement);
    }
    sqlite3_finalize(statement);

    if ([overflowImageNames count] > 0) {
        [self removeImageFilesAndCacheEntriesNamed:overflowImageNames forHistoryWithKey:listKey];
    }
}

/**
 * 删除给定图片名对应的缓存缩略图与磁盘文件。
 */
- (void)removeImageFilesAndCacheEntriesNamed:(NSArray *)imageNames forHistoryWithKey:(NSString *)historyKey {
    NSCache *cache = [self imageCacheForHistoryKey:historyKey];
    NSString *imagesPath = [PasteboardManager historyImagesPath];
    for (NSString *imageName in imageNames) {
        [cache removeObjectForKey:imageName];
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", imagesPath, imageName];
        [_fileManager removeItemAtPath:filePath error:nil];
    }
}

- (BOOL)hasItemsForListKey:(NSString *)listKey {
    BOOL hasItems = NO;

    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT 1 FROM items WHERE list_key = ? LIMIT 1;";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        hasItems = sqlite3_step(statement) == SQLITE_ROW;
    }
    sqlite3_finalize(statement);

    return hasItems;
}

- (NSDictionary *)dictionaryFromRowStatement:(sqlite3_stmt *)statement {
    const char *bundleIdentifierText = (const char *)sqlite3_column_text(statement, 0);
    const char *contentText = (const char *)sqlite3_column_text(statement, 1);
    const char *imageNameText = (const char *)sqlite3_column_text(statement, 2);
    const char *remarkText = (const char *)sqlite3_column_text(statement, 3);
    BOOL hasLink = sqlite3_column_int(statement, 4) != 0;
    double recordedAt = sqlite3_column_double(statement, 5);

    return @{
        kItemKeyBundleIdentifier : bundleIdentifierText ? [NSString stringWithUTF8String:bundleIdentifierText] : @"",
        kItemKeyContent : contentText ? [NSString stringWithUTF8String:contentText] : @"",
        kItemKeyImageName : imageNameText ? [NSString stringWithUTF8String:imageNameText] : @"",
        kItemKeyRemark : remarkText ? [NSString stringWithUTF8String:remarkText] : @"",
        kItemKeyHasLink : @(hasLink),
        kItemKeyRecordedAt : @(recordedAt)
    };
}

- (void)notifyReload {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyCoreReload, nil, nil, YES);
}

/**
 * Immediately shrinks the history down to a new maximum amount, instead of waiting for the next
 * pasteboard change to trigger the truncation lazily.
 *
 * @param maximumAmount The new maximum amount of history items to keep.
 */
- (void)truncateHistoryToMaximumAmount:(NSUInteger)maximumAmount {
    [self setMaximumHistoryAmount:maximumAmount];

    [self ensureResourcesExist];
    [self truncateListKey:kHistoryKeyHistory toMaximumCount:maximumAmount];
    [self notifyReload];
}


/**
 * Returns the image for an item.
 *
 * @param item The item from which to get the image from.
 *
 * @return The image.
 */
- (UIImage *)getImageForItem:(PasteboardItem *)item {
    NSString *imageName = [item imageName] ?: @"";
    if (![imageName length]) {
        return nil;
    }

    NSData *imageData = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName]];
    UIImage *image = [UIImage imageWithData:imageData];    

    return image;
}

- (NSCache *)imageCacheForHistoryKey:(NSString *)historyKey {
    return [historyKey isEqualToString:kHistoryKeyFavorites] ? _favoritesImageCache : _historyImageCache;
}

- (void)getImageForItem:(PasteboardItem *)item
      fromHistoryWithKey:(NSString *)historyKey
              completion:(void (^)(UIImage *image))completion {
    NSString *imageName = item.imageName ?: @"";
    if (imageName.length == 0) {
        if (completion) completion(nil);
        return;
    }

    NSCache *cache = [self imageCacheForHistoryKey:historyKey];

    UIImage *cachedImage = [cache objectForKey:imageName];
    if (cachedImage) {
        if (completion) completion(cachedImage);
        return;
    }

    dispatch_async(_queue, ^{
      UIImage *image = [self getThumbnailForItem:item];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (image) {
            [cache setObject:image forKey:imageName];
        }
        if (completion) completion(image);
      });
    });
}

- (UIImage *)getThumbnailForItem:(PasteboardItem *)item {
    NSString *imageName = [item imageName] ?: @"";
    if (![imageName length]) {
        return nil;
    }

    NSString *imagePath = [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], imageName];
    NSURL *imageURL = [NSURL fileURLWithPath:imagePath];
    NSDictionary *options = @{
        (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        // (__bridge id)kCGImageSourceThumbnailMaxPixelSize: @(1000),
        (__bridge id)kCGImageSourceShouldCacheImmediately: @YES,
        (__bridge id)kCGImageSourceCreateThumbnailWithTransform: @YES
    };
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, nil);
    if (!source) {
        return nil;
    }

    CGImageRef thumbnailRef = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    if (!thumbnailRef) {
        return nil;
    }

    UIImage *thumbnail = [UIImage imageWithCGImage:thumbnailRef];
    CGImageRelease(thumbnailRef);

    return thumbnail;
}
/**
 * Creates the database and image directory, and migrates legacy plist data if present.
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

    [self openDatabaseIfNeeded];
    dispatch_async(_queue, ^{
      [self migrateLegacyPlistDataIfNeeded];
    });

    _didEnsureResourcesExist = YES;
}

/**
 * Opens (and lazily creates) the SQLite database used to store history and favorites.
 */
- (void)openDatabaseIfNeeded {
    if (_database) {
        return;
    }

    NSString *databasePath = [PasteboardManager databasePath];
    if (sqlite3_open_v2([databasePath UTF8String], &_database,
                         SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, NULL) != SQLITE_OK) {
        NSLog(@"[Kayoko] Failed to open database at %@: %s", databasePath, sqlite3_errmsg(_database));
        return;
    }

    sqlite3_exec(_database, "PRAGMA journal_mode=WAL;", NULL, NULL, NULL);
    sqlite3_exec(_database,
                 "CREATE TABLE IF NOT EXISTS items ("
                 "id INTEGER PRIMARY KEY AUTOINCREMENT,"
                 "list_key TEXT NOT NULL,"
                 "position INTEGER NOT NULL,"
                 "bundle_identifier TEXT,"
                 "content TEXT,"
                 "image_name TEXT,"
                 "remark TEXT,"
                 "has_link INTEGER,"
                 "recorded_at REAL);",
                 NULL, NULL, NULL);
    sqlite3_exec(_database, "CREATE INDEX IF NOT EXISTS idx_items_list_position ON items(list_key, position);", NULL, NULL, NULL);
    sqlite3_exec(_database, "CREATE INDEX IF NOT EXISTS idx_items_list_content ON items(list_key, content);", NULL, NULL, NULL);
}

/**
 * Migrates any pre-existing history.plist/favorites.plist data into the SQLite database,
 * then removes the legacy plist files.
 */
- (void)migrateLegacyPlistDataIfNeeded {
    if ([self hasItemsForListKey:kHistoryKeyHistory] || [self hasItemsForListKey:kHistoryKeyFavorites]) {
        return;
    }
    NSString *legacyHistoryPlistPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/history.plist");
    NSString *legacyFavoritesPlistPath = jbroot(@"/var/mobile/Library/codes.aurora.kayoko/favorites.plist");

    [self migrateLegacyPlistAtPath:legacyHistoryPlistPath intoListKey:kHistoryKeyHistory];
    [self migrateLegacyPlistAtPath:legacyFavoritesPlistPath intoListKey:kHistoryKeyFavorites];
}

- (void)migrateLegacyPlistAtPath:(NSString *)legacyPlistPath intoListKey:(NSString *)listKey {
    if (![_fileManager fileExistsAtPath:legacyPlistPath]) {
        return;
    }

    if (![self hasItemsForListKey:listKey]) {
        NSData *plistData = [NSData dataWithContentsOfFile:legacyPlistPath];
        NSArray *legacyItems = [NSPropertyListSerialization propertyListWithData:plistData
                                                                          options:0
                                                                           format:NULL
                                                                            error:nil];
        if ([legacyItems isKindOfClass:[NSArray class]] && [legacyItems count] > 0) {
            [self setItems:legacyItems forHistoryWithKey:listKey];
        }
    }

    // [_fileManager removeItemAtPath:legacyPlistPath error:nil];
}

- (void)dealloc {
    if (_database) {
        sqlite3_close(_database);
        _database = NULL;
    }
}

@end

