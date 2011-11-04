//
//  Event.h
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/4/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Image;

@interface Event : NSManagedObject

@property (nonatomic, retain) NSString * location;
@property (nonatomic, retain) NSString * name;
@property (nonatomic) float numberOfBoobs;
@property (nonatomic) NSTimeInterval timeStamp;
@property (nonatomic, retain) NSSet *people;
@property (nonatomic, retain) Image *image;
@end

@interface Event (CoreDataGeneratedAccessors)

- (void)addPeopleObject:(NSManagedObject *)value;
- (void)removePeopleObject:(NSManagedObject *)value;
- (void)addPeople:(NSSet *)values;
- (void)removePeople:(NSSet *)values;

@end
