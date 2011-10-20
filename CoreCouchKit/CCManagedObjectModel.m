//
//  CDCouchManagedObjectModel.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCManagedObjectModel.h"
#import "CoreDataJSONKit.h"
#import "CoreCouchKit.h"
#import <objc/runtime.h>

@interface CCManagedObjectModel ()

+ (NSEntityDescription *)documentEntityWithSubentities:(NSArray *)subentities;
+ (NSString *)dynamicDocumentSubclassForClassName:(NSString *)className;

@end

@implementation CCManagedObjectModel

+ (NSManagedObjectModel *)couchManagedObjectModelWithContentsOfURL:(NSURL *)modelURL
{
    NSManagedObjectModel *model = [[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] mutableCopy];
    
    NSArray *originalEntities = [model entities];
    NSMutableArray *documentEntities = [NSMutableArray array];
    for (NSEntityDescription *entity in originalEntities) 
    {
        NSString *couchType = [entity.userInfo objectForKey:kCouchTypeKey];
        if ([couchType isEqualToString:kCouchTypeDocument]) 
        {
            // Make sure we have the top level entity for this entity
            NSEntityDescription *superentity = entity;
            while ([superentity superentity]) 
            {
                superentity = [superentity superentity];
            }
            
            [documentEntities addObject:superentity];
            [entity setUserInfo:[NSDictionary dictionaryWithObject:kCouchIDPropertyName 
                                                            forKey:kCJEntityUniqueIDKey]];
            
            // Dynamically subclass the document entities to add methods for JSON serialization and CouchDB synchronization. See CCDocument for their original implementations.
            
            NSLog(@"Dynamically subclassing %@", [entity name]);
            NSString *dynamicDocumentSubclassName = [self dynamicDocumentSubclassForClassName:[entity managedObjectClassName]];
            [entity setManagedObjectClassName:dynamicDocumentSubclassName];
        }
        else if ([couchType isEqualToString:kCouchTypeAttachment])
        {
            // Use the ExcludeInRelationships feature of CoreDataJSONKit to make sure attachment entities aren't included in JSON descriptions of their parent objects, since they'll be included as attachments instead.
            NSMutableDictionary *userInfo = [[entity userInfo] mutableCopy];
            [userInfo setObject:[NSNumber numberWithBool:YES] forKey:kCJEntityExcludeInRelationshipsKey];
            [entity setUserInfo:userInfo];
        }
    }
    NSLog(@"Document entities: %@", documentEntities);
    
    // Make all document entities subentities of CCDocument
    NSEntityDescription *documentEntity = [self documentEntityWithSubentities:documentEntities];
    
    NSArray *mergedEntities = [originalEntities arrayByAddingObject:documentEntity];
    [model setEntities:mergedEntities];
    
    return model;
}

+ (NSEntityDescription *)documentEntityWithSubentities:(NSArray *)subentities
{
    NSString *entityClassName = NSStringFromClass([CCDocument class]);
    NSEntityDescription *documentEntity = [[NSEntityDescription alloc] init];
    [documentEntity setName:entityClassName];
    [documentEntity setManagedObjectClassName:entityClassName];
    [documentEntity setAbstract:YES];
    
    NSAttributeDescription *IDAttribute = [[NSAttributeDescription alloc] init];
    [IDAttribute setName:kCouchIDPropertyName];
    [IDAttribute setAttributeType:NSStringAttributeType];
    
    NSAttributeDescription *revAttribute = [[NSAttributeDescription alloc] init];
    [revAttribute setName:kCouchRevPropertyName];
    [revAttribute setAttributeType:NSStringAttributeType];
    
    [documentEntity setProperties:[NSArray arrayWithObjects:IDAttribute, revAttribute, nil]];
    
    [documentEntity setSubentities:subentities];
    
    return documentEntity;
}

+ (NSString *)dynamicDocumentSubclassForClassName:(NSString *)className
{
    static NSString *prefix = @"CCDocument_";
    if ([className hasPrefix:prefix]) 
    {
        return className;
    }
    NSString *subclassName = [NSString stringWithFormat:@"%@%@", prefix, className];
    Class originalClass = NSClassFromString(className);
    
    
    NSAssert(originalClass, @"Couldn't find original class %@, did you create an NSManagedObject subclass for it?", className);
    
    Class sourceClass = [CCDocument class];
    Class subclass = NSClassFromString(subclassName);
    if (!subclass) 
    {
        subclass = objc_allocateClassPair(originalClass, [subclassName UTF8String], 0);
        if (subclass) 
        {
            // Grab all the methods from CCDocument and attach them to our new dynamic subclass of the document entity
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(sourceClass, &methodCount);
            
            for (NSUInteger methodIndex = 0; methodIndex < methodCount; methodIndex++)
            {
                Method aMethod = methods[methodIndex];
                SEL selector = method_getName(aMethod);
                
                IMP implementation = method_getImplementation(aMethod);
                const char *types = method_getTypeEncoding(aMethod);
                class_addMethod(subclass, selector, implementation, types);
                NSLog(@"Adding method: %@ of class %@ to class: %@", NSStringFromSelector(selector), sourceClass, subclassName);
            }
            
            // Grab all the protocols and do the same
            
            unsigned int protocolCount = 0;
            Protocol * __unsafe_unretained *protocols = class_copyProtocolList(sourceClass, &protocolCount);
            
            for (NSUInteger protocolIndex = 0; protocolIndex < protocolCount; protocolIndex++) 
            {
                Protocol *aProtocol = protocols[protocolIndex];
                class_addProtocol(subclass, aProtocol);
                NSLog(@"Adding protocol: %@ of class %@ to class: %@", NSStringFromProtocol(aProtocol), sourceClass, subclassName);
            }
            
            // We don't need ivars or properties yet but could add them too!
            
            objc_registerClassPair(subclass);
        }
    }
    
    if (subclass) 
    {
        return subclassName;
    }
    
    NSAssert(subclass, @"Failed to create subclass of %@", className);
    return className;
}

@end
