//
//  CoreCouchKit.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CoreCouchKit.h"
#import "CCManagedObjectModel.h"
#import "CCDocument.h"

@interface CoreCouchKit ()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) id contextWillSaveObserver;

- (void)updateWithNote:(NSNotification *)note;
- (id)initWithContext:(NSManagedObjectContext *)context;

@end

@implementation CoreCouchKit
@synthesize managedObjectContext, contextWillSaveObserver;
static CoreCouchKit *sharedCoreCouchKit = nil;

- (void)dealloc
{
    contextWillSaveObserver = nil;
}

+ (void)setupWithContext:(NSManagedObjectContext *)context
{
    NSParameterAssert(context);
    if (!sharedCoreCouchKit) 
    {
        sharedCoreCouchKit = [[self alloc] initWithContext:context];
    }
}

+ (CoreCouchKit *)sharedCoreCouchKit
{
    NSAssert(sharedCoreCouchKit, @"Must call setupWithContext before using the sharedCoreCouchKit");
    return sharedCoreCouchKit;
}

- (id)initWithContext:(NSManagedObjectContext *)context
{
    self = [super init];
    if (self) 
    {
        self.managedObjectContext = context;
        
        self.contextWillSaveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextWillSaveNotification object:self.managedObjectContext queue:nil usingBlock:^(NSNotification *note) 
        {
            [self updateWithNote:note];
        }];
    }
    return self;
}

- (void)updateWithNote:(NSNotification *)note
{
    NSLog(@"Got note! %@", note);
    NSSet *changedObjects = [[self.managedObjectContext updatedObjects] setByAddingObjectsFromSet:[self.managedObjectContext insertedObjects]];
    
    for (NSManagedObject *object in changedObjects) 
    {
        if ([object cc_isCouchAttachment]) 
        {
            [object cc_PUTAttachment];
        }
    }
}

@end

@implementation NSManagedObject (CoreCouchAttachmentHandling)

- (BOOL)cc_isCouchAttachment
{
    NSDictionary *userInfo = [[self entity] userInfo];
    return [[userInfo objectForKey:kCouchTypeKey] isEqualToString:kCouchTypeAttachment];
}

- (void)cc_PUTAttachment
{
    NSData *attachmentRepresentation = [self cc_attachmentRepresentation];
    if (self.hasChanges && attachmentRepresentation) 
    {
        RESTOperation *operation = [[self cc_couchAttachment] PUT:attachmentRepresentation];
        [operation start];
        NSLog(@"Uploading %@ with operation %@", self, operation);
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
    CouchAttachment *attachment = [[[self cc_document] cc_couchDocument].currentRevision createAttachmentWithName:[self cc_attachmentProperty] 
                                                                                                        type:[self cc_contentType]];
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
        
        [self cc_setFromAttachmentRepresentation:[[self cc_couchAttachment] body]];
        
        NSError *error = nil;
        if (![self.managedObjectContext cc_saveWithoutPUT:&error]) 
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
