//
//  KayokoFavoritesSortListController.m
//  Kayoko
//

#import "KayokoFavoritesSortListController.h"

#import <UIKit/UIKit.h>

#import "../NotificationKeys.h"
#import "PasteboardItem.h"
#import "PasteboardManager.h"

@interface KayokoFavoritesSortListController () <UITableViewDataSource, UITableViewDelegate>

@property(nonatomic, strong) NSMutableArray *favoriteItems;
@property(nonatomic, strong) UITableView *tableView;

@end

@implementation KayokoFavoritesSortListController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    self.title = [bundle localizedStringForKey:@"Favorites Sort Order" value:nil table:@"Root"];
    self.favoriteItems = [[NSMutableArray alloc] init];

    UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    tableView.dataSource = self;
    tableView.delegate = self;
    tableView.editing = YES;
    tableView.allowsSelection = NO;
    tableView.translatesAutoresizingMaskIntoConstraints = NO;
    if (@available(iOS 13.0, *)) {
        tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    self.tableView = tableView;

    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    [self.view addSubview:tableView];

    [NSLayoutConstraint activateConstraints:@[
        [tableView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    [self reloadFavorites];
}

- (void)reloadFavorites {
    NSArray *favorites = [[PasteboardManager sharedInstance] getItemsFromHistoryWithKey:kHistoryKeyFavorites];
    self.favoriteItems = favorites ? [favorites mutableCopy] : [[NSMutableArray alloc] init];

    [self updateEmptyState];
    [self.tableView reloadData];
}

- (void)updateEmptyState {
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    if ([self.favoriteItems count] > 0) {
        [self.tableView setBackgroundView:nil];
        return;
    }

    UILabel *label = [[UILabel alloc] init];
    [label setText:[bundle localizedStringForKey:@"No favorites yet." value:nil table:@"Root"]];
    [label setTextAlignment:NSTextAlignmentCenter];
    [label setTextColor:[UIColor secondaryLabelColor]];
    [label setNumberOfLines:0];
    [self.tableView setBackgroundView:label];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.favoriteItems count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *const cellIdentifier = @"FavoritesSortCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    NSDictionary *dictionary = self.favoriteItems[indexPath.row];
    NSString *remark = dictionary[kItemKeyRemark] ?: @"";
    NSString *content = dictionary[kItemKeyContent] ?: @"";
    NSString *imageName = dictionary[kItemKeyImageName] ?: @"";

    NSString *title = [remark length] > 0 ? remark : ([imageName length] > 0 ? imageName : content);
    NSString *subtitle = [remark length] > 0 ? ([imageName length] > 0 ? imageName : content) : @"";

    cell.textLabel.text = [title length] > 0 ? title : @"-";
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.text = subtitle;
    cell.detailTextLabel.numberOfLines = 1;
    cell.showsReorderControl = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryType = UITableViewCellAccessoryNone;

    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (sourceIndexPath.row == destinationIndexPath.row) {
        return;
    }

    id item = self.favoriteItems[sourceIndexPath.row];
    [self.favoriteItems removeObjectAtIndex:sourceIndexPath.row];
    [self.favoriteItems insertObject:item atIndex:destinationIndexPath.row];

    [[PasteboardManager sharedInstance] setItems:self.favoriteItems forHistoryWithKey:kHistoryKeyFavorites];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (CFStringRef)kNotificationKeyPreferencesReload, nil, nil, YES);
}

@end