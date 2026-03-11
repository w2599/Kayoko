//
//  KayokoTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableView.h"
#import "KayokoTableViewCell.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

#import <objc/runtime.h>

static CGFloat const kKayokoTableViewRowHeight = 46.6;
static CGFloat const kKayokoSearchBarHeight = 44.0;

@interface KayokoTableView ()
@property(nonatomic, assign) BOOL didHideSearchHeader;
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)sharedInstance;
- (void)showTokenSelectionPopup:(NSString *)text;
@end

@implementation KayokoTableView

- (void)presentTokenSelectionPopupForText:(NSString *)text {
    NSString *trimmedText = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![trimmedText length]) {
        return;
    }

    if ([[self superview] respondsToSelector:@selector(hide)]) {
        [[self superview] performSelector:@selector(hide)];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.34 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        Class keyboardImplClass = objc_getClass("UIKeyboardImpl");
        UIKeyboardImpl *keyboardImpl = nil;

        if ([keyboardImplClass respondsToSelector:@selector(sharedInstance)]) {
            keyboardImpl = [keyboardImplClass sharedInstance];
        }
        if (keyboardImpl && [keyboardImpl respondsToSelector:@selector(showTokenSelectionPopup:)]) {
            [keyboardImpl showTokenSelectionPopup:trimmedText];
        }
    });
}

- (UIContextualAction *)tokenSelectionActionForItem:(PasteboardItem *)item {
    NSString *text = [[item content] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![text length] || ![[item imageName] isEqualToString:@""]) {
        return nil;
    }

    __weak typeof(self) weakSelf = self;
    UIContextualAction *tokenAction = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal
                                                                              title:@""
                                                                            handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                                                                      void (^_Nonnull completionHandler)(BOOL)) {
                                                                              completionHandler(YES);
                                                                              __strong typeof(weakSelf) strongSelf = weakSelf;
                                                                              if (!strongSelf) {
                                                                                  return;
                                                                              }

                                                                              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                                                                  [strongSelf presentTokenSelectionPopupForText:text];
                                                                              });
                                                                            }];
    [tokenAction setImage:[UIImage systemImageNamed:@"textformat"]];
    [tokenAction setBackgroundColor:[UIColor systemTealColor]];
    return tokenAction;
}

- (void)layoutSubviews {
    [super layoutSubviews];

    // UITableView 的 tableHeaderView 不会自动跟随 AutoLayout 调整宽度；手动同步。
    if ([self searchBar]) {
        CGRect frame = [[self searchBar] frame];
        CGFloat width = [self bounds].size.width;
        if (width > 0 && fabs(frame.size.width - width) > 0.5) {
            frame.size.width = width;
            [[self searchBar] setFrame:frame];
            // 重新赋值触发布局刷新。
            [self setTableHeaderView:[self searchBar]];
        }
    }

    [self hideSearchHeaderIfNeededAnimated:NO];
}

- (void)configureSearchBarIfNeeded {
    if ([self searchBar]) {
        return;
    }

    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 0, kKayokoSearchBarHeight)];
    [searchBar setSearchBarStyle:UISearchBarStyleMinimal];
    [searchBar setAutocapitalizationType:UITextAutocapitalizationTypeNone];
    [searchBar setAutocorrectionType:UITextAutocorrectionTypeNo];
    [searchBar setReturnKeyType:UIReturnKeyDone];
    [searchBar setEnablesReturnKeyAutomatically:YES];
    [searchBar setDelegate:self];

    NSString *placeholder = [[PasteboardManager localizationBundle] localizedStringForKey:@"Search"
                                                                                   value:@"Search"
                                                                                   table:@"Tweak"];
    [searchBar setPlaceholder:placeholder];

    [searchBar sizeToFit];
    [self setSearchBar:searchBar];
    [self setTableHeaderView:searchBar];
}

- (void)hideSearchHeaderIfNeededAnimated:(BOOL)animated {
    if ([self didHideSearchHeader] || ![self searchBar]) {
        return;
    }

    CGFloat height = [[self searchBar] bounds].size.height;
    if (height <= 0) {
        return;
    }

    // 把搜索栏先“藏起来”，用户下拉即可露出并搜索。
    [self setDidHideSearchHeader:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
        // 如果用户已经在滚动/交互，不强行修改。
        if ([self isDragging] || [self isDecelerating]) {
            return;
        }
        [self setContentOffset:CGPointMake(0, height) animated:animated];
    });
}

- (BOOL)dictionary:(NSDictionary *)dictionary matchesSearchText:(NSString *)searchText {
    if (!dictionary || ![searchText length]) {
        return YES;
    }

    NSString *content = dictionary[kItemKeyContent] ?: @"";
    NSString *bundleIdentifier = dictionary[kItemKeyBundleIdentifier] ?: @"";

    NSRange contentRange = [content rangeOfString:searchText options:NSCaseInsensitiveSearch];
    if (contentRange.location != NSNotFound) {
        return YES;
    }

    NSRange bundleRange = [bundleIdentifier rangeOfString:searchText options:NSCaseInsensitiveSearch];
    return bundleRange.location != NSNotFound;
}

