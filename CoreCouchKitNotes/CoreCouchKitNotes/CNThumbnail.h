//
//  CNThumbnail.h
//  CoreCouchKitNotes
//
//  Created by Luke Iannini on 12/12/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class CNNote;

@interface CNThumbnail : NSManagedObject

@property (nonatomic, retain) id image;
@property (nonatomic, retain) CNNote *note;

@end
