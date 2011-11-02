//
//  CCDDetailViewController.h
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/1/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CCDDetailViewController : UIViewController <UISplitViewControllerDelegate, UITextFieldDelegate>

@property (strong, nonatomic) id detailItem;

@property (strong, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (strong, nonatomic) IBOutlet UITextField *nameField;
@property (strong, nonatomic) IBOutlet UITextField *locationField;

@end
