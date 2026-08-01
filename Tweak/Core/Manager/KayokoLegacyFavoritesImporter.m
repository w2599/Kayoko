//
//  KayokoLegacyFavoritesImporter.m
//  Kayoko
//

#import "KayokoLegacyFavoritesImporter.h"

#import "KayokoPasteboardItem.h"
#import "KayokoPasteboardManager.h"

#import <roothide.h>
#import <sqlite3.h>

static NSString *const kKayokoLegacyDatabasePath = @"/var/mobile/Library/codes.aurora.kayoko/kayoko.sqlite3";
static NSString *const kKayokoLegacyImagesPath = @"/var/mobile/Library/codes.aurora.kayoko/images";
static NSString *const kKayokoLegacyImportMarkerPath = @"/var/mobile/Library/codes.aurora.kayoko/.kayoko-v4-favorites-imported";

@implementation KayokoLegacyFavoritesImporter

+ (void)importWithPasteboardManager:(KayokoPasteboardManager *)pasteboardManager
                          completion:(void (^)(BOOL success, NSUInteger importedCount))completion {
    if (!pasteboardManager) {
        if (completion) completion(NO, 0);
        return;
    }

    NSString *databasePath = jbroot(kKayokoLegacyDatabasePath);
    NSString *markerPath = jbroot(kKayokoLegacyImportMarkerPath);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:markerPath] || ![fileManager isReadableFileAtPath:databasePath]) {
        if (completion) completion(NO, 0);
        return;
    }

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
      [self importFromDatabasePath:databasePath
                        markerPath:markerPath
               pasteboardManager:pasteboardManager
                   completion:completion];
    });
}

+ (void)importFromDatabasePath:(NSString *)databasePath
                    markerPath:(NSString *)markerPath
           pasteboardManager:(KayokoPasteboardManager *)pasteboardManager
               completion:(void (^)(BOOL success, NSUInteger importedCount))completion {
    sqlite3 *database = NULL;
    if (sqlite3_open_v2(databasePath.fileSystemRepresentation, &database, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) {
        if (database) {
            sqlite3_close(database);
        }
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, 0); });
        return;
    }

    sqlite3_busy_timeout(database, 1000);
    sqlite3_stmt *statement = NULL;
    const char *sql = "SELECT bundle_identifier, content, image_name, remark, has_link, recorded_at "
                      "FROM items WHERE list_key = 'favorites' ORDER BY position ASC";
    int prepareResult = sqlite3_prepare_v2(database, sql, -1, &statement, NULL);
    if (prepareResult != SQLITE_OK) {
        sqlite3_close(database);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(NO, 0); });
        return;
    }

    NSMutableArray<NSDictionary<NSString *, id> *> *items = [[NSMutableArray alloc] init];
    while (sqlite3_step(statement) == SQLITE_ROW) {
        NSString *bundleIdentifier = [self stringFromColumn:statement index:0] ?: @"com.apple.springboard";
        NSString *content = [self stringFromColumn:statement index:1] ?: @"";
        NSString *imageName = [self stringFromColumn:statement index:2] ?: @"";
        NSString *remark = [self stringFromColumn:statement index:3] ?: @"";
        BOOL hasLink = sqlite3_column_int(statement, 4) != 0;
        NSTimeInterval recordedAt = sqlite3_column_double(statement, 5);
        if (recordedAt <= 0) {
            recordedAt = [[NSDate date] timeIntervalSince1970];
        }

        [items addObject:@{
            kKayokoItemKeyBundleIdentifier : bundleIdentifier,
            kKayokoItemKeyContent : content,
            kKayokoItemKeyImageName : imageName,
            kKayokoItemKeyNote : remark,
            kKayokoItemKeyHasLink : @(hasLink),
            kKayokoItemKeyCapturedAt : @(recordedAt)
        }];
    }
    sqlite3_finalize(statement);
    sqlite3_close(database);

    NSString *legacyImagesPath = jbroot(kKayokoLegacyImagesPath);
    NSString *currentImagesPath = [KayokoPasteboardManager historyImagesPath];
    [self copyImagesForItems:items fromPath:legacyImagesPath toPath:currentImagesPath];

    NSMutableSet<NSString *> *existingContents = [[self existingFavoriteContents:pasteboardManager] mutableCopy];
    NSUInteger importedCount = 0;
    for (NSDictionary<NSString *, id> *dictionary in [items reverseObjectEnumerator]) {
        NSString *content = dictionary[kKayokoItemKeyContent] ?: @"";
        NSString *imageName = dictionary[kKayokoItemKeyImageName] ?: @"";
        NSString *uniqueKey = [content length] > 0 ? content : imageName;
        if ([uniqueKey length] == 0 || [existingContents containsObject:uniqueKey]) {
            continue;
        }

        KayokoPasteboardItem *item = [KayokoPasteboardItem itemFromDictionary:dictionary];
        if (item) {
            if ([pasteboardManager addPasteboardItem:item toHistoryWithKey:kKayokoHistoryKeyFavorites]) {
                [existingContents addObject:uniqueKey];
                importedCount++;
            }
        }
    }

    [@{ @"imported_at" : @([[NSDate date] timeIntervalSince1970]) }
        writeToFile:markerPath atomically:YES];
    if (completion) {
        dispatch_async(dispatch_get_main_queue(), ^{ completion(YES, importedCount); });
    }
}

+ (NSSet<NSString *> *)existingFavoriteContents:(KayokoPasteboardManager *)pasteboardManager {
    NSMutableSet<NSString *> *values = [[NSMutableSet alloc] init];
    for (NSDictionary<NSString *, id> *dictionary in [pasteboardManager getItemsFromHistoryWithKey:kKayokoHistoryKeyFavorites]) {
        NSString *content = dictionary[kKayokoItemKeyContent] ?: @"";
        NSString *imageName = dictionary[kKayokoItemKeyImageName] ?: @"";
        if ([content length] > 0) {
            [values addObject:content];
        } else if ([imageName length] > 0) {
            [values addObject:imageName];
        }
    }
    return values;
}

+ (void)copyImagesForItems:(NSArray<NSDictionary<NSString *, id> *> *)items
                  fromPath:(NSString *)sourcePath
                    toPath:(NSString *)destinationPath {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager createDirectoryAtPath:destinationPath withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSDictionary<NSString *, id> *dictionary in items) {
        NSString *imageName = dictionary[kKayokoItemKeyImageName];
        if ([imageName length] == 0) {
            continue;
        }

        NSString *source = [sourcePath stringByAppendingPathComponent:imageName];
        NSString *destination = [destinationPath stringByAppendingPathComponent:imageName];
        if (![fileManager fileExistsAtPath:source] || [fileManager fileExistsAtPath:destination]) {
            continue;
        }
        [fileManager copyItemAtPath:source toPath:destination error:nil];
    }
}

+ (NSString *)stringFromColumn:(sqlite3_stmt *)statement index:(int)index {
    const unsigned char *value = sqlite3_column_text(statement, index);
    return value ? [NSString stringWithUTF8String:(const char *)value] : nil;
}

@end
