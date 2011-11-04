//
//  CCQuery.m
//  CoreCouchKit
//
//  Created by Luke Iannini on 11/2/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCQuery.h"
#import "CoreCouchKit.h"
#import "CouchLiveQueryFix.h"

@interface CCQuery ()
{
    CouchQuery *query;
    CouchDesignDocument *designDocument;
    NSString *relatedKey;
    NSString *relatedValue;
    BOOL deleteMissing;
    NSManagedObjectContext *managedObjectContext;
    NSString *viewName;
}

@property (nonatomic, strong, readwrite) NSString *entityName;

// Fetching
- (void)updateLocalObjectsWithCouchDocuments;

- (NSMutableDictionary *)couchResultsByID;
- (NSMutableDictionary *)localResultsByID;

- (NSString *)docTypePredicate;
- (NSPredicate *)localPredicate;

// Updating

- (void)deleteManagedObjects:(NSArray *)objects;

@end

@implementation CCQuery
@synthesize entityName;

+ (id)queryForRelationship:(NSString *)key 
                  ofObject:(NSManagedObject *)owner 
               inCoreCouch:(CoreCouchKit *)coreCouch
{
    NSManagedObjectContext *backgroundContext = coreCouch.backgroundContext;
    CouchDatabase *database = coreCouch.database;
    CouchDesignDocument *designDoc = [database designDocumentWithName:@"design"];
    
    CCDocument *document = (CCDocument *)owner;
    NSRelationshipDescription *inverseRelationship = [[[[owner entity] relationshipsByName] 
                                                       objectForKey:key] inverseRelationship];
    NSString *inverseKey = [inverseRelationship name];
    NSString *inverseEntityName = [[inverseRelationship entity] name];
    NSString *ownerID = document.couchID;
    NSString *viewName = [NSString stringWithFormat:@"%@By%@", key, [inverseKey capitalizedString]];
    
    NSString *relatedKey = [inverseKey stringByAppendingString:@".couchID"];
    
    return [[self alloc] initWithDesignDoc:designDoc 
                                  viewName:viewName 
                                entityName:inverseEntityName 
                                relatedKey:relatedKey 
                              relatedValue:ownerID 
                                   context:backgroundContext];
}

+ (id)queryForObjectsOfType:(NSString *)entityName 
                      whose:(NSString *)key 
                         is:(NSString *)value 
                inCoreCouch:(CoreCouchKit *)coreCouch
{
    NSManagedObjectContext *backgroundContext = coreCouch.backgroundContext;
    CouchDatabase *database = coreCouch.database;
    CouchDesignDocument *designDoc = [database designDocumentWithName:@"design"];
    
    NSString *viewName = entityName;
    if (key) 
    {
        viewName = [NSString stringWithFormat:@"%@sBy%@", entityName, key];
    }
    
    return [[self alloc] initWithDesignDoc:designDoc 
                                  viewName:viewName 
                                entityName:entityName 
                                relatedKey:key 
                              relatedValue:value 
                                   context:backgroundContext];
}

- (id)initWithDesignDoc:(CouchDesignDocument *)aDesignDoc
               viewName:(NSString *)aViewName
             entityName:(NSString *)anEntityName
             relatedKey:(NSString *)aRelatedKey
           relatedValue:(NSString *)aRelatedValue
                context:(NSManagedObjectContext *)aManagedObjectContext
{
    self = [super init];
    if (self) {
        designDocument = aDesignDoc;
        viewName = aViewName;
        entityName = anEntityName;
        relatedKey = aRelatedKey;
        relatedValue = aRelatedValue;
        managedObjectContext = aManagedObjectContext;
        deleteMissing = YES;
    }
    return self;
}

