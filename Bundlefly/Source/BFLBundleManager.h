//
//  BFLBundleManager.h
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

#import <Foundation/Foundation.h>

@class BFLFileSystemNodeReconciliationResult;

@interface BFLBundleManager : NSObject

@property (nonatomic, strong, readonly) NSURL *rootURL;
@property (nonatomic, copy, readonly) NSArray *bundles;

- (id)initWithRootURL:(NSURL *)rootURL;

- (void)reconcileBundleWithName:(NSString *)bundleName againstRemoteURL:(NSURL *)remoteURL queue:(NSOperationQueue *)completionQueue completion:(void(^)(BFLFileSystemNodeReconciliationResult *result, NSError *error))completionBlock;

- (void)synchronizeBundleNamed:(NSString *)bundleName queue:(NSOperationQueue *)completionQueue completion:(void(^)(BOOL finished, NSURL *remoteURL, NSError *error))completionBlock;

- (void)selectBundleWithName:(NSString *)bundleName;
- (void)deleteBundleWithName:(NSString *)bundleName;

@end
