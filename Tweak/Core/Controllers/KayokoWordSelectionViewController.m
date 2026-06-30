//
//  KayokoWordSelectionViewController.m
//  Kayoko
//

#import "KayokoWordSelectionViewController.h"

#import "KayokoWordSelectionView.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoWordSelectionViewController ()
@property(nonatomic, weak) KayokoWordSelectionView *wordSelectionView;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoWordSelectionViewController

- (instancetype)initWithWordSelectionView:(KayokoWordSelectionView *)wordSelectionView {
    self = [super init];
    if (self) {
        _wordSelectionView = wordSelectionView;
        __weak typeof(self) weakSelf = self;
        [wordSelectionView setSelectionChangedHandler:^{
          if ([weakSelf selectionChangedHandler]) {
              [weakSelf selectionChangedHandler]();
          }
        }];
    }
    return self;
}

@end
