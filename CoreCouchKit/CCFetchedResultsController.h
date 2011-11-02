//
//  CCFetchedResultsController.h
//  CoreCouchKit
//
//  Created by Luke Iannini on 11/2/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <CoreData/CoreData.h>


@class CCQuery;
// Automatically sets up and holds a CouchLiveQuery and queues object updates onto the main CoreCouchKit thread

@interface CCFetchedResultsController : NSFetchedResultsController

- (id)initWithQuery:(CCQuery *)aQuery
    sortDescriptors:(NSArray *)sortDescriptors
managedObjectContext:(NSManagedObjectContext *)managedObjectContext
           delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

@end
