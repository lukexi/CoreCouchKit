//
//  CNDetailViewController.h
//  CoreCouchKitNotes
//
//  Created by Luke Iannini on 12/12/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <UIKit/UIKit.h>


@class CNNote;
@interface CNDetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) CNNote *note;

@property (strong, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@property (strong, nonatomic) IBOutlet UITextView *detailTextView;
- (IBAction)saveAction:(id)sender;

@end
