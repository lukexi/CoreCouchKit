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
#import "CCMixin.h"

@interface CCManagedObjectModel ()

+ (NSEntityDescription *)documentEntityWithSubentities:(NSArray *)subentities;
+ (NSEntityDescription *)attachmentEntityWithSubEntities:(NSArray *)subentities;

@end

@implementation CCManagedObjectModel

+ (NSManagedObjectModel *)couchManagedObjectModelWithContentsOfURL:(NSURL *)modelURL
{
    NSManagedObjectModel *model = [[[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL] mutableCopy];
    
    NSArray *originalEntities = [model entities];
    NSMutableArray *documentEntities = [NSMutableArray array];
    NSMutableArray *attachmentEntities = [NSMutableArray array];
    for (NSEntityDescription *entity in originalEntities) 
    {
        NSString *couchType = [entity.userInfo objectForKey:kCouchTypeKey];
        BOOL isDocumentType = [couchType isEqualToString:kCouchTypeDocument];
        BOOL isAttachmentType = [couchType isEqualToString:kCouchTypeAttachment];
        NSEntityDescription *superentity = entity;
        // Make sure we have the top level entity for this entity
        if (isDocumentType || isAttachmentType) {
            while ([superentity superentity]) 
            {
                superentity = [superentity superentity];
            }
        }
        
        if (isDocumentType) 
        {
            [documentEntities addObject:superentity];
            [entity setUserInfo:[NSDictionary dictionaryWithObject:kCouchIDPropertyName 
                                                            forKey:kCJEntityUniqueIDKey]];
            
            // Dynamically subclass the document entities to add methods for JSON serialization and CouchDB synchronization. See CCDocument for their original implementations.
            
            //NSLog(@"Dynamically subclassing %@", [entity name]);
            NSString *entityClassName = [entity managedObjectClassName];
            Class originalClass = NSClassFromString(entityClassName);
            NSAssert(originalClass, @"Couldn't find original class %@, did you create an NSManagedObject subclass for it?", entityClassName);
            Class dynamicDocumentSubclass = [CCMixin classByAddingContentsOfClass:[CCDocument class] toClass:originalClass];
            [entity setManagedObjectClassName:NSStringFromClass(dynamicDocumentSubclass)];
        }
        else if (isAttachmentType)
        {
            [attachmentEntities addObject:superentity];
            // Use the ExcludeInRelationships feature of CoreDataJSONKit to make sure attachment entities aren't included in JSON descriptions of their parent objects, since they'll be included as attachments instead.
            NSMutableDictionary *userInfo = [[entity userInfo] mutableCopy];
            [userInfo setObject:[NSNumber numberWithBool:YES] forKey:kCJEntityExcludeInRelationshipsKey];
            [entity setUserInfo:userInfo];
        }
    }
    //NSLog(@"Document entities: %@", [documentEntities valueForKey:@"name"]);
    
    // Make all document entities subentities of CCDocument, and all attachment entities subentities of CCAttachment
    NSEntityDescription *documentEntity = [self documentEntityWithSubentities:documentEntities];
    NSEntityDescription *attachmentEntity = [self attachmentEntityWithSubEntities:attachmentEntities];
    
    NSArray *mergedEntities = [originalEntities arrayByAddingObjectsFromArray:
                               [NSArray arrayWithObjects:documentEntity, attachmentEntity, nil]];
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
    
    NSAttributeDescription *attachmentsMetadataAttribute = [[NSAttributeDescription alloc] init];
    [attachmentsMetadataAttribute setName:kCouchAttachmentsMetadataPropertyName];
    [attachmentsMetadataAttribute setAttributeType:NSTransformableAttributeType];
    
    [documentEntity setProperties:[NSArray arrayWithObjects:IDAttribute, revAttribute, attachmentsMetadataAttribute, nil]];
    
    [documentEntity setSubentities:subentities];
    
    return documentEntity;
}

+ (NSEntityDescription *)attachmentEntityWithSubEntities:(NSArray *)subentities
{
    NSString *entityClassName = NSStringFromClass([CCAttachment class]);
    NSEntityDescription *attachmentEntity = [[NSEntityDescription alloc] init];
    [attachmentEntity setName:entityClassName];
    [attachmentEntity setManagedObjectClassName:entityClassName];
    [attachmentEntity setAbstract:YES];
    
    NSAttributeDescription *documentRevisionAttribute = [[NSAttributeDescription alloc] init];
    [documentRevisionAttribute setName:kCouchAttachmentDocumentRevisionPropertyName];
    [documentRevisionAttribute setAttributeType:NSStringAttributeType];
    
    [attachmentEntity setProperties:[NSArray arrayWithObjects:documentRevisionAttribute, nil]];
    [attachmentEntity setSubentities:subentities];
    return attachmentEntity;
}

@end
