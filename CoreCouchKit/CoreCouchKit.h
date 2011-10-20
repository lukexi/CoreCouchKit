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

#define kCouchIDPropertyName @"couchID"
#define kCouchRevPropertyName @"couchRev"
#define kCouchTypeKey @"couchType"
#define kCouchTypeDocument @"document"
#define kCouchTypeAttachment @"attachment"
#define kCouchAttachmentContentTypeKey @"contentType"
#define kCouchAttachmentDocumentPropertyKey @"documentProperty"
#define kCouchAttachmentDataPropertyKey @"dataProperty"

@interface CoreCouchKit : NSObject

+ (void)setupWithContext:(NSManagedObjectContext *)context;
+ (CoreCouchKit *)sharedCoreCouchKit;

@end


typedef void(^CCValueBlock)(id value);
@class CCDocument;
@interface NSManagedObject (CoreCouchAttachmentHandling)
- (BOOL)cc_isCouchAttachment;
- (void)cc_PUTAttachment;
- (NSData *)cc_attachmentRepresentation;
- (NSValueTransformer *)cc_valueTransformer;
- (void)cc_setFromAttachmentRepresentation:(NSData *)attachmentRepresentation;
- (CouchAttachment *)cc_couchAttachment;
- (void)cc_valueWithCompletion:(CCValueBlock)valueBlock;

- (CCDocument *)cc_document;
- (NSString *)cc_attachmentProperty;
- (NSString *)cc_contentType;

@end