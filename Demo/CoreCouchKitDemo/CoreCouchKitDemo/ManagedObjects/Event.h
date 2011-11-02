//
//  Event.h
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/2/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Event : NSManagedObject

@property (nonatomic) NSTimeInterval timeStamp;
@property (nonatomic) float numberOfBoobs;

@end
