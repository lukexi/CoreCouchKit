//
//  CCDDetailViewController.m
//  CoreCouchKitDemo
//
//  Created by Luke Iannini on 11/1/11.
//  Copyright (c) 2011 Eeoo. All rights reserved.
//

#import "CCDDetailViewController.h"
#import "CoreCouchKit.h"
#import "Event.h"
#import "Image.h"

@interface CCDDetailViewController ()
{
    id nameObserver;
    id locationObserver;
    id imageObserver;
    UIPopoverController *imagePickerPopoverController;
}
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
- (void)save;
@end

@implementation CCDDetailViewController

@synthesize detailItem = _detailItem;
@synthesize detailDescriptionLabel = _detailDescriptionLabel;
@synthesize nameField = _nameField;
@synthesize locationField = _locationField;
@synthesize imageView = _imageView;
@synthesize masterPopoverController = _masterPopoverController;

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showImagePicker"]) 
    {
        [[segue destinationViewController] setDelegate:self];
        UIStoryboardPopoverSegue *popoverSegue = (UIStoryboardPopoverSegue *)segue;
        imagePickerPopoverController = [popoverSegue popoverController];
    }
}

- (void)demoImagePicker:(CCDDemoImagePicker *)demoImagePicker didFinishWithImage:(UIImage *)image
{
    Event *event = self.detailItem;
    event.image.image = image;
    [self save];
    [imagePickerPopoverController dismissPopoverAnimated:YES];
    imagePickerPopoverController = nil;
}

- (void)dealloc
{
    [_detailItem removeKVOBlockForToken:nameObserver];
    [_detailItem removeKVOBlockForToken:locationObserver];
    [_detailItem removeKVOBlockForToken:imageObserver];
}

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) 
    {
        [_detailItem removeKVOBlockForToken:nameObserver];
        [_detailItem removeKVOBlockForToken:locationObserver];
        [_detailItem removeKVOBlockForToken:imageObserver];
        
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) 
    {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.detailItem) 
    {
        self.detailDescriptionLabel.text = [self.detailItem description];
        
        __weak CCDDetailViewController *weakSelf = self;
        nameObserver = [self.detailItem addKVOBlockForKeyPath:@"name" 
                                                      options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew 
                                                      handler:^(NSString *keyPath, id object, NSDictionary *change) 
        {
            weakSelf.nameField.text = [weakSelf.detailItem valueForKey:@"name"];
        }];
        
        locationObserver = [self.detailItem addKVOBlockForKeyPath:@"location" 
                                                          options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew 
                                                          handler:^(NSString *keyPath, id object, NSDictionary *change)
        {
            weakSelf.locationField.text = [weakSelf.detailItem valueForKey:@"location"];
        }];
        
        imageObserver = [self.detailItem addKVOBlockForKeyPath:@"image.image" 
                                                       options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew 
                                                       handler:^(NSString *keyPath, id object, NSDictionary *change) 
        {
            weakSelf.imageView.image = [weakSelf.detailItem valueForKeyPath:@"image.image"];
        }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    NSLog(@"textfield should return %@", textField);
    [textField resignFirstResponder];
    return NO;
}

- (void)save
{
    NSError *error;
    if (![[self.detailItem managedObjectContext] save:&error]) 
    {
        NSLog(@"Error saving textfield change: %@", error);
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    NSLog(@"textfield did end editing %@", textField);
    
    if (textField == self.nameField) 
    {
        [self.detailItem setValue:textField.text forKey:@"name"];
    }
    else if (textField == self.locationField) 
    {
        [self.detailItem setValue:textField.text forKey:@"location"];
    }
    [self save];
}
#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)viewDidUnload
{
    [self setNameField:nil];
    [self setLocationField:nil];
    [self setImageView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Master", @"Master");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
