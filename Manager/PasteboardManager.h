//
//  PasteboardManager.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

static NSString *const kHistoryKeyHistory = @"history";
static NSString *const kHistoryKeyFavorites = @"favorites";

@interface PasteboardManager : NSObject {
    UIPasteboard *_pasteboard;
    NSUInteger _lastChangeCount;
    NSFileManager *_fileManager;
}
@property(nonatomic, assign) NSUInteger maximumHistoryAmount;
@property(nonatomic, assign) BOOL saveText;
@property(nonatomic, assign) BOOL saveImages;
@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL shouldIgnoreNextPasteboardChange;

+ (instancetype)sharedInstance;
- (instancetype)init NS_UNAVAILABLE;
- (void)preparePasteboardQueue;

+ (NSString *)historyPath;
+ (NSString *)favoritesPath;
+ (NSString *)historyImagesPath;
+ (NSBundle *)localizationBundle;

- (BOOL)pullPasteboardChanges;
- (BOOL)addPasteboardItem:(PasteboardItem *)item toHistoryWithKey:(NSString *)historyKey;
- (void)updatePasteboardWithItem:(PasteboardItem *)item
              fromHistoryWithKey:(NSString *)historyKey
                 shouldAutoPaste:(BOOL)shouldAutoPaste;
- (void)removePasteboardItem:(PasteboardItem *)item
          fromHistoryWithKey:(NSString *)historyKey
           shouldRemoveImage:(BOOL)shouldRemoveImage;
- (void)updateRemark:(NSString *)remark
         forItem:(PasteboardItem *)item
    inHistoryWithKey:(NSString *)historyKey;

- (NSMutableArray *)getItemsFromHistoryWithKey:(NSString *)historyKey;
- (void)setItems:(NSArray *)items forHistoryWithKey:(NSString *)historyKey;
- (PasteboardItem *)getLatestHistoryItem;
- (UIImage *)getImageForItem:(PasteboardItem *)item;

@end

@interface SBApplication : NSObject
@property(nonatomic, copy, readonly) NSString *bundleIdentifier;
@end

@interface UIApplication (Private)
- (SBApplication *)_accessibilityFrontMostApplication;
@end
