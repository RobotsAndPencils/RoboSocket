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


- (instancetype)initWithSocketURL:(NSURL *)socketURL;

- (void)closeSocket;

- (RBKSocketOperation *)socketOperationWithMessage:(id)message
                                           success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                           failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;

- (RBKSocketOperation *)sendSocketOperationWithMessage:(id)message
                                               success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                               failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;
@end
