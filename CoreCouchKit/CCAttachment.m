//
//  CCAttachment.m
//  CoreCouchKit
//
//  Created by Luke Iannini on 10/23/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCAttachment.h"
#import "CCDocument.h"
#import "CoreCouchKit.h"

@implementation CCAttachment
@dynamic couchDocumentRev;
@end

@implementation NSManagedObject (CoreCouchAttachmentHandling)

- (BOOL)cc_isCouchAttachment
{
    return [[self entity] isKindOfEntity:[NSEntityDescription entityForName:NSStringFromClass([CCAttachment class]) 
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
        [operation wait];
        NSLog(@"Uploaded %@ with operation %@", self, operation);
        NSLog(@"Revision after updating attachment: %@", [[[self cc_couchAttachment] document] currentRevisionID]);
        NSLog(@"operation response: %@", operation.responseBody.fromJSON);
        
        CCAttachment *attachmentSelf = (CCAttachment *)self;
        attachmentSelf.couchDocumentRev = [[[self cc_couchAttachment] document] currentRevisionID];
        [self cc_document].couchRev = [[[self cc_couchAttachment] document] currentRevisionID];
        
#warning must update owning document with new revision caused by editing the attachment, and update metadata?
        
        if (operation.httpStatus == 409 || 
            operation.httpStatus == 412) 
        {
            NSLog(@"Conflict in attachment! Pulling the latest...");
            [[self cc_document] cc_GET];
            NSLog(@"Done.");
            [self cc_PUTAttachment];
        }
    }
}

- (NSData *)cc_attachmentRepresentation
{
    id attachment = [self valueForKey:[self cc_attachmentProperty]];
    NSData *attachmentData = [[self cc_valueTransformer] transformedValue:attachment];
    return attachmentData;
}

- (NSValueTransformer *)cc_valueTransformer
{
    NSString *valueTransformerName = [[[[self entity] attributesByName] objectForKey:[self cc_attachmentProperty]] valueTransformerName];
    NSValueTransformer *valueTransformer = [NSValueTransformer valueTransformerForName:valueTransformerName];
    
    return valueTransformer;
}

- (void)cc_setFromAttachmentRepresentation:(NSData *)attachmentRepresentation
{
    id attachment = [[self cc_valueTransformer] reverseTransformedValue:attachmentRepresentation];
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
    if ([self cc_attachmentDataIsUpToDate]) 
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
    CCAttachment *attachmentSelf = (CCAttachment *)self;
    return [attachmentSelf.couchDocumentRev isEqualToString:[self cc_document].couchRev];
}

- (void)cc_GETAttachment
{
    RESTOperation *operation = [[self cc_couchAttachment] GET];
    [operation wait];
    [self cc_setFromAttachmentRepresentation:[[self cc_couchAttachment] body]];
    
    CCAttachment *attachmentSelf = (CCAttachment *)self;
    attachmentSelf.couchDocumentRev = [self cc_document].couchRev;
}

/*
- (void)cc_valueWithCompletion:(CCValueBlock)valueBlock
{
    id currentValue = [self valueForKey:[self cc_attachmentProperty]];
    if (currentValue) 
    {
        if (valueBlock) 
        {
            valueBlock(currentValue);
        }
        return;
    }
    
    // Getting the contents asynchronously
    
    [operation onCompletion:^{
        NSLog(@"Downloaded attachment for class %@ with metadata: %@", [self class], [[self cc_couchAttachment] metadata]);
        [self cc_setFromAttachmentRepresentation:[[self cc_couchAttachment] body]];
        
        NSError *error = nil;
        if (![self.managedObjectContext save:&error]) 
        {
            NSLog(@"Error saving: %@", error);
        }
        
        if (valueBlock) 
        {
            valueBlock([self valueForKey:[self cc_attachmentProperty]]);
        }
    }];
    [operation start];
}
 */

- (CCDocument *)cc_document
{
    NSString *documentKey = [[[self entity] userInfo] objectForKey:kCouchAttachmentDocumentPropertyKey];
    NSAssert2(documentKey, @"Must add the key %@ with the name of the property pointing to the parent document for your attachment %@", kCouchAttachmentDocumentPropertyKey, self);
    return [self valueForKey:documentKey];
}

- (NSString *)cc_attachmentProperty
{
    NSString *attachmentProperty = [[[self entity] userInfo] objectForKey:kCouchAttachmentDataPropertyKey];
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