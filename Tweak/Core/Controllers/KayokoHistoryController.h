//
//  KayokoHistoryController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoEmptyStateView;
@class KayokoFavoritesTableView;
@class KayokoHistoryController;
@class KayokoHistoryTableView;
@class KayokoTableView;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoHistoryControllerDelegate <NSObject>

- (BOOL)historyControllerIsPanelVisible:(KayokoHistoryController *)controller;
- (void)historyControllerNeedsVisibleReload:(KayokoHistoryController *)controller;
- (void)historyController:(KayokoHistoryController *)controller didUpdateActiveTableView:(KayokoTableView *)tableView;

@end

@interface KayokoHistoryController : NSObject

@property(nonatomic, weak, nullable) id<KayokoHistoryControllerDelegate> delegate;
@property(nonatomic, copy) NSString *activeHistoryKey;

- (instancetype)initWithHistoryTableView:(KayokoHistoryTableView *)historyTableView
                      favoritesTableView:(KayokoFavoritesTableView *)favoritesTableView
                          emptyStateView:(KayokoEmptyStateView *)emptyStateView;

- (NSString *)effectiveActiveHistoryKeyWithClearConfirmationHistoryKey:(nullable NSString *)clearConfirmationHistoryKey;
- (KayokoTableView *)tableViewForHistoryKey:(NSString *)historyKey;
- (KayokoTableView *)activeTableViewWithClearConfirmationHistoryKey:(nullable NSString *)clearConfirmationHistoryKey;
- (UIView *)contentViewForHistoryKey:(NSString *)historyKey;
- (UIView *)activeHistoryContentView;
- (UIView *)setHistoryContentVisibleForKey:(NSString *)historyKey;
- (nullable NSString *)titleForContentView:(UIView *)view;

- (void)markHistoryKeyLoaded:(NSString *)historyKey;
- (void)handleHistoryChanged;
- (void)preloadHistoryWithCompletion:(nullable void (^)(void))completion;
- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
              animatingTopInsertions:(BOOL)animatingTopInsertions
                           completion:(nullable void (^)(KayokoTableView *tableView))completion;
- (void)reloadTableViewForHistoryKey:(NSString *)historyKey
                          completion:(nullable void (^)(KayokoTableView *tableView))completion;
- (void)handlePasteboardItemDictionary:(NSDictionary<NSString *, id> *)dictionary
                   movedFromHistoryKey:(NSString *)sourceHistoryKey
                           toHistoryKey:(NSString *)destinationHistoryKey;

@end

NS_ASSUME_NONNULL_END
