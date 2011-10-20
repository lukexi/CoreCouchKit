//
//  CCDocument.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CouchCocoa/CouchCocoa.h>

#define kCouchIDKey @"_id"
#define kCouchRevKey @"_rev"
#define kCouchPreventPUTKey @"kCouchPreventPUTKey"

@interface CCDocument : NSManagedObject <CouchDocumentModel, CJRelationshipRepresentation>

@property (nonatomic, retain) NSString * couchRev;
@property (nonatomic, retain) NSString * couchID;

@end

@interface NSManagedObjectContext (CCDocument)

- (BOOL)cc_saveWithoutPUT:(NSError **)error;
- (BOOL)cc_isSavingWithoutPUT;

@end

@interface NSManagedObject (CCDocument)

+ (NSString *)cc_generateUUID;
- (CouchDatabase *)cc_couchDatabase;
- (NSMutableDictionary *)cc_userProperties;
- (CouchDocument *)cc_couchDocument;

- (void)cc_putToCouch;
- (void)cc_putToCouchWithCompletion:(OnCompleteBlock)completion;
- (void)cc_getFromCouch;
- (void)cc_getFromCouchWithCompletion:(OnCompleteBlock)completion;

@end