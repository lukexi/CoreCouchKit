//
//  CDCouchSync.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/7/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCCouchResultsController.h"
#import "CCDocument.h"
#import "CoreDataJSONKit.h"
#import "CouchLiveQueryFix.h"
#import "CoreCouchKit.h"

@interface CCCouchResultsController ()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) CouchDatabase *couchDatabase;
@property (nonatomic, strong) CouchDesignDocument *designDocument;
@property (nonatomic, strong) NSString *viewName;
@property (nonatomic, strong) NSString *entityName;
@property (nonatomic, strong) NSString *relatedKey;
@property (nonatomic, strong) NSString *relatedValue;
@property (nonatomic, strong) CouchLiveQuery *query;

- (void)stop;

- (void)updateLocalObjectsWithCouchDocuments;

- (NSMutableDictionary *)couchResultsByID;
- (NSMutableDictionary *)localResultsByID;

- (void)deleteManagedObjects:(NSArray *)objects;
- (void)saveAndPUT;
- (void)saveWithoutPUT;

- (NSString *)docTypePredicate;
- (NSPredicate *)localPredicate;

@end

@implementation CCCouchResultsController
@synthesize managedObjectContext;
@synthesize couchDatabase, designDocument, viewName, entityName, query, relatedKey, relatedValue;
@synthesize resultsBlock, deleteMissing;

+ (id)couchResultsControllerFor:(NSString *)key of:(NSManagedObject *)owner
{
    CCDocument *document = (CCDocument *)owner;
    NSRelationshipDescription *inverseRelationship = [[[[owner entity] relationshipsByName] objectForKey:key] inverseRelationship];
    NSString *inverseKey = [inverseRelationship name];
    NSString *inverseEntityName = [[inverseRelationship entity] name];
    NSString *ownerID = document.couchID;
    NSString *viewName = [NSString stringWithFormat:@"%@By%@", key, [inverseKey capitalizedString]];
    
    return [self couchResultsControllerWithDesignDocName:@"design" 
                                                viewName:viewName 
                                              entityName:inverseEntityName 
                                              relatedKey:[inverseKey stringByAppendingString:@".couchID"] 
                                            relatedValue:ownerID 
                                                 context:owner.managedObjectContext];
}

+ (id)couchResultsControllerWithDesignDocName:(NSString *)designDocName
                                     viewName:(NSString *)viewName
                                   entityName:(NSString *)entityName
                                   relatedKey:(NSString *)relatedKey
                                 relatedValue:(NSString *)relatedValue
                                      context:(NSManagedObjectContext *)managedObjectContext
{
    CCCouchResultsController *controller = [[CCCouchResultsController alloc] init];
    controller.couchDatabase = [managedObjectContext.userInfo objectForKey:kCouchDatabaseKey];
    controller.managedObjectContext = managedObjectContext;
    controller.designDocument = [controller.couchDatabase designDocumentWithName:designDocName];
    controller.entityName = entityName;
    controller.viewName = viewName;
    controller.relatedKey = relatedKey;
    controller.relatedValue = relatedValue;
    controller.deleteMissing = YES;
    return controller;
}

- (void)dealloc
{
    [self stop];
}

- (void)stop
{
    [self.query removeObserver:self forKeyPath:@"rows"];
}

- (NSString *)docTypePredicate
{
    NSString *docTypePredicate = [NSString stringWithFormat:@"doc.documentType == '%@'", self.entityName];
    return docTypePredicate;
}

- (void)start
{
    NSString *map = [NSString stringWithFormat:
                     @"function(doc) {if (%@) emit(doc.%@, null);}", 
                     [self docTypePredicate], [self.relatedKey stringByReplacingOccurrencesOfString:@".couchID" withString:@""] ?: @"_id"];
    NSLog(@"Map: %@", map);
    [self.designDocument defineViewNamed:self.viewName
                                     map:map];
    self.query = [[self.designDocument queryViewNamed:self.viewName] ck_asLiveQuery]; // see fix definition for details
    if (self.relatedValue) 
    {
        self.query.keys = [NSArray arrayWithObject:self.relatedValue];
    }
    NSLog(@"Query keys: %@", self.query.keys);
    self.query.prefetch = YES; // include_docs=true
    
    [self.query addObserver:self 
                 forKeyPath:@"rows" 
                    options:0 
                    context:(__bridge void *)self.viewName];
    
    [self.query start];
}

- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary *)change 
                       context:(void *)context
{
    if (context == (__bridge void *)self.viewName) 
    {
        NSLog(@"Got LiveQuery rows KVO: %@", self.query.rows);
        
        [self updateLocalObjectsWithCouchDocuments];
    }
    else 
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateLocalObjectsWithCouchDocuments
{
    // Make sure any pending changes are put to couch before we update,
    // because the saveWithoutPUT will commit them to the database without
    // putting them and they'll no longer be known as changes.
    // This definitely increases the chance of conflicts.
    // A more robust solution would be to emulate couch, and keep the previous revision
    // of the data around so we can then reapply its changes afterwards...
    [self saveAndPUT];
    
    NSMutableDictionary *couchResultsByID = [self couchResultsByID];
    NSMutableDictionary *localResultsByID = [self localResultsByID];
    
    Class documentClass = NSClassFromString(self.entityName);
    
    NSMutableArray *couchResults = [NSMutableArray array];
    for (NSString *couchID in [couchResultsByID allKeys]) 
    {
        NSDictionary *properties = [couchResultsByID objectForKey:couchID];
        CCDocument *document = [localResultsByID objectForKey:couchID];
        
        if (document)
        {
            NSLog(@"Updating existing ID: %@ with properties: %@", couchID, properties);
            if ([document conformsToProtocol:@protocol(CCDocumentUpdate)]) 
                [(CCDocument <CCDocumentUpdate> *)document willUpdateFromCouch];
            
            [document cj_setPropertiesFromDescription:properties];
            document.couchRev = [properties objectForKey:kCouchRevKey];
            [localResultsByID removeObjectForKey:couchID];
            
            if ([document conformsToProtocol:@protocol(CCDocumentUpdate)]) 
                [(CCDocument <CCDocumentUpdate> *)document didUpdateFromCouch];
            NSLog(@"Document is now %@", document);
        }
        else
        {
            NSLog(@"Creating missing ID: %@", couchID);
            NSLog(@"properties: %@", properties);
            document = [documentClass cj_insertInManagedObjectContext:self.managedObjectContext 
                                                fromObjectDescription:properties];
            document.couchID = [properties objectForKey:kCouchIDKey];
            document.couchRev = [properties objectForKey:kCouchRevKey];
            NSLog(@"created document %@ with ID: %@", document, document.couchID);
        }
        [couchResults addObject:document];
    }
    
    NSLog(@"Remaining: %@", localResultsByID);
    if (self.deleteMissing) 
    {
        [self deleteManagedObjects:[localResultsByID allValues]];
    }
    
    [self saveWithoutPUT];
    
    if (self.resultsBlock) 
    {
        self.resultsBlock(couchResults);
    }
}

- (void)saveAndPUT
{
    NSError *error = nil;
    if (![self.managedObjectContext save:&error]) 
    {
        NSLog(@"Error saving: %@", error);
    }
}

// Prevents CDCouchDocuments from attempting to PUT during willSave;
// there's no need since these changes are just fetched from Couch.
- (void)saveWithoutPUT
{
    NSError *error = nil;
    if (![self.managedObjectContext cc_saveWithoutPUT:&error]) 
    {
        NSLog(@"Error saving: %@", error);
    }
}

- (void)deleteManagedObjects:(NSArray *)objects
{
    for (CCDocument *document in objects) 
    {
        [self.managedObjectContext deleteObject:document];
    }
}

- (NSMutableDictionary *)couchResultsByID
{
    NSMutableDictionary *couchResultsByID = [NSMutableDictionary dictionaryWithCapacity:
                                             [self.query.rows count]];
    for (CouchQueryRow *row in self.query.rows)
    {
        [couchResultsByID setObject:row.documentProperties forKey:row.documentID];
    }
    NSLog(@"Couch IDs: %@", [couchResultsByID allKeys]);
    return couchResultsByID;
}

- (NSMutableDictionary *)localResultsByID
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    [request setPredicate:[self localPredicate]];
    NSError *error = nil;
    NSArray *localResults = [self.managedObjectContext executeFetchRequest:request error:&error];
    NSLog(@"Local IDs: %@", [localResults valueForKey:@"couchID"]);
    NSMutableDictionary *localResultsByID = [NSMutableDictionary dictionaryWithCapacity:[localResults count]];
    for (CCDocument *document in localResults) 
    {
        [localResultsByID setObject:document forKey:document.couchID];
    }
    return localResultsByID;
}

- (NSPredicate *)localPredicate
{
    if (self.relatedKey && self.relatedValue) 
        return [NSPredicate predicateWithFormat:@"%K == %@", self.relatedKey, self.relatedValue];
    return nil;
}

- (NSFetchedResultsController *)fetchedResultsControllerWithSortDescriptors:(NSArray *)sortDescriptors
                                                                   delegate:(id <NSFetchedResultsControllerDelegate>)delegate
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    request.predicate = [self localPredicate];
    NSLog(@"Request predicate: %@", request.predicate);
    request.sortDescriptors = sortDescriptors;
    NSFetchedResultsController *fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                               managedObjectContext:self.managedObjectContext 
                                                                                                 sectionNameKeyPath:nil
                                                                                                          cacheName:nil];
    fetchedResultsController.delegate = delegate;
    return fetchedResultsController;
}

@end
