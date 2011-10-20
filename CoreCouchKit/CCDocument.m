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
    return properties;
}

- (void)cc_putToCouch
{
    [self cc_putToCouchWithCompletion:nil];
}

- (void)cc_putToCouchWithCompletion:(OnCompleteBlock)completion
{
    NSMutableDictionary *properties = [self cc_userProperties];
    NSLog(@"Putting to couch %@!", properties);
    // If we have a rev, we're updating an existing doc. Otherwise, we're putting for the first time and creating a new doc.
    
    CCDocument *documentSelf = (CCDocument *)self;
    
    if (documentSelf.couchRev) 
    {
        [properties setObject:documentSelf.couchRev forKey:kCouchRevKey];
    }
    
    RESTOperation *putOperation = [[self cc_couchDocument] putProperties:properties];
    [putOperation onCompletion:^{
        if (!putOperation.isSuccessful) 
        {
            NSLog(@"Error: %@", putOperation.error);
        }
        
        if (putOperation.httpStatus == 412) 
        {
            // Conflict — get latest revision 
            NSLog(@"Getting from couch due to conflict... %@", self);
            [self cc_getFromCouchWithCompletion:^{
                [self cc_putToCouch];
            }];
        }
        else
        {
            NSLog(@"Put successfully! %@", putOperation.resultObject);
            CouchRevision *newRevision = putOperation.resultObject;
            documentSelf.couchRev = newRevision.revisionID;
            
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

- (void)cc_getFromCouch
{
    [self cc_getFromCouchWithCompletion:nil];
}

- (void)cc_getFromCouchWithCompletion:(OnCompleteBlock)completion
{
    NSLog(@"Getting from couch... %@", self);
    RESTOperation *getOperation = [[self cc_couchDocument] GET];
    [getOperation onCompletion:^{
        if (!getOperation.isSuccessful) 
        {
            NSLog(@"Error: %@", getOperation.error);
        }
        
        NSLog(@"New properties from get! %@", getOperation.resultObject);
    }];
    
    // Multiple onCompletion blocks get called in order of adding.
    if (completion) 
    {
        [getOperation onCompletion:completion];
    }
}

- (CouchDocument *)cc_couchDocument
{
    CCDocument *documentSelf = (CCDocument *)self;
    CouchDocument *couchDocument = objc_getAssociatedObject(self, @"couchDocument");
    if (!couchDocument && documentSelf.couchID && documentSelf.couchRev) 
    {
        couchDocument = [[self cc_couchDatabase] documentWithID:documentSelf.couchID];
        couchDocument.modelObject = self;
        objc_setAssociatedObject(self, @"couchDocument", couchDocument, 
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return couchDocument;
}

@end

@implementation CCDocument
@dynamic couchRev;
@dynamic couchID;

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

- (void)willSave
{
    [super willSave];
    NSLog(@"WILL SAVE ON %@ %@", [self class], self.couchID);
    // Don't do a redundant put when we just got changes or new objects from Couch.
    if (self.isDeleted || !self.hasChanges || [self.managedObjectContext cc_isSavingWithoutPUT]) 
    {
        return;
    }
    NSLog(@"PUTTING %@ %@ TO COUCH", [self class], self.couchID);
    [self cc_putToCouch];
}

- (void)prepareForDeletion
{
    [super prepareForDeletion];
    if (self.couchRev) 
    {
        CouchRevision *revision = [[self cc_couchDocument] revisionWithID:self.couchRev];
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