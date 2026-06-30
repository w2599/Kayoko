//
//  KayokoSearchViewController.m
//  Kayoko
//

#import "KayokoSearchViewController.h"

static CGFloat const kKayokoAppTokenSuggestionRowHeight = 44;
static CGFloat const kKayokoAppTokenSuggestionMaximumHeight = 220;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchViewController ()
@property(nonatomic, weak) UIView *containerView;
@property(nonatomic, strong, readwrite) UITableView *suggestionTableView;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchViewController

- (instancetype)initWithContainerView:(UIView *)containerView {
    self = [super init];
    if (self) {
        _containerView = containerView;

        _suggestionTableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        [_suggestionTableView setRowHeight:kKayokoAppTokenSuggestionRowHeight];
        [_suggestionTableView setBackgroundColor:[UIColor clearColor]];
        [_suggestionTableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [_suggestionTableView setHidden:YES];
        [_suggestionTableView setClipsToBounds:YES];
        [[_suggestionTableView layer] setCornerRadius:12];
        [self setView:_suggestionTableView];
    }
    return self;
}

- (void)layoutSuggestionTableViewWithHeaderView:(UIView *)headerView
                                     itemCount:(NSUInteger)itemCount
                                  searchActive:(BOOL)searchActive
                            searchHeaderHeight:(CGFloat)searchHeaderHeight {
    CGFloat height = MIN(itemCount * kKayokoAppTokenSuggestionRowHeight, kKayokoAppTokenSuggestionMaximumHeight);
    if (height <= 0 || !searchActive) {
        [[self suggestionTableView] setFrame:CGRectZero];
        return;
    }

    CGFloat y = CGRectGetMaxY([headerView frame]) + 8 + searchHeaderHeight;
    CGRect frame = CGRectMake(16, y, MAX(CGRectGetWidth([[self containerView] bounds]) - 32, 0), height);
    [[self suggestionTableView] setFrame:frame];
    [[self containerView] bringSubviewToFront:[self suggestionTableView]];
}

@end
