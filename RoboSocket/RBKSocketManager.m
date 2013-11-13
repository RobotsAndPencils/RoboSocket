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

@interface RBKSocketManager () <RBKSocketControlDelegate>

@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (strong, nonatomic) RoboSocket *socket;
@property (strong, nonatomic) NSMutableArray *pendingOperations;
@property (assign, nonatomic, getter = socketIsOpen) BOOL socketOpen;

@end


@implementation RBKSocketManager

- (instancetype)initWithSocketURL:(NSURL *)socketURL {
    self = [super init];
    if (self) {
        _socket = [[RoboSocket alloc] initWithSocketURL:socketURL];
        _socket.controlDelegate = self;
        _operationQueue = [[NSOperationQueue alloc] init];
        _pendingOperations = [NSMutableArray array];
        _socketOpen = NO;
        _requestSerializer = [RBKSocketStringRequestSerializer serializer];
        _responseSerializer = [RBKSocketStringResponseSerializer serializer];
        [self openSocket];
    }
    return self;
}

#pragma mark -

- (void)setRequestSerializer:(RBKSocketRequestSerializer <RBKSocketRequestSerialization> *)requestSerializer {
    NSParameterAssert(requestSerializer);
    
    _requestSerializer = requestSerializer;
}

- (void)setResponseSerializer:(RBKSocketResponseSerializer <RBKSocketResponseSerialization> *)responseSerializer {
    NSParameterAssert(responseSerializer);
    
    _responseSerializer = responseSerializer;
}

#pragma mark -

- (RBKSocketOperation *)socketOperationWithMessage:(id)message
                                           success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                           failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {
    
    
    RBKSocketOperation *operation = [self.requestSerializer requestOperationWithMessage:message];
    
    operation.responseSerializer = self.responseSerializer;
    // operation.shouldUseCredentialStorage = self.shouldUseCredentialStorage;
    // operation.credential = self.credential;
    // operation.securityPolicy = self.securityPolicy;
    
    // give the operation the socket to use?
    operation.socket = self.socket;
    [operation setCompletionBlockWithSuccess:success failure:failure];

    return operation;
}

- (RBKSocketOperation *)sendSocketOperationWithMessage:(id)message
                                               success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                               failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {
    RBKSocketOperation *operation = [self socketOperationWithMessage:message success:success failure:failure];
    
    if (!operation) {
        NSLog(@"Failed to create a socket operation");
        NSError *error = [NSError errorWithDomain:@"com.robotsandpencils.robosocket" code:-1 userInfo:nil];
        if (failure) {
            failure(nil, error);
        }
        return nil;
    }
    
    if (self.socketIsOpen) {
        [self.operationQueue addOperation:operation]; // can't send until the socket is opened
    } else {
        [self.pendingOperations addObject:operation];
    }
    return operation;
}

- (void)sendMessageToSocket:(NSString *)message {
    [self.socket sendMessage:message];
}

- (void)openSocket {
    [self.socket openSocket];
}

- (void)closeSocket {
    [self.socket closeSocket];
    
    while (self.socketOpen && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]); // don't advance until the socket has closed completely
    // NSLog(@"Socket Closed");
}

#pragma mark - RBKSocketControlDelegate

- (void)webSocketDidOpen:(RoboSocket *)webSocket {

    for (RBKSocketOperation *operation in self.pendingOperations) {
        [self.operationQueue addOperation:operation]; // now that the socket is open, send them all
    }
    [self.pendingOperations removeAllObjects];
    
    // track if socket is open/closed
    self.socketOpen = YES; // now new operations will sent
    
}

- (void)webSocket:(RoboSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    
    self.socketOpen = NO; // operations should now be stored
}


@end
