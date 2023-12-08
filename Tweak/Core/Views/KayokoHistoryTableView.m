//
//  KayokoHistoryTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoHistoryTableView.h"

@implementation KayokoHistoryTableView
/**
 * Sets up the swipe actions on the left.
 *
 * @param tableView
 * @param indexPath
 */
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray* actions = [[NSMutableArray alloc] init];
    PasteboardItem* item = [PasteboardItem itemFromDictionary:[self items][[indexPath row]]];

    UIContextualAction* favoriteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [[PasteboardManager sharedInstance] addPasteboardItem:item toHistoryWithKey:kHistoryKeyFavorites];
        [[PasteboardManager sharedInstance] removePasteboardItem:item fromHistoryWithKey:kHistoryKeyHistory shouldRemoveImage:NO];
        completionHandler(YES);
    }];
    [favoriteAction setImage:[UIImage systemImageNamed:@"heart.fill"]];
    [favoriteAction setBackgroundColor:[UIColor systemPinkColor]];
    [actions addObject:favoriteAction];

    // If automatic paste is enabled and the item has text, add an option to only copy the contents without pasting.
    // If the item has an image we want to instead add an option to save the image to the photo library.
    if ([self automaticallyPaste] || [item hasImage]) {
        UIContextualAction* saveAction;

        if (![item hasImage]) {
            saveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
                [[UIPasteboard generalPasteboard] setString:[item content]];
                completionHandler(YES);
            }];
            [saveAction setImage:[UIImage systemImageNamed:@"doc.on.doc.fill"]];
        } else {
            saveAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
                UIImageWriteToSavedPhotosAlbum([[PasteboardManager sharedInstance] imageForItem:item], nil, nil, nil);
                completionHandler(YES);
            }];
            [saveAction setImage:[UIImage systemImageNamed:@"square.and.arrow.down.fill"]];
        }

        [saveAction setBackgroundColor:[UIColor systemOrangeColor]];
        [actions addObject:saveAction];
    }

    if ([item hasLink]) {
        UIContextualAction* linkAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[item content]] options:@{} completionHandler:nil];
            completionHandler(YES);
        }];
        [linkAction setImage:[UIImage systemImageNamed:@"arrow.up"]];
        [linkAction setBackgroundColor:[UIColor systemGreenColor]];
        [actions addObject:linkAction];
    }

    if ([self addSongDotLinkOption] && [item hasMusicLink]) {
        UIContextualAction* songDotLinkAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [[PasteboardManager sharedInstance] addSongDotLinkItemFromItem:item];
            completionHandler(YES);
        }];
        [songDotLinkAction setImage:[UIImage systemImageNamed:@"music.note"]];
        [songDotLinkAction setBackgroundColor:[UIColor systemPurpleColor]];
        [actions addObject:songDotLinkAction];
    }

    if ([self addTranslateOption] && [item hasPlainText]) {
        UIContextualAction* translateAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
            [[PasteboardManager sharedInstance] addTranslateItemFromItem:item];
            completionHandler(YES);
        }];
        [translateAction setImage:[UIImage systemImageNamed:@"globe"]];
        [translateAction setBackgroundColor:[UIColor systemBlueColor]];
        [actions addObject:translateAction];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

/**
 * Sets up the swipe actions on the right.
 *
 * @param tableView
 * @param indexPath
 */
- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray* actions = [[NSMutableArray alloc] init];
    PasteboardItem* item = [PasteboardItem itemFromDictionary:[self items][[indexPath row]]];

    UIContextualAction* deleteAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"" handler:^(UIContextualAction* _Nonnull action, __kindof UIView* _Nonnull sourceView, void (^ _Nonnull completionHandler)(BOOL)) {
        [[PasteboardManager sharedInstance] removePasteboardItem:item fromHistoryWithKey:kHistoryKeyHistory shouldRemoveImage:YES];
        completionHandler(YES);
    }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    [deleteAction setBackgroundColor:[UIColor systemRedColor]];
    [actions addObject:deleteAction];

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}
@end
