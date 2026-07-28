//
//  KayokoTableView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@class PasteboardItem;

@interface KayokoTableView : UITableView <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate>
@property(nonatomic, copy) NSString *name;

// 当前展示（可能已被搜索过滤）的 items。
@property(nonatomic, strong) NSArray *items;

// 完整数据源（未过滤），用于搜索与恢复。
@property(nonatomic, strong) NSArray *allItems;

// 下拉出现的搜索栏（tableHeaderView）。
@property(nonatomic, strong) UISearchBar *searchBar;

@property(nonatomic, assign) BOOL automaticallyPaste;
@property(nonatomic, assign) BOOL showRecordedTime;

- (instancetype)initWithName:(NSString *)name rowHeight:(CGFloat)rowHeight;
- (void)reloadDataWithItems:(NSArray *)items;
- (UIContextualAction *)tokenSelectionActionForItem:(PasteboardItem *)item;

// 子类返回自己对应的历史记录键（history/favorites），用于图片缓存等场景。
- (NSString *)historyKey;

// 子类在“删除/移除”等操作时，同步维护 allItems。
- (void)removeItemDictionaryFromAllItems:(NSDictionary *)dictionary;
@end
