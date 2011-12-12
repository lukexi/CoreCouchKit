//
//  CCAttachment.m
//  CoreCouchKit
//
//  Created by Luke Iannini on 10/23/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "NSManagedObject+CCAttachment.h"
#import "CoreCouchKit.h"

@implementation NSManagedObject (CoreCouchAttachmentHandling)

- (BOOL)cc_isCouchAttachment
{
    return [[self entity] isKindOfEntity:[NSEntityDescription entityForName:@"CCAttachment"
                                                     inManagedObjectContext:self.managedObjectContext]];
}

- (void)cc_PUTAttachment
{
    NSLog(@"Putting attachment: %@", NSStringFromClass([self class]));
    NSData *attachmentRepresentation = [self cc_attachmentRepresentation];
    if (attachmentRepresentation) 
    {
        NSLog(@"Revision before updating attachment: %@", [[[self cc_couchAttachment] document] currentRevisionID]);
        RESTOperation *operation = [[self cc_couchAttachment] PUT:attachmentRepresentation];
        NSLog(@"Upload operation beginning %@", operation);
        [operation wait];
        NSLog(@"Uploaded %@ with operation %@", self, operation);
        NSLog(@"Revision after updating attachment: %@", [[[self cc_couchAttachment] document] currentRevisionID]);
        NSLog(@"operation response: %@", operation.responseBody.fromJSON);
        if (operation.error) 
        {
            NSLog(@"Error uploading attachment: %@", operation.error);
            return;
        }
        
        if (operation.httpStatus == 409 || 
            operation.httpStatus == 412) 
        {
            NSLog(@"Conflict in attachment! Pulling the latest...");
            [[self cc_document] cc_GET];
            NSLog(@"Done.");
            [self cc_PUTAttachment];
            return;
        }
        
        NSString *currentRevisionID = [[[self cc_couchAttachment] document] currentRevisionID];
        [self cc_setCouchDocumentRev:currentRevisionID];
        [[self cc_document] cc_setCouchRev:currentRevisionID];
        #warning update metadata with md5 of attachment, because an attachment can stay valid even if the doc revision changes
    }
}

- (void)cc_setCouchDocumentRev:(NSString *)couchDocumentRev
{
    [self setValue:couchDocumentRev forKey:kCouchAttachmentDocumentRevisionPropertyName];
}

- (NSString *)cc_couchDocumentRev
{
    return [self valueForKey:kCouchAttachmentDocumentRevisionPropertyName];
}

// Attachements may be NSData directly, or transformable via an NSValueTransformer
- (NSData *)cc_attachmentRepresentation
{
    id attachment = [self valueForKey:[self cc_attachmentProperty]];
    NSData *attachmentData = attachment;
    if ([self cc_usesTransformableAttribute])
    {
        attachmentData = [[self cc_valueTransformer] transformedValue:attachment];
    }
    return attachmentData;
}

- (BOOL)cc_usesTransformableAttribute
{
    return [[self cc_attachmentAttributeDescription] attributeType] == NSTransformableAttributeType;
}

- (NSAttributeDescription *)cc_attachmentAttributeDescription
{
    return [[[self entity] attributesByName] objectForKey:[self cc_attachmentProperty]];
}

- (NSValueTransformer *)cc_valueTransformer
{
    NSString *valueTransformerName = [[self cc_attachmentAttributeDescription] valueTransformerName];
    NSValueTransformer *valueTransformer = [NSValueTransformer valueTransformerForName:valueTransformerName];
    return valueTransformer;
}

- (void)cc_setFromAttachmentRepresentation:(NSData *)attachmentRepresentation
{
    id attachment = attachmentRepresentation;
    if ([self cc_usesTransformableAttribute]) 
    {
        attachment = [[self cc_valueTransformer] reverseTransformedValue:attachmentRepresentation];
    }
    [self setValue:attachment forKey:[self cc_attachmentProperty]];
}

- (CouchAttachment *)cc_couchAttachment
{
    CouchRevision *revision = [[self cc_document] cc_couchRevision];
    CouchAttachment *attachment = [revision attachmentNamed:[self cc_attachmentProperty]];
    if (!attachment) 
    {
        attachment = [revision createAttachmentWithName:[self cc_attachmentProperty] 
                                                   type:[self cc_contentType]];
    }
    return attachment;
}

- (void)cc_updateAttachmentData
{
    if ([self cc_attachmentDataIsUpToDate] || ![self cc_couchDocumentRev]) 
    {
        NSLog(@"Attachment data for %@ is up to date, skipping download", self);
        return;
    }
    // TODO: look at the attachment metadata (digest key) and figure out if an update is needed.
    [[CoreCouchKit sharedCoreCouchKit] changeObject:self 
                                onBackgroundContext:^(NSManagedObject *backgroundObject, NSManagedObjectContext *context) 
    {
        [backgroundObject cc_GETAttachment];
        NSError *error;
        if (![context save:&error]) 
        {
            NSLog(@"Error saving attachment update: %@", error);
        }
    }];
}

- (BOOL)cc_attachmentDataIsUpToDate
{
    return [[self cc_couchDocumentRev] isEqualToString:[[self cc_document] cc_couchRev]];
}

- (void)cc_GETAttachment
{
    RESTOperation *operation = [[self cc_couchAttachment] GET];
    [operation wait];
    [self cc_setFromAttachmentRepresentation:[[self cc_couchAttachment] body]];
    [self cc_setCouchDocumentRev:[[self cc_document] cc_couchRev]];
}

- (NSManagedObject *)cc_document
{
    __block NSString *documentKey = [[[self entity] userInfo] objectForKey:kCouchAttachmentDocumentPropertyKey];
    /*
    // Search relationships for a CCDocument-derived entity. If more than one is found, kCouchAttachmentDocumentPropertyKey must be set to determine the correct one.
    if (!documentKey) 
    {
        __block BOOL found = NO;
        [[[self entity] relationshipsByName] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSRelationshipDescription *relationship = obj;
            if ([[relationship entity] isKindOfEntity:[NSEntityDescription entityForName:@"CCDocument" 
                                                                  inManagedObjectContext:self.managedObjectContext]])
            {
                documentKey = key;
                NSAssert2(!found, @"Found multiple CCDocument-type relationships in entity %@. Please set %@ in the entity's metadata to determine the data-holding attribute for this attachment.", self, kCouchAttachmentDocumentPropertyKey);
                found = YES;
            }
        }];
    }
     */
    NSAssert2(documentKey, @"Must add the key %@ with the name of the property pointing to the parent document for your attachment %@", kCouchAttachmentDocumentPropertyKey, self);
    return [self valueForKey:documentKey];
}

- (NSString *)cc_attachmentProperty
{
    __block NSString *attachmentProperty = [[[self entity] userInfo] objectForKey:kCouchAttachmentDataPropertyKey];
    // Search attributes for a Transformable or Binary Data attribute. If more than one is found, kCouchAttachmentDataPropertyKey must be set to determine the correct one.
    /*
    if (!attachmentProperty) 
    {
        __block BOOL found = NO;
        [[[self entity] attributesByName] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSAttributeDescription *description = obj;
            if ([description attributeType] == NSBinaryDataAttributeType || 
                [description attributeType] == NSTransformableAttributeType) 
            {
                attachmentProperty = key;
                NSAssert2(!found, @"Found multiple Binary Data or Transformable attributes in entity %@. Please set %@ in the entity's metadata to determine the data-holding attribute for this attachment.", self, kCouchAttachmentDataPropertyKey);
                found = YES;
            }
        }];
    }
     */
    NSAssert2(attachmentProperty, @"Must add the key %@ with the name the property holding the data for your attachment %@", kCouchAttachmentDataPropertyKey, self);
    return attachmentProperty;
}

- (NSString *)cc_contentType
{
    NSString *contentType = [[[self entity] userInfo] objectForKey:kCouchAttachmentContentTypeKey];
    NSAssert2(contentType, @"Must add the key %@ holding a value with the content type of your attachment %@", kCouchAttachmentContentTypeKey, self);
    return contentType;
}

@end