//
//  CoreCouchKitTests.m
//  CoreCouchKitTests
//
//  Created by Luke Iannini on 10/20/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CoreCouchKitTests.h"
#import "CoreCouchKit.h"
@interface CoreCouchKitTests ()
{
    NSManagedObjectContext *managedObjectContext;
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
}

@end

@interface CoreCouchKitTests (Private)

- (NSString *)applicationDocumentsDirectory;

@end

@implementation CoreCouchKitTests

- (void)setUp
{
    [super setUp];
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"CoreCouchKitTests" withExtension:@"momd"];
    managedObjectModel = [CCManagedObjectModel couchManagedObjectModelWithContentsOfURL:modelURL];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:managedObjectModel];
    NSURL *storeURL = [NSURL fileURLWithPath:
                       [[self applicationDocumentsDirectory]
                        stringByAppendingPathComponent:@"CoreCouchKitTests.sqlite"]];
    NSError *error;
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) 
    {
        STFail(@"Couldn't set up PSC: %@", error);
    }
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
    STFail(@"Unit tests are not implemented yet in CoreCouchKitTests");
}

@end

@implementation CoreCouchKitTests (Private)

- (NSString *)applicationDocumentsDirectory
{
	return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

@end
