//
//  Event.m
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/4/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "Event.h"
#import "Image.h"


@implementation Event

@dynamic location;
@dynamic name;
@dynamic numberOfBoobs;
@dynamic timeStamp;
@dynamic people;
@dynamic image;

- (void)awakeFromInsert
{
    self.image = [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass([Image class]) 
                                               inManagedObjectContext:self.managedObjectContext];
}

@end
