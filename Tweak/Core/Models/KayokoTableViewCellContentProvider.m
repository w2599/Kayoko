//
//  KayokoTableViewCellContentProvider.m
//  Kayoko
//

#import "KayokoTableViewCellContentProvider.h"

#import "ImageUtil.h"
#import "KayokoApplicationMetadataProvider.h"
#import "KayokoTableViewCellContent.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCellContentProvider ()
@property(nonatomic, strong) KayokoApplicationMetadataProvider *metadataProvider;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableViewCellContentProvider

- (instancetype)init {
    self = [super init];
    if (self) {
        _metadataProvider = [[KayokoApplicationMetadataProvider alloc] init];
    }
    return self;
}

- (UIImage *)scaledContentImageForItem:(PasteboardItem *)item {
    if ([[item imageName] length] == 0) {
        return nil;
    }

    UIImage *originalImage = [[PasteboardManager sharedInstance] getImageForItem:item];
    if (!originalImage) {
        return nil;
    }

    return [ImageUtil getImageWithImage:originalImage
                           scaledToSize:CGSizeMake(originalImage.size.width / 4, originalImage.size.height / 4)];
}

- (KayokoTableViewCellContent *)cellContentForItem:(PasteboardItem *)item previewLineCount:(NSUInteger)previewLineCount {
    KayokoTableViewCellContent *content = [[KayokoTableViewCellContent alloc] init];
    NSString *bundleIdentifier = [item bundleIdentifier];
    [content setIcon:[[self metadataProvider] iconForBundleIdentifier:bundleIdentifier]];
    [content setDisplayName:[[self metadataProvider] displayNameForBundleIdentifier:bundleIdentifier]];
    [content setContentText:[([item content] ?: @"") stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
    [content setContentImage:[self scaledContentImageForItem:item]];
    [content setPreviewLineCount:previewLineCount];
    return content;
}

@end
