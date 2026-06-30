//
//  KayokoSearchSuggestionController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@class KayokoSearchSuggestionController;

NS_ASSUME_NONNULL_BEGIN

@protocol KayokoSearchSuggestionControllerDelegate <NSObject>

- (void)searchSuggestionController:(KayokoSearchSuggestionController *)controller
        didSelectBundleIdentifier:(NSString *)bundleIdentifier;

@end

@interface KayokoSearchSuggestionController : NSObject

@property(nonatomic, weak, nullable) id<KayokoSearchSuggestionControllerDelegate> delegate;
@property(nonatomic, copy, readonly) NSArray<NSDictionary<NSString *, id> *> *suggestionItems;

- (instancetype)initWithSuggestionTableView:(UITableView *)suggestionTableView;
- (void)updateSuggestionItems:(NSArray<NSDictionary<NSString *, id> *> *)suggestionItems;
- (NSUInteger)numberOfSuggestions;
- (void)setHidden:(BOOL)hidden;
- (void)reloadData;

@end

NS_ASSUME_NONNULL_END
