//
//  BFLFileSystemNode.m
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

#import "BFLFileSystemNode.h"
#import <CommonCrypto/CommonCrypto.h>

@interface BFLFileSystemNodeReconciliationResult ()

@property (strong, readwrite) NSURL *localURL;
@property (strong, readwrite) NSURL *remoteURL;
@property (assign, readwrite) BFLFileSystemNodeComparisonResult comparisonResult;
@property (copy, readwrite) NSArray *children;

@end

@implementation BFLFileSystemNodeReconciliationResult

@end

@implementation BFLFileSystemNode
{
    NSArray *_children;
    BOOL _childrenAreDirty;
    NSString *_md5String;
}

@dynamic displayName;
@dynamic children;
@dynamic isDirectory;
@dynamic md5String;

- (id)initWithFileURL:(NSURL *)fileURL
{
    NSParameterAssert([fileURL isFileURL]);
    
    self = [super init];
    if (self) {
        _url = fileURL;
    }
    
    return self;
}

- (NSString *)displayName
{
    id value = nil;
    NSError *error = nil;
    NSString *result = nil;
    
    if ([self.url getResourceValue:&value forKey:NSURLLocalizedNameKey error:&error]) {
        result = value;
    } else {
        result = [error localizedDescription];
    }
    
    return result;
}

- (NSString *)abbreviatedPathWithInitialLetters
{
    NSArray *pathComponents = [self.url pathComponents];
    NSUInteger count = [pathComponents count];
    NSUInteger lastIndex = count - 1;
    NSMutableArray *abbreviatedPathComponents = [[NSMutableArray alloc] initWithCapacity:count];
    [pathComponents enumerateObjectsUsingBlock:^(NSString *component, NSUInteger idx, BOOL *stop) {
        if (idx == lastIndex || [component length] < 1) {
            [abbreviatedPathComponents addObject:component];
        } else {
            NSString *abbreviatedComponent = [component substringWithRange:NSMakeRange(0, 1)];
            [abbreviatedPathComponents addObject:abbreviatedComponent];
        }
    }];
    
    NSURL *url = [NSURL fileURLWithPathComponents:abbreviatedPathComponents];
    return [url path];
}

- (BOOL)isDirectory
{
    id value = nil;
    BOOL result = NO;
    
    if ([self.url getResourceValue:&value forKey:NSURLIsDirectoryKey error:NULL]) {
        result = [value boolValue];
    }
    
    return result;
}

- (NSUInteger)fileSize
{
    if (self.isDirectory)
        return 0;
    
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[self.url path] error:NULL];
    
    return [attributes fileSize];
}

- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[BFLFileSystemNode class]]) {
        BFLFileSystemNode *other = (BFLFileSystemNode *)object;
        
        return [other.url isEqual:self.url];
    }
    
    return NO;
}

- (NSUInteger)hash
{
    return [self.url hash];
}

- (NSString *)md5String
{
    if (self.isDirectory)
        return nil;
    
    if (!_md5String) {
        NSData *data = [[NSData alloc] initWithContentsOfURL:self.url options:NSDataReadingMapped error:NULL];
        if (!data)
            return @"";
        
        CC_MD5_CTX context;
        CC_MD5_Init(&context);
        NSUInteger totalLength = [data length];
        NSUInteger bufferLen = MIN(1024, totalLength);
        if (bufferLen == 0)
            return @"";
        
        NSUInteger offset = 0;
        uint8_t *buffer = calloc(bufferLen, sizeof(uint8_t));
        if (buffer == NULL)
            return @"";
        
        while (offset < totalLength) {
            NSRange range = NSMakeRange(offset, bufferLen);
            [data getBytes:buffer range:range];
            CC_MD5_Update(&context, buffer, (CC_LONG)bufferLen);
            
            offset += bufferLen;
            bufferLen = MIN(1024, totalLength - offset);
        }
        free(buffer), buffer = NULL;

        unsigned char result[CC_MD5_DIGEST_LENGTH];
        CC_MD5_Final(result, &context);
        
        _md5String = [[NSString alloc] initWithFormat:
                      @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
                      result[0], result[1], result[2], result[3],
                      result[4], result[5], result[6], result[7],
                      result[8], result[9], result[10], result[11],
                      result[12], result[13], result[14], result[15]];
    }
    
    return [_md5String copy];
}

