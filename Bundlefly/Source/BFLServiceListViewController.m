//
//  BFLServiceListViewController.m
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

#import "BFLServiceListViewController.h"
#import "BFLBundleTableViewCell.h"
#import "BFLFileSystemNode.h"

#define MANUAL_BOOKMARK_SUPPORT 0
#if MANUAL_BOOKMARK_SUPPORT
#define BONJOUR_SECTION_OFFSET 1
#else
#define BONJOUR_SECTION_OFFSET 0
#endif

@interface BFLServiceListViewController ()

@end

@implementation BFLServiceListViewController
{
    NSNetServiceBrowser *_netServiceBrowser;
    NSMutableDictionary *_bonjourServicesByDomain;
    NSMutableArray *_sortedDomains;
    NSMutableDictionary *_reconciliationResults;

#if MANUAL_BOOKMARK_SUPPORT
    NSMutableArray *_bookmarkServices;
#endif
}

+ (UIImage *)imageForReconciliationResult:(BFLFileSystemNodeReconciliationResult *)result
{
    if (!result || result.comparisonResult == BFLFileSystemNodeIsMissingLocallyComparison)
        return [UIImage imageNamed:@"bundlefly_status_missing"];
    
    if (result.comparisonResult == BFLFileSystemNodesDifferComparison)
        return [UIImage imageNamed:@"bundlefly_status_not_synced"];
    
    return [UIImage imageNamed:@"bundlefly_status_synced"];
}

+ (NSString *)serviceNameForBundleName:(NSString *)bundleName
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
        _sortedDomains = [[NSMutableArray alloc] init];
        _bonjourServicesByDomain = [[NSMutableDictionary alloc] init];
        _reconciliationResults = [[NSMutableDictionary alloc] init];
        
        [self.tableView registerClass:[BFLBundleTableViewCell class] forCellReuseIdentifier:@"ServiceCell"];
        self.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:0];
        self.title = NSLocalizedString(@"Bookmarks", nil);

#if MANUAL_BOOMARK_SUPPORT
        self.navigationItem.rightBarButtonItem = self.editButtonItem;

        _bookmarkServices = [[NSMutableArray alloc] init];
        NSNetService *netService = [[NSNetService alloc] initWithDomain:@"darrylhthomas.github.com" type:@"_http._tcp." name:@"darrylhthomas" port:80];
        [_bookmarkServices addObject:netService];
#endif
    }
    return self;
}

- (void)setServiceType:(NSString *)serviceType
{
    if (_serviceType && [serviceType isEqualToString:_serviceType])
        return;

    _serviceType = [serviceType copy];
    if (!_serviceType)
        return;
    
    if (_netServiceBrowser) {
        [_netServiceBrowser stop];
    } else {
        _netServiceBrowser = [[NSNetServiceBrowser alloc] init];
        _netServiceBrowser.delegate = self;
    }
    
    [_netServiceBrowser searchForServicesOfType:_serviceType inDomain:@""];
}

- (void)sortBonjourServices
{
    [[_bonjourServicesByDomain allValues] enumerateObjectsUsingBlock:^(NSMutableArray *domainArray, NSUInteger idx, BOOL *stop) {
        [domainArray sortUsingComparator:^NSComparisonResult(NSNetService *obj1, NSNetService *obj2) {
            return [[obj1 name] localizedCaseInsensitiveCompare:[obj2 name]];
        }];
    }];

    [_sortedDomains sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (void)setReconciliationResult:(BFLFileSystemNodeReconciliationResult *)result forNetServiceWithName:(NSString *)name
{
    name = [[self class] serviceNameForBundleName:name];
    __block NSNetService *service = nil;
    [_bonjourServicesByDomain enumerateKeysAndObjectsUsingBlock:^(NSString *domain, NSArray *services, BOOL *domainsStop) {
        [services enumerateObjectsUsingBlock:^(NSNetService *enumeratedService, NSUInteger idx, BOOL *servicesStop) {
            if ([[enumeratedService name] isEqualToString:name]) {
                service = enumeratedService;
                *servicesStop = YES;
            }
        }];
        if (service) {
            *domainsStop = YES;
        }
    }];
    
    if (service) {
        [self setReconciliationResult:result forNetService:service];
    }
}

- (void)setReconciliationResult:(BFLFileSystemNodeReconciliationResult *)result forNetService:(NSNetService *)service
{
    NSInteger row = NSNotFound;
    NSIndexPath *cellIndexPath = nil;

#if MANUAL_BOOKMARK_SUPPORT
    row = [_bookmarkServices indexOfObject:service];
#endif

    if (row != NSNotFound) {
        cellIndexPath = [NSIndexPath indexPathForRow:row inSection:0];
    } else {
        NSString *domain = service.domain;
        NSInteger section = [_sortedDomains indexOfObject:domain];
        if (section != NSNotFound) {
            row = [_bonjourServicesByDomain[domain] indexOfObject:service];
            if (row != NSNotFound) {
                cellIndexPath = [NSIndexPath indexPathForRow:row inSection:section  + BONJOUR_SECTION_OFFSET];
            }
        }
    }
    
    if (cellIndexPath) {
        if (result) {
            _reconciliationResults[cellIndexPath] = result;
        } else {
            [_reconciliationResults removeObjectForKey:cellIndexPath];
        }
        
        BFLBundleTableViewCell *cell = (BFLBundleTableViewCell *)[self.tableView cellForRowAtIndexPath:cellIndexPath];
        
        cell.detailTextLabel.text = nil;
        [cell setStatusImage:[[self class] imageForReconciliationResult:result]];
        [cell hideActivityIndicator];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return BONJOUR_SECTION_OFFSET + [_sortedDomains count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
#if MANUAL_BOOKMARK_SUPPORT
    if (section == 0)
        return 1 + [_bookmarkServices count];
#endif

    return [_bonjourServicesByDomain[_sortedDomains[section - BONJOUR_SECTION_OFFSET]] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
#if MANUAL_BOOKMARK_SUPPORT
    if (section == 0)
        return NSLocalizedString(@"Saved Bookmarks", nil);
#endif
    
    return [@"Bonjour: " stringByAppendingString:_sortedDomains[section - BONJOUR_SECTION_OFFSET]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"ServiceCell";
    BFLBundleTableViewCell *cell = (BFLBundleTableViewCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    BFLFileSystemNodeReconciliationResult *reconciliationResult = _reconciliationResults[indexPath];
    BOOL isServiceCell = NO;
    
#if MANUAL_BOOKMARK_SUPPORT
    if (indexPath.section == 0) {
        if (indexPath.row == [_bookmarkServices count]) {
            cell.textLabel.text = NSLocalizedString(@"Add bookmark…", nil);
        } else {
            NSNetService *service = _bookmarkServices[indexPath.row];
            cell.textLabel.text = service.name;
            cell.imageView.image = [UIImage imageNamed:@"bundlefly_bookmark_cell_image"];
            isServiceCell = YES;
        }
    }
#endif
    
    if (indexPath.section >= BONJOUR_SECTION_OFFSET) {
        NSNetService *service = _bonjourServicesByDomain[_sortedDomains[indexPath.section - BONJOUR_SECTION_OFFSET]][indexPath.row];
        cell.textLabel.text = service.name;
        cell.imageView.image = [UIImage imageNamed:@"bundlefly_bonjour_cell_image"];
        [cell showActivityIndicator];
        cell.detailTextLabel.text = NSLocalizedString(@"Checking sync status…", nil);
        isServiceCell = YES;
    }
    
    if (isServiceCell) {
        [cell setStatusImage:[[self class] imageForReconciliationResult:reconciliationResult]];
        if (reconciliationResult) {
            [cell hideActivityIndicator];
            cell.detailTextLabel.text = nil;
        }
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
#if MANUAL_BOOKMARK_SUPPORT
    return (indexPath.section == 0 && indexPath.row != [_bookmarkServices count]);
#else
    return NO;
#endif
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
#if MANUAL_BOOKMARK_SUPPORT
    NSParameterAssert(indexPath.section == 0);
    NSParameterAssert(indexPath.row < [_bookmarkServices count]);
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_bookmarkServices removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        NSLog(@"Recieved insertion request for index path %@", indexPath);
    }
#endif
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

#if MANUAL_BOOKMARK_SUPPORT
    // TODO: manual bookmark support
#endif
    if (indexPath.section >= BONJOUR_SECTION_OFFSET) {
        BFLFileSystemNodeReconciliationResult *reconciliationResult = _reconciliationResults[indexPath];
        NSNetService *service = _bonjourServicesByDomain[_sortedDomains[indexPath.section - BONJOUR_SECTION_OFFSET]][indexPath.row];
        if (reconciliationResult) {
            if ([self.delegate respondsToSelector:@selector(serviceListViewController:syncWasRequestedForService:)]) {
                BFLBundleTableViewCell *cell = (BFLBundleTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
                if (reconciliationResult.comparisonResult == BFLFileSystemNodesDifferComparison) {
                    cell.detailTextLabel.text = NSLocalizedString(@"Synchronizing…", nil);
                } else {
                    cell.detailTextLabel.text = NSLocalizedString(@"Downloading…", nil);
                }
                [cell showActivityIndicator];
                [self.delegate serviceListViewController:self syncWasRequestedForService:service];
            }
        } else {
            // TODO: refactor -netServiceDidResolveAddress: so we don't have to call it directly
            [self netServiceDidResolveAddress:service];
        }
    }
}

#pragma mark - NSNetServiceBrowserDelegate Methods

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    aNetService.delegate = self;
    [aNetService resolveWithTimeout:0.0];
    BOOL insertedDomain = NO;
    NSString *domain = aNetService.domain;
    NSMutableArray *services = _bonjourServicesByDomain[domain];
    if (!services) {
        services = [[NSMutableArray alloc] init];
        _bonjourServicesByDomain[domain] = services;
        [_sortedDomains addObject:domain];
        insertedDomain = YES;
    }
    
    [services addObject:aNetService];
    [self sortBonjourServices];
    
    [self.tableView beginUpdates];
    if (insertedDomain) {
        NSIndexSet *changeSet = [[NSIndexSet alloc] initWithIndex:[_sortedDomains indexOfObject:domain] + BONJOUR_SECTION_OFFSET];
        [self.tableView insertSections:changeSet withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        NSInteger section = [_sortedDomains indexOfObject:domain] + BONJOUR_SECTION_OFFSET;
        NSInteger row = [services indexOfObject:aNetService];
        [self.tableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:section]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self.tableView endUpdates];
    
    if (!moreComing && self.refreshControl.refreshing)
        [self.refreshControl endRefreshing];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
    BOOL removedDomain = NO;
    [aNetService stop];
    
    NSString *domain = aNetService.domain;
    NSInteger section = [_sortedDomains indexOfObject:domain] + BONJOUR_SECTION_OFFSET;
    NSInteger row = NSNotFound;
    NSMutableArray *services = _bonjourServicesByDomain[domain];
    if (services) {
        row = [services indexOfObject:aNetService];
        [services removeObject:aNetService];
        if ([services count] == 0) {
            [_bonjourServicesByDomain removeObjectForKey:domain];
            [_sortedDomains removeObject:domain];
            removedDomain = YES;
        }
    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
    [_reconciliationResults removeObjectForKey:indexPath];
    
    [self sortBonjourServices];
    [self.tableView beginUpdates];
    if (removedDomain) {
        NSIndexSet *changeSet = [[NSIndexSet alloc] initWithIndex:section];
        [self.tableView deleteSections:changeSet withRowAnimation:UITableViewRowAnimationAutomatic];
    } else {
        [self.tableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:section]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    [self.tableView endUpdates];
}

#pragma mark - NSNetServiceDelegate Methods

- (void)netService:(NSNetService *)service didNotResolve:(NSDictionary *)errorDictionary
{
    NSLog(@"Resolve failure: %@", errorDictionary);
}


- (void)netServiceDidResolveAddress:(NSNetService *)service
{	
	NSDictionary* txtDictionary = [NSNetService dictionaryFromTXTRecordData:[service TXTRecordData]];
    NSString *host = [service hostName];
    NSString *user = [self stringFromTXTDictionary:txtDictionary key:@"u"];
    NSString *password = [self stringFromTXTDictionary:txtDictionary key:@"p"];
	NSString* portString = @"";
	
	NSInteger port = [service port];
	if (port != 0 && port != 80)
        portString = [[NSString alloc] initWithFormat:@":%d",port];
	
	NSString* path = [self stringFromTXTDictionary:txtDictionary key:@"path"];
	if (!path || [path length]==0) {
        path = @"/";
	} else if (![[path substringToIndex:1] isEqual:@"/"]) {
        path = [@"/%@" stringByAppendingString:path];
	}
	
	NSString* string = [[NSString alloc] initWithFormat:@"http://%@%@%@%@%@%@%@",
                        user?user:@"",
                        password?@":":@"",
                        password?password:@"",
                        (user||password)?@"@":@"",
                        host,
                        portString,
                        path];
	
	NSURL *url = [[NSURL alloc] initWithString:string];
    if ([self.delegate respondsToSelector:@selector(serviceListViewController:didResolveService:toURL:)]) {
        [self.delegate serviceListViewController:self didResolveService:service toURL:url];
    }
}

- (NSString *)stringFromTXTDictionary:(NSDictionary *)dictionary key:(NSString*)key {
	// Helper for getting information from the TXT data
	NSData* data = dictionary[key];
	NSString *result = nil;
	if (data) {
		result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	return result;
}

@end
