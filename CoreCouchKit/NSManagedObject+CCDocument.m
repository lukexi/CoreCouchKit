//
//  CCDocument.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "NSManagedObject+CCDocument.h"
#import "CoreCouchKit.h"
#import "CoreDataJSONKit.h"
#import <objc/runtime.h>

@implementation NSManagedObject (CCDocument)

+ (NSString *)cc_generateUUID
{
    // Get the current date+time as a string in standard JSON format:
    NSString *dateString = [RESTBody JSONObjectWithDate:[NSDate date]];
    
    // Construct a unique document ID that will sort chronologically:
    CFUUIDRef uuid = CFUUIDCreate(nil);
    NSString *guid = (__bridge_transfer NSString *)CFUUIDCreateString(nil, uuid);
    CFRelease(uuid);
	NSString *docId = [NSString stringWithFormat:@"%@-%@", dateString, guid];
    return docId;
}

- (BOOL)cc_isCouchDocument
{
    return [[self entity] isKindOfEntity:[NSEntityDescription entityForName:@"CCDocument"
                                                     inManagedObjectContext:self.managedObjectContext]];
}

- (CouchDatabase *)cc_couchDatabase
{
    return [self.managedObjectContext.userInfo objectForKey:kCouchDatabaseKey];
}

// Returns the dictionary representation of this object without any couchDB-related properties
- (NSMutableDictionary *)cc_userProperties
{
    NSMutableDictionary *properties = [[self cj_dictionaryRepresentation] mutableCopy];
    
    [properties removeObjectForKey:kCouchRevPropertyName];
    [properties removeObjectForKey:kCouchIDPropertyName];
    [properties removeObjectForKey:kCouchAttachmentsMetadataPropertyName];
    
    return properties;
}

- (void)cc_setCouchID:(NSString *)couchID
{
    [self setValue:couchID forKey:kCouchIDPropertyName];
}

- (NSString *)cc_couchID
{
    return [self valueForKey:kCouchIDPropertyName];
}

- (void)cc_setCouchRev:(NSString *)couchRev
{
    [self setValue:couchRev forKey:kCouchRevPropertyName];
}

- (NSString *)cc_couchRev
{
    return [self valueForKey:kCouchRevPropertyName];
}

- (NSString *)cc_attachmentsMetadata
{
    return [self valueForKey:kCouchAttachmentsMetadataPropertyName];
}

// Synchronous
- (void)cc_GET
{
    NSLog(@"(Revision was %@", [[self cc_couchDocument] currentRevision]);
    CouchQuery *query = [[self cc_couchDatabase] getDocumentsWithIDs:[NSArray arrayWithObject:[self cc_couchID]]];
    RESTOperation *getOperation = [query start];
    [getOperation wait];
    
    CouchRevision *currentRevision = [[self cc_couchDocument] currentRevision];
    
    NSLog(@"Updating current revision to %@", currentRevision);
    [self cc_setCouchRevision:currentRevision];
    NSLog(@"Got it.");
    
    [self cc_updateAttachments];
    
    // TODO get changedValues from the original object and pass them in so we can do merging without overwriting them here or create a CCConflict object
    [self cj_setPropertiesFromDescription:currentRevision.userProperties];
}

- (void)cc_PUT
{
    NSMutableDictionary *properties = [self cc_userProperties];
    
    // If we have a rev, we're updating an existing doc. Otherwise, we're putting for the first time and creating a new doc.
    
    if ([self cc_couchRev]) 
    {
        [properties setObject:[self cc_couchRev] forKey:kCouchRevKey];
        if ([self cc_attachmentsMetadata])
        {
            [properties setObject:[self cc_attachmentsMetadata] forKey:kCouchAttachmentsMetadataKey];
        }
    }
    else if (![self cc_couchID])
    {
        [self setValue:[[self class] cc_generateUUID] forKey:kCouchIDPropertyName];
    }
    
    NSLog(@"Putting to couch %@!", [properties objectForKey:@"documentType"]);
    RESTOperation *putOperation = [[self cc_couchDocument] putProperties:properties];
    [putOperation wait];
    
    if (!putOperation.isSuccessful) 
    {
        NSLog(@"Error: %@", putOperation.error);
    }
    
    if (putOperation.httpStatus == 412 || 
        putOperation.httpStatus == 409) 
    {
        // Conflict — get latest revision
        NSLog(@"Conflict! getting current revision...");
        [self cc_GET];
        [self cc_PUT];
    }
    else
    {
        NSLog(@"Put successfully! %@", putOperation.resultObject);
        CouchRevision *newRevision = putOperation.resultObject;
        [self cc_setCouchRevision:newRevision];
        
        NSError *error = nil;
        if (![self.managedObjectContext save:&error]) 
        {
            NSLog(@"Error saving! %@", error);
        }
    }
}

- (void)cc_updateAttachments
{
    [[[self entity] relationshipsByName] enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSRelationshipDescription *relationship = obj;
        BOOL isAttachment = [[[[relationship destinationEntity] userInfo] objectForKey:kCouchTypeKey] isEqualToString:kCouchTypeAttachment];
        if (isAttachment) {
            NSLog(@"Downloading attachment data for %@ of %@", key, [[self entity] name]);
            NSManagedObject *relatedAttachment = [self valueForKey:key];
            [relatedAttachment cc_updateAttachmentData];
        }
    }];
}

- (void)cc_setCouchDocument:(CouchDocument *)newDocument
{
    objc_setAssociatedObject(self, @"couchDocument", newDocument, 
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CouchDocument *)cc_couchDocument
{
    CouchDocument *couchDocument = objc_getAssociatedObject(self, @"couchDocument");
    if (!couchDocument && [self cc_couchID]) 
    {
        couchDocument = [[self cc_couchDatabase] documentWithID:[self cc_couchID]];
        [self cc_setCouchDocument:couchDocument];
    }
    return couchDocument;
}

// Will return nil if we don't have a revision yet
- (CouchRevision *)cc_couchRevision
{
    CouchRevision *couchRevision = objc_getAssociatedObject(self, @"couchRevision");
    if (!couchRevision && [self cc_couchRev]) 
    {
        CouchDocument *couchDocument = [self cc_couchDocument];
        couchRevision = [couchDocument revisionWithID:[self cc_couchRev]];
        [self cc_setCouchRevision:couchRevision];
    }
    return couchRevision;
}

- (void)cc_setCouchRevision:(CouchRevision *)couchRevision
{
    [self setValue:couchRevision.revisionID forKey:kCouchRevPropertyName];
    [self setValue:[couchRevision.properties objectForKey:@"_attachments"] 
            forKey:kCouchAttachmentsMetadataPropertyName];
    objc_setAssociatedObject(self, @"couchRevision", couchRevision, 
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// sketches of interfaces to asynchronously get values

- (void)applyValue:(NSString *)key 
                to:(CCValueBlock)valueBlock
{
    
}

// should return a token to stop monitoring with
- (id)monitor:(NSString *)toManyRelationshipKey 
        added:(CCSetBlock)addedBlock
      changed:(CCSetBlock)changedBlock
      removed:(CCSetBlock)removedBlock
{
    return nil;
}

@end