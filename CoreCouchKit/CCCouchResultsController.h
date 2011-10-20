//
//  CDCouchSync.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/7/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCCouchResultsController : NSObject

- (void)start;

+ (id)couchResultsControllerWithDesignDocName:(NSString *)designDocName
                                     viewName:(NSString *)viewName
                                   entityName:(NSString *)entityName
                                   relatedKey:(NSString *)relatedKey
                                 relatedValue:(NSString *)relatedValue
                                      context:(NSManagedObjectContext *)managedObjectContext;

- (NSFetchedResultsController *)fetchedResultsControllerWithSortDescriptors:(NSArray *)sortDescriptors
                                                                   delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

@end
