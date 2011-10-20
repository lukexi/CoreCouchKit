//
//  CouchLiveQueryFix.m
//  CouchTestApp
//
//  Created by Luke Iannini on 10/19/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CouchLiveQueryFix.h"

@interface CouchLiveQueryFix ()

- (id) initWithQuery: (CouchQuery*)query;

@end

@implementation CouchLiveQueryFix

// reimplementation of private method from CouchQuery
- (id) initWithQuery: (CouchQuery*)query {
    self = [super initWithParent: query.parent relativePath: query.relativePath];
    if (self) {
        self.limit = query.limit;
        self.skip = query.skip;
        self.startKey = query.startKey;
        self.endKey = query.endKey;
        self.descending = query.descending;
        self.prefetch = query.prefetch;
        self.keys = query.keys;
        self.groupLevel = query.groupLevel;
    }
    return self;
}

// We force prefetch to on to route around a not-understood behavior of CouchLiveQuery wherein it disables document prefetching
// upon receiving its first batch of results.
- (void)setPrefetch:(BOOL)prefetch
{
    [super setPrefetch:YES];
}

@end

@implementation CouchQuery (UseLiveQueryFix)

- (CouchLiveQuery *)ck_asLiveQuery
{
    return [[CouchLiveQueryFix alloc] initWithQuery:self];
}

@end