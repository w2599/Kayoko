//
//  KayokoFavoritesSortListController.m
//  Kayoko
//

#import "KayokoFavoritesSortListController.h"

#import <UIKit/UIKit.h>
#import <roothide.h>

#import "../KayokoNotificationKeys.h"
#import "KayokoFavoriteItemEditController.h"

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
    tableView.allowsSelectionDuringEditing = YES;
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
    [self sendEditorRequest:@{ @"operation" : @"read" } completion:^(NSDictionary *response) {
      if (![response[@"success"] boolValue]) {
          return;
      }
      self.favoriteItems = [response[@"items"] mutableCopy] ?: [[NSMutableArray alloc] init];
      [self updateEmptyState];
      [self.tableView reloadData];
    }];
}

- (void)pollEditorResponseForRequestID:(NSString *)requestID
                               attempt:(NSUInteger)attempt
                            completion:(void (^)(NSDictionary *response))completion {
    NSDictionary *response = [NSDictionary dictionaryWithContentsOfFile:jbroot(kKayokoFavoritesEditorResponsePath)];
    if ([response[@"request_id"] isEqualToString:requestID]) {
        [[NSFileManager defaultManager] removeItemAtPath:jbroot(kKayokoFavoritesEditorResponsePath) error:nil];
        if (completion) completion(response);
        return;
    }
    if (attempt >= 30) {
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
                     [self pollEditorResponseForRequestID:requestID attempt:attempt + 1 completion:completion];
                   });
}

- (void)sendEditorRequest:(NSDictionary *)request completion:(void (^)(NSDictionary *response))completion {
    NSString *requestID = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *payload = [request mutableCopy];
    payload[@"request_id"] = requestID;
    [payload writeToFile:jbroot(kKayokoFavoritesEditorRequestPath) atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                          (__bridge CFStringRef)kKayokoNotificationKeyFavoritesEditorRequest,
                                          NULL, NULL, YES);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pollEditorResponseForRequestID:requestID attempt:0 completion:completion];
        });
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
    NSString *remark = dictionary[@"note"] ?: @"";
    NSString *content = dictionary[@"content"] ?: @"";
    NSString *imageName = dictionary[@"image_name"] ?: @"";

    NSString *title = [remark length] > 0 ? remark : ([imageName length] > 0 ? imageName : content);
    NSString *subtitle = [remark length] > 0 ? ([imageName length] > 0 ? imageName : content) : @"";

    cell.textLabel.text = [title length] > 0 ? title : @"-";
    cell.textLabel.numberOfLines = 1;
    cell.detailTextLabel.text = subtitle;
    cell.detailTextLabel.numberOfLines = 1;
    cell.showsReorderControl = YES;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.editingAccessoryType = UITableViewCellAccessoryDetailButton;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    [self pushEditControllerForRowAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    [self pushEditControllerForRowAtIndexPath:indexPath];
}

- (void)pushEditControllerForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [self.favoriteItems count]) {
        return;
    }

    NSDictionary *dictionary = self.favoriteItems[indexPath.row];
    NSString *imageName = dictionary[@"image_name"] ?: @"";

    KayokoFavoriteItemEditController *editController = [[KayokoFavoriteItemEditController alloc] init];
    editController.isImage = [imageName length] > 0;
    editController.initialContent = dictionary[@"content"] ?: @"";
    editController.initialRemark = dictionary[@"note"] ?: @"";

    __weak typeof(self) weakSelf = self;
    editController.completionHandler = ^(NSString *content, NSString *remark) {
      [weakSelf applyContent:content remark:remark toItemAtIndexPath:indexPath];
    };

    [self.navigationController pushViewController:editController animated:YES];
}

- (void)applyContent:(NSString *)content remark:(NSString *)remark toItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [self.favoriteItems count]) {
        return;
    }

        NSDictionary *item = self.favoriteItems[indexPath.row];
        NSMutableDictionary *updatedItem = [item mutableCopy];
        if ([item[@"image_name"] length] == 0) {
            updatedItem[@"content"] = content ?: @"";
        }
        updatedItem[@"note"] = remark ?: @"";
        self.favoriteItems[indexPath.row] = updatedItem;
        [self sendEditorRequest:@{ @"operation" : @"update",
                                   @"item" : item,
                                   @"content" : updatedItem[@"content"] ?: @"",
                                   @"note" : updatedItem[@"note"] ?: @"" }
                          completion:nil];
        [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
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

    [self sendEditorRequest:@{ @"operation" : @"order", @"items" : self.favoriteItems } completion:nil];
}

@end