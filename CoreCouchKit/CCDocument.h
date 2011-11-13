//
//  CCDocument.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CoreDataJSONKit.h"
#import <CouchCocoa/CouchCocoa.h>

#define kCouchIDKey @"_id"
#define kCouchRevKey @"_rev"
#define kCouchAttachmentsMetadataKey @"_attachments"
#define kCouchPreventPUTKey @"kCouchPreventPUTKey"

typedef void(^CCBlock)(void);

@interface CCDocument : NSManagedObject <CouchDocumentModel, CJRelationshipRepresentation>

@property (nonatomic, retain) NSString * couchRev;
@property (nonatomic, retain) NSString * couchID;
@property (nonatomic, retain) id attachmentsMetadata;

@end

@interface NSManagedObject (CCDocument)

+ (NSString *)cc_generateUUID;
- (BOOL)cc_isCouchDocument;
- (CouchDatabase *)cc_couchDatabase;
- (NSMutableDictionary *)cc_userProperties;

- (void)cc_setCouchDocument:(CouchDocument *)document;
- (CouchDocument *)cc_couchDocument;

- (void)cc_setCouchRevision:(CouchRevision *)couchRevision;
- (CouchRevision *)cc_couchRevision;

- (void)cc_GET;
- (void)cc_PUT;

- (void)cc_updateAttachments;

@end