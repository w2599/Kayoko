//
//  KayokoSearchView.m
//  Kayoko
//

#import "KayokoSearchView.h"

static CGFloat const kKayokoSearchViewRowHeight = 44;

@implementation KayokoSearchView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero style:UITableViewStylePlain];
    if (self) {
        [self setRowHeight:kKayokoSearchViewRowHeight];
        [self setBackgroundColor:[UIColor clearColor]];
        [self setSeparatorStyle:UITableViewCellSeparatorStyleNone];
        [self setHidden:YES];
        [self setClipsToBounds:YES];
        [[self layer] setCornerRadius:12];
    }
    return self;
}

@end
