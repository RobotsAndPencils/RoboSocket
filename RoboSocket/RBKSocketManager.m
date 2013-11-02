//
//  RBKSocketManager.m
//  RoboSocket
//
//  Created by David Anderson on 11/1/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import "RBKSocketManager.h"
#import "RoboSocket.h"
#import "RBKSocketOperation.h"

@interface RBKSocketManager ()

@property (strong, nonatomic) RoboSocket *socket;

@end


@implementation RBKSocketManager

- (instancetype)initWithSocketURL:(NSURL *)socketURL {
    self = [super init];
    if (self) {
        _socket = [[RoboSocket alloc] initWithSocketURL:socketURL];
        _operationQueue = [[NSOperationQueue alloc] init];

    }
    return self;
}

- (RBKSocketOperation *)socketOperationWithMessage:(NSString *)message
                                           success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                           failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {
    
    
    RBKSocketOperation *operation = [[RBKSocketOperation alloc] initWithRequestMessage:message];
    // operation.responseSerializer = self.responseSerializer;
    // operation.shouldUseCredentialStorage = self.shouldUseCredentialStorage;
    // operation.credential = self.credential;
    // operation.securityPolicy = self.securityPolicy;
    
    [operation setCompletionBlockWithSuccess:success failure:failure];

    return operation;
}

- (RBKSocketOperation *)sendSocketOperationWithMessage:(NSString *)message
                                               success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                               failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {
    RBKSocketOperation *operation = [self socketOperationWithMessage:message success:success failure:failure];
    [self.operationQueue addOperation:operation];
    return operation;
}

- (void)sendMessageToSocket:(NSString *)message {
    [self.socket sendMessage:message];
}


@end
