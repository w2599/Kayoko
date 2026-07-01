//
//  PasteboardItem.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "PasteboardItem.h"

@implementation PasteboardItem

- (instancetype)initWithBundleIdentifier:(NSString *)bundleIdentifier
                              andContent:(NSString *)content
                          withImageNamed:(NSString *)imageName {
    self = [super init];

    if (self) {
        [self setBundleIdentifier:bundleIdentifier];
        [self setContent:content];
        [self setImageName:imageName];
        [self setHasLink:[content hasPrefix:@"http://"] || [content hasPrefix:@"https://"]];
    }

    return self;
}

+ (PasteboardItem *)itemFromDictionary:(NSDictionary<NSString *, id> *)dictionary {
    if (!dictionary) {
        return nil;
    }

    NSString *bundleIdentifier = dictionary[kItemKeyBundleIdentifier];
    NSString *content = dictionary[kItemKeyContent];
    NSString *imageName = dictionary[kItemKeyImageName];
    return [[PasteboardItem alloc] initWithBundleIdentifier:bundleIdentifier
                                                 andContent:content
                                             withImageNamed:imageName];
}

- (NSDictionary<NSString *, id> *)dictionaryRepresentation {
    return @{
        kItemKeyBundleIdentifier : [self bundleIdentifier] ?: @"com.apple.springboard",
        kItemKeyContent : [self content] ?: @"",
        kItemKeyImageName : [self imageName] ?: @"",
        kItemKeyHasLink : @([self hasLink])
    };
}

@end
