//
//  KayokoTableViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoTableView;
@class KayokoTableViewController;
@class PasteboardItem;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoTableViewControllerDelegate <NSObject>

- (void)tableViewControllerDidRequestHide:(KayokoTableViewController *)controller;
- (void)tableViewController:(KayokoTableViewController *)controller didRequestPreviewForItem:(PasteboardItem *)item;
- (void)tableViewController:(KayokoTableViewController *)controller
    didChangeContentStateMaintainingSearchBarVisibility:(BOOL)maintainsSearchBarVisibility;
- (void)tableViewController:(KayokoTableViewController *)controller
      didMoveItemDictionary:(NSDictionary<NSString *, id> *)dictionary
         fromHistoryWithKey:(NSString *)sourceHistoryKey
           toHistoryWithKey:(NSString *)destinationHistoryKey;

@end

@interface KayokoTableViewController : NSObject

@property(nonatomic, weak, nullable) id<KayokoTableViewControllerDelegate> delegate;

- (instancetype)initWithTableViews:(NSArray<KayokoTableView *> *)tableViews;

@end

NS_ASSUME_NONNULL_END
