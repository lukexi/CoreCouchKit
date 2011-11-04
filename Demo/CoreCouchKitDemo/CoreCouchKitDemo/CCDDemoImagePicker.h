//
//  CCDDemoImagePicker.h
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/3/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CCDDemoImagePicker;
@protocol CCDDemoImagePickerDelegate <NSObject>

- (void)demoImagePicker:(CCDDemoImagePicker *)demoImagePicker didFinishWithImage:(UIImage *)image;

@end

@interface CCDDemoImagePicker : UIViewController
@property (nonatomic, weak) id <CCDDemoImagePickerDelegate> delegate;
@end
