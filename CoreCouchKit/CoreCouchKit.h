//
//  CoreCouchKit.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCManagedObjectModel.h"
#import "CCDocument.h"
#import "CCCouchResultsController.h"
#import "CCAttachment.h"
#import "CCQuery.h"
#import "CCFetchedResultsController.h"

#define kCouchDatabaseKey @"couchDatabase"
#define kCouchIDPropertyName @"couchID"
#define kCouchRevPropertyName @"couchRev"
#define kCouchNeedsPUTPropertyName @"needsPUT"
#define kCouchAttachmentsMetadataPropertyName @"attachmentsMetadata"
#define kCouchTypeKey @"couchType"
#define kCouchTypeDocument @"document"
#define kCouchTypeAttachment @"attachment"
#define kCouchAttachmentContentTypeKey @"contentType"
#define kCouchAttachmentDocumentPropertyKey @"documentProperty"
#define kCouchAttachmentDataPropertyKey @"dataProperty"

@interface CoreCouchKit : NSObject

+ (void)setupWithContext:(NSManagedObjectContext *)context
               serverURL:(NSString *)serverURLString
            databaseName:(NSString *)databaseName;
+ (NSManagedObjectModel *)couchManagedObjectModelWithContentsOfURL:(NSURL *)modelURL;

+ (CoreCouchKit *)sharedCoreCouchKit;

@property (nonatomic, strong) NSManagedObjectContext *backgroundContext;
@property (nonatomic, strong) CouchDatabase *database;
- (CCQuery *)queryForRelationship:(NSString *)key ofObject:(NSManagedObject *)managedObject;
- (CCFetchedResultsController *)fetchedResultsControllerForRelationship:(NSString *)key 
                                                      ofObject:(NSManagedObject *)managedObject
                                               sortDescriptors:(NSArray *)sortDescriptors
                                                      delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

- (CCQuery *)queryForObjectsOfType:(NSString *)entityName whose:(NSString *)key is:(NSString *)value;
- (CCFetchedResultsController *)fetchedResultsControllerForObjectsOfType:(NSString *)entityName whose:(NSString *)key is:(NSString *)value sortDescriptors:(NSArray *)sortDescriptors delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

@end


