//
//  CCMixin.h
//  CCMixinTest
//
//  Created by Luke Iannini on 10/23/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CCMixin : NSObject

+ (Class)classByAddingContentsOfClass:(Class)mixinClass
                              toClass:(Class)originalClass;

@end