- (void)start
{
    NSString *map = [NSString stringWithFormat:
                     @"function(doc) {if (%@) emit(doc.%@, null);}", 
                     [self docTypePredicate], 
                     [relatedKey stringByReplacingOccurrencesOfString:@".couchID" 
                                                           withString:@""] ?: @"_id"];
    NSLog(@"Map: %@", map);
    [designDocument defineViewNamed:viewName
                                map:map];
    query = [[designDocument queryViewNamed:viewName] ck_asLiveQuery]; // see fix definition for details
    if (relatedValue) 
    {
        query.keys = [NSArray arrayWithObject:relatedValue];
    }
    NSLog(@"Query keys: %@", query.keys);
    query.prefetch = YES; // include_docs=true
    
    [query addObserver:self 
            forKeyPath:@"rows" 
               options:0 
               context:(__bridge void *)viewName];
    
    [query start];
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
    if (context == (__bridge void *)viewName) 
    {
        NSLog(@"Got LiveQuery rows KVO: %@", query.rows);
        
        [managedObjectContext performBlock:^{
            [self updateLocalObjectsWithCouchDocuments];
        }];
    }
    else 
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateLocalObjectsWithCouchDocuments
{
    NSMutableDictionary *couchResultsByID = [self couchResultsByID];
    NSMutableDictionary *localResultsByID = [self localResultsByID];
    
    Class documentClass = NSClassFromString(entityName);
    
    NSMutableArray *couchResults = [NSMutableArray array];
    for (NSString *couchID in [couchResultsByID allKeys]) 
    {
        NSDictionary *properties = [couchResultsByID objectForKey:couchID];
        CCDocument *document = [localResultsByID objectForKey:couchID];
        
        if (document)
        {
            NSLog(@"Updating existing ID: %@ with properties: %@", couchID, properties);
            [document cj_setPropertiesFromDescription:properties];
            document.couchRev = [properties objectForKey:kCouchRevKey];
            [localResultsByID removeObjectForKey:couchID];
        }
        else
        {
            NSLog(@"Creating missing ID: %@", couchID);
            NSLog(@"properties: %@", properties);
            document = [documentClass cj_insertInManagedObjectContext:managedObjectContext 
                                                fromObjectDescription:properties];
            document.couchID = [properties objectForKey:kCouchIDKey];
            document.couchRev = [properties objectForKey:kCouchRevKey];
            NSLog(@"created document %@ with ID: %@", document, document.couchID);
        }
        
        [document cc_updateAttachments];
        
        [couchResults addObject:document];
    }
    
    NSLog(@"Remaining: %@", localResultsByID);
    if (deleteMissing) 
    {
        [self deleteManagedObjects:[localResultsByID allValues]];
    }
    
    // TODO Post CCQueryWillSaveNotification with updated objectIDs
    
    NSError *error = nil;
    if (![managedObjectContext save:&error]) 
    {
        NSLog(@"Error saving: %@", error);
    };
    
    // TODO Post CCQueryDidSaveNotification with updated objectIDs
}

- (NSString *)docTypePredicate
{
    NSString *docTypePredicate = [NSString stringWithFormat:@"doc.documentType == '%@'", entityName];
    return docTypePredicate;
}

- (NSPredicate *)localPredicate
{
    if (relatedKey && relatedValue) 
        return [NSPredicate predicateWithFormat:@"%K == %@", relatedKey, relatedValue];
    return nil;
}

- (NSMutableDictionary *)couchResultsByID
{
    NSMutableDictionary *couchResultsByID = [NSMutableDictionary dictionaryWithCapacity:
                                             [query.rows count]];
    for (CouchQueryRow *row in query.rows)
    {
        [couchResultsByID setObject:row.documentProperties 
                             forKey:row.documentID];
    }
    NSLog(@"Couch IDs: %@", [couchResultsByID allKeys]);
    return couchResultsByID;
}

- (NSMutableDictionary *)localResultsByID
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entityName];
    [request setPredicate:[self localPredicate]];
    NSError *error = nil;
    NSArray *localResults = [managedObjectContext executeFetchRequest:request error:&error];
    NSLog(@"Local IDs: %@", [localResults valueForKey:@"couchID"]);
    NSMutableDictionary *localResultsByID = [NSMutableDictionary dictionaryWithCapacity:[localResults count]];
    for (CCDocument *document in localResults) 
    {
        [localResultsByID setObject:document forKey:document.couchID];
    }
    return localResultsByID;
}

- (void)deleteManagedObjects:(NSArray *)objects
{
    for (CCDocument *document in objects) 
    {
        [managedObjectContext deleteObject:document];
    }
}

- (void)dealloc
{
    [self stop];
}

- (void)stop
{
    [query removeObserver:self 
               forKeyPath:@"rows"];
}

@end
