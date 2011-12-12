//
//  CNNoteCell.m
//  CoreCouchKitNotes
//
//  Created by Luke Iannini on 12/12/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CNNoteCell.h"

@implementation CNNoteCell
@synthesize thumbnailView, titleLabel, subLabel1, subLabel2;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    self.thumbnailView.highlighted = selected;
    self.titleLabel.highlighted = selected;
    self.subLabel1.highlighted = selected;
    self.subLabel2.highlighted = selected;
}

@end
