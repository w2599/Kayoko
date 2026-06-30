//
//  KayokoTableViewCellContentProvider.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableViewCellContent;
@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewCellContentProvider : NSObject

- (KayokoTableViewCellContent *)cellContentForItem:(PasteboardItem *)item previewLineCount:(NSUInteger)previewLineCount;

@end

NS_ASSUME_NONNULL_END
