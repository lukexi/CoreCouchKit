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
#define kCouchDatabaseKey @"couchDatabase"
#define kCouchIDPropertyName @"couchID"
#define kCouchRevPropertyName @"couchRev"
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

@end


