//
//  BFLBundlesViewController.m
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

#import "BFLBundlesViewController.h"
#import "BFLBundleTableViewCell.h"
#import "BFLFileSystemNode.h"

@implementation BFLBundlesViewController
{
    NSMutableArray *_bundles;
}

@dynamic bundles;

+ (NSString *)displayNameForBundleName:(NSString *)bundleName
{
    NSArray *components = [bundleName componentsSeparatedByString:@":"];
    NSString *name = components[0];
    if ([components count] > 1) {
        NSArray *pathComponents = [components subarrayWithRange:NSMakeRange(1, [components count] - 1)];
        name = [name stringByAppendingFormat:@":%@", [pathComponents componentsJoinedByString:@"/"]];
    }
    
    return name;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemDownloads tag:1];
        self.title = NSLocalizedString(@"Downloads", nil);
        [self.tableView registerClass:[BFLBundleTableViewCell class] forCellReuseIdentifier:@"BundleCell"];
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    }
    return self;
}

- (void)sortBundles
{
    [_bundles sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        return [obj1[@"name"] localizedCaseInsensitiveCompare:obj2[@"name"]];
    }];
}

- (NSIndexPath *)indexPathForBundleWithName:(NSString *)name
{
    if (!name)
        return nil;
    
    NSInteger row = [_bundles indexOfObjectPassingTest:^BOOL(NSDictionary *bundle, NSUInteger idx, BOOL *stop) {
        BOOL result = [bundle[@"name"] isEqualToString:name];
        if (result)
            *stop = YES;
        
        return result;
    }];
    
    if (row == NSNotFound)
        return nil;
    
    return [NSIndexPath indexPathForRow:row inSection:0];
}

- (void)setSelectedBundleName:(NSString *)selectedBundleName
{
    if ([selectedBundleName isEqualToString:_selectedBundleName])
        return;
    
    NSIndexPath *currentSelectionIndexPath = [self indexPathForBundleWithName:_selectedBundleName];
    NSIndexPath *newSelectionIndexPath = [self indexPathForBundleWithName:selectedBundleName];
    
    _selectedBundleName = [selectedBundleName copy];
    
    UITableView *tableView = self.tableView;
    if (currentSelectionIndexPath) {
        BFLBundleTableViewCell *cell = (BFLBundleTableViewCell *)[tableView cellForRowAtIndexPath:currentSelectionIndexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    if (newSelectionIndexPath) {
        BFLBundleTableViewCell *cell = (BFLBundleTableViewCell *)[tableView cellForRowAtIndexPath:newSelectionIndexPath];
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
}

- (void)setBundles:(NSArray *)bundles
{
    _bundles = [bundles mutableCopy];
    [self sortBundles];
    [self.tableView reloadData];
}

- (NSArray *)bundles
{
    return [_bundles copy];
}

- (void)addBundle:(NSDictionary *)bundle
{
    NSInteger oldIndex = [_bundles indexOfObject:bundle];
    if (oldIndex == NSNotFound) {
        // It's possible the dictionary differs from the one we're storing even though it represents the same bundle, so search by name.
        oldIndex = [_bundles indexOfObjectPassingTest:^BOOL(NSDictionary *object, NSUInteger idx, BOOL *stop) {
            BOOL result = ([bundle[@"name"] isEqualToString:object[@"name"]]);
            if (result)
                *stop = YES;
            
            return result;
        }];
    }
    
    // If we already have the bundle, just bail
    if (oldIndex != NSNotFound)
        return;
    
    [_bundles addObject:bundle];
    [self sortBundles];
    NSInteger row = [_bundles indexOfObject:bundle];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
    UITableView *tableView = self.tableView;
    [tableView beginUpdates];
    [tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [tableView endUpdates];
}

- (void)removeBundle:(NSDictionary *)bundle
{
    NSInteger oldIndex = [_bundles indexOfObject:bundle];
    if (oldIndex == NSNotFound) {
        // It's possible the dictionary differs from the one we're storing even though it represents the same bundle, so search by name.
        oldIndex = [_bundles indexOfObjectPassingTest:^BOOL(NSDictionary *object, NSUInteger idx, BOOL *stop) {
            BOOL result = ([bundle[@"name"] isEqualToString:object[@"name"]]);
            if (result)
                *stop = YES;
            
            return result;
        }];
    }
    
    // If we still didn't find the bundle, just bail
    if (oldIndex == NSNotFound)
        return;
    
    if ([bundle[@"name"] isEqualToString:_selectedBundleName])
        _selectedBundleName = nil;
    
    [_bundles removeObjectAtIndex:oldIndex];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:oldIndex inSection:0];
    UITableView *tableView = self.tableView;
    [tableView beginUpdates];
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [tableView endUpdates];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_bundles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"BundleCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    
    NSDictionary *bundle = [_bundles objectAtIndex:indexPath.row];
    NSString *bundleName = bundle[@"name"];
    cell.imageView.image = [UIImage imageNamed:@"bundlefly_bundle_cell_image"];
    cell.textLabel.text = [[self class] displayNameForBundleName:bundleName];
    
    if ([_selectedBundleName isEqualToString:bundleName]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSDictionary *bundle = _bundles[indexPath.row];
        NSString *bundleName = bundle[@"name"];
        if ([_selectedBundleName isEqualToString:bundleName])
            _selectedBundleName = nil;
        
        [_bundles removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [self.delegate bundlesViewcontroller:self didDeleteBundleWithName:bundleName];
    }   
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *bundle = [_bundles objectAtIndex:indexPath.row];
    NSString *bundleName = bundle[@"name"];
    
    if ([bundleName isEqualToString:_selectedBundleName])
        bundleName = nil;
    
    [self.delegate bundlesViewController:self didSelectBundleWithName:bundleName];
}

@end
