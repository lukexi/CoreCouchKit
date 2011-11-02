//
//  CCFetchedResultsController.m
//  CoreCouchKit
//
//  Created by Luke Iannini on 11/2/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCFetchedResultsController.h"
#import "CoreCouchKit.h"

@interface CCFetchedResultsController ()
{
    CCQuery *query;
}

@end

@implementation CCFetchedResultsController

- (void)dealloc
{
    [query stop];
}

- (id)initWithQuery:(CCQuery *)aQuery
    sortDescriptors:(NSArray *)sortDescriptors
managedObjectContext:(NSManagedObjectContext *)managedObjectContext
           delegate:(id <NSFetchedResultsControllerDelegate>)delegate
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:aQuery.entityName];
    request.sortDescriptors = sortDescriptors;
    request.predicate = [aQuery localPredicate];
    self = [super initWithFetchRequest:request 
                  managedObjectContext:managedObjectContext 
                    sectionNameKeyPath:nil 
                             cacheName:nil];
    if (self) 
    {
        self.delegate = delegate;
        query = aQuery;
    }
    return self;
}

- (BOOL)performFetch:(NSError *__autoreleasing *)error
{
    [query start];
    return [super performFetch:error];
}

@end

