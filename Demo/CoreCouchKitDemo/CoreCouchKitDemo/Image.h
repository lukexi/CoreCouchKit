//
//  Image.h
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/3/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Image;

@interface Image : NSManagedObject

@property (nonatomic, retain) id image;
@property (nonatomic, retain) Image *event;

@end
