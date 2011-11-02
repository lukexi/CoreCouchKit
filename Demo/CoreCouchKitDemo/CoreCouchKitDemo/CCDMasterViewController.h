//
//  CCDMasterViewController.h
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/1/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CCDDetailViewController;

#import <CoreData/CoreData.h>

@interface CCDMasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) CCDDetailViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