- (NSArray *)children
{
    if (!self.isDirectory)
        return nil;
    
    if (_children == nil || _childrenAreDirty) {
        NSMutableArray *children = [[NSMutableArray alloc] init];
        
        CFURLEnumeratorRef enumerator = CFURLEnumeratorCreateForDirectoryURL(NULL, (__bridge CFURLRef)_url, kCFURLEnumeratorSkipInvisibles, (__bridge CFArrayRef)[NSArray array]);
        
        NSURL *childURL = nil;
        CFURLRef childURLRef = NULL;
        CFURLEnumeratorResult enumeratorResult;
        do {
            enumeratorResult = CFURLEnumeratorGetNextURL(enumerator, &childURLRef, NULL);
            if (enumeratorResult == kCFURLEnumeratorSuccess) {
                childURL = (__bridge NSURL *)childURLRef;
                BFLFileSystemNode *childNode = [[BFLFileSystemNode alloc] initWithFileURL:childURL];
                
                if (_children) {
                    NSUInteger oldIndex = [_children indexOfObject:childNode];
                    if (oldIndex != NSNotFound) {
                        childNode = _children[oldIndex];
                    }
                }
                [children addObject:childNode];
            }
        } while (enumeratorResult != kCFURLEnumeratorEnd);
        
        CFRelease(enumerator);
        
        _childrenAreDirty = NO;
        _children = nil;
        
        _children = [children sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSString *obj1Name = [obj1 displayName];
            NSString *obj2Name = [obj2 displayName];
            
            NSComparisonResult result = [obj1Name compare:obj2Name options:NSNumericSearch | NSCaseInsensitiveSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch range:NSMakeRange(0, [obj1Name length]) locale:[NSLocale currentLocale]];
            
            return result;
        }];
    }
    
    return _children;
}

- (void)invalidateChildren
{
    _childrenAreDirty = YES;
    
    [_children makeObjectsPerformSelector:@selector(invalidateChildren)];
}

- (NSDictionary *)dictionaryRepresentation
{
    return [self dictionaryRepresentationWithBaseURL:self.url];
}

- (NSDictionary *)dictionaryRepresentationWithBaseURL:(NSURL *)baseURL
{
    return [self dictionaryRepresentationWithBaseURL:baseURL isRootNode:YES];
}

- (NSDictionary *)dictionaryRepresentationWithBaseURL:(NSURL *)baseURL isRootNode:(BOOL)isRootNode
{
    NSURL *url = nil;
    if (isRootNode) {
        url = baseURL;
    } else if (![baseURL isEqual:self.url]) {
        url = [baseURL URLByAppendingPathComponent:[self.url lastPathComponent] isDirectory:self.isDirectory];
    }
    
    NSMutableArray *children = nil;
    if (self.isDirectory) {
        children = [[NSMutableArray alloc] initWithCapacity:[self.children count]];
        for (BFLFileSystemNode *child in self.children) {
            [children addObject:[child dictionaryRepresentationWithBaseURL:url isRootNode:NO]];
        }
    }
    
    return @{
             @"url" : [url absoluteString],
             @"name" : isRootNode ? @"/" : [self.url lastPathComponent],
             @"isDirectory" : @(self.isDirectory),
             @"children" : self.isDirectory ? [children copy] : [NSNull null],
             @"md5Sum" : self.isDirectory ? [NSNull null] : self.md5String,
             @"size" : @(self.fileSize),
             };
}

- (BFLFileSystemNode *)nodeAtRelativePath:(NSString *)nodePath
{
    BFLFileSystemNode *result = self;
    NSArray *pathComponents = [nodePath pathComponents];
    for (NSString *component in pathComponents) {
        if ([component isEqualToString:@"/"])
            continue;
        
        result = [result childWithFilename:component];
        if (!result)
            break;
    }
    
    return result;
}

- (BFLFileSystemNode *)childWithFilename:(NSString *)childName
{
    NSParameterAssert(childName);
    
    BFLFileSystemNode *result = nil;
    for (BFLFileSystemNode *child in self.children) {
        if ([[child.url lastPathComponent] isEqualToString:childName]) {
            result = child;
            break;
        }
    }
    
    return result;
}

