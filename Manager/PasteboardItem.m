//
//  PasteboardItem.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardItem.h"

@implementation PasteboardItem

/**
 * Initializes an item based on the given content.
 */
- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(NSString *)imageName
                          remark:(NSString *)remark {
    self = [super init];

    if (self) {
        [self setBundleIdentifier:bundleIdentifier];
        [self setContent:content];
        [self setImageName:imageName];
        [self setHasLink:[content hasPrefix:@"http://"] || [content hasPrefix:@"https://"]];
        [self setRemark:remark];
        [self setRecordedAt:[[NSDate date] timeIntervalSince1970]];
    }

    return self;
}

/**
 * Creates an item from a dictionary.
 *
 * @param dictionary The dictionary to create the item from.
 *
 * @return The created item.
 */
+ (PasteboardItem *)itemFromDictionary:(NSDictionary *)dictionary {
    NSString *bundleIdentifier = dictionary[kItemKeyBundleIdentifier];
    NSString *content = dictionary[kItemKeyContent];
    NSString *imageName = dictionary[kItemKeyImageName];
    NSString *remark = dictionary[kItemKeyRemark];
    PasteboardItem *item = [[PasteboardItem alloc] initWithBundleIdentifier:bundleIdentifier
                                                                  andContent:content
                                                              withImageNamed:imageName
                                                                      remark:remark];
    NSNumber *recordedAtNumber = dictionary[kItemKeyRecordedAt];
    if ([recordedAtNumber isKindOfClass:[NSNumber class]]) {
        [item setRecordedAt:[recordedAtNumber doubleValue]];
    } else {
        [item setRecordedAt:0];
    }

    NSNumber *rowIdNumber = dictionary[kItemKeyRowId];
    if ([rowIdNumber isKindOfClass:[NSNumber class]]) {
        [item setRowId:[rowIdNumber longLongValue]];
    }

    return item;
}

@end
