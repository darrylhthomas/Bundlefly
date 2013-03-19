//
//  BFLBundleManager.m
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

#import "BFLBundleManager.h"
#import "BFLFileSystemNode.h"
#import "NSBundle+ProxyBundle.h"

@implementation BFLBundleManager
{
    NSOperationQueue *_operationQueue;
    NSMutableDictionary *_knownBundles;
}

@dynamic bundles;

- (id)initWithRootURL:(NSURL *)rootURL
{
    self = [self init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 1;

        _rootURL = rootURL;
        _knownBundles = [[self findBundles] mutableCopy];
        if (!_knownBundles)
            _knownBundles = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (NSArray *)bundles
{
    return [_knownBundles allValues];
}

- (NSDictionary *)findBundles
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray *directoryContents = [fileManager contentsOfDirectoryAtURL:_rootURL includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    NSMutableDictionary *bundles = nil;
    if (directoryContents) {
        bundles = [[NSMutableDictionary alloc] initWithCapacity:[directoryContents count]];
        for (NSURL *bundleURL in directoryContents) {
            BFLFileSystemNode *node = [[BFLFileSystemNode alloc] initWithFileURL:bundleURL];
            NSString *bundleName = [bundleURL lastPathComponent];
            NSDictionary *bundle = @{
                                     @"name" : bundleName,
                                     @"node" : node,
                                     @"baseURL" : bundleURL,
                                     };
            
            bundles[bundleName] = bundle;
        }
    } else {
        NSLog(@"Error discovering bundles: %@", [error localizedDescription]);
    }
    
    return [bundles copy];
}

- (void)reconcileBundleWithName:(NSString *)bundleName againstRemoteURL:(NSURL *)remoteURL queue:(NSOperationQueue *)completionQueue completion:(void (^)(BFLFileSystemNodeReconciliationResult *, NSError *))completionBlock
{
    [_operationQueue addOperationWithBlock:^{
        BFLFileSystemNodeReconciliationResult *result = nil;
        NSError *error = nil;
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL:remoteURL];
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:NULL error:&error];
        if (data) {
            NSDictionary *remoteDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            if (remoteDictionary) {
                NSString *normalizedBundleName = [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@":"];
                NSURL *localURL = [[[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask][0] URLByAppendingPathComponent:@"Bundlefly" isDirectory:YES] URLByAppendingPathComponent:normalizedBundleName isDirectory:YES];
                BFLFileSystemNode *node = [[BFLFileSystemNode alloc] initWithFileURL:localURL];
                result = [node reconcileAgainstDictionaryRepresentation:remoteDictionary];
                if (result) {
                    _knownBundles[normalizedBundleName] = @{
                                                            @"name" : normalizedBundleName,
                                                            @"reconciliationResult" : result,
                                                            @"baseURL" : localURL,
                                                            @"node" : node,
                                                            };
                }
            }
        }
        if (completionBlock != NULL) {
            [completionQueue addOperationWithBlock:^{
                completionBlock(result, error);
            }];
        }
    }];
}

- (void)synchronizeBundleNamed:(NSString *)bundleName queue:(NSOperationQueue *)completionQueue completion:(void (^)(BOOL, NSURL*, NSError *))completionBlock
{
    bundleName = [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@":"];

    [_operationQueue addOperationWithBlock:^{
        BOOL success = NO;
        NSError *error = nil;
        BFLFileSystemNodeReconciliationResult *reconciliationResult = nil;
        NSDictionary *bundleDictionary = _knownBundles[bundleName];
        if (bundleDictionary) {
            reconciliationResult = bundleDictionary[@"reconciliationResult"];
            NSURL *baseURL = bundleDictionary[@"baseURL"];
            success = [self performSynchronizationForReconciliationResult:reconciliationResult error:&error];
            if (success) {
                BFLFileSystemNode *node = [[BFLFileSystemNode alloc] initWithFileURL:baseURL];
                bundleDictionary = @{
                                     @"name" : bundleName,
                                     @"baseURL" : baseURL,
                                     @"node" : node,
                                     };
                _knownBundles[bundleName] = bundleDictionary;
            }
            
        } else {
            success = NO;
            error = [[NSError alloc] initWithDomain:@"BFLBundleflyDomain" code:86 userInfo:@{
                                  NSLocalizedDescriptionKey : NSLocalizedString(@"The bundle must be reconciled before it can be synchronized.", nil),
                              }];
        }

        if (completionBlock != NULL) {
            [completionQueue addOperationWithBlock:^{
                completionBlock(success, reconciliationResult.remoteURL, error);
            }];
        }
    }];
}

- (BOOL)performSynchronizationForReconciliationResult:(BFLFileSystemNodeReconciliationResult *)reconciliationResult error:(NSError *__autoreleasing*)outError
{
    NSURL *localURL = reconciliationResult.localURL;
    NSURL *remoteURL = reconciliationResult.remoteURL;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL success = YES;
    
    switch (reconciliationResult.comparisonResult) {
        case BFLFileSystemNodeIsMissingLocallyComparison:
            if (reconciliationResult.children) {
                success = [fileManager createDirectoryAtURL:localURL withIntermediateDirectories:YES attributes:nil error:outError];
                if (!success)
                    break;
            }
        case BFLFileSystemNodesDifferComparison:
            if (reconciliationResult.children) {
                for (BFLFileSystemNodeReconciliationResult *childResult in reconciliationResult.children) {
                    success = [self performSynchronizationForReconciliationResult:childResult error:outError];
                    if (!success)
                        break;
                }
                if (!success)
                    break;
            } else {
                NSURLRequest *request = [[NSURLRequest alloc] initWithURL:remoteURL];
                NSURLResponse *response = nil;
                NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:outError];
                if (!data) {
                    success = NO;
                    break;
                }
                
                success = [data writeToURL:localURL options:NSDataWritingAtomic | NSDataWritingFileProtectionNone error:outError];
            }
            break;
        case BFLFileSystemNodeIsMissingRemotelyComparison:
            success = [fileManager removeItemAtURL:localURL error:outError];
        default:
            break;
    }
    
    return success;
}

- (void)selectBundleWithName:(NSString *)bundleName
{
    if (!bundleName) {
        [NSBundle bpr_setMainBundleSubstitutionBundle:nil];
        return;
    }
    
    bundleName = [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    NSDictionary *bundle = _knownBundles[bundleName];
    
    NSURL *bundleURL = bundle[@"baseURL"];
    NSString *path = [bundleURL path];
    [NSBundle bpr_setMainBundleSubstitutionPath:path];
}

- (void)deleteBundleWithName:(NSString *)bundleName
{
    bundleName = [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@":"];
    NSDictionary *bundle = _knownBundles[bundleName];
    
    if (!bundle)
        return;
    
    NSURL *bundleURL = bundle[@"baseURL"];
    if ([[[NSBundle mainBundle] bundleURL] isEqual:bundleURL]) {
        [NSBundle bpr_setMainBundleSubstitutionBundle:nil];
    }

    [_operationQueue addOperationWithBlock:^{
        [_knownBundles removeObjectForKey:bundleName];
        [[NSFileManager defaultManager] removeItemAtURL:bundleURL error:NULL];
    }];
}

@end
