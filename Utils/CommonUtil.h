//
//  CommonUtil.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Foundation/Foundation.h>

@interface CommonUtil : NSObject
+ (NSString *)randomStringWithLength:(NSUInteger)length;
+ (void)showAlertWithTitle:(NSString *)title andMessage:(NSString *)message withDismissButtonTitle:(NSString *)dismissButtonTitle;
@end
