//
//  CCDocument.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <CouchCocoa/CouchCocoa.h>

#define kCouchIDKey @"_id"
#define kCouchRevKey @"_rev"
#define kCouchAttachmentsMetadataKey @"_attachments"
#define kCouchPreventPUTKey @"kCouchPreventPUTKey"

typedef void(^CCBlock)(void);

@interface NSManagedObject (CCDocument)

+ (NSString *)cc_generateUUID;

- (void)cc_setCouchID:(NSString *)couchID;
- (NSString *)cc_couchID;
- (void)cc_setCouchRev:(NSString *)couchRev;
- (NSString *)cc_couchRev;
- (NSString *)cc_attachmentsMetadata;

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