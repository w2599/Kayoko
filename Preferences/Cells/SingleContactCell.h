//
//  SingleContactCell.h
//  UNDRESSD Utils
//
//  Created by Alexandra Aurora Göttlicher
//

#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>

@interface SingleContactCell : PSTableCell
@property(nonatomic, retain)UIImageView* avatarImageView;
@property(nonatomic, retain)UILabel* displayNameLabel;
@property(nonatomic, retain)UILabel* usernameLabel;
@property(nonatomic, retain)UIView* tapRecognizerView;
@property(nonatomic, retain)UITapGestureRecognizer* tap;
@property(nonatomic, retain)NSString* displayName;
@property(nonatomic, retain)NSString* username;
@end
