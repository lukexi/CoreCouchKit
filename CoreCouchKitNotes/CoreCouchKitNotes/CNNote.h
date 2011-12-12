//
//  CNNote.h
//  CoreCouchKitNotes
//
//  Created by Luke Iannini on 12/12/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CNThumbnail;

@interface CNNote : NSManagedObject

@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) CNThumbnail *thumbnail;

@end
