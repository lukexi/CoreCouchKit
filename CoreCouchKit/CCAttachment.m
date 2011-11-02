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

@dynamic needsPUT;

@end

@implementation NSManagedObject (CoreCouchAttachmentHandling)

- (BOOL)cc_isCouchAttachment
{
    NSDictionary *userInfo = [[self entity] userInfo];
    return [[userInfo objectForKey:kCouchTypeKey] isEqualToString:kCouchTypeAttachment];
}

- (void)cc_PUTAttachment
{
    NSLog(@"Putting attachment: %@", NSStringFromClass([self class]));
    NSData *attachmentRepresentation = [self cc_attachmentRepresentation];
    if (attachmentRepresentation) 
    {
        RESTOperation *operation = [[self cc_couchAttachment] PUT:attachmentRepresentation];
        [operation start];
        NSLog(@"Uploading %@ with operation %@", self, operation);
        
        [operation onCompletion:^{
            if (operation.httpStatus == 409) 
            {
                NSLog(@"Conflict in attachment! Pulling the latest...");
                CouchRevision *currentRevision = [[[self cc_document] cc_couchDocument] currentRevision];
                NSLog(@"Done.");
                [[self cc_document] cc_setCouchRevision:currentRevision];
                [self cc_PUTAttachment];
            }
            NSLog(@"Completed upload operation: %@", operation);
        }];
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
    RESTOperation *operation = [[self cc_couchAttachment] GET];
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