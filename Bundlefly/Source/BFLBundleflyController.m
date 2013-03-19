//
//  BFLBundleflyController.m
//  Bundlefly
//
//  Created by Darryl H. Thomas on 3/13/13.
//  Copyright (c) 2013 Darryl H. Thomas. All rights reserved.
//
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


// IMPORTANT!!!! Do not use this for production builds.
// The functionality provided by NSBundle+ProxyBundle is accomplished through
// the use of runtime hacks and should be considered very fragile.

#import <UIKit/UIGestureRecognizerSubclass.h>
#import "BFLBundleflyController.h"
#import "BFLBundleManager.h"

NSString const * BFLBundleflyControllerDidChangeBundleContentsNotification = @"BFLBundleflyControllerDidChangeBundleContents";

NSString const * BFLServiceTypeSettingsKey = @"BFLServiceTypeSetting";

static BFLBundleflyController *BFLSharedBundleflyController = nil;

@interface BFLBundleflyController ()

@end

@implementation BFLBundleflyController
{
    BFLServiceListViewController *_serviceListViewController;
    BFLBundlesViewController *_bundlesViewController;
    BFLSettingsViewController *_settingsViewController;
    __weak UIViewController *_attachedController;
    __weak UIGestureRecognizer *_presentationGestureRecognizer;


    BFLSwitchTableViewCell *_bonjourEnabledCell;
    BFLTextFieldTableViewCell *_serviceTypeCell;
    UITableViewCell *_disableBundleProxyCell;
    UITableViewCell *_deleteBundlesCell;
    
    NSArray *_sections;
    
    BFLBundleManager *_bundleManager;
}

+ (BFLBundleflyController *)sharedController
{
    if (!BFLSharedBundleflyController) {
        BFLSharedBundleflyController = [[self alloc] initSharedControllerWithNibName:nil bundle:nil];
    }
    
    return BFLSharedBundleflyController;
}

+ (NSDictionary *)defaultSettings
{
    return @{
             BFLServiceTypeSettingsKey : @"_http._tcp.",
             };
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (BFLSharedBundleflyController) {
        return BFLSharedBundleflyController;
    }
    
    self = [self initSharedControllerWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    return self;
}

- (id)initSharedControllerWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        
        NSURL *bundlesDirectoryURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask][0] URLByAppendingPathComponent:@"Bundlefly" isDirectory:YES];
        _bundleManager = [[BFLBundleManager alloc] initWithRootURL:bundlesDirectoryURL];
        
        _serviceListViewController = [[BFLServiceListViewController alloc] initWithStyle:UITableViewStylePlain];
        _serviceListViewController.delegate = self;
        _bundlesViewController = [[BFLBundlesViewController alloc] initWithStyle:UITableViewStylePlain];
        _bundlesViewController.delegate = self;
//        _settingsViewController = [[BFLSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
        
        _bundlesViewController.bundles = _bundleManager.bundles;
        
        UINavigationController *servicesNavController = [[UINavigationController alloc] initWithRootViewController:_serviceListViewController];
        UINavigationController *bundlesNavController = [[UINavigationController alloc] initWithRootViewController:_bundlesViewController];
//        UINavigationController *settingsNavController = [[UINavigationController alloc] initWithRootViewController:_settingsViewController];
        
        
        self.viewControllers = @[
                                 servicesNavController,
                                 bundlesNavController,
//                                 settingsNavController,
                                 ];
        for (UINavigationController *navController in self.viewControllers) {
            UISwipeGestureRecognizer *recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleDismissalSwipeGesture:)];
            recognizer.direction = UISwipeGestureRecognizerDirectionDown;
            
            UINavigationBar *navigationBar = navController.navigationBar;
            [navigationBar addGestureRecognizer:recognizer];
            UIViewController *controller = navController.viewControllers[0];
            controller.navigationItem.prompt = NSLocalizedString(@"Swipe down from the top to dismiss.", nil);
        }
        
        [self setupSettingsCells];
        
        _settingsViewController.tableView.delegate = self;
        _settingsViewController.tableView.dataSource = self;
        
        _serviceListViewController.serviceType = @"_bundleflyhttp._tcp.";
        
        BFLSharedBundleflyController = self;
    }
    
    return self;
}

