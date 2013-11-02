//
//  RBKSocketManager.h
//  RoboSocket
//
//  Created by David Anderson on 11/1/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RBKSocketOperation;

@interface RBKSocketManager : NSObject

@property (nonatomic, strong) NSOperationQueue *operationQueue;


- (instancetype)initWithSocketURL:(NSURL *)socketURL;

- (RBKSocketOperation *)socketOperationWithMessage:(NSString *)message
                                           success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                           failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;

- (RBKSocketOperation *)sendSocketOperationWithMessage:(NSString *)message
                                               success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                               failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;
@end