- (BFLFileSystemNodeReconciliationResult *)reconcileAgainstDictionaryRepresentation:(NSDictionary *)otherNodeRepresentation
{
    BFLFileSystemNodeReconciliationResult *result = [[BFLFileSystemNodeReconciliationResult alloc] init];
    
    result.localURL = self.url;
    result.remoteURL = [NSURL URLWithString:otherNodeRepresentation[@"url"]];
    
    BOOL isDirectory = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:[self.url path] isDirectory:&isDirectory];
    if (exists) {
        if (self.isDirectory) {
            if (![otherNodeRepresentation[@"isDirectory"] boolValue]) {
                result.comparisonResult = BFLFileSystemNodesDifferComparison;
            } else {
                NSArray *remoteChildren = otherNodeRepresentation[@"children"];
                NSMutableDictionary *remoteChildrenByName = [[NSMutableDictionary alloc] initWithCapacity:[remoteChildren count]];
                [remoteChildren enumerateObjectsUsingBlock:^(NSDictionary *childRepresentation, NSUInteger idx, BOOL *stop) {
                    remoteChildrenByName[childRepresentation[@"name"]] = childRepresentation;
                }];
                
                NSMutableIndexSet *unprocessedRemoteChildIndexes = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, [remoteChildren count])];
                NSMutableArray *childResults = [[NSMutableArray alloc] initWithCapacity:[self.children count] + [remoteChildren count]];
                __block BOOL childrenDiffer = NO;
                
                [self.children enumerateObjectsUsingBlock:^(BFLFileSystemNode *localChild, NSUInteger idx, BOOL *stop) {
                    NSString *childName = localChild.displayName;
                    NSDictionary *remoteChild = remoteChildrenByName[childName];
                    if (remoteChild) {
                        BFLFileSystemNodeReconciliationResult *childResult = [localChild reconcileAgainstDictionaryRepresentation:remoteChild];
                        
                        if (childResult.comparisonResult != BFLFileSystemNodesAreEqualComparison) {
                            childrenDiffer = YES;
                        }
                        [childResults addObject:childResult];
                        [unprocessedRemoteChildIndexes removeIndex:[remoteChildren indexOfObject:remoteChild]];
                    } else {
                        childrenDiffer = YES;
                        BFLFileSystemNodeReconciliationResult *childResult = [[BFLFileSystemNodeReconciliationResult alloc] init];
                        childResult.localURL = localChild.url;
                        childResult.comparisonResult = BFLFileSystemNodeIsMissingRemotelyComparison;
                        
                        [childResults addObject:childResult];
                    }
                }];
                
                NSArray *remainingRemoteChildren = [remoteChildren objectsAtIndexes:unprocessedRemoteChildIndexes];
                if ([remainingRemoteChildren count]) {
                    childrenDiffer = YES;
                    [childResults addObjectsFromArray:[self fileSystemNodeReconciliationResultsForMissingLocalChildren:remainingRemoteChildren baseURL:self.url]];
                }
                
                result.comparisonResult = childrenDiffer ? BFLFileSystemNodesDifferComparison : BFLFileSystemNodesAreEqualComparison;
                result.children = [childResults copy];
            }
        } else {
            if ([otherNodeRepresentation[@"isDirectory"] boolValue]) {
                result.comparisonResult = BFLFileSystemNodesDifferComparison;
                result.children = [self fileSystemNodeReconciliationResultsForMissingLocalChildren:otherNodeRepresentation[@"children"] baseURL:self.url];
            } else if (([otherNodeRepresentation[@"size"] unsignedIntegerValue] != self.fileSize) || (![otherNodeRepresentation[@"md5Sum"] isEqualToString:self.md5String])) {
                result.comparisonResult = BFLFileSystemNodesDifferComparison;
            } else {
                result.comparisonResult = BFLFileSystemNodesAreEqualComparison;
            }
        }
    } else {
        result.comparisonResult = BFLFileSystemNodeIsMissingLocallyComparison;
        if ([otherNodeRepresentation[@"isDirectory"] boolValue]) {
            result.children = [self fileSystemNodeReconciliationResultsForMissingLocalChildren:otherNodeRepresentation[@"children"] baseURL:self.url];
        }
    }
    
    return result;
}

- (NSArray *)fileSystemNodeReconciliationResultsForMissingLocalChildren:(NSArray *)children baseURL:(NSURL *)baseURL
{
    NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:[children count]];
    for (NSDictionary *child in children) {
        [result addObject:[self fileSystemNodeReconciliationResultForMissingLocalChild:child baseURL:baseURL]];
    }
    return [result copy];
}

- (BFLFileSystemNodeReconciliationResult *)fileSystemNodeReconciliationResultForMissingLocalChild:(NSDictionary *)childRepresentation baseURL:(NSURL *)baseURL
{
    BFLFileSystemNodeReconciliationResult *result = [[BFLFileSystemNodeReconciliationResult alloc] init];
    NSURL *remoteURL = [NSURL URLWithString:childRepresentation[@"url"]];
    BOOL isDirectory = [childRepresentation[@"isDirectory"] boolValue];
    NSURL *localURL = [baseURL URLByAppendingPathComponent:childRepresentation[@"name"] isDirectory:isDirectory];
    result.remoteURL = remoteURL;
    result.localURL = localURL;
    result.comparisonResult = BFLFileSystemNodeIsMissingLocallyComparison;
    
    if (isDirectory) {
        result.children = [self fileSystemNodeReconciliationResultsForMissingLocalChildren:childRepresentation[@"children"] baseURL:localURL];
    }
    
    return result;
}

@end

