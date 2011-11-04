//
//  CCDocument.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCDocument.h"
#import "CoreCouchKit.h"
#import <objc/runtime.h>

@interface CCDocument ()

@end

@implementation CCDocument
@dynamic couchRev;
@dynamic couchID;
@dynamic attachmentsMetadata;

- (NSString *)couchID 
{
    [self willAccessValueForKey:kCouchIDPropertyName];
    NSString *ourCouchID = [self primitiveValueForKey:kCouchIDPropertyName];
    [self didAccessValueForKey:kCouchIDPropertyName];
    if (!ourCouchID) 
    {
        NSLog(@"Generating new shared ID for inserted object: %@", [self class]);
        ourCouchID = [[self class] cc_generateUUID];
        self.couchID = ourCouchID;
    }
    return ourCouchID;
}

- (void)override_prepareForDeletion // CCMixin will place the contents of the original implementation of the method in this selector, and place the contents of this implementation under the original selector (i.e. willSave in this case)
{
    [self override_prepareForDeletion];
    if (self.couchRev) 
    {
        CouchRevision *revision = [self cc_couchRevision];
        NSLog(@"Revision: %@ for document: %@", revision, [self cc_couchDocument]);
        RESTOperation *delete = [revision DELETE];
        [delete onCompletion:^{
            NSLog(@"Deleted %@", self);
        }];
        [delete start];
    }
}

#pragma mark - CouchDocumentModel
- (void)couchDocumentChanged:(CouchDocument *)doc
{
    NSLog(@"Updating %@ with changed doc! %@", self, doc);
    [self cj_setPropertiesFromDescription:doc.userProperties];
}

#pragma mark - CJRelationshipRepresentation

// If one couch document includes another in a relationship,
// just embed its ID in the JSON description as one usually does
// with couchdb relationships.
- (id)cj_relationshipRepresentation
{
    return self.couchID;
}

+ (NSManagedObject *)cj_objectFromRelationshipRepresentation:(id)relationshipRepresentation
                                                   inContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:NSStringFromClass(self)];
    [request setPredicate:[NSPredicate predicateWithFormat:@"%K == %@", 
                           kCouchIDPropertyName, relationshipRepresentation]];
    
    NSError *error = nil;
    NSArray *results = [managedObjectContext executeFetchRequest:request error:&error];
    if ([results count]) 
    {
        return [results objectAtIndex:0];
    }
    
    return [NSEntityDescription insertNewObjectForEntityForName:NSStringFromClass(self) 
                                         inManagedObjectContext:managedObjectContext];
}

@end


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
    NSDictionary *userInfo = [[self entity] userInfo];
    return [[userInfo objectForKey:kCouchTypeKey] isEqualToString:kCouchTypeDocument];
}

- (CouchDatabase *)cc_couchDatabase
{
    return [self.managedObjectContext.userInfo objectForKey:kCouchDatabaseKey];
}

- (NSMutableDictionary *)cc_userProperties
{
    NSMutableDictionary *properties = [[self cj_dictionaryRepresentation] mutableCopy];
    
    [properties removeObjectForKey:kCouchRevPropertyName];
    [properties removeObjectForKey:kCouchIDPropertyName];
    [properties removeObjectForKey:kCouchAttachmentsMetadataPropertyName];
    
    return properties;
}

- (void)cc_GET
{
    CCDocument *documentSelf = (CCDocument *)self;
    NSLog(@"(Revision was %@", [[self cc_couchDocument] currentRevision]);
    CouchQuery *query = [[self cc_couchDatabase] getDocumentsWithIDs:[NSArray arrayWithObject:documentSelf.couchID]];
    RESTOperation *getOperation = [query start];
    [getOperation wait];
    
    CouchRevision *currentRevision = [[self cc_couchDocument] currentRevision];
    
    NSLog(@"Updating current revision to %@", currentRevision);
    [self cc_setCouchRevision:currentRevision];
    NSLog(@"Got it.");
    
#warning get changedValues from the original object and pass them in so we can do merging without overwriting them here or create a CCConflict object
    [self cj_setPropertiesFromDescription:currentRevision.userProperties];
}

- (void)cc_PUT
{
    NSMutableDictionary *properties = [self cc_userProperties];
    
    // If we have a rev, we're updating an existing doc. Otherwise, we're putting for the first time and creating a new doc.
    
    CCDocument *documentSelf = (CCDocument *)self;
    if (documentSelf.couchRev) 
    {
        [properties setObject:documentSelf.couchRev forKey:kCouchRevKey];
        if (documentSelf.attachmentsMetadata) 
        {
            [properties setObject:documentSelf.attachmentsMetadata forKey:kCouchAttachmentsMetadataKey];
        }
    }
    
    NSLog(@"Putting to couch %@!", properties);
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

- (void)cc_setCouchDocument:(CouchDocument *)newDocument
{
    CouchDocument *currentDocument = objc_getAssociatedObject(self, @"couchDocument");
    currentDocument.modelObject = nil;
    newDocument.modelObject = self;
    objc_setAssociatedObject(self, @"couchDocument", newDocument, 
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CouchDocument *)cc_couchDocument
{
    CCDocument *documentSelf = (CCDocument *)self;
    CouchDocument *couchDocument = objc_getAssociatedObject(self, @"couchDocument");
    if (!couchDocument && documentSelf.couchID) 
    {
        couchDocument = [[self cc_couchDatabase] documentWithID:documentSelf.couchID];
        [self cc_setCouchDocument:couchDocument];
    }
    return couchDocument;
}

- (CouchRevision *)cc_couchRevision
{
    CCDocument *documentSelf = (CCDocument *)self;
    CouchRevision *couchRevision = objc_getAssociatedObject(self, @"couchRevision");
    if (!couchRevision && documentSelf.couchRev) 
    {
        CouchDocument *couchDocument = [self cc_couchDocument];
        couchRevision = [couchDocument revisionWithID:documentSelf.couchRev];
        [self cc_setCouchRevision:couchRevision];
    }
    return couchRevision;
}

- (void)cc_setCouchRevision:(CouchRevision *)couchRevision
{
    CCDocument *documentSelf = (CCDocument *)self;
    documentSelf.couchRev = couchRevision.revisionID;
    documentSelf.attachmentsMetadata = [couchRevision.properties objectForKey:@"_attachments"];
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