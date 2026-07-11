//
//  KayokoCopyVaultImporter.m
//  Kayoko
//

#import "KayokoCopyVaultImporter.h"
#import "KayokoHistoryStore.h"
#import "KayokoPasteboardItem.h"
#import "KayokoTag.h"
#import "KayokoTagStore.h"

#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>

static NSString *const kKayokoCopyVaultImporterErrorDomain = @"com.82flex.kayoko.copyvault-importer";
static NSString *const kKayokoCopyVaultHistorySection = @"History";
static NSString *const kKayokoCopyVaultArchiveSection = @"Archive";
static NSString *const kKayokoCopyVaultHistoryKey = @"history";
static NSString *const kKayokoCopyVaultFavoritesKey = @"favorites";

@interface KayokoCopyVaultPreparedItem : NSObject
@property(nonatomic, strong) NSMutableDictionary<NSString *, id> *dictionary;
@property(nonatomic, copy) NSString *historyKey;
@property(nonatomic, copy, nullable) NSString *categoryTitle;
@property(nonatomic, copy, nullable) NSString *sourceUniqueIdentifier;
@property(nonatomic, copy, nullable) NSString *imageName;
@property(nonatomic, strong, nullable) NSData *imageData;
@end

@implementation KayokoCopyVaultPreparedItem
@end

@interface KayokoCopyVaultImagePayload : NSObject
@property(nonatomic, strong) NSData *data;
@property(nonatomic, copy) NSString *extension;
@property(nonatomic, assign) NSUInteger pixelWidth;
@property(nonatomic, assign) NSUInteger pixelHeight;
@end

@implementation KayokoCopyVaultImagePayload
@end

@interface KayokoCopyVaultImporter ()
@property(nonatomic, copy) NSString *sourceDirectoryPath;
@property(nonatomic, strong) KayokoHistoryStore *historyStore;
@property(nonatomic, strong) KayokoTagStore *tagStore;
@property(nonatomic, strong) NSDateFormatter *dateFormatter;
@property(nonatomic, copy) NSDictionary<NSString *, NSString *> *categoryTitlesByIdentifier;
@end

@implementation KayokoCopyVaultImporter

- (instancetype)initWithSourceDirectoryPath:(NSString *)sourceDirectoryPath
                               historyStore:(KayokoHistoryStore *)historyStore
                                   tagStore:(KayokoTagStore *)tagStore {
    self = [super init];
    if (self) {
        _sourceDirectoryPath = [sourceDirectoryPath copy];
        _historyStore = historyStore;
        _tagStore = tagStore;

        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        _dateFormatter.timeZone = [NSTimeZone localTimeZone];
        _dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ssSSS";
        _dateFormatter.lenient = NO;
    }
    return self;
}

#pragma mark - Import

- (BOOL)runWithError:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:self.sourceDirectoryPath isDirectory:&isDirectory] || !isDirectory) {
        [self populateError:error code:1 formatKey:@"CopyVault data directory was not found." detail:nil];
        return NO;
    }

    NSString *indexPath = [self.sourceDirectoryPath stringByAppendingPathComponent:@"CopyVault.plist"];
    NSDictionary<NSString *, id> *index = [self dictionaryPropertyListAtPath:indexPath error:error];
    if (!index) {
        return NO;
    }

    if (![self loadCategoryConfigurationWithError:error]) {
        return NO;
    }

    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *existingContentByHistoryKey =
        [[NSMutableDictionary alloc] init];
    for (NSString *historyKey in @[ kKayokoCopyVaultHistoryKey, kKayokoCopyVaultFavoritesKey ]) {
        NSError *readError = nil;
        NSArray<NSDictionary<NSString *, id> *> *items = [self.historyStore itemsForHistoryKey:historyKey
                                                                                         error:&readError];
        if (!items) {
            if (error) {
                *error = readError;
            }
            return NO;
        }

        NSMutableSet<NSString *> *contents = [[NSMutableSet alloc] initWithCapacity:[items count]];
        for (NSDictionary<NSString *, id> *item in items) {
            NSString *content = [self stringValue:item[kKayokoItemKeyContent]];
            if ([content length] > 0) {
                [contents addObject:content];
            }
        }
        existingContentByHistoryKey[historyKey] = contents;
    }

    NSMutableArray<KayokoCopyVaultPreparedItem *> *preparedItems = [[NSMutableArray alloc] init];
    NSMutableSet<NSString *> *seenUniqueIdentifiers = [[NSMutableSet alloc] init];
    NSMutableDictionary<NSString *, NSMutableSet<NSString *> *> *seenContentByHistoryKey = @{
        kKayokoCopyVaultHistoryKey : [[NSMutableSet alloc] init],
        kKayokoCopyVaultFavoritesKey : [[NSMutableSet alloc] init]
    }
                                                                                               .mutableCopy;

    NSArray<NSDictionary<NSString *, NSString *> *> *sections = @[
        @{@"source" : kKayokoCopyVaultHistorySection, @"target" : kKayokoCopyVaultHistoryKey},
        @{@"source" : kKayokoCopyVaultArchiveSection, @"target" : kKayokoCopyVaultFavoritesKey}
    ];
    for (NSDictionary<NSString *, NSString *> *section in sections) {
        NSString *sourceSection = section[@"source"];
        NSString *historyKey = section[@"target"];
        id recordsValue = index[sourceSection];
        if (recordsValue && ![recordsValue isKindOfClass:[NSArray class]]) {
            [self populateInvalidDataError:error
                                    detail:[NSString stringWithFormat:@"%@ is not an array", sourceSection]];
            return NO;
        }

        NSArray *records = [recordsValue isKindOfClass:[NSArray class]] ? recordsValue : @[];
        for (id recordValue in records) {
            if (![recordValue isKindOfClass:[NSDictionary class]]) {
                [self
                    populateInvalidDataError:error
                                      detail:[NSString stringWithFormat:@"%@ contains an invalid item", sourceSection]];
                return NO;
            }

            NSArray<KayokoCopyVaultPreparedItem *> *recordItems = [self preparedItemsForRecord:recordValue
                                                                                 sourceSection:sourceSection
                                                                                    historyKey:historyKey
                                                                                         error:error];
            if (!recordItems) {
                return NO;
            }

            NSString *sourceUniqueIdentifier = [[recordItems firstObject] sourceUniqueIdentifier];
            BOOL duplicateUniqueIdentifier =
                [sourceUniqueIdentifier length] > 0 && [seenUniqueIdentifiers containsObject:sourceUniqueIdentifier];
            if ([sourceUniqueIdentifier length] > 0) {
                [seenUniqueIdentifiers addObject:sourceUniqueIdentifier];
            }

            for (KayokoCopyVaultPreparedItem *item in recordItems) {
                NSString *content = [self stringValue:item.dictionary[kKayokoItemKeyContent]];
                if ([content length] == 0 || duplicateUniqueIdentifier) {
                    continue;
                }

                NSMutableSet<NSString *> *seenContents = seenContentByHistoryKey[historyKey];
                if ([seenContents containsObject:content]) {
                    continue;
                }
                [seenContents addObject:content];

                BOOL alreadyExists = [existingContentByHistoryKey[historyKey] containsObject:content];
                if (!alreadyExists ||
                    ([item.imageName length] > 0 &&
                     ![fileManager fileExistsAtPath:[self.historyStore.imagesPath
                                                        stringByAppendingPathComponent:item.imageName]])) {
                    [preparedItems addObject:item];
                }
            }
        }
    }

    NSMutableArray<KayokoTag *> *tags = [self.tagStore loadTagsWithError:error];
    if (!tags) {
        return NO;
    }
    NSArray<KayokoTag *> *originalTags = [[NSArray alloc] initWithArray:tags copyItems:YES];
    NSMutableDictionary<NSString *, KayokoTag *> *tagsByTitle = [[NSMutableDictionary alloc] init];
    for (KayokoTag *tag in tags) {
        if ([[tag title] length] > 0 && !tagsByTitle[[tag title]]) {
            tagsByTitle[[tag title]] = tag;
        }
    }

    BOOL didAddTag = NO;
    NSMutableDictionary<NSString *, NSMutableArray<NSDictionary<NSString *, id> *> *> *itemsByHistoryKey =
        @{
            kKayokoCopyVaultHistoryKey : [[NSMutableArray alloc] init],
            kKayokoCopyVaultFavoritesKey : [[NSMutableArray alloc] init]
        }
            .mutableCopy;
    NSMutableDictionary<NSString *, NSData *> *imageDataByName = [[NSMutableDictionary alloc] init];

    for (KayokoCopyVaultPreparedItem *item in preparedItems) {
        NSString *content = [self stringValue:item.dictionary[kKayokoItemKeyContent]];
        BOOL alreadyExists = [existingContentByHistoryKey[item.historyKey] containsObject:content];
        if (!alreadyExists) {
            if ([item.categoryTitle length] > 0) {
                KayokoTag *tag = tagsByTitle[item.categoryTitle];
                if (!tag) {
                    tag = [KayokoTag tagWithTitle:item.categoryTitle hexColor:@"#ADADB0FF"];
                    tagsByTitle[item.categoryTitle] = tag;
                    [tags addObject:tag];
                    didAddTag = YES;
                }
                item.dictionary[kKayokoItemKeyTagUUID] = tag.uuid;
            }
            [itemsByHistoryKey[item.historyKey] addObject:item.dictionary];
        }

        if ([item.imageName length] > 0 && item.imageData) {
            NSData *existingPlannedData = imageDataByName[item.imageName];
            if (existingPlannedData && ![existingPlannedData isEqualToData:item.imageData]) {
                [self populateInvalidDataError:error
                                        detail:[NSString stringWithFormat:@"conflicting image %@", item.imageName]];
                return NO;
            }
            imageDataByName[item.imageName] = item.imageData;
        }
    }

    return [self commitItemsByHistoryKey:itemsByHistoryKey
                         imageDataByName:imageDataByName
                                    tags:tags
                            originalTags:originalTags
                           didChangeTags:didAddTag
                                   error:error];
}

#pragma mark - Record Preparation

- (NSArray<KayokoCopyVaultPreparedItem *> *)preparedItemsForRecord:(NSDictionary<NSString *, id> *)record
                                                     sourceSection:(NSString *)sourceSection
                                                        historyKey:(NSString *)historyKey
                                                             error:(NSError **)error {
    NSString *time = [self stringValue:record[@"time"]];
    if ([time length] == 0 || [time containsString:@"/"] || [time isEqualToString:@"."] ||
        [time isEqualToString:@".."]) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid %@ timestamp", sourceSection]];
        return nil;
    }

    NSDate *capturedAt = [self.dateFormatter dateFromString:time];
    if (!capturedAt) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid timestamp %@", time]];
        return nil;
    }

    NSString *recordPath = [[self.sourceDirectoryPath stringByAppendingPathComponent:sourceSection]
        stringByAppendingPathComponent:[time stringByAppendingPathExtension:@"plist"]];
    NSString *standardizedSectionPath = [[[self.sourceDirectoryPath stringByAppendingPathComponent:sourceSection]
        stringByStandardizingPath] stringByAppendingString:@"/"];
    if (![[recordPath stringByStandardizingPath] hasPrefix:standardizedSectionPath]) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"invalid item path %@", time]];
        return nil;
    }

    NSDictionary<NSString *, id> *contentsPropertyList = [self dictionaryPropertyListAtPath:recordPath error:error];
    if (!contentsPropertyList) {
        return nil;
    }
    id contentsValue = contentsPropertyList[@"contents"];
    if (![contentsValue isKindOfClass:[NSArray class]] || [(NSArray *)contentsValue count] == 0) {
        [self populateInvalidDataError:error detail:[NSString stringWithFormat:@"%@ has no contents", time]];
        return nil;
    }

    BOOL remote = [record[@"remote"] boolValue];
    NSString *bundleIdentifier = remote ? kKayokoContinuityBundleIdentifier : [self stringValue:record[@"bundleID"]];
    if ([bundleIdentifier length] == 0) {
        bundleIdentifier = @"com.apple.springboard";
    }
    NSString *note = [self stringValue:record[@"notes"]];
    NSString *categoryTitle = [self resolvedCategoryTitle:[self stringValue:record[@"category"]]];
    NSString *uniqueIdentifier = [self normalizedUniqueIdentifier:[self stringValue:record[@"unique"]]];

    NSMutableArray<KayokoCopyVaultPreparedItem *> *preparedItems = [[NSMutableArray alloc] init];
    NSUInteger contentIndex = 0;
    for (id contentValue in (NSArray *)contentsValue) {
        if (![contentValue isKindOfClass:[NSDictionary class]]) {
            [self populateInvalidDataError:error
                                    detail:[NSString stringWithFormat:@"%@ contains an invalid payload", time]];
            return nil;
        }

        KayokoCopyVaultPreparedItem *item = [self preparedItemForContentDictionary:contentValue
                                                                        historyKey:historyKey
                                                                  bundleIdentifier:bundleIdentifier
                                                                        capturedAt:capturedAt
                                                                              note:note
                                                                     categoryTitle:categoryTitle
                                                                  uniqueIdentifier:uniqueIdentifier
                                                                      contentIndex:contentIndex
                                                                        sourceName:time
                                                                             error:error];
        if (!item) {
            return nil;
        }
        [preparedItems addObject:item];
        contentIndex++;
    }

    return preparedItems;
}

- (KayokoCopyVaultPreparedItem *)preparedItemForContentDictionary:(NSDictionary<NSString *, id> *)contents
                                                       historyKey:(NSString *)historyKey
                                                 bundleIdentifier:(NSString *)bundleIdentifier
                                                       capturedAt:(NSDate *)capturedAt
                                                             note:(NSString *)note
                                                    categoryTitle:(NSString *)categoryTitle
                                                 uniqueIdentifier:(NSString *)uniqueIdentifier
                                                     contentIndex:(NSUInteger)contentIndex
                                                       sourceName:(NSString *)sourceName
                                                            error:(NSError **)error {
    KayokoCopyVaultImagePayload *imagePayload = [self imagePayloadFromContents:contents];
    NSString *text = imagePayload ? nil : [self textFromContents:contents];
    if (!imagePayload && [text length] == 0) {
        NSArray<NSString *> *types = [[contents allKeys] sortedArrayUsingSelector:@selector(compare:)];
        NSString *detail = [NSString stringWithFormat:@"%@ (%@)", sourceName, [types componentsJoinedByString:@", "]];
        [self populateError:error code:3 formatKey:@"CopyVault contains unsupported content: %@" detail:detail];
        return nil;
    }

    KayokoCopyVaultPreparedItem *item = [[KayokoCopyVaultPreparedItem alloc] init];
    item.historyKey = historyKey;
    item.categoryTitle = categoryTitle;
    item.sourceUniqueIdentifier = uniqueIdentifier;

    NSMutableDictionary<NSString *, id> *dictionary = [@{
        kKayokoItemKeyBundleIdentifier : bundleIdentifier,
        kKayokoItemKeyCapturedAt : @([capturedAt timeIntervalSince1970])
    } mutableCopy];
    if ([note length] > 0) {
        dictionary[kKayokoItemKeyNote] = note;
    }

    if (imagePayload) {
        NSString *imageIdentifier = uniqueIdentifier;
        if ([imageIdentifier length] == 0) {
            imageIdentifier = [self SHA256StringForData:imagePayload.data];
        }
        NSString *imageName = [NSString stringWithFormat:@"copyvault-%@-%lu.%@", imageIdentifier,
                                                         (unsigned long)contentIndex, imagePayload.extension];
        dictionary[kKayokoItemKeyContent] = imageName;
        dictionary[kKayokoItemKeyImageName] = imageName;
        dictionary[kKayokoItemKeyImagePixelWidth] = @(imagePayload.pixelWidth);
        dictionary[kKayokoItemKeyImagePixelHeight] = @(imagePayload.pixelHeight);
        dictionary[kKayokoItemKeyHasLink] = @NO;
        item.imageName = imageName;
        item.imageData = imagePayload.data;
    } else {
        dictionary[kKayokoItemKeyContent] = text;
        dictionary[kKayokoItemKeyImageName] = @"";
        dictionary[kKayokoItemKeyImagePixelWidth] = @0;
        dictionary[kKayokoItemKeyImagePixelHeight] = @0;
        dictionary[kKayokoItemKeyHasLink] = @([text hasPrefix:@"http://"] || [text hasPrefix:@"https://"]);
    }

    item.dictionary = dictionary;
    return item;
}

#pragma mark - Payload Selection

- (KayokoCopyVaultImagePayload *)imagePayloadFromContents:(NSDictionary<NSString *, id> *)contents {
    NSData *pngData = [self dataValueForKeys:@[ @"copyvault.public.png", @"public.png" ] inDictionary:contents];
    NSData *jpegData = [self dataValueForKeys:@[ @"copyvault.public.jpeg", @"public.jpeg", @"public.jpg" ]
                                 inDictionary:contents];
    NSData *UIKitData = [self dataValueForKeys:@[ @"copyvault.com.apple.uikit.image", @"com.apple.uikit.image" ]
                                  inDictionary:contents];

    KayokoCopyVaultImagePayload *pngPayload = [self imagePayloadForData:pngData extension:@"png"];
    if ([self imageDataHasAlpha:pngData] && pngPayload) {
        return pngPayload;
    }

    KayokoCopyVaultImagePayload *jpegPayload = [self imagePayloadForData:jpegData extension:@"jpg"];
    if (jpegPayload) {
        return jpegPayload;
    }
    if (pngPayload) {
        return pngPayload;
    }

    if (UIKitData) {
        NSString *extension =
            [UIKitData length] >= 8 && memcmp([UIKitData bytes], "\x89PNG\r\n\x1a\n", 8) == 0 ? @"png" : @"jpg";
        return [self imagePayloadForData:UIKitData extension:extension];
    }
    return nil;
}

