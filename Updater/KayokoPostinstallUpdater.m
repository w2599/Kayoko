//
//  KayokoPostinstallUpdater.m
//  Kayoko
//

#import "KayokoPostinstallUpdater.h"
#import "KayokoHistoryMigrator.h"
#import "KayokoHistoryStore.h"

#import <roothide.h>

static NSString *const kKayokoCurrentDataDirectory = @"/var/mobile/Library/com.82flex.kayoko";

@implementation KayokoPostinstallUpdater

- (BOOL)runPostinstallWithError:(NSError **)error {
    KayokoHistoryStore *store = [self historyStore];
    KayokoHistoryMigrator *migrator =
        [[KayokoHistoryMigrator alloc] initWithHistoryStore:store
                                           migrationSources:[KayokoHistoryMigrator defaultMigrationSources]];
    return [migrator migrateIfNeededWithError:error];
}

- (NSArray<NSString *> *)safelyDeletableLegacyPathsWithError:(NSError **)error {
    KayokoHistoryStore *store = [self historyStore];
    if (![store prepareStoreWithError:error]) {
        return @[];
    }

    if (![store isMigrationCompletedWithError:error]) {
        return @[];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *activeImagesPath = [[store imagesPath] stringByStandardizingPath];
    NSMutableArray<NSString *> *paths = [[NSMutableArray alloc] init];
    NSMutableSet<NSString *> *seenPaths = [[NSMutableSet alloc] init];

    for (KayokoHistoryMigrationSource *source in [KayokoHistoryMigrator defaultMigrationSources]) {
        [self addPathIfExists:[source historyPath] fileManager:fileManager paths:paths seenPaths:seenPaths];

        NSString *sourceImagesPath = [[source imagesPath] stringByStandardizingPath];
        if (![sourceImagesPath isEqualToString:activeImagesPath]) {
            [self addPathIfExists:[source imagesPath] fileManager:fileManager paths:paths seenPaths:seenPaths];
        }
    }

    return paths;
}

#pragma mark - Private

- (KayokoHistoryStore *)historyStore {
    return [[KayokoHistoryStore alloc] initWithDatabasePath:[KayokoHistoryStore defaultDatabasePath]
                                                 imagesPath:[self currentImagesPath]];
}

- (NSString *)currentImagesPath {
    return [jbroot(kKayokoCurrentDataDirectory) stringByAppendingPathComponent:@"images"];
}

- (void)addPathIfExists:(NSString *)path
            fileManager:(NSFileManager *)fileManager
                  paths:(NSMutableArray<NSString *> *)paths
              seenPaths:(NSMutableSet<NSString *> *)seenPaths {
    if ([path length] == 0 || ![fileManager fileExistsAtPath:path]) {
        return;
    }

    NSString *standardizedPath = [path stringByStandardizingPath];
    if ([seenPaths containsObject:standardizedPath]) {
        return;
    }

    [seenPaths addObject:standardizedPath];
    [paths addObject:path];
}

@end
