//
//  KayokoSearchSuggestionDataSource.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoSearchSuggestionDataSource;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchSuggestionDataSourceDelegate <NSObject>

- (void)searchSuggestionDataSource:(KayokoSearchSuggestionDataSource *)controller
         didSelectBundleIdentifier:(NSString *)bundleIdentifier;

@end

@interface KayokoSearchSuggestionDataSource : NSObject

@property(nonatomic, weak, nullable) id<KayokoSearchSuggestionDataSourceDelegate> delegate;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *suggestionItems;

- (instancetype)initWithSuggestionTableView:(UITableView *)suggestionTableView;
- (void)updateSuggestionItems:(NSArray<NSDictionary<NSString *, id> *> *)suggestionItems;
- (NSUInteger)numberOfSuggestions;
- (void)setHidden:(BOOL)hidden;
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
