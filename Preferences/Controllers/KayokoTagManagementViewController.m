//
//  KayokoTagManagementViewController.m
//  Kayoko
//

#import "KayokoTagManagementViewController.h"
#import "KayokoTagEditorViewController.h"
#import "KayokoTagTableViewCell.h"
#import "KayokoTag.h"
#import "KayokoTagStore.h"

#import <UIKit/UIKit.h>

static NSString *const kKayokoTagCellReuseIdentifier = @"KayokoTagCell";

@interface KayokoTagManagementViewController () <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating,
                                                 UISearchControllerDelegate>
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UISearchController *searchController;
@property(nonatomic, strong) NSMutableArray<KayokoTag *> *tags;
@property(nonatomic, strong) NSMutableArray<KayokoTag *> *filteredTags;
@property(nonatomic, strong) NSMutableSet<NSString *> *selectedTagUUIDs;
@property(nonatomic, strong) KayokoTagStore *tagStore;
@property(nonatomic, strong) NSBundle *localizationBundle;
@end

@implementation KayokoTagManagementViewController

- (void)loadView {
    UIView *view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [view setBackgroundColor:[UIColor systemGroupedBackgroundColor]];
    [self setView:view];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _localizationBundle = [NSBundle bundleForClass:[self class]];
    _selectedTagUUIDs = [[NSMutableSet alloc] init];
    _filteredTags = [[NSMutableArray alloc] init];
    _tagStore = [[KayokoTagStore alloc] initWithTagsPath:[KayokoTagStore defaultTagsPath]
                                      localizationBundle:_localizationBundle];

    [self setTitle:[self localizedStringForKey:@"Tags"]];
    [self loadTags];
    [self configureNavigationItem];
    [self configureSearchController];
    [self configureTableView];
    [self updateToolbarItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[self navigationController] setToolbarHidden:NO animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if ([self isMovingFromParentViewController] || [[self navigationController] isBeingDismissed]) {
        [[self navigationController] setToolbarHidden:YES animated:animated];
    }
}

- (void)loadTags {
    NSError *error = nil;
    NSMutableArray<KayokoTag *> *loadedTags = [[self tagStore] loadTagsWithError:&error];
    if (!loadedTags) {
        _tags = [[NSMutableArray alloc] init];
        [self presentError:error];
        return;
    }

    _tags = loadedTags;
}

- (void)configureNavigationItem {
    [[self navigationItem] setLargeTitleDisplayMode:UINavigationItemLargeTitleDisplayModeNever];
    [[self navigationItem] setRightBarButtonItem:[self editDoneButton]];
}

- (UIBarButtonItem *)editDoneButton {
    NSString *title = [self localizedStringForKey:[self isEditing] ? @"Done" : @"Edit"];
    UIBarButtonItemStyle style = [self isEditing] ? UIBarButtonItemStyleDone : UIBarButtonItemStylePlain;
    return [[UIBarButtonItem alloc] initWithTitle:title style:style target:self action:@selector(toggleEditing)];
}

- (void)configureSearchController {
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    [_searchController setSearchResultsUpdater:self];
    [_searchController setDelegate:self];
    [_searchController setObscuresBackgroundDuringPresentation:NO];
    [_searchController setHidesNavigationBarDuringPresentation:NO];
    [[_searchController searchBar] setPlaceholder:[self localizedStringForKey:@"Search Tags…"]];

    [self setDefinesPresentationContext:YES];
    [[self navigationItem] setSearchController:_searchController];
    [[self navigationItem] setHidesSearchBarWhenScrolling:YES];
}

- (void)configureTableView {
    _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    [_tableView setTranslatesAutoresizingMaskIntoConstraints:NO];
    [_tableView setDataSource:self];
    [_tableView setDelegate:self];
    [_tableView setRowHeight:58.0];
    [_tableView setAllowsSelection:YES];
    [_tableView setAllowsMultipleSelectionDuringEditing:YES];
    [_tableView registerClass:[KayokoTagTableViewCell class] forCellReuseIdentifier:kKayokoTagCellReuseIdentifier];
    [[self view] addSubview:_tableView];

    [NSLayoutConstraint activateConstraints:@[
        [[_tableView topAnchor] constraintEqualToAnchor:[[self view] topAnchor]],
        [[_tableView leadingAnchor] constraintEqualToAnchor:[[self view] leadingAnchor]],
        [[_tableView trailingAnchor] constraintEqualToAnchor:[[self view] trailingAnchor]],
        [[_tableView bottomAnchor] constraintEqualToAnchor:[[self view] bottomAnchor]]
    ]];
}

- (void)toggleEditing {
    [self setEditing:![self isEditing] animated:YES];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    [[self tableView] setEditing:editing animated:animated];
    [[self navigationItem] setRightBarButtonItem:[self editDoneButton] animated:animated];

    if (!editing) {
        [[self selectedTagUUIDs] removeAllObjects];
        for (NSIndexPath *indexPath in [[self tableView] indexPathsForSelectedRows]) {
            [[self tableView] deselectRowAtIndexPath:indexPath animated:animated];
        }
    }

    [self updateToolbarItems];
}

#pragma mark - Toolbar

- (void)updateToolbarItems {
    UIBarButtonItem *flexibleSpace =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    if (![self isEditing]) {
        UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Add"]
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(addTag)];
        [self setToolbarItems:@[ flexibleSpace, addButton ] animated:YES];
        return;
    }

    NSString *selectTitle = [self allDisplayedTagsSelected] ? [self localizedStringForKey:@"Deselect All"]
                                                            : [self localizedStringForKey:@"Select All"];
    UIBarButtonItem *selectButton = [[UIBarButtonItem alloc] initWithTitle:selectTitle
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(toggleSelectAll)];
    UIBarButtonItem *deleteButton = [[UIBarButtonItem alloc] initWithTitle:[self localizedStringForKey:@"Delete"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(deleteSelectedTags)];
    [deleteButton setTintColor:[UIColor systemRedColor]];
    [deleteButton setEnabled:[[self selectedTagUUIDs] count] > 0];
    [self setToolbarItems:@[ selectButton, flexibleSpace, deleteButton ] animated:YES];
}

#pragma mark - Actions

- (void)addTag {
    if ([self isFiltering]) {
        [[[self searchController] searchBar] setText:@""];
        [[self searchController] setActive:NO];
        [self refreshFilteredTags];
        [[self tableView] reloadData];
    }

    KayokoTag *tag = [KayokoTag tagWithTitle:[self localizedStringForKey:@"Untitled"] hexColor:@"#00000000"];
    NSMutableArray<KayokoTag *> *updatedTags = [[self tags] mutableCopy];
    [updatedTags addObject:tag];
    if (![self saveTags:updatedTags]) {
        return;
    }

    NSUInteger insertedIndex = [updatedTags count] - 1;
    [self setTags:updatedTags];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:insertedIndex inSection:0];
    [[self tableView] insertRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [[self tableView] scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)toggleSelectAll {
    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    if ([displayedTags count] == 0) {
        return;
    }

    BOOL shouldDeselect = [self allDisplayedTagsSelected];
    for (NSUInteger index = 0; index < [displayedTags count]; index++) {
        KayokoTag *tag = displayedTags[index];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        if (shouldDeselect) {
            [[self selectedTagUUIDs] removeObject:[tag uuid]];
            [[self tableView] deselectRowAtIndexPath:indexPath animated:YES];
        } else {
            [[self selectedTagUUIDs] addObject:[tag uuid]];
            [[self tableView] selectRowAtIndexPath:indexPath
                                          animated:YES
                                    scrollPosition:UITableViewScrollPositionNone];
        }
    }
    [self updateToolbarItems];
}

- (void)deleteSelectedTags {
    if ([[self selectedTagUUIDs] count] == 0) {
        return;
    }

    NSSet<NSString *> *selectedUUIDs = [[self selectedTagUUIDs] copy];
    NSArray<KayokoTag *> *displayedTagsBeforeDeletion = [[self displayedTags] copy];
    NSMutableArray<NSIndexPath *> *deletedIndexPaths = [[NSMutableArray alloc] init];
    for (NSUInteger index = 0; index < [displayedTagsBeforeDeletion count]; index++) {
        KayokoTag *tag = displayedTagsBeforeDeletion[index];
        if ([selectedUUIDs containsObject:[tag uuid]]) {
            [deletedIndexPaths addObject:[NSIndexPath indexPathForRow:index inSection:0]];
        }
    }

    NSMutableArray<KayokoTag *> *updatedTags = [[NSMutableArray alloc] init];
    for (KayokoTag *tag in [self tags]) {
        if (![selectedUUIDs containsObject:[tag uuid]]) {
            [updatedTags addObject:tag];
        }
    }
    if (![self saveTags:updatedTags]) {
        return;
    }

    [self setTags:updatedTags];
    [[self selectedTagUUIDs] removeAllObjects];
    [self refreshFilteredTags];
    if ([deletedIndexPaths count] > 0) {
        [[self tableView] deleteRowsAtIndexPaths:deletedIndexPaths withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self updateToolbarItems];
}

- (void)deleteTagAtIndexPath:(NSIndexPath *)indexPath {
    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    if ((NSUInteger)[indexPath row] >= [displayedTags count]) {
        return;
    }

    KayokoTag *deletedTag = displayedTags[(NSUInteger)[indexPath row]];
    NSMutableArray<KayokoTag *> *updatedTags = [[NSMutableArray alloc] init];
    for (KayokoTag *tag in [self tags]) {
        if (![[tag uuid] isEqualToString:[deletedTag uuid]]) {
            [updatedTags addObject:tag];
        }
    }
    if (![self saveTags:updatedTags]) {
        return;
    }

    [self setTags:updatedTags];
    [[self selectedTagUUIDs] removeObject:[deletedTag uuid]];
    [self refreshFilteredTags];
    [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self updateToolbarItems];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return (NSInteger)[[self displayedTags] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTagTableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:kKayokoTagCellReuseIdentifier forIndexPath:indexPath];
    [cell configureWithTag:[self displayedTags][(NSUInteger)[indexPath row]] editing:[self isEditing]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return [self isEditing] ? UITableViewCellEditingStyleNone : UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if (editingStyle == UITableViewCellEditingStyleDelete && ![self isEditing]) {
        [self deleteTagAtIndexPath:indexPath];
    }
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
    trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    if ([self isEditing]) {
        return nil;
    }

    UIContextualAction *deleteAction =
        [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                title:[self localizedStringForKey:@"Delete"]
                                              handler:^(__kindof UIContextualAction *action, __kindof UIView *sourceView,
                                                        void (^completionHandler)(BOOL)) {
                                                (void)action;
                                                (void)sourceView;
                                                [self deleteTagAtIndexPath:indexPath];
                                                completionHandler(YES);
                                              }];
    [deleteAction setImage:[UIImage systemImageNamed:@"trash.fill"]];
    return [UISwipeActionsConfiguration configurationWithActions:@[ deleteAction ]];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)tableView;
    (void)indexPath;
    return [self isEditing] && ![self isFiltering];
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
           toIndexPath:(NSIndexPath *)destinationIndexPath {
    (void)tableView;
    if ([self isFiltering] || [sourceIndexPath row] == [destinationIndexPath row]) {
        return;
    }

    NSMutableArray<KayokoTag *> *updatedTags = [[self tags] mutableCopy];
    KayokoTag *tag = updatedTags[(NSUInteger)[sourceIndexPath row]];
    [updatedTags removeObjectAtIndex:(NSUInteger)[sourceIndexPath row]];
    [updatedTags insertObject:tag atIndex:(NSUInteger)[destinationIndexPath row]];
    if (![self saveTags:updatedTags]) {
        [tableView moveRowAtIndexPath:destinationIndexPath toIndexPath:sourceIndexPath];
        return;
    }
    [self setTags:updatedTags];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    KayokoTag *tag = [self displayedTags][(NSUInteger)[indexPath row]];
    if ([self isEditing]) {
        [[self selectedTagUUIDs] addObject:[tag uuid]];
        [self updateToolbarItems];
        return;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self presentEditorForTag:tag];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![self isEditing]) {
        return;
    }

    KayokoTag *tag = [self displayedTags][(NSUInteger)[indexPath row]];
    [[self selectedTagUUIDs] removeObject:[tag uuid]];
    [self updateToolbarItems];
}

- (void)tableView:(UITableView *)tableView
     willDisplayCell:(UITableViewCell *)cell
   forRowAtIndexPath:(NSIndexPath *)indexPath {
    (void)cell;
    if (![self isEditing]) {
        return;
    }

    KayokoTag *tag = [self displayedTags][(NSUInteger)[indexPath row]];
    if ([[self selectedTagUUIDs] containsObject:[tag uuid]]) {
        [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
}

#pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    (void)searchController;
    [self refreshFilteredTags];
    [[self tableView] reloadData];
    [self updateToolbarItems];
}

#pragma mark - Editing

- (void)presentEditorForTag:(KayokoTag *)tag {
    KayokoTagEditorViewController *editor =
        [[KayokoTagEditorViewController alloc] initWithTag:tag localizationBundle:[self localizationBundle]];
    __weak typeof(self) weakSelf = self;
    [editor setCompletionHandler:^(KayokoTag *updatedTag) {
      [weakSelf updateTag:updatedTag];
    }];

    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:editor];
    [navigationController setModalPresentationStyle:UIModalPresentationPageSheet];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)updateTag:(KayokoTag *)updatedTag {
    NSUInteger index = [self indexOfTagWithUUID:[updatedTag uuid] inTags:[self tags]];
    if (index == NSNotFound) {
        return;
    }

    NSArray<KayokoTag *> *displayedTagsBeforeUpdate = [[self displayedTags] copy];
    NSUInteger visibleIndexBeforeUpdate = [self indexOfTagWithUUID:[updatedTag uuid] inTags:displayedTagsBeforeUpdate];

    NSMutableArray<KayokoTag *> *updatedTags = [[self tags] mutableCopy];
    updatedTags[index] = updatedTag;
    if (![self saveTags:updatedTags]) {
        return;
    }

    [self setTags:updatedTags];
    [self refreshFilteredTags];

    if (visibleIndexBeforeUpdate == NSNotFound) {
        return;
    }

    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:visibleIndexBeforeUpdate inSection:0];
    NSUInteger visibleIndexAfterUpdate = [self indexOfTagWithUUID:[updatedTag uuid] inTags:[self displayedTags]];
    if (visibleIndexAfterUpdate == NSNotFound) {
        [[self tableView] deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [[self tableView] reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark - Helpers

- (NSArray<KayokoTag *> *)displayedTags {
    return [self isFiltering] ? [self filteredTags] : [self tags];
}

- (BOOL)isFiltering {
    NSString *searchText = [[[self searchController] searchBar] text];
    return [searchText length] > 0;
}

- (void)refreshFilteredTags {
    [[self filteredTags] removeAllObjects];
    NSString *searchText = [[[[self searchController] searchBar] text]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([searchText length] == 0) {
        return;
    }

    for (KayokoTag *tag in [self tags]) {
        if ([[tag title] rangeOfString:searchText options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch]
                .location != NSNotFound) {
            [[self filteredTags] addObject:tag];
        }
    }
}

- (BOOL)allDisplayedTagsSelected {
    NSArray<KayokoTag *> *displayedTags = [self displayedTags];
    if ([displayedTags count] == 0) {
        return NO;
    }

    for (KayokoTag *tag in displayedTags) {
        if (![[self selectedTagUUIDs] containsObject:[tag uuid]]) {
            return NO;
        }
    }
    return YES;
}

- (NSUInteger)indexOfTagWithUUID:(NSString *)uuid inTags:(NSArray<KayokoTag *> *)tags {
    if ([uuid length] == 0) {
        return NSNotFound;
    }

    for (NSUInteger index = 0; index < [tags count]; index++) {
        if ([[tags[index] uuid] isEqualToString:uuid]) {
            return index;
        }
    }
    return NSNotFound;
}

- (BOOL)saveTags:(NSArray<KayokoTag *> *)tags {
    NSError *error = nil;
    BOOL saved = [[self tagStore] saveTags:tags error:&error];
    if (!saved) {
        [self presentError:error];
    }
    return saved;
}

- (void)presentError:(NSError *)error {
    NSString *message = [error localizedDescription] ?: [self localizedStringForKey:@"Unable to Save Tags"];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[self localizedStringForKey:@"Tags"]
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:[self localizedStringForKey:@"OK"]
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil];
    [alert addAction:action];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)localizedStringForKey:(NSString *)key {
    return [[self localizationBundle] localizedStringForKey:key value:key table:@"Tags"] ?: key;
}

@end
