//
//  CCMixin.m
//  CCMixinTest
//
//  Created by Luke Iannini on 10/23/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCMixin.h"
#import <objc/runtime.h>

@implementation CCMixin

+ (Class)classByAddingContentsOfClass:(Class)mixinClass
                              toClass:(Class)originalClass
{
    NSString *sourceClassName = NSStringFromClass(mixinClass);
    NSString *destinationClassName = NSStringFromClass(originalClass);
    
    NSString *subclassName = [NSString stringWithFormat:@"%@_Plus_%@", destinationClassName, sourceClassName];
   // NSLog(@"Creating subclass %@", subclassName);
    
    Class subclass = NSClassFromString(subclassName);
    if (subclass) 
    {
        NSLog(@"Subclass %@ already exists", subclass);
    }
    
    // Create a subclass named <originalClass>_Plus_<mixinClass> that we'll put methods from sourceClass into
    subclass = objc_allocateClassPair(originalClass, [subclassName UTF8String], 0);
    if (subclass) 
    {
        // Grab all the methods from CCDocument and attach them to our new dynamic subclass of the document entity
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList(mixinClass, &methodCount);
        
        for (NSUInteger methodIndex = 0; methodIndex < methodCount; methodIndex++)
        {
            Method aMethod = methods[methodIndex];
            SEL selector = method_getName(aMethod);
            IMP implementation = method_getImplementation(aMethod);
            const char *types = method_getTypeEncoding(aMethod);
            NSString *selectorName = NSStringFromSelector(selector);
            
            // For methods that are overriding already-present methods in the destinationClass, we need to preserve the original method
            // because calling [super originalMethod] calls through to the superclass of destinationClass rather than the actual new superclass (i.e. destinationClass) :/
            
            // This is similar to swizzling, except we don't need to replace or exchange implementations since we've created a new subclass.
            if ([selectorName hasPrefix:@"override_"]) 
            {
                NSString *originalSelectorName = [selectorName stringByReplacingOccurrencesOfString:@"override_" withString:@""];
                SEL originalSelector = NSSelectorFromString(originalSelectorName);
                Method originalMethod = class_getInstanceMethod(originalClass, originalSelector);
                IMP originalImplementation = method_getImplementation(originalMethod);
                const char *originalTypes = method_getTypeEncoding(originalMethod);
                
                //NSLog(@"Adding %@ implementation under selector %@", mixinClass, originalSelectorName);
                /*BOOL addedMixinImplementation = */class_addMethod(subclass, originalSelector, implementation, types);
                //NSLog(@"Added mixin implemenetation %@", addedMixinImplementation ? @"YEP": @"NOPE");
                // <selector> now contains our new implementation, which calls through to override_<selector> first, and...
                //NSLog(@"Adding %@ implementation under selector %@", originalClass, selectorName);
                /*BOOL addedOriginalImplementation = */class_addMethod(subclass, selector, originalImplementation, originalTypes);
                //NSLog(@"Added original implemenetation %@", addedOriginalImplementation ? @"YEP": @"NOPE");
                // override_<selector> now contains the original implementation, so can can still call it.
            }
            else
            {
                class_addMethod(subclass, selector, implementation, types);
                //NSLog(@"Adding method: %@ of class %@ to class: %@", NSStringFromSelector(selector), mixinClass, subclassName);
            }
        }
        
        // Grab all the protocols and do the same
        
        unsigned int protocolCount = 0;
        Protocol * __unsafe_unretained *protocols = class_copyProtocolList(mixinClass, &protocolCount);
        
        for (NSUInteger protocolIndex = 0; protocolIndex < protocolCount; protocolIndex++) 
        {
            Protocol *aProtocol = protocols[protocolIndex];
            class_addProtocol(subclass, aProtocol);
            //NSLog(@"Adding protocol: %@ of class %@ to class: %@", NSStringFromProtocol(aProtocol), mixinClass, subclassName);
        }
        
        // We don't need ivars or properties yet but could add them too!
        
        objc_registerClassPair(subclass);
    }
    
    if (subclass) 
    {
        return subclass;
    }
    
    NSAssert(subclass, @"Failed to create subclass of %@", destinationClassName);
    return originalClass;
}

@end
