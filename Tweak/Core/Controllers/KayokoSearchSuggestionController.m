//
//  KayokoSearchSuggestionController.m
//  Kayoko
//

#import "KayokoSearchSuggestionController.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchSuggestionController () <UITableViewDelegate, UITableViewDataSource>
@property(nonatomic, weak) UITableView *suggestionTableView;
@property(nonatomic, copy, readwrite) NSArray<NSDictionary<NSString *, id> *> *suggestionItems;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchSuggestionController

- (instancetype)initWithSuggestionTableView:(UITableView *)suggestionTableView {
    self = [super init];
    if (self) {
        _suggestionTableView = suggestionTableView;
        _suggestionItems = @[];
        [_suggestionTableView setDelegate:self];
        [_suggestionTableView setDataSource:self];
    }
    return self;
}

- (void)updateSuggestionItems:(NSArray<NSDictionary<NSString *, id> *> *)suggestionItems {
    _suggestionItems = [suggestionItems copy] ?: @[];
    [self reloadData];
}

- (NSUInteger)numberOfSuggestions {
    return [[self suggestionItems] count];
}

- (void)setHidden:(BOOL)hidden {
    [[self suggestionTableView] setHidden:hidden];
}

- (void)reloadData {
    [[self suggestionTableView] reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView != [self suggestionTableView]) {
        return 0;
    }
    return [[self suggestionItems] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"KayokoAppTokenSuggestionCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:@"KayokoAppTokenSuggestionCell"];
        [cell setBackgroundColor:[UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traitCollection) {
          if ([traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
              return [UIColor colorWithWhite:0.12 alpha:0.92];
          }
          return [UIColor colorWithWhite:1 alpha:0.94];
        }]];
        [[cell textLabel] setFont:[UIFont systemFontOfSize:15 weight:UIFontWeightMedium]];
        [[cell imageView] setContentMode:UIViewContentModeScaleAspectFit];
        [[[cell imageView] layer] setCornerRadius:6];
        [[cell imageView] setClipsToBounds:YES];
    }

    NSDictionary<NSString *, id> *item = [self suggestionItems][[indexPath row]];
    [[cell textLabel] setText:item[@"displayName"]];
    [[cell imageView] setImage:item[@"icon"]];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView != [self suggestionTableView]) {
        return;
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, id> *item = [self suggestionItems][[indexPath row]];
    NSString *bundleIdentifier = item[@"bundleIdentifier"];
    if ([bundleIdentifier length] > 0) {
        [[self delegate] searchSuggestionController:self didSelectBundleIdentifier:bundleIdentifier];
    }
}

@end
