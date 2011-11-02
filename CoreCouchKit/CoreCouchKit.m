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

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) id contextWillSaveObserver;

@property (nonatomic, strong) CouchServer *server;
@property (nonatomic, strong) CouchDatabase *database;

- (void)updateWithNote:(NSNotification *)note;
- (id)initWithContext:(NSManagedObjectContext *)context
            serverURL:(NSString *)serverURLString
         databaseName:(NSString *)databaseName;

@end

@implementation CoreCouchKit
@synthesize managedObjectContext, contextWillSaveObserver;
@synthesize server, database;

static CoreCouchKit *sharedCoreCouchKit = nil;

- (void)dealloc
{
    contextWillSaveObserver = nil;
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
        self.server = [[CouchServer alloc] initWithURL:serverURL];
        self.database = [self.server databaseNamed:databaseName];
        
        // TODO: Should probably make this optional as it blocks startup, but it's handy during development
        [[self.database create] wait];
        
        self.database.tracksChanges = YES;
        self.database.tracksActiveOperations = YES;
        
        self.managedObjectContext = context;
        [self.managedObjectContext.userInfo setObject:self.database 
                                               forKey:kCouchDatabaseKey];
        
        self.contextWillSaveObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextWillSaveNotification object:self.managedObjectContext queue:nil usingBlock:^(NSNotification *note) 
        {
            [self updateWithNote:note];
        }];
        
        [UIImageToDataTransformer class]; // Prevent dead stripping
    }
    return self;
}

- (void)updateWithNote:(NSNotification *)note
{
    NSLog(@"Got note! %@", note);
    if ([self.managedObjectContext cc_isSavingWithoutPUT]) 
    {
        NSLog(@"Saving without put, skipping attachment putting...");
        return;
    }
    
    NSSet *changedObjects = [[self.managedObjectContext updatedObjects] setByAddingObjectsFromSet:
                             [self.managedObjectContext insertedObjects]];
    NSLog(@"Changed objects: %@", changedObjects);
    for (NSManagedObject *object in changedObjects) 
    {
        // TODO 
        
        NSLog(@"Saving object %@", object);
        if ([object cc_isCouchAttachment] && [object hasChanges]) 
        {
            NSLog(@"Is couch attachment... object %@", [object class]);
            [object cc_PUTAttachment];
        }
    }
    
    for (NSManagedObject *object in [self.managedObjectContext deletedObjects]) 
    {
        // que deletion
    }
}

- (void)xxx
{
    
}

@end


