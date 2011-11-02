//
//  CCQuery.h
//  CoreCouchKit
//
//  Created by Luke Iannini on 11/2/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CouchDesignDocument;
@class CoreCouchKit;
@interface CCQuery : NSObject

+ (id)queryForRelationship:(NSString *)key ofObject:(NSManagedObject *)owner inCoreCouch:(CoreCouchKit *)coreCouch;

+ (id)queryForObjectsOfType:(NSString *)entityName whose:(NSString *)key is:(NSString *)value inCoreCouch:(CoreCouchKit *)coreCouch;

- (id)initWithDesignDoc:(CouchDesignDocument *)aDesignDoc
               viewName:(NSString *)aViewName
             entityName:(NSString *)anEntityName
             relatedKey:(NSString *)aRelatedKey
           relatedValue:(NSString *)aRelatedValue
                context:(NSManagedObjectContext *)aManagedObjectContext;

- (void)start;
- (void)stop;

@property (nonatomic, strong, readonly) NSString *entityName;
@property (nonatomic, strong, readonly) NSPredicate *localPredicate;

@end
