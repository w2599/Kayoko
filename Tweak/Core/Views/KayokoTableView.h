//
//  KayokoTableView.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

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

- (instancetype)initWithName:(NSString *)name;
- (void)reloadDataWithItems:(NSArray *)items;

// 子类在“删除/移除”等操作时，同步维护 allItems。
- (void)removeItemDictionaryFromAllItems:(NSDictionary *)dictionary;
@end
