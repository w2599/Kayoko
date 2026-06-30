//
//  KayokoSearchViewController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface KayokoSearchViewController : NSObject

@property(nonatomic, strong, readonly) UITableView *suggestionTableView;

- (instancetype)initWithContainerView:(UIView *)containerView;
- (void)layoutSuggestionTableViewWithHeaderView:(UIView *)headerView
                                     itemCount:(NSUInteger)itemCount
                                  searchActive:(BOOL)searchActive
                            searchHeaderHeight:(CGFloat)searchHeaderHeight;

@end

NS_ASSUME_NONNULL_END
