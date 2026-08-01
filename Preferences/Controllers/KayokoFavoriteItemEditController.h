//
//  KayokoFavoriteItemEditController.h
//  Kayoko
//

#import <UIKit/UIKit.h>

@interface KayokoFavoriteItemEditController : UIViewController

@property(nonatomic, copy) NSString *initialContent;
@property(nonatomic, copy) NSString *initialRemark;
@property(nonatomic, assign) BOOL isImage;
@property(nonatomic, copy) void (^completionHandler)(NSString *content, NSString *remark);

@end
