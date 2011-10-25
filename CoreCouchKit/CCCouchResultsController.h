//
//  CDCouchSync.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/7/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCDocument.h"

@protocol CCDocumentUpdate <NSObject>

- (void)willUpdateFromCouch;
- (void)didUpdateFromCouch;

@end

typedef void(^CCCouchResultsBlock)(NSArray *results);

@interface CCCouchResultsController : NSObject

@property (nonatomic) BOOL deleteMissing;
@property (nonatomic, copy) CCCouchResultsBlock resultsBlock;

- (void)start;

+ (id)couchResultsControllerFor:(NSString *)key of:(NSManagedObject *)owner;

+ (id)couchResultsControllerWithDesignDocName:(NSString *)designDocName
                                     viewName:(NSString *)viewName
                                   entityName:(NSString *)entityName
                                   relatedKey:(NSString *)relatedKey
                                 relatedValue:(NSString *)relatedValue
                                      context:(NSManagedObjectContext *)managedObjectContext;

- (NSFetchedResultsController *)fetchedResultsControllerWithSortDescriptors:(NSArray *)sortDescriptors
                                                                   delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

@end
