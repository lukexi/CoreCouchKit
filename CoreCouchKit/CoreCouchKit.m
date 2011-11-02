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
#import "UIImageToDataTransformer.h"

@interface CoreCouchKit ()
{
    NSManagedObjectContext *managedObjectContext;
    id contextWillSaveObserver;
    id contextDidSaveObserver;
    id backgroundContextDidSaveObserver;
    CouchServer *server;
    
    NSOperationQueue *operationQueue;
}

- (id)initWithContext:(NSManagedObjectContext *)context
            serverURL:(NSString *)serverURLString
         databaseName:(NSString *)databaseName;

- (void)handleWillSaveNotification:(NSNotification *)note;
- (void)handleDidSaveNotification:(NSNotification *)note;

@end

@implementation CoreCouchKit
@synthesize backgroundContext;
@synthesize database;
static CoreCouchKit *sharedCoreCouchKit = nil;

- (void)dealloc
{
    contextWillSaveObserver = nil;
    contextDidSaveObserver = nil;
}

+ (void)setupWithContext:(NSManagedObjectContext *)context
               serverURL:(NSString *)serverURLString
            databaseName:(NSString *)databaseName
{
    NSParameterAssert(context);
    NSParameterAssert(serverURLString);
    NSParameterAssert(databaseName);
    if (!sharedCoreCouchKit) 
    {
        sharedCoreCouchKit = [[self alloc] initWithContext:context
                                                 serverURL:serverURLString
                                              databaseName:databaseName];
    }
}

+ (NSManagedObjectModel *)couchManagedObjectModelWithContentsOfURL:(NSURL *)modelURL
{
    return [CCManagedObjectModel couchManagedObjectModelWithContentsOfURL:modelURL];
}

+ (CoreCouchKit *)sharedCoreCouchKit
{
    NSAssert(sharedCoreCouchKit, @"Must call setupWithContext before using the sharedCoreCouchKit");
    return sharedCoreCouchKit;
}

- (id)initWithContext:(NSManagedObjectContext *)context
            serverURL:(NSString *)serverURLString
         databaseName:(NSString *)databaseName
{
    self = [super init];
    if (self) 
    {
        // TODO: could disassemble the serverURLString and add the port workaround (i.e. add :80 if there is none). Or, just submit a patch to Jens.
        NSURL *serverURL = [NSURL URLWithString:serverURLString];
        NSAssert1([serverURL port], @"Must provide an explicit port (e.g. http://sperts.iriscouch.com:80 to workaround bug in CouchCocoa (you provided %@)", serverURLString);
        server = [[CouchServer alloc] initWithURL:serverURL];
        database = [server databaseNamed:databaseName];
        
        // TODO: Should probably make this optional as it blocks startup, but it's handy during development
        [[database create] wait];
        
        database.tracksChanges = YES;
        database.tracksActiveOperations = YES;
        
        operationQueue = [[NSOperationQueue alloc] init];
        operationQueue.maxConcurrentOperationCount = 1;
        
        managedObjectContext = context;
        if ([managedObjectContext mergePolicy] != NSErrorMergePolicy) 
        {
            NSLog(@"Warning: CoreCouchKit is changing your %@ merge policy to NSMergeByPropertyObjectTrumpMergePolicy", context);
        }
        [managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [managedObjectContext.userInfo setObject:database 
                                          forKey:kCouchDatabaseKey];
        
        backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [backgroundContext setPersistentStoreCoordinator:managedObjectContext.persistentStoreCoordinator];
        [backgroundContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [backgroundContext.userInfo setObject:database 
                                       forKey:kCouchDatabaseKey];
        
        backgroundContextDidSaveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:backgroundContext queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) 
        {
            [managedObjectContext mergeChangesFromContextDidSaveNotification:note];
        }];
        
        contextWillSaveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextWillSaveNotification object:managedObjectContext queue:nil usingBlock:^(NSNotification *note) 
        {
            [self handleWillSaveNotification:note];
        }];
        
        contextDidSaveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveNotification object:managedObjectContext queue:nil usingBlock:^(NSNotification *note) 
          {
              [self handleDidSaveNotification:note];
          }];
        
        [UIImageToDataTransformer class]; // Prevent dead stripping
    }
    return self;
}

- (void)handleWillSaveNotification:(NSNotification *)note
{
    NSLog(@"Got note! %@", note);
    
    NSSet *changedObjects = [[managedObjectContext updatedObjects] setByAddingObjectsFromSet:
                             [managedObjectContext insertedObjects]];
    NSLog(@"Changed objects: %@", changedObjects);
    
    // Wait until after didSave to actually begin these operations
    [operationQueue setSuspended:YES];
    
    for (NSManagedObject *object in changedObjects) 
    {
        if ([object hasChanges]) 
        {
            __weak NSManagedObjectContext *weakBackgroundContext = backgroundContext;
            [operationQueue addOperationWithBlock:^{
                [weakBackgroundContext performBlock:^{
                    NSManagedObjectID *objectID = object.objectID;
                    NSManagedObject *backgroundObject = [weakBackgroundContext objectWithID:objectID];
                    NSLog(@"PUTting %@", backgroundObject);
                    [backgroundObject cc_PUT];
                }];
            }];
        }
        
        // TODO use [object changedValues] and check if the attachment has changed
        
        NSLog(@"Saving object %@", object);
        if ([object cc_isCouchAttachment] && [object hasChanges]) 
        {
            NSLog(@"Is couch attachment... object %@", [object class]);
            [object cc_PUTAttachment];
        }
    }
    
    for (NSManagedObject *object in [managedObjectContext deletedObjects]) 
    {
        // que deletion
    }
}

- (void)handleDidSaveNotification:(NSNotification *)note
{
    NSLog(@"Resuming operation queue");
    [operationQueue setSuspended:NO];
}

#pragma mark Query

- (CCQuery *)queryForRelationship:(NSString *)key ofObject:(NSManagedObject *)managedObject
{
    return [CCQuery queryForRelationship:key ofObject:managedObject inCoreCouch:self];
}

- (CCFetchedResultsController *)fetchedResultsControllerForRelationship:(NSString *)key 
                                                               ofObject:(NSManagedObject *)managedObject
                                                        sortDescriptors:(NSArray *)sortDescriptors
                                                               delegate:(id <NSFetchedResultsControllerDelegate>)delegate
{
    CCQuery *query = [self queryForRelationship:key ofObject:managedObject];
    CCFetchedResultsController *fetchedResultsController = [[CCFetchedResultsController alloc] initWithQuery:query sortDescriptors:sortDescriptors managedObjectContext:managedObjectContext delegate:delegate];
    return fetchedResultsController;
}

- (CCQuery *)queryForObjectsOfType:(NSString *)entityName whose:(NSString *)key is:(NSString *)value
{
    return [CCQuery queryForObjectsOfType:entityName whose:key is:value inCoreCouch:self];
}

- (CCFetchedResultsController *)fetchedResultsControllerForObjectsOfType:(NSString *)entityName whose:(NSString *)key is:(NSString *)value sortDescriptors:(NSArray *)sortDescriptors delegate:(id <NSFetchedResultsControllerDelegate>)delegate
{
    CCQuery *query = [self queryForObjectsOfType:entityName whose:key is:value];
    CCFetchedResultsController *fetchedResultsController = [[CCFetchedResultsController alloc] initWithQuery:query sortDescriptors:sortDescriptors managedObjectContext:managedObjectContext delegate:delegate];
    return fetchedResultsController;
}

@end


