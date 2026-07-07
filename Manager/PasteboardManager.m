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

static int kKayokoImageCacheLimit = 20;

@implementation PasteboardManager {
    dispatch_queue_t _queue;
    BOOL _didEnsureResourcesExist;
    NSMutableDictionary *_historyImageCache;
    sqlite3 *_database;
}

/**
 * 使用共享实例创建管理器。
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
 * 使用共享实例创建管理器。
 */
- (instancetype)init {
    self = [super init];
    if (self) {
        _fileManager = [NSFileManager defaultManager];
        _didEnsureResourcesExist = NO;
        _historyImageCache = [[NSMutableDictionary alloc] init];
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
 * 从剪贴板中拉取新的更改。
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
 * 向指定历史记录中添加一个项目。
 *
 * @param item 要保存的条目。
 * @param historyKey 要保存到的历史记录的键。
 */
- (BOOL)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey {
    NSString *content = [item content] ?: @"";
    NSString *imageName = [item imageName] ?: @"";
    NSString *trimmedContent = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (imageName.length < 1 && trimmedContent.length < 1) {
        return NO;
    }

    [self ensureResourcesExist];

    // 收藏夹应保持去重，但历史记录允许保留重复条目
    if ([historyKey isEqualToString:kHistoryKeyFavorites]) {
        [self deleteItemsWithContent:content fromListKey:historyKey];
    }

    NSTimeInterval recordedAt = [item recordedAt] > 0 ? [item recordedAt] : [[NSDate date] timeIntervalSince1970];
    [self insertItemAtFrontWithBundleIdentifier:[item bundleIdentifier] ?: @"com.apple.springboard"
                                        content:content
                                      imageName:imageName
                                         remark:[item remark] ?: @""
                                        hasLink:[item hasLink]
                                     recordedAt:recordedAt
                                    intoListKey:historyKey];

    // 截断历史记录以符合设置的限制。
    [self truncateListKey:historyKey toMaximumCount:[self maximumHistoryAmount]];

    [self notifyReload];

    return YES;
}

/**
 * 从指定历史记录中移除一个项目。
 *
 * @param item 要移除的条目。
 * @param historyKey 要从中移除条目的历史记录的键。
 * @param shouldRemoveImage 是否应移除条目对应的图片。
 */
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage {
    [self ensureResourcesExist];

    BOOL didDelete;
    if ([item rowId] > 0) {
        didDelete = [self deleteItemWithRowId:[item rowId] fromListKey:historyKey];
    } else {
        NSString *content = [item content] ?: @"";
        didDelete = [self deleteItemsWithContent:content fromListKey:historyKey];
    }

    if (didDelete && shouldRemoveImage && ![[item imageName] isEqualToString:@""]) {
        NSString *filePath = [NSString stringWithFormat:@"%@/%@", [PasteboardManager historyImagesPath], [item imageName]];

        [_historyImageCache removeObjectForKey:[item imageName]];
        [_fileManager removeItemAtPath:filePath error:nil];
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

    sqlite3_stmt *statement = NULL;
    if ([item rowId] > 0) {
        const char *sql = "UPDATE items SET remark = ? WHERE list_key = ? AND id = ?;";
        if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [safeRemark UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 2, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_int64(statement, 3, (sqlite3_int64)[item rowId]);
            sqlite3_step(statement);
        }
    } else {
        NSString *content = [item content] ?: @"";
        const char *sql = "UPDATE items SET remark = ? WHERE list_key = ? AND content = ?;";
        if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
            sqlite3_bind_text(statement, 1, [safeRemark UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 2, [historyKey UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_bind_text(statement, 3, [content UTF8String], -1, SQLITE_TRANSIENT);
            sqlite3_step(statement);
        }
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
 * 使用项目内容更新剪贴板。
 *
 * @param item 要从中设置内容的条目。
 * @param historyKey 条目所属历史记录的键。
 * @param shouldAutoPaste 是否应自动粘贴新内容。
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
        [updatedItem setRowId:[item rowId]];
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
    if ([item rowId] > 0) {
        [self deleteItemWithRowId:[item rowId] fromListKey:historyKey];
    } else {
        [self deleteItemsWithContent:content fromListKey:historyKey];
    }

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
 * 返回指定历史记录中的所有条目。
 *
 * @param historyKey 要获取条目的历史记录的键。
 *
 * @return 历史记录的条目。
 */
- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey {
    [self ensureResourcesExist];

    NSMutableArray *items = [[NSMutableArray alloc] init];

    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT id, bundle_identifier, content, image_name, remark, has_link, recorded_at "
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
 * 在给定列表的最前面（即所有现有行之前）插入一个新行。
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
 * 删除列表中所有匹配给定内容的行。
 *
 * @return 是否实际删除了任何行。
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
 * 删除列表中由唯一行 ID 标识的单行。
 * 当允许重复内容共存时，用于精确定位一次出现。
 *
 * @return 是否实际删除了该行。
 */
- (BOOL)deleteItemWithRowId:(long long)rowId fromListKey:(NSString *)listKey {
    sqlite3_stmt *statement = NULL;
    const char *sql = "DELETE FROM items WHERE list_key = ? AND id = ?;";
    if (sqlite3_prepare_v2(_database, sql, -1, &statement, NULL) == SQLITE_OK) {
        sqlite3_bind_text(statement, 1, [listKey UTF8String], -1, SQLITE_TRANSIENT);
        sqlite3_bind_int64(statement, 2, (sqlite3_int64)rowId);
        sqlite3_step(statement);
    }
    sqlite3_finalize(statement);

    return sqlite3_changes(_database) > 0;
}

/**
 * 删除溢出的行，以便给定列表中最多只保留 maximumCount 行，按最旧的顺序。
 */
- (void)truncateListKey:(NSString *)listKey toMaximumCount:(NSUInteger)maximumCount {
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
    sqlite3_int64 rowId = sqlite3_column_int64(statement, 0);
    const char *bundleIdentifierText = (const char *)sqlite3_column_text(statement, 1);
    const char *contentText = (const char *)sqlite3_column_text(statement, 2);
    const char *imageNameText = (const char *)sqlite3_column_text(statement, 3);
    const char *remarkText = (const char *)sqlite3_column_text(statement, 4);
    BOOL hasLink = sqlite3_column_int(statement, 5) != 0;
    double recordedAt = sqlite3_column_double(statement, 6);

    return @{
        kItemKeyRowId : @(rowId),
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
 * 立即将历史记录缩减到新的最大数量，而不是等待下一次剪贴板更改触发延迟截断。
 *
 * @param maximumAmount 要保留的历史记录条目的新最大数量。
 */
- (void)truncateHistoryToMaximumAmount:(NSUInteger)maximumAmount {
    [self setMaximumHistoryAmount:maximumAmount];

    [self ensureResourcesExist];
    [self truncateListKey:kHistoryKeyHistory toMaximumCount:maximumAmount];
    [self notifyReload];
}


/**
 * 返回条目的图像。
 *
 * @param item 要获取图像的条目。
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

- (void)getImageForItem:(PasteboardItem *)item completion:(void (^)(UIImage *image))completion {
    NSString *imageName = item.imageName ?: @"";
    if (imageName.length == 0) {
        if (completion) completion(nil);
        return;
    }

    UIImage *cachedImage = [_historyImageCache objectForKey:imageName];
    if (cachedImage) {
        if (completion) completion(cachedImage);
        return;
    }

    dispatch_async(_queue, ^{
      UIImage *image = [self getThumbnailForItem:item];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (image && [_historyImageCache count] <= kKayokoImageCacheLimit) {
            [_historyImageCache setObject:image forKey:imageName];
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
 * 创建数据库和镜像目录，并在存在旧版 plist 数据时进行迁移。
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
 * 打开（并按需创建）用于存储历史记录和收藏的 SQLite 数据库。
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
 * 将任何预先存在的 history.plist/favorites.plist 数据迁移到 SQLite 数据库中，
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