- (void)applyFilterForSearchText:(NSString *)searchText {
    NSString *trimmed = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![trimmed length]) {
        [self setItems:[self allItems] ?: @[]];
        [self reloadData];
        return;
    }

    NSMutableArray *filtered = [[NSMutableArray alloc] init];
    for (NSDictionary *dictionary in ([self allItems] ?: @[])) {
        if ([self dictionary:dictionary matchesSearchText:trimmed]) {
            [filtered addObject:dictionary];
        }
    }
    [self setItems:filtered];
    [self reloadData];
}

/**
 * Initializes the table view.
 *
 * @param name The associated name with the table view that's displayed on the main view.
 */
- (instancetype)initWithName:(NSString *)name {
    self = [super init];

    if (self) {
        [self setName:name];
        [self setDelegate:self];
        [self setDataSource:self];
        [self setBackgroundColor:[UIColor clearColor]];
        [self setRowHeight:kKayokoTableViewRowHeight];

        [self configureSearchBarIfNeeded];
    }

    return self;
}

/**
 * Defines how many rows are in the table view.
 *
 * @param tableView
 * @param section
 */
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self items] count] ?: 0;
}

/**
 * Styles the table view cells.
 *
 * @param tableView
 * @param indexPath
 */
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

    KayokoTableViewCell *cell = [[KayokoTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                                   andItem:item
                                    showRecordedTime:[self showRecordedTime]
                                                           reuseIdentifier:@"KayokoTableViewCell"];

    // Add long press gesture recognizer to preview the cell's content.
    UILongPressGestureRecognizer *gesture =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
    [cell addGestureRecognizer:gesture];

    return cell;
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applyFilterForSearchText:searchText];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar setText:@""];
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    [self applyFilterForSearchText:@""];
    [self hideSearchHeaderIfNeededAnimated:YES];
}

/**
 * Handles table view cell selection.
 *
 * it creates a dictionary from the cell's row index.
 * Then it creates a pasteboard item from the dictionary and updates the pasteboard with it.
 *
 * @param tableView
 * @param indexPath
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];

    NSDictionary *dictionary = [self items][[indexPath row]];
    PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];
    [[PasteboardManager sharedInstance] updatePasteboardWithItem:item
                                              fromHistoryWithKey:kHistoryKeyHistory
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
    PasteboardItem *item = [PasteboardItem itemFromDictionary:[self items][[indexPath row]]];

    // If automatic paste is enabled and the item has text, add an option to only copy the contents without pasting.
    // If the item has an image we want to instead add an option to save the image to the photo library.
    if ([self automaticallyPaste] || ![[item imageName] isEqualToString:@""]) {
        UIContextualAction *saveAction;

        if ([[item imageName] isEqualToString:@""]) {
            saveAction = [UIContextualAction
                contextualActionWithStyle:UIContextualActionStyleNormal
                                    title:@""
                                  handler:^(UIContextualAction *_Nonnull action, __kindof UIView *_Nonnull sourceView,
                                            void (^_Nonnull completionHandler)(BOOL)) {
                                    [[UIPasteboard generalPasteboard] setString:[item content]];
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
        [actions addObject:tokenAction];
    }

    return [UISwipeActionsConfiguration configurationWithActions:actions];
}

/**
 * Handles the long press gesture for the preview.
 *
 * It creates a dictionary from the cell's content and sends it to the main view to preview it.
 *
 * @param recognizer The long press gesture recognizer.
 */
- (void)handleLongPressGestureRecognizer:(UILongPressGestureRecognizer *)recognizer {
    if ([recognizer state] == UIGestureRecognizerStateBegan) {
        KayokoTableViewCell *cell = (KayokoTableViewCell *)[recognizer view];
        NSIndexPath *indexPath = [self indexPathForCell:cell];

        NSDictionary *dictionary = [self items][[indexPath row]];
        PasteboardItem *item = [PasteboardItem itemFromDictionary:dictionary];

        [[self superview] performSelector:@selector(showPreviewWithItem:) withObject:item];
    }
}

/**
 * Reloads the table view with new items.
 *
 * @param items The new items to laod.
 */
- (void)reloadDataWithItems:(NSArray *)items {
    NSArray *safeItems = items ?: @[];
    [self setAllItems:safeItems];

    // 刷新数据时，重置搜索状态。
    if ([self searchBar]) {
        [[self searchBar] setText:@""];
        [[self searchBar] setShowsCancelButton:NO animated:NO];
        [[self searchBar] resignFirstResponder];
    }

    [self setItems:safeItems];
    [self reloadData];

    // 允许再次“下拉出现”。
    [self setDidHideSearchHeader:NO];
    [self hideSearchHeaderIfNeededAnimated:NO];
}

- (void)removeItemDictionaryFromAllItems:(NSDictionary *)dictionary {
    if (!dictionary) {
        return;
    }

    NSMutableArray *allItems = [[self allItems] mutableCopy] ?: [[NSMutableArray alloc] init];
    NSUInteger idx = [allItems indexOfObject:dictionary];
    if (idx != NSNotFound) {
        [allItems removeObjectAtIndex:idx];
        [self setAllItems:allItems];
    }
}

@end
