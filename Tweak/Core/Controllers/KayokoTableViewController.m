//
//  KayokoTableViewController.m
//  Kayoko
//

#import "KayokoTableViewController.h"

#import "KayokoTableViewCellContent.h"
#import "KayokoTableViewCellContentProvider.h"
#import "KayokoTableViewCell.h"
#import "KayokoTableView.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoTableViewController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, copy) NSArray<KayokoTableView *> *tableViews;
@property(nonatomic, strong) KayokoTableViewCellContentProvider *cellContentProvider;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoTableViewController

- (instancetype)initWithTableViews:(NSArray<KayokoTableView *> *)tableViews {
    self = [super init];
    if (self) {
        _tableViews = [tableViews copy] ?: @[];
        _cellContentProvider = [[KayokoTableViewCellContentProvider alloc] init];
        [self configureTableViews];
    }
    return self;
}

- (void)configureTableViews {
    for (KayokoTableView *tableView in [self tableViews]) {
        [tableView setDelegate:self];
        [tableView setDataSource:self];
    }
}

- (KayokoTableView *)kayokoTableViewFromTableView:(UITableView *)tableView {
    return [tableView isKindOfClass:[KayokoTableView class]] ? (KayokoTableView *)tableView : nil;
}

- (BOOL)shouldMaintainSearchBarVisibilityAfterSwipeInTableView:(KayokoTableView *)tableView {
    UIView *headerView = [tableView tableHeaderView];
    CGFloat headerHeight = headerView ? CGRectGetHeight([headerView frame]) : 0;
    if (headerHeight <= 0) {
        return NO;
    }

    CGFloat offsetY = [tableView contentOffset].y;
    return fabs(offsetY - headerHeight) <= 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[[self kayokoTableViewFromTableView:tableView] displayedItems] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTableView *kayokoTableView = [self kayokoTableViewFromTableView:tableView];
    NSDictionary<NSString *, id> *dictionary = [kayokoTableView itemDictionaryAtIndexPath:indexPath];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
    KayokoTableViewCellContent *content = [[self cellContentProvider] cellContentForItem:item
                                                                        previewLineCount:[kayokoTableView previewLineCount]];

    KayokoTableViewCell *cell = [[KayokoTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                   content:content
                                                           reuseIdentifier:@"KayokoTableViewCell"];
    UILongPressGestureRecognizer *gesture =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
    [cell addGestureRecognizer:gesture];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];

    KayokoTableView *kayokoTableView = [self kayokoTableViewFromTableView:tableView];
    NSDictionary<NSString *, id> *dictionary = [kayokoTableView itemDictionaryAtIndexPath:indexPath];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
    [self performDirectPasteWithItem:item historyKey:[kayokoTableView historyKey]];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTableView *kayokoTableView = [self kayokoTableViewFromTableView:tableView];
    NSMutableArray<UIContextualAction *> *actions = [[NSMutableArray alloc] init];
    NSDictionary<NSString *, id> *dictionary = [kayokoTableView itemDictionaryAtIndexPath:indexPath];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

    UIContextualAction *moveAction = [self moveActionForItem:item dictionary:dictionary tableView:kayokoTableView indexPath:indexPath];
    if (moveAction) {
        [actions addObject:moveAction];
    }

    UIContextualAction *saveAction = [self saveActionForItem:item tableView:kayokoTableView];
    if (saveAction) {
        [actions addObject:saveAction];
    }

    UIContextualAction *linkAction = [self linkActionForItem:item];
    if (linkAction) {
        [actions addObject:linkAction];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTableView *kayokoTableView = [self kayokoTableViewFromTableView:tableView];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:[kayokoTableView itemDictionaryAtIndexPath:indexPath]];

    UIContextualAction *deleteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            BOOL maintainsSearchBarVisibility =
                                [self shouldMaintainSearchBarVisibilityAfterSwipeInTableView:kayokoTableView];
                            [self deleteItem:item historyKey:[kayokoTableView historyKey] completion:^(BOOL success) {
                              if (!success) {
                                  completionHandler(NO);
                                  return;
                              }
                              [kayokoTableView removeItemAtIndexPath:indexPath
                                                          completion:^(BOOL removed) {
                                                            if (removed) {
                                                                [[self delegate]
                                                                        tableViewController:self
                                                                    didChangeContentStateMaintainingSearchBarVisibility:
                                                                        maintainsSearchBarVisibility];
                                                            }
                                                            completionHandler(removed);
                                                          }];
                            }];
                          }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    [deleteAction setBackgroundColor:[UIColor systemRedColor]];
    return [UISwipeActionsConfiguration configurationWithActions:@[ deleteAction ]];
}

- (UIContextualAction *)moveActionForItem:(PasteboardItem *)item
                                dictionary:(NSDictionary<NSString *, id> *)dictionary
                                 tableView:(KayokoTableView *)tableView
                                 indexPath:(NSIndexPath *)indexPath {
    NSString *sourceHistoryKey = [tableView historyKey];
    BOOL sourceIsFavorites = [sourceHistoryKey isEqualToString:kHistoryKeyFavorites];
    NSString *destinationHistoryKey = sourceIsFavorites ? kHistoryKeyHistory : kHistoryKeyFavorites;
    NSString *imageName = sourceIsFavorites ? @"heart.slash.fill" : @"heart.fill";

    UIContextualAction *moveAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleDestructive
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            BOOL maintainsSearchBarVisibility =
                                [self shouldMaintainSearchBarVisibilityAfterSwipeInTableView:tableView];
                            [self moveItem:item
                                dictionary:dictionary
                          sourceHistoryKey:sourceHistoryKey
                     destinationHistoryKey:destinationHistoryKey
                                completion:^(BOOL success) {
                                  if (!success) {
                                      completionHandler(NO);
                                      return;
                                  }
                                  [tableView removeItemAtIndexPath:indexPath
                                                        completion:^(BOOL removed) {
                                                          if (removed) {
                                                              [[self delegate]
                                                                      tableViewController:self
                                                                  didChangeContentStateMaintainingSearchBarVisibility:
                                                                      maintainsSearchBarVisibility];
                                                          }
                                                          completionHandler(removed);
                                                        }];
                                }];
                          }];
    [moveAction setImage:[UIImage systemImageNamed:imageName]];
    [moveAction setBackgroundColor:[UIColor systemPinkColor]];
    return moveAction;
}

- (UIContextualAction *)saveActionForItem:(PasteboardItem *)item tableView:(KayokoTableView *)tableView {
    if (![tableView automaticallyPaste] && [[item imageName] length] == 0) {
        return nil;
    }

    BOOL savesImage = [[item imageName] length] > 0;
    UIContextualAction *saveAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            if (savesImage) {
                                [self saveImageForItem:item completion:completionHandler];
                            } else {
                                [self copyItem:item completion:completionHandler];
                            }
                          }];
    [saveAction setImage:[UIImage systemImageNamed:savesImage ? @"square.and.arrow.down.fill" : @"doc.on.doc.fill"]];
    [saveAction setBackgroundColor:[UIColor systemOrangeColor]];
    return saveAction;
}

- (UIContextualAction *)linkActionForItem:(PasteboardItem *)item {
    if (![item hasLink]) {
        return nil;
    }

    UIContextualAction *linkAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(__unused UIContextualAction *action, __unused __kindof UIView *sourceView,
                                    void (^completionHandler)(BOOL)) {
                            [self openLinkForItem:item completion:completionHandler];
                          }];
    [linkAction setImage:[UIImage systemImageNamed:@"arrow.up"]];
    [linkAction setBackgroundColor:[UIColor systemGreenColor]];
    return linkAction;
}

- (KayokoTableView *)tableViewForCell:(UIView *)view {
    UIView *candidate = view;
    while (candidate && ![candidate isKindOfClass:[KayokoTableView class]]) {
        candidate = [candidate superview];
    }
    return (KayokoTableView *)candidate;
}

- (void)handleLongPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([recognizer state] != UIGestureRecognizerStateBegan) {
        return;
    }

    KayokoTableView *tableView = [self tableViewForCell:[recognizer view]];
    NSIndexPath *indexPath = [tableView indexPathForCell:(UITableViewCell *)[recognizer view]];
    NSDictionary<NSString *, id> *dictionary = [tableView itemDictionaryAtIndexPath:indexPath];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
    if (item) {
        [[self delegate] tableViewController:self didRequestPreviewForItem:item];
    }
}

- (void)performDirectPasteWithItem:(PasteboardItem *)item historyKey:(NSString *)historyKey {
    if (!item) {
        return;
    }

    [[PasteboardManager sharedInstance] performDirectPasteWithPasteboardItem:item
                                                                 historyItem:item
                                                          fromHistoryWithKey:historyKey
                                                             shouldAutoPaste:YES];
    [[self delegate] tableViewControllerDidRequestHide:self];
}

- (void)copyItem:(PasteboardItem *)item completion:(void (^)(BOOL success))completion {
    BOOL copied = item && [[PasteboardManager sharedInstance] copyPasteboardItemToPasteboard:item];
    if (completion) {
        completion(copied);
    }
}

- (void)saveImageForItem:(PasteboardItem *)item completion:(void (^)(BOOL success))completion {
    UIImage *image = item ? [[PasteboardManager sharedInstance] getImageForItem:item] : nil;
    if (image) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
    }
    if (completion) {
        completion(image != nil);
    }
}

- (void)openLinkForItem:(PasteboardItem *)item completion:(void (^)(BOOL success))completion {
    NSURL *URL = [NSURL URLWithString:[item content] ?: @""];
    if (!URL) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[UIApplication sharedApplication] openURL:URL
                                       options:@{}
                             completionHandler:^(BOOL success) {
                               if (completion) {
                                   completion(success);
                               }
                             }];
}

- (void)deleteItem:(PasteboardItem *)item
        historyKey:(NSString *)historyKey
        completion:(void (^)(BOOL success))completion {
    if (!item || [historyKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[PasteboardManager sharedInstance] removePasteboardItem:item
                                          fromHistoryWithKey:historyKey
                                           shouldRemoveImage:YES
                                                  completion:completion];
}

- (void)moveItem:(PasteboardItem *)item
      dictionary:(NSDictionary<NSString *, id> *)dictionary
sourceHistoryKey:(NSString *)sourceHistoryKey
destinationHistoryKey:(NSString *)destinationHistoryKey
      completion:(void (^)(BOOL success))completion {
    if (!item || !dictionary || [sourceHistoryKey length] == 0 || [destinationHistoryKey length] == 0) {
        if (completion) {
            completion(NO);
        }
        return;
    }

    [[PasteboardManager sharedInstance] movePasteboardItem:item
                                        fromHistoryWithKey:sourceHistoryKey
                                          toHistoryWithKey:destinationHistoryKey
                                                completion:^(BOOL success) {
                                                  if (success) {
                                                      [[self delegate] tableViewController:self
                                                                     didMoveItemDictionary:dictionary
                                                                        fromHistoryWithKey:sourceHistoryKey
                                                                          toHistoryWithKey:destinationHistoryKey];
                                                  }
                                                  if (completion) {
                                                      completion(success);
                                                  }
                                                }];
}

@end
