//
//  CCAttachment.h
//  CoreCouchKit
//
//  Created by Luke Iannini on 10/23/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface CCAttachment : NSManagedObject

@property (nonatomic, retain) NSNumber * needsPUT;

@end

typedef void(^CCValueBlock)(id value);
typedef void(^CCSetBlock)(NSSet *results);

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