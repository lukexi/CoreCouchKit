//
//  CouchLiveQueryFix.h
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <CouchCocoa/CouchCocoa.h>

@interface CouchLiveQueryFix : CouchLiveQuery



@end

@interface CouchQuery (UseLiveQueryFix)

- (CouchLiveQuery*)ck_asLiveQuery;

@end
