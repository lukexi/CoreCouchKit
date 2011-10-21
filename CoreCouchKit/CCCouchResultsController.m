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
- (void)saveWithoutPUT;

- (NSString *)docTypePredicate;
- (NSPredicate *)localPredicate;

@end

@implementation CCCouchResultsController
@synthesize managedObjectContext;
@synthesize couchDatabase, designDocument, viewName, entityName, query, relatedKey, relatedValue;

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
                     [self docTypePredicate], self.relatedKey ?: @"_id"];
    [self.designDocument defineViewNamed:self.viewName
                                     map:map];
    self.query = [[self.designDocument queryViewNamed:viewName] ck_asLiveQuery]; // see fix definition for details
    self.query.descending = YES;  // Sort by descending date, i.e. newest items first
    if (self.relatedValue) 
    {
        self.query.keys = [NSArray arrayWithObject:self.relatedValue];
    }
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
    NSMutableDictionary *couchResultsByID = [self couchResultsByID];
    NSMutableDictionary *localResultsByID = [self localResultsByID];
    
    Class documentClass = NSClassFromString(self.entityName);
    
    for (NSString *couchID in [couchResultsByID allKeys]) 
    {
        NSDictionary *properties = [couchResultsByID objectForKey:couchID];
        CCDocument *document = [localResultsByID objectForKey:couchID];
        
        if (document)
        {
            NSLog(@"Updating existing ID: %@ with properties: %@", couchID, properties);
            if ([document conformsToProtocol:@protocol(CCDocumentUpdate)]) 
            {
                [(CCDocument <CCDocumentUpdate> *)document willUpdateFromCouch];
            }
            
            [document cj_setPropertiesFromDescription:properties];
            [localResultsByID removeObjectForKey:couchID];
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
    }
    
    NSLog(@"Remaining: %@", localResultsByID);
    [self deleteManagedObjects:[localResultsByID allValues]];
    
    [self saveWithoutPUT];
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
        return [NSPredicate predicateWithFormat:@"%K.couchID == %@", self.relatedKey, self.relatedValue];
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
