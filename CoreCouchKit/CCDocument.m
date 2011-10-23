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

- (void)override_willSave // CCMixin will place the contents of the original implementation of the method in this selector, and place the contents of this implementation under the original selector (i.e. willSave in this case)
{
    [self override_willSave]; // So, this actually calls the original implementation.
    NSLog(@"WILL SAVE ON %@ %@", [self class], self.couchID);
    // Don't do a redundant put when we just got changes or new objects from Couch.
    if (self.isDeleted || !self.hasChanges || [self.managedObjectContext cc_isSavingWithoutPUT]) 
    {
        return;
    }
    NSLog(@"PUTTING %@ %@ TO COUCH", [self class], self.couchID);
    [self cc_putToCouch];
}

- (void)override_prepareForDeletion // See above.
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

- (void)cc_putToCouch
{
    [self cc_putToCouchWithCompletion:nil];
}

- (void)cc_putToCouchWithCompletion:(OnCompleteBlock)completion
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
    [putOperation onCompletion:^{
        if (!putOperation.isSuccessful) 
        {
            NSLog(@"Error: %@", putOperation.error);
        }
        
        if (putOperation.httpStatus == 412 || 
            putOperation.httpStatus == 409) 
        {
            // Conflict — get latest revision 
            NSLog(@"CONFLICT! BLOCKING TO GET CURRENT REVISION");
            CouchRevision *currentRevision = [[self cc_couchDocument] currentRevision];
            [self cc_setCouchRevision:currentRevision];
            NSLog(@"DONE! Current revision is now %@", documentSelf.couchRev);
            [self cj_setPropertiesFromDescription:currentRevision.userProperties];
            [self cc_putToCouch];
        }
        else
        {
            NSLog(@"Put successfully! %@", putOperation.resultObject);
            CouchRevision *newRevision = putOperation.resultObject;
            [self cc_setCouchRevision:newRevision];
            
            NSError *error = nil;
            if (![self.managedObjectContext cc_saveWithoutPUT:&error]) 
            {
                NSLog(@"Error saving! %@", error);
            }
        }        
    }];
    
    // Multiple onCompletion blocks get called in order of adding.
    if (completion) 
    {
        [putOperation onCompletion:completion];
    }
    
    [putOperation start];
}

- (CouchDocument *)cc_couchDocument
{
    CCDocument *documentSelf = (CCDocument *)self;
    CouchDocument *couchDocument = objc_getAssociatedObject(self, @"couchDocument");
    if (!couchDocument && documentSelf.couchID) 
    {
        couchDocument = [[self cc_couchDatabase] documentWithID:documentSelf.couchID];
        couchDocument.modelObject = self;
        objc_setAssociatedObject(self, @"couchDocument", couchDocument, 
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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

@end

@implementation NSManagedObjectContext (CCDocument)

- (BOOL)cc_isSavingWithoutPUT
{
    return [[[self userInfo] objectForKey:kCouchPreventPUTKey] boolValue];
}

- (BOOL)cc_saveWithoutPUT:(NSError **)error
{
    [[self userInfo] setObject:[NSNumber numberWithBool:YES] forKey:kCouchPreventPUTKey];
    BOOL success = [self save:error];
    [[self userInfo] removeObjectForKey:kCouchPreventPUTKey];
    return success;
}

@end