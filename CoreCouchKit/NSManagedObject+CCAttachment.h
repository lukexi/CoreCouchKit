//
//  CCAttachment.h
//  CoreCouchKit
//
//  Created by Luke Iannini on 10/23/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <CoreData/CoreData.h>

typedef void(^CCValueBlock)(id value);
typedef void(^CCSetBlock)(NSSet *results);

@class CouchAttachment;
@interface NSManagedObject (CoreCouchAttachmentHandling)
- (BOOL)cc_isCouchAttachment;
- (void)cc_PUTAttachment;
- (void)cc_GETAttachment;

- (void)cc_setCouchDocumentRev:(NSString *)couchDocumentRev;
- (NSString *)cc_couchDocumentRev;

// Asynchronously update the attachment data
- (void)cc_updateAttachmentData;
- (BOOL)cc_attachmentDataIsUpToDate;

- (NSData *)cc_attachmentRepresentation;
- (NSValueTransformer *)cc_valueTransformer;
- (BOOL)cc_usesTransformableAttribute;
- (NSAttributeDescription *)cc_attachmentAttributeDescription;
- (void)cc_setFromAttachmentRepresentation:(NSData *)attachmentRepresentation;
- (CouchAttachment *)cc_couchAttachment;

// deprecated, just use KVO
//- (void)cc_valueWithCompletion:(CCValueBlock)valueBlock;

- (NSManagedObject *)cc_document;
- (NSString *)cc_attachmentProperty;
- (NSString *)cc_contentType;

@end