//
//  KayokoFavoritesTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoFavoritesTableView.h"
#import "KayokoTableViewCell.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

@interface KayokoFavoritesTableView ()
@property(nonatomic, strong) UIWindow *remarkAlertWindow;
@property(nonatomic, weak) UIWindow *previousKeyWindow;
@end

@implementation KayokoFavoritesTableView

- (UIWindow *)currentKeyWindow {
  if (@available(iOS 13.0, *)) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
      if ([scene activationState] != UISceneActivationStateForegroundActive ||
        ![scene isKindOfClass:[UIWindowScene class]]) {
        continue;
      }

      UIWindowScene *windowScene = (UIWindowScene *)scene;
      for (UIWindow *window in [windowScene windows]) {
        if ([window isKeyWindow]) {
          return window;
        }
      }
    }
  }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  return [UIApplication sharedApplication].keyWindow;
#pragma clang diagnostic pop
}

- (UIWindowScene *)activeWindowScene {
  if (@available(iOS 13.0, *)) {
    if ([[self window] windowScene]) {
      return [[self window] windowScene];
    }

    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
      if ([scene activationState] == UISceneActivationStateForegroundActive &&
        [scene isKindOfClass:[UIWindowScene class]]) {
        return (UIWindowScene *)scene;
      }
    }
  }

  return nil;
}

- (void)cleanupRemarkAlertWindow {
  UIWindow *window = [self remarkAlertWindow];
  if (!window) {
    return;
  }

  [window setHidden:YES];
  [window setRootViewController:nil];
  [self setRemarkAlertWindow:nil];

  UIWindow *previousKeyWindow = [self previousKeyWindow];
  if (previousKeyWindow) {
    [previousKeyWindow makeKeyWindow];
  }
  [self setPreviousKeyWindow:nil];
}

- (UIViewController *)topMostViewController {
  UIWindow *keyWindow = nil;

  if (@available(iOS 13.0, *)) {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
      if ([scene activationState] == UISceneActivationStateForegroundActive &&
        [scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in [windowScene windows]) {
          if ([window isKeyWindow]) {
            keyWindow = window;
            break;
          }
        }
      }

      if (keyWindow) {
        break;
      }
    }
  }

  if (!keyWindow) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    keyWindow = [UIApplication sharedApplication].keyWindow;
    #pragma clang diagnostic pop
  }

  UIViewController *controller = [keyWindow rootViewController];
  while ([controller presentedViewController]) {
    controller = [controller presentedViewController];
  }

  return controller;
}

- (void)updateLocalRemark:(NSString *)remark forDictionary:(NSDictionary *)dictionary atIndexPath:(NSIndexPath *)indexPath {
  NSMutableDictionary *updatedDictionary = [dictionary mutableCopy];
  updatedDictionary[kItemKeyRemark] = remark ?: @"";

  NSMutableArray *items = [[self items] mutableCopy] ?: [[NSMutableArray alloc] init];
  if ([indexPath row] < [items count]) {
    items[[indexPath row]] = updatedDictionary;
    [self setItems:items];
  }

  NSMutableArray *allItems = [[self allItems] mutableCopy] ?: [[NSMutableArray alloc] init];
  NSUInteger allItemsIndex = [allItems indexOfObject:dictionary];

  if (allItemsIndex == NSNotFound) {
    NSString *targetContent = dictionary[kItemKeyContent] ?: @"";
    for (NSUInteger idx = 0; idx < [allItems count]; idx++) {
      NSDictionary *candidate = allItems[idx];
      NSString *candidateContent = candidate[kItemKeyContent] ?: @"";
      if ([candidateContent isEqualToString:targetContent]) {
        allItemsIndex = idx;
        break;
      }
    }
  }

  if (allItemsIndex != NSNotFound) {
    allItems[allItemsIndex] = updatedDictionary;
    [self setAllItems:allItems];
  }

  [self reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
}

- (void)presentRemarkAlertForItem:(PasteboardItem *)item
             dictionary:(NSDictionary *)dictionary
            atIndexPath:(NSIndexPath *)indexPath {
  NSBundle *bundle = [PasteboardManager localizationBundle];
  NSString *title = [bundle localizedStringForKey:@"Remark" value:nil table:@"Tweak"];
  NSString *message = [bundle localizedStringForKey:@"Edit remark" value:nil table:@"Tweak"];
  NSString *cancelTitle = [bundle localizedStringForKey:@"Cancel" value:nil table:@"Tweak"];
  NSString *saveTitle = [bundle localizedStringForKey:@"Save" value:nil table:@"Tweak"];
  NSString *placeholder = [bundle localizedStringForKey:@"Enter remark" value:nil table:@"Tweak"];

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                   message:message
                              preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField *_Nonnull textField) {
    [textField setPlaceholder:placeholder];
    [textField setClearButtonMode:UITextFieldViewModeWhileEditing];
    [textField setText:[item remark] ?: @""];
  }];

  __weak typeof(self) weakSelf = self;
  [alert addAction:[UIAlertAction actionWithTitle:cancelTitle
                        style:UIAlertActionStyleCancel
                      handler:^(UIAlertAction *_Nonnull action) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        [strongSelf cleanupRemarkAlertWindow];
                      }]];
  [alert addAction:[UIAlertAction actionWithTitle:saveTitle
                        style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction *_Nonnull action) {
                        __strong typeof(weakSelf) strongSelf = weakSelf;
                        if (!strongSelf) {
                          return;
                        }

                        NSString *remark = [alert.textFields.firstObject.text
                          stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                        [[PasteboardManager sharedInstance] updateRemark:remark
                                             forItem:item
                                        inHistoryWithKey:kHistoryKeyFavorites];
                        [strongSelf updateLocalRemark:remark forDictionary:dictionary atIndexPath:indexPath];
                        [strongSelf cleanupRemarkAlertWindow];
                      }]];

  UIWindow *alertWindow = nil;
  if (@available(iOS 13.0, *)) {
    UIWindowScene *windowScene = [self activeWindowScene];
    if (windowScene) {
      alertWindow = [[UIWindow alloc] initWithWindowScene:windowScene];
    }
  }

  if (!alertWindow) {
    alertWindow = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  }

  [self setPreviousKeyWindow:[self currentKeyWindow]];
  [alertWindow setFrame:[[UIScreen mainScreen] bounds]];
  [alertWindow setWindowLevel:UIWindowLevelAlert + 10086];
  [alertWindow setBackgroundColor:[UIColor clearColor]];

  UIViewController *hostController = [[UIViewController alloc] init];
  [[hostController view] setBackgroundColor:[UIColor clearColor]];
  [alertWindow setRootViewController:hostController];
  [self setRemarkAlertWindow:alertWindow];
  [alertWindow makeKeyAndVisible];
  [hostController presentViewController:alert animated:YES completion:nil];
}