- (KayokoCopyVaultImagePayload *)imagePayloadForData:(NSData *)data extension:(NSString *)extension {
    if ([data length] == 0) {
        return nil;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return nil;
    }
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    NSUInteger width = [properties[(NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue];
    NSUInteger height = [properties[(NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
    if (width == 0 || height == 0) {
        return nil;
    }

    KayokoCopyVaultImagePayload *payload = [[KayokoCopyVaultImagePayload alloc] init];
    payload.data = data;
    payload.extension = extension;
    payload.pixelWidth = width;
    payload.pixelHeight = height;
    return payload;
}

- (BOOL)imageDataHasAlpha:(NSData *)data {
    if ([data length] == 0) {
        return NO;
    }
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) {
        return NO;
    }
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    return [properties[(NSString *)kCGImagePropertyHasAlpha] boolValue];
}

- (NSString *)textFromContents:(NSDictionary<NSString *, id> *)contents {
    NSArray<NSString *> *preferredTypes = @[
        @"public.utf8-plain-text", @"copyvault.public.utf8-plain-text", @"public.plain-text",
        @"copyvault.public.plain-text", @"public.text", @"copyvault.public.text", @"public.url",
        @"copyvault.public.url", @"public.file-url", @"copyvault.public.file-url"
    ];
    for (NSString *type in preferredTypes) {
        NSString *value = [self stringValue:contents[type]];
        if ([value length] > 0) {
            return value;
        }
    }
    for (id value in [contents allValues]) {
        NSString *string = [self stringValue:value];
        if ([string length] > 0) {
            return string;
        }
    }
    return nil;
}

#pragma mark - Categories

- (BOOL)loadCategoryConfigurationWithError:(NSError **)error {
    NSString *path = [self.sourceDirectoryPath stringByAppendingPathComponent:@"Archive.plist"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        self.categoryTitlesByIdentifier = @{};
        return YES;
    }

    NSDictionary<NSString *, id> *propertyList = [self dictionaryPropertyListAtPath:path error:error];
    if (!propertyList) {
        return NO;
    }
    id contentsValue = propertyList[@"contents"];
    if (contentsValue && ![contentsValue isKindOfClass:[NSDictionary class]]) {
        [self populateInvalidDataError:error detail:@"Archive.plist contents is not a dictionary"];
        return NO;
    }
    id indexValue = propertyList[@"index"];
    if (indexValue && ![indexValue isKindOfClass:[NSArray class]]) {
        [self populateInvalidDataError:error detail:@"Archive.plist index is not an array"];
        return NO;
    }
    for (id categoryIdentifier in (NSArray *)indexValue) {
        if (![categoryIdentifier isKindOfClass:[NSString class]]) {
            [self populateInvalidDataError:error detail:@"Archive.plist index contains an invalid category"];
            return NO;
        }
    }

    NSMutableDictionary<NSString *, NSString *> *titles = [[NSMutableDictionary alloc] init];
    [(NSDictionary *)contentsValue enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
      (void)stop;
      NSString *identifier = [self stringValue:key];
      NSString *title = [self stringValue:value];
      if (!title && [value isKindOfClass:[NSDictionary class]]) {
          title = [self stringValue:value[@"title"]] ?: [self stringValue:value[@"name"]];
      }
      if ([identifier length] > 0 && [title length] > 0) {
          titles[identifier] = title;
      }
    }];
    self.categoryTitlesByIdentifier = titles;
    return YES;
}

- (NSString *)resolvedCategoryTitle:(NSString *)categoryIdentifier {
    if ([categoryIdentifier length] == 0) {
        return nil;
    }
    static NSSet<NSString *> *builtInCategories = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      builtInCategories =
          [NSSet setWithArray:@[ @"BUILTIN_CATEGORY_TEXT", @"BUILTIN_CATEGORY_IMG", @"BUILTIN_CATEGORY_URL" ]];
    });
    if ([builtInCategories containsObject:categoryIdentifier]) {
        return nil;
    }
    return self.categoryTitlesByIdentifier[categoryIdentifier] ?: categoryIdentifier;
}

#pragma mark - Commit

- (BOOL)commitItemsByHistoryKey:(NSDictionary<NSString *, NSArray<NSDictionary<NSString *, id> *> *> *)itemsByHistoryKey
                imageDataByName:(NSDictionary<NSString *, NSData *> *)imageDataByName
                           tags:(NSArray<KayokoTag *> *)tags
                   originalTags:(NSArray<KayokoTag *> *)originalTags
                  didChangeTags:(BOOL)didChangeTags
                          error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *stagingPath = [self.historyStore.imagesPath
        stringByAppendingPathComponent:[@".copyvault-import-" stringByAppendingString:[[NSUUID UUID] UUIDString]]];
    if (![fileManager createDirectoryAtPath:stagingPath withIntermediateDirectories:YES attributes:nil error:error]) {
        return NO;
    }

    NSMutableArray<NSString *> *stagedImageNames = [[NSMutableArray alloc] init];
    for (NSString *imageName in imageDataByName) {
        NSString *targetPath = [self.historyStore.imagesPath stringByAppendingPathComponent:imageName];
        NSData *targetData = [NSData dataWithContentsOfFile:targetPath];
        if (targetData) {
            if (![targetData isEqualToData:imageDataByName[imageName]]) {
                [fileManager removeItemAtPath:stagingPath error:nil];
                [self populateInvalidDataError:error
                                        detail:[NSString stringWithFormat:@"image %@ already contains different data",
                                                                          imageName]];
                return NO;
            }
            continue;
        }

        NSString *stagedPath = [stagingPath stringByAppendingPathComponent:imageName];
        if (![imageDataByName[imageName] writeToFile:stagedPath options:NSDataWritingAtomic error:error]) {
            [fileManager removeItemAtPath:stagingPath error:nil];
            return NO;
        }
        [stagedImageNames addObject:imageName];
    }

    if (didChangeTags && ![self.tagStore saveTags:tags error:error]) {
        [fileManager removeItemAtPath:stagingPath error:nil];
        return NO;
    }

    NSMutableArray<NSString *> *movedImageNames = [[NSMutableArray alloc] init];
    for (NSString *imageName in stagedImageNames) {
        NSString *sourcePath = [stagingPath stringByAppendingPathComponent:imageName];
        NSString *targetPath = [self.historyStore.imagesPath stringByAppendingPathComponent:imageName];
        if (![fileManager moveItemAtPath:sourcePath toPath:targetPath error:error]) {
            [self rollbackTags:originalTags didChangeTags:didChangeTags movedImages:movedImageNames];
            [fileManager removeItemAtPath:stagingPath error:nil];
            return NO;
        }
        [movedImageNames addObject:imageName];
    }

    BOOL imported = [self.historyStore importItemDictionariesByHistoryKey:itemsByHistoryKey error:error];
    if (!imported) {
        [self rollbackTags:originalTags didChangeTags:didChangeTags movedImages:movedImageNames];
        [fileManager removeItemAtPath:stagingPath error:nil];
        return NO;
    }

    [fileManager removeItemAtPath:stagingPath error:nil];
    return YES;
}

- (void)rollbackTags:(NSArray<KayokoTag *> *)originalTags
       didChangeTags:(BOOL)didChangeTags
         movedImages:(NSArray<NSString *> *)movedImageNames {
    if (didChangeTags) {
        [self.tagStore saveTags:originalTags error:nil];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSString *imageName in movedImageNames) {
        [fileManager removeItemAtPath:[self.historyStore.imagesPath stringByAppendingPathComponent:imageName]
                                error:nil];
    }
}

#pragma mark - Values and Errors

- (NSDictionary<NSString *, id> *)dictionaryPropertyListAtPath:(NSString *)path error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:path options:0 error:error];
    if (!data) {
        if (error && *error) {
            NSError *underlyingError = *error;
            [self populateError:error
                           code:2
                      formatKey:@"Unable to read CopyVault data: %@"
                         detail:[underlyingError localizedDescription]];
        }
        return nil;
    }
    NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
    id propertyList = [NSPropertyListSerialization propertyListWithData:data
                                                                options:NSPropertyListImmutable
                                                                 format:&format
                                                                  error:error];
    if (![propertyList isKindOfClass:[NSDictionary class]]) {
        NSString *detail = error && *error ? [*error localizedDescription] : [path lastPathComponent];
        [self populateInvalidDataError:error detail:detail];
        return nil;
    }
    return propertyList;
}

- (NSData *)dataValueForKeys:(NSArray<NSString *> *)keys inDictionary:(NSDictionary<NSString *, id> *)dictionary {
    for (NSString *key in keys) {
        id value = dictionary[key];
        if ([value isKindOfClass:[NSData class]] && [value length] > 0) {
            return value;
        }
    }
    return nil;
}

- (NSString *)stringValue:(id)value {
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

- (NSString *)normalizedUniqueIdentifier:(NSString *)uniqueIdentifier {
    if ([uniqueIdentifier length] == 0) {
        return nil;
    }
    NSCharacterSet *invalidCharacters = [[NSCharacterSet
        characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"]
        invertedSet];
    if ([uniqueIdentifier rangeOfCharacterFromSet:invalidCharacters].location != NSNotFound) {
        return nil;
    }
    return [uniqueIdentifier lowercaseString];
}

- (NSString *)SHA256StringForData:(NSData *)data {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256([data bytes], (CC_LONG)[data length], digest);
    NSMutableString *result = [[NSMutableString alloc] initWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; index++) {
        [result appendFormat:@"%02x", digest[index]];
    }
    return result;
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [self.tagStore.localizationBundle localizedStringForKey:key value:key table:@"Tweak"] ?: key;
}

- (void)populateInvalidDataError:(NSError **)error detail:(NSString *)detail {
    [self populateError:error code:2 formatKey:@"CopyVault data is invalid: %@" detail:detail];
}

- (void)populateError:(NSError **)error code:(NSInteger)code formatKey:(NSString *)formatKey detail:(NSString *)detail {
    if (!error) {
        return;
    }
    NSString *format = [self localizedStringForKey:formatKey];
    NSString *description = [detail length] > 0 ? [NSString stringWithFormat:format, detail] : format;
    *error = [NSError errorWithDomain:kKayokoCopyVaultImporterErrorDomain
                                 code:code
                             userInfo:@{NSLocalizedDescriptionKey : description}];
}

@end
