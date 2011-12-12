//
//  CNNoteCell.h
//  CoreCouchKitNotes
//
//  Created by Luke Iannini on 12/12/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CNNoteCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIImageView *thumbnailView;
@property (nonatomic, strong) IBOutlet UILabel *titleLabel;
@property (nonatomic, strong) IBOutlet UILabel *subLabel1;
@property (nonatomic, strong) IBOutlet UILabel *subLabel2;

@end
