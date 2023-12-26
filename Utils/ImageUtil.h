//
//  ImageUtil.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>

@interface ImageUtil : NSObject
+ (BOOL)imageHasAlpha:(UIImage *)image;
+ (UIImage *)rotatedImageFromImage:(UIImage *)image;
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
@end
