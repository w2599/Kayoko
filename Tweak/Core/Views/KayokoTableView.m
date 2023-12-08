//
//  KayokoTableView.m
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import "KayokoTableView.h"

@implementation KayokoTableView
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
        [self setRowHeight:65];
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
    NSDictionary* dictionary = [self items][[indexPath row]];
    PasteboardItem* item = [PasteboardItem itemFromDictionary:dictionary];

    KayokoTableViewCell* cell = [[KayokoTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault andItem:item reuseIdentifier:@"KayokoTableViewCell"];

    // Add long press gesture recognizer to preview the cell's content.
    UILongPressGestureRecognizer* gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
    [cell addGestureRecognizer:gesture];

    return cell;
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

    NSDictionary* dictionary = [self items][[indexPath row]];
    PasteboardItem* item = [PasteboardItem itemFromDictionary:dictionary];
    [[PasteboardManager sharedInstance] updatePasteboardWithItem:item fromHistoryWithKey:kHistoryKeyHistory shouldAutoPaste:YES];

    [[self superview] performSelector:@selector(hide)];
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
        KayokoTableViewCell* cell = (KayokoTableViewCell *)[recognizer view];
        NSIndexPath* indexPath = [self indexPathForCell:cell];

        NSDictionary* dictionary = [self items][[indexPath row]];
        PasteboardItem* item = [PasteboardItem itemFromDictionary:dictionary];

        [[self superview] performSelector:@selector(showPreviewWithItem:) withObject:item];
    }
}

/**
 * Reloads the table view with new items.
 *
 * @param items The new items to laod.
 */
- (void)reloadDataWithItems:(NSArray *)items {
    [self setItems:items];
    [self reloadData];
}

/**
 * Removes all items for a specified history.
 *
 * @param key The key for the history which to clear.
 */
- (void)clearHistoryWithKey:(NSString *)key {
    [[self superview] performSelector:@selector(hide)];

    UIAlertController* clearAlert = [UIAlertController alertControllerWithTitle:@"Kayoko" message:[NSString stringWithFormat:@"This will clear your %@.", key] preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction* yesAction = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDestructive handler:^(UIAlertAction* action) {
        [[self superview] performSelector:@selector(show)];

        for (NSDictionary* dictionary in [self items]) {
            PasteboardItem* item = [PasteboardItem itemFromDictionary:dictionary];
            [[PasteboardManager sharedInstance] removePasteboardItem:item fromHistoryWithKey:key shouldRemoveImage:YES];
        }
	}];

	UIAlertAction* noAction = [UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {
        [[self superview] performSelector:@selector(show)];
    }];

	[clearAlert addAction:yesAction];
	[clearAlert addAction:noAction];

	[[[[UIApplication sharedApplication] keyWindow] rootViewController] presentViewController:clearAlert animated:YES completion:nil];
}
@end