- (void)setupSettingsCells
{
    _bonjourEnabledCell = [[BFLSwitchTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _bonjourEnabledCell.textLabel.text = @"Bonjour"; // Should not be localized
    _bonjourEnabledCell.switchControl.on = YES;
    _bonjourEnabledCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    _serviceTypeCell = [[BFLTextFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _serviceTypeCell.textLabel.text = NSLocalizedString(@"Service Type", nil);
    _serviceTypeCell.textField.placeholder = [[self class] defaultSettings][BFLServiceTypeSettingsKey];
    _serviceTypeCell.textField.delegate = self;
    _serviceTypeCell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    
    _disableBundleProxyCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _disableBundleProxyCell.textLabel.textAlignment = NSTextAlignmentCenter;
    _disableBundleProxyCell.textLabel.text = NSLocalizedString(@"Disable Bundle Substitution", nil);
    
    _deleteBundlesCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    _deleteBundlesCell.textLabel.textAlignment = NSTextAlignmentCenter;
    _deleteBundlesCell.textLabel.text = NSLocalizedString(@"Delete Downloaded Content", nil);
    
    _sections = @[
                  @{
                      @"title" : @"Bonjour", // Should not be localized
                      @"rows" : @[
                              _bonjourEnabledCell,
                              _serviceTypeCell,
                              ],
                      },
                  @{
                      @"rows" : @[
                              _disableBundleProxyCell,
                              ],
                      @"footer" : NSLocalizedString(@"Re-enable bundle substitution by selecting a bundle from the downloads tab.", nil),
                      },
                  @{
                      @"rows" : @[
                              _deleteBundlesCell,
                              ],
                      },
                  ];
}

- (void)attachToViewController:(UIViewController *)controller
{
    [self attachToViewController:controller addingGestureRecognizerToView:controller.view];
}

- (void)attachToViewController:(UIViewController *)controller addingGestureRecognizerToView:(UIView *)view
{
    [_presentationGestureRecognizer.view removeGestureRecognizer:_presentationGestureRecognizer];
    UISwipeGestureRecognizer *recognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handlePresentationSwipeGesture:)];
    recognizer.direction = UISwipeGestureRecognizerDirectionUp;
    recognizer.delegate = self;
    [view addGestureRecognizer:recognizer];
    _attachedController = controller;
    _presentationGestureRecognizer = recognizer;
}

- (void)handlePresentationSwipeGesture:(UISwipeGestureRecognizer *)recognizer
{
    [_attachedController presentViewController:self animated:YES completion:NULL];
}

- (void)handleDismissalSwipeGesture:(UISwipeGestureRecognizer *)recognizer
{
    [_attachedController dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UIGestureRecognizerDelegate Methods

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    UIView *view = gestureRecognizer.view;
    CGPoint touchPoint = [gestureRecognizer locationInView:view];

    return touchPoint.y >= view.bounds.size.height - 20.0f;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _sections[section][@"title"];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return _sections[section][@"footer"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *section = _sections[indexPath.section];
    UITableViewCell *cell = section[@"rows"][indexPath.row];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[BFLTextFieldTableViewCell class]]) {
        [((BFLTextFieldTableViewCell *)cell).textField becomeFirstResponder];
    } else if ([cell isKindOfClass:[BFLSwitchTableViewCell class]]) {
        [((BFLSwitchTableViewCell *)cell).switchControl setOn:!((BFLSwitchTableViewCell *)cell).switchControl.on animated:YES];
    } else if ((cell == _disableBundleProxyCell) || (cell == _deleteBundlesCell)) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isKindOfClass:[BFLTextFieldTableViewCell class]]) {
        [((BFLTextFieldTableViewCell *)cell).textField resignFirstResponder];
    }
}

#pragma mark - UITextFieldDelegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    return YES;
}

#pragma mark - BFLServiceListViewControllerDelegate Methods

- (void)serviceListViewController:(BFLServiceListViewController *)controller didResolveService:(NSNetService *)service toURL:(NSURL *)url
{
    NSString *serviceName = [service name];

    [_bundleManager reconcileBundleWithName:serviceName againstRemoteURL:url queue:[NSOperationQueue mainQueue] completion:^(BFLFileSystemNodeReconciliationResult *result, NSError *error) {
        
        [_serviceListViewController setReconciliationResult:result forNetService:service];

    }];
}

- (void)serviceListViewController:(BFLServiceListViewController *)controller syncWasRequestedForService:(NSNetService *)service
{
    NSString *serviceName = [service name];
    [_bundleManager synchronizeBundleNamed:serviceName queue:[NSOperationQueue mainQueue] completion:^(BOOL finished, NSURL *remoteURL, NSError *syncError) {
        if (finished) {
            
            [_bundleManager reconcileBundleWithName:serviceName againstRemoteURL:remoteURL queue:[NSOperationQueue mainQueue] completion:^(BFLFileSystemNodeReconciliationResult *result, NSError *reconciliationError) {
                
                [_serviceListViewController setReconciliationResult:result forNetService:service];
                [_bundlesViewController addBundle:@{@"name" : serviceName}];
            }];
        } else {
            
            [_serviceListViewController setReconciliationResult:nil forNetService:service];
            
        }
    }];
}

#pragma mark - BFLBundlesViewControllerDelegate Methods

- (void)bundlesViewController:(BFLBundlesViewController *)controller didSelectBundleWithName:(NSString *)bundleName
{
    [_bundleManager selectBundleWithName:bundleName];
    controller.selectedBundleName = bundleName;
}

- (void)bundlesViewcontroller:(BFLBundlesViewController *)controller didDeleteBundleWithName:(NSString *)bundleName
{
    [_bundleManager deleteBundleWithName:bundleName];
    [_serviceListViewController setReconciliationResult:nil forNetServiceWithName:bundleName];
}

@end
