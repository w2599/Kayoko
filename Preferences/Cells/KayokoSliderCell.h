//
//  KayokoSliderCell.h
//  Kayoko
//
//  Created by Alexandra Aurora Göttlicher
//

#import <Preferences/PSSpecifier.h>
#import <UIKit/UIKit.h>

@interface KayokoSliderCell : PSTableCell
@property(nonatomic, strong) UISlider *slider;
@property(nonatomic, strong) UILabel *valueLabel;
@end
