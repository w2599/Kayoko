//
//  KayokoClearConfirmationViewController.m
//  Kayoko
//

#import "KayokoClearConfirmationViewController.h"

#import "KayokoClearConfirmationView.h"
#import "PasteboardManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface KayokoClearConfirmationViewController ()
@property(nonatomic, weak) KayokoClearConfirmationView *view;
@end

NS_ASSUME_NONNULL_END

@implementation KayokoClearConfirmationViewController

- (instancetype)initWithView:(KayokoClearConfirmationView *)view {
    self = [super init];
    if (self) {
        _view = view;
        [[view cancelButton] addTarget:self action:@selector(handleCancel) forControlEvents:UIControlEventTouchUpInside];
        [[view confirmButton] addTarget:self action:@selector(handleConfirm) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)beginWithHistoryKey:(NSString *)historyKey {
    [self setHistoryKey:historyKey];
    [[self view] updateWithHistoryKey:historyKey];
    [[[self view] cancelButton] setEnabled:YES];
    [[[self view] confirmButton] setEnabled:YES];
}

- (void)handleCancel {
    [[self delegate] clearConfirmationViewControllerDidCancel:self];
}

- (void)handleConfirm {
    NSString *historyKey = [self historyKey];
    if ([historyKey length] == 0) {
        return;
    }

    [[[self view] cancelButton] setEnabled:NO];
    [[[self view] confirmButton] setEnabled:NO];
    [[PasteboardManager sharedInstance]
        removeAllPasteboardItemsFromHistoryWithKey:historyKey
                                shouldRemoveImages:YES
                           postsChangeNotification:NO
                                        completion:^(BOOL success) {
                                          if (success) {
                                              [[self delegate] clearConfirmationViewControllerDidClearHistoryKey:historyKey];
                                          } else {
                                              [[[self view] cancelButton] setEnabled:YES];
                                              [[[self view] confirmButton] setEnabled:YES];
                                              [[self delegate] clearConfirmationViewController:self
                                                                    didFailClearingHistoryKey:historyKey];
                                          }
                                        }];
}

@end
