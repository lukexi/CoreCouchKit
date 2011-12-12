//
//  CoreCouchKit.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CoreCouchKit.h"
#import "CCManagedObjectModel.h"
#import "NSManagedObject+CCDocument.h"
#import "NSManagedObject+CCAttachment.h"
#import "UIImageToDataTransformer.h"

@interface CoreCouchKit ()
{
    NSManagedObjectContext *managedObjectContext;
    id contextWillSaveObserver;
    id contextDidSaveObserver;
    id backgroundContextDidSaveObserver;
    CouchServer *server;
    
    NSOperationQueue *operationQueue;
    NSMutableSet *objectsExplicityMarkedAsNeedingPUT;
}

- (id)initWithContext:(NSManagedObjectContext *)context
            serverURL:(NSString *)serverURLString
         databaseName:(NSString *)databaseName;

- (void)handleWillSaveNotification:(NSNotification *)note;
- (void)handleDidSaveNotification:(NSNotification *)note;

- (void)checkIfObjectNeedsPUT:(NSManagedObject *)object;

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
        
        objectsExplicityMarkedAsNeedingPUT = [NSMutableSet set];
        
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
    //NSLog(@"Changed objects: %@", changedObjects);
    
    // Wait until after didSave to actually begin these operations
    [operationQueue setSuspended:YES];
    
    // We automatically detect changed objects right now, but maybe make this optional to reduce frequency of updates?
    for (NSManagedObject *object in changedObjects) 
    {
        [self checkIfObjectNeedsPUT:object];
    }
    
    // Marked objects might not have 'changes', since they might be in their child objects
    for (NSManagedObject *object in objectsExplicityMarkedAsNeedingPUT) 
    {
        [self checkIfObjectNeedsPUT:object];
    }
    [objectsExplicityMarkedAsNeedingPUT removeAllObjects];
    
    for (NSManagedObject *object in [managedObjectContext deletedObjects]) 
    {
        // We can't use a background context on deleted objects since they'll have lost their property information
        // by the time the background operation runs, so we pull everything we need out here.
        BOOL isDocument = [object cc_isCouchDocument];
        BOOL isAttachment = [object cc_isCouchAttachment];
        BOOL isCouchManaged = isDocument || isAttachment;
        if (isCouchManaged) 
        {
            RESTResource *resource = nil;
            if (isDocument) 
            {
                resource = [object cc_couchRevision];
            }
            else if (isAttachment)
            {
                resource = [object cc_couchAttachment];
            }
            
            // Workaround for a bug in NSFetchedResultsController wherein the object was reinserted when a property was accessed.
            [managedObjectContext deleteObject:object];
            
            [operationQueue addOperationWithBlock:^{
                NSLog(@"Deleting %@", resource);
                RESTOperation *operation = [resource DELETE];
                [operation wait];
                if (operation.error) 
                {
                    NSLog(@"Error deleting object: %@", operation.error);
                }
            }];
        }
    }
}

- (void)checkIfObjectNeedsPUT:(NSManagedObject *)object
{
    BOOL isDocument = [object cc_isCouchDocument];
    BOOL isAttachment = [object cc_isCouchAttachment];
    BOOL isCouchManaged = isDocument || isAttachment;
    if ((isCouchManaged && [object hasChanges]) || [objectsExplicityMarkedAsNeedingPUT containsObject:object])
    {
        [self changeObject:object onBackgroundContext:^(NSManagedObject *backgroundObject, NSManagedObjectContext *context) 
         {
             NSLog(@"PUTting %@", backgroundObject);
             
             if (isDocument) 
             {
                 [backgroundObject cc_PUT];
             }
             else if (isAttachment)
             {
                 NSLog(@"Is couch attachment... object %@", [backgroundObject class]);
                 [backgroundObject cc_PUTAttachment];
             }
         }];
    }
    
    // TODO use [object changedValues] and check if the attachment has changed when using "store in external record" attachments (or, md5 approach to validating attachments is probably fast enough to obviate this
    
    //NSLog(@"Saving object %@", object);
}

- (void)markNeedsPUT:(NSManagedObject *)documentObject
{
    NSAssert1([documentObject cc_isCouchDocument], @"Objects for PUT must be of couchType 'document'. %@ is not.", documentObject);
    [objectsExplicityMarkedAsNeedingPUT addObject:documentObject];
}

- (void)changeObject:(NSManagedObject *)object 
 onBackgroundContext:(CCBackgroundContextBlock)backgroundBlock
{
    __weak NSManagedObjectContext *weakBackgroundContext = backgroundContext;
    [operationQueue addOperationWithBlock:^{
        [weakBackgroundContext performBlock:^{
            // Objects were coming out with old values, so we refresh.
            [weakBackgroundContext reset];
            NSManagedObjectID *objectID = object.objectID;
            NSError *error;
            NSManagedObject *backgroundObject = [weakBackgroundContext existingObjectWithID:objectID error:&error];
            if (!backgroundObject) 
            {
                NSLog(@"Error pulling %@ into background context: %@", object, error);
            }
            
            backgroundBlock(backgroundObject, weakBackgroundContext);
        }];
    }];
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
    CCFetchedResultsController *fetchedResultsController = [[CCFetchedResultsController alloc] initWithQuery:query 
                                                                                             sortDescriptors:sortDescriptors 
                                                                                        managedObjectContext:managedObjectContext 
                                                                                                    delegate:delegate];
    return fetchedResultsController;
}

- (CCQuery *)queryForObjectsOfType:(NSString *)entityName whose:(NSString *)key is:(NSString *)value
{
    return [CCQuery queryForObjectsOfType:entityName whose:key is:value inCoreCouch:self];
}

- (CCFetchedResultsController *)fetchedResultsControllerForObjectsOfType:(NSString *)entityName 
                                                                   whose:(NSString *)key 
                                                                      is:(NSString *)value 
                                                         sortDescriptors:(NSArray *)sortDescriptors 
                                                                delegate:(id <NSFetchedResultsControllerDelegate>)delegate
{
    CCQuery *query = [self queryForObjectsOfType:entityName whose:key is:value];
    CCFetchedResultsController *fetchedResultsController = [[CCFetchedResultsController alloc] initWithQuery:query 
                                                                                             sortDescriptors:sortDescriptors 
                                                                                        managedObjectContext:managedObjectContext
                                                                                                    delegate:delegate];
    return fetchedResultsController;
}

@end


