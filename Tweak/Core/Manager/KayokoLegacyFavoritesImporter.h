//
//  KayokoLegacyFavoritesImporter.h
//  Kayoko
//

#import <Foundation/Foundation.h>

@class KayokoPasteboardManager;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoLegacyFavoritesImporter : NSObject

+ (void)importWithPasteboardManager:(KayokoPasteboardManager *)pasteboardManager
						  completion:(nullable void (^)(BOOL success, NSUInteger importedCount))completion;

@end

NS_ASSUME_NONNULL_END
