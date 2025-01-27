//
//  ColorUtil.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@interface ColorUtil : NSObject
+ (UIColor *)colorFromHex:(NSString *)hex;
+ (UIColor *)colorFromRgb:(NSString *)rgb;
+ (UIColor *)colorFromRgba:(NSString *)rgba;
@end