/**
 * Handles table view cell selection.
 *
 * For favorites, updating the pasteboard should not create a new history entry.
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  KayokoTableViewCell *cell = (KayokoTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
  [cell setSelected:NO animated:YES];

  NSDictionary *dictionary = [self items][[indexPath row]];
  PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
  [[PasteboardManager sharedInstance] updatePasteboardWithItem:item
                        fromHistoryWithKey:kHistoryKeyFavorites
                         shouldAutoPaste:YES];

  [[self superview] performSelector:@selector(hide)];
}

/**
 * Sets up the swipe actions on the left.
 *
 * @param tableView
 * @param indexPath
 */
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSMutableArray *actions = [[NSMutableArray alloc] init];
    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

    UIContextualAction *unfavoriteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                    void (^_Nonnull completionHandler)(BOOL)) {
                            [self
                                performBatchUpdates:^{
                                  [self deleteRowsAtIndexPaths:@[ indexPath ]
                                              withRowAnimation:UITableViewRowAnimationRight];
                                  NSMutableArray *items = [[self items] mutableCopy];
                                  [items removeObjectAtIndex:[indexPath row]];
                                  [self setItems:items];
                                  [self removeItemDictionaryFromAllItems:dictionary];
                                }
                                completion:^(BOOL finished) {
                                  [[PasteboardManager sharedInstance] removePasteboardItem:item
                                                                        fromHistoryWithKey:kHistoryKeyFavorites
                                                                         shouldRemoveImage:NO];
                                  completionHandler(YES);
                                }];
                          }];
    [unfavoriteAction setImage:[UIImage systemImageNamed:@"heart.slash.fill"]];
    [unfavoriteAction setBackgroundColor:[UIColor systemPinkColor]];
    NSUInteger unfavoriteActionIndex = [actions count] > 0 ? 1 : 0;
    [actions insertObject:unfavoriteAction atIndex:unfavoriteActionIndex];

    // Match base table behavior (copy/link actions), but ensure favorites content does not enter history.
    if ([self automaticallyPaste] || ![[item imageName] isEqualToString:@""]) {
        UIContextualAction *saveAction;

        if ([[item imageName] isEqualToString:@""]) {
            saveAction = [UIContextualAction
                contextualActionWithStyle:UIContextualActionStyleNormal
                                    title:@""
                                  handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                            void (^_Nonnull completionHandler)(BOOL)) {
                                    [[PasteboardManager sharedInstance] updatePasteboardWithItem:item
                                                                              fromHistoryWithKey:kHistoryKeyFavorites
                                                                                 shouldAutoPaste:NO];
                                    completionHandler(YES);
                                  }];
            [saveAction setImage:[UIImage systemImageNamed:@"doc.on.doc.fill"]];
        } else {
            saveAction = [UIContextualAction
                contextualActionWithStyle:UIContextualActionStyleNormal
                                    title:@""
                                  handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                            void (^_Nonnull completionHandler)(BOOL)) {
                                    UIImageWriteToSavedPhotosAlbum(
                                        [[PasteboardManager sharedInstance] getImageForItem:item], nil, nil, nil);
                                    completionHandler(YES);
                                  }];
            [saveAction setImage:[UIImage systemImageNamed:@"square.and.arrow.down.fill"]];
        }

        [saveAction setBackgroundColor:[UIColor systemOrangeColor]];
        [actions addObject:saveAction];
    }

    if ([item hasLink]) {
        UIContextualAction *linkAction = [UIContextualAction
            contextualActionWithStyle:UIContextualActionStyleNormal
                                title:@""
                              handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                        void (^_Nonnull completionHandler)(BOOL)) {
                                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[item content]]
                                                                   options:@{}
                                                         completionHandler:nil];
                                completionHandler(YES);
                              }];
        [linkAction setImage:[UIImage systemImageNamed:@"arrow.up"]];
        [linkAction setBackgroundColor:[UIColor systemGreenColor]];
        [actions addObject:linkAction];
    }

    UIContextualAction *tokenAction = [self tokenSelectionActionForItem:item];
    if (tokenAction) {
        [actions insertObject:tokenAction atIndex:0];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

/**
 * Sets up the swipe actions on the right.
 *
 * @param tableView
 * @param indexPath
 */
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray *actions = [[NSMutableArray alloc] init];
    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

    UIContextualAction *deleteAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                    void (^_Nonnull completionHandler)(BOOL)) {
                            [self
                                performBatchUpdates:^{
                                  [self deleteRowsAtIndexPaths:@[ indexPath ]
                                              withRowAnimation:UITableViewRowAnimationLeft];
                                  NSMutableArray *items = [[self items] mutableCopy];
                                  [items removeObjectAtIndex:[indexPath row]];
                                  [self setItems:items];
                                  [self removeItemDictionaryFromAllItems:dictionary];
                                }
                                completion:^(BOOL finished) {
                                  [[PasteboardManager sharedInstance] removePasteboardItem:item
                                                                        fromHistoryWithKey:kHistoryKeyFavorites
                                                                         shouldRemoveImage:YES];
                                  completionHandler(YES);
                                }];
                          }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    [deleteAction setBackgroundColor:[UIColor systemRedColor]];
    [actions addObject:deleteAction];

    UIContextualAction *remarkAction = [UIContextualAction
        contextualActionWithStyle:UIContextualActionStyleNormal
                            title:@""
                          handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                    void (^_Nonnull completionHandler)(BOOL)) {
                            completionHandler(YES);
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                                           dispatch_get_main_queue(), ^{
                                             [self presentRemarkAlertForItem:item
                                                                  dictionary:dictionary
                                                                 atIndexPath:indexPath];
                                           });
                          }];
    [remarkAction setImage:[UIImage systemImageNamed:@"square.and.pencil"]];
    [remarkAction setBackgroundColor:[UIColor systemBlueColor]];
    [actions addObject:remarkAction];

    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:actions];
    [configuration setPerformsFirstActionWithFullSwipe:NO];
    return configuration;
}
@end
