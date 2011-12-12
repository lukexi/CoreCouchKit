//
//  CNNote+Additions.m
//  CoreCouchKitNotes
//
//  Created by Luke Iannini on 12/12/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CNNote+Additions.h"
#import "CNThumbnail.h"

@implementation CNNote (Additions)

- (void)awakeFromInsert
{
    self.thumbnail = [NSEntityDescription insertNewObjectForEntityForName:@"CNThumbnail" 
                                                   inManagedObjectContext:self.managedObjectContext];
}

- (void)updateThumbnail
{
    CGRect rect = CGRectMake(0, 0, 512, 512);
    UIGraphicsBeginImageContext(rect.size);
    [[UIColor whiteColor] set];
    UIRectFill(rect);
    [[UIColor blackColor] set];
    [self.text drawInRect:rect withFont:[UIFont boldSystemFontOfSize:25]];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.thumbnail.image = image;
}

@end
