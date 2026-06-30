//
//  KayokoSearchViewController.m
//  Kayoko
//

#import "KayokoSearchViewController.h"

#import "KayokoMainView.h"
#import "KayokoSearchView.h"

static CGFloat const kKayokoAppTokenSuggestionMaximumHeight = 220;

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchViewController ()
@property(nonatomic, weak) UIView *containerView;
@property(nonatomic, strong, readwrite) KayokoSearchView *searchView;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoSearchViewController

- (instancetype)initWithContainerView:(UIView *)containerView {
    self = [super init];
    if (self) {
        _containerView = containerView;
        _searchView = [[KayokoSearchView alloc] init];
        [self setView:_searchView];
    }
    return self;
}

- (UITableView *)suggestionTableView {
    return [self searchView];
}

- (void)layoutSuggestionTableViewWithHeaderView:(UIView *)headerView
                                      itemCount:(NSUInteger)itemCount
                                   searchActive:(BOOL)searchActive
                             searchHeaderHeight:(CGFloat)searchHeaderHeight {
    CGFloat height = MIN(itemCount * [[self searchView] rowHeight], kKayokoAppTokenSuggestionMaximumHeight);
    if (height <= 0 || !searchActive) {
        [[self searchView] setFrame:CGRectZero];
        return;
    }

    UIEdgeInsets safeAreaInsets = [[self containerView] safeAreaInsets];
    if ([[self containerView] isKindOfClass:[KayokoMainView class]]) {
        safeAreaInsets = [(KayokoMainView *)[self containerView] effectiveContentSafeAreaInsets];
    }
    CGFloat horizontalInset = 16;
    CGFloat x = safeAreaInsets.left + horizontalInset;
    CGFloat width = MAX(CGRectGetWidth([[self containerView] bounds]) - safeAreaInsets.left - safeAreaInsets.right -
                            horizontalInset * 2,
                        0);
    CGFloat y = CGRectGetMaxY([headerView frame]) + 8 + searchHeaderHeight;
    CGRect frame = CGRectMake(x, y, width, height);
    [[self searchView] setFrame:frame];
    [[self containerView] bringSubviewToFront:[self searchView]];
}

@end
