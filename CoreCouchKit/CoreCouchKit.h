//
//  CoreCouchKit.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCManagedObjectModel.h"
#import "NSManagedObject+CCDocument.h"
#import "NSManagedObject+CCAttachment.h"
#import "CCQuery.h"
#import "CCFetchedResultsController.h"
#import "NSObject_KVOBlock.h"

#define kCouchDatabaseKey @"couchDatabase"
#define kCouchIDPropertyName @"couchID"
#define kCouchRevPropertyName @"couchRev"
#define kCouchAttachmentDocumentRevisionPropertyName @"couchDocumentRev"
#define kCouchAttachmentsMetadataPropertyName @"attachmentsMetadata"
#define kCouchTypeKey @"couchType"
#define kCouchTypeDocument @"document"
#define kCouchTypeAttachment @"attachment"
#define kCouchAttachmentContentTypeKey @"contentType"
#define kCouchAttachmentDocumentPropertyKey @"documentProperty"
#define kCouchAttachmentDataPropertyKey @"dataProperty"

typedef void(^CCBackgroundContextBlock)(NSManagedObject *backgroundObject, 
                                        NSManagedObjectContext *context);

@interface CoreCouchKit : NSObject

+ (void)setupWithContext:(NSManagedObjectContext *)context
               serverURL:(NSString *)serverURLString
            databaseName:(NSString *)databaseName;

+ (NSManagedObjectModel *)couchManagedObjectModelWithContentsOfURL:(NSURL *)modelURL;

+ (CoreCouchKit *)sharedCoreCouchKit;

@property (nonatomic, strong) NSManagedObjectContext *backgroundContext;
@property (nonatomic, strong) CouchDatabase *database;

// I haven't yet implemented a way for a Document object to notice changes to things on the ends of its relationships,
// so users can manaully mark their document as needing PUTs for now.
// (e.g., a Car entity can't tell when a child Wheel entity changes its tireBrand property)
// By traversing the relationships out from the Document and marking the route back to the document, it's possible to do this automatically (though it might have performance considerations)
// Could also detect changes by rendering the dictionary and saving the old version and comparing the two.
- (void)markNeedsPUT:(NSManagedObject *)documentObject;

#pragma mark - Editing
- (void)changeObject:(NSManagedObject *)object 
 onBackgroundContext:(CCBackgroundContextBlock)backgroundBlock;

#pragma mark - Queries
- (CCQuery *)queryForRelationship:(NSString *)key
                         ofObject:(NSManagedObject *)managedObject;

- (CCFetchedResultsController *)fetchedResultsControllerForRelationship:(NSString *)key
                                                               ofObject:(NSManagedObject *)managedObject
                                                        sortDescriptors:(NSArray *)sortDescriptors
                                                               delegate:(id <NSFetchedResultsControllerDelegate>)delegate;


- (CCQuery *)queryForObjectsOfType:(NSString *)entityName 
                             whose:(NSString *)key 
                                is:(NSString *)value;

- (CCFetchedResultsController *)fetchedResultsControllerForObjectsOfType:(NSString *)entityName 
                                                                   whose:(NSString *)key 
                                                                      is:(NSString *)value 
                                                         sortDescriptors:(NSArray *)sortDescriptors 
                                                                delegate:(id <NSFetchedResultsControllerDelegate>)delegate;

@end