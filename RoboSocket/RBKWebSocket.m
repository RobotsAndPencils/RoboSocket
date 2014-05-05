//
// Created by Michael Beauregard on 2014-03-07.
// Copyright (c) 2014 Robots and Pencils Inc. All rights reserved.
//

#import "RBKSocketOperation.h"
#import "RoboSocket.h"
#import "RBKSTOMPSocket.h"
#import "RBKWebSocket.h"


@interface RBKWebSocket () <RBKSocketControlDelegate, RBKSocketFrameDelegate>
@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) RoboSocket *socket;
@property (strong, nonatomic) NSMutableArray *pendingOperations;
@end

@implementation RBKWebSocket {

}
- (instancetype)initWithSocketURL:(NSURL *)socketURL {
    self = [super init];
    if (self) {
        _socket = [[RoboSocket alloc] initWithSocketURL:socketURL];
        _socket.controlDelegate = self;
        _socket.defaultFrameDelegate = self;
        _socket.responseFrameDelegate = self;
        
        _operationQueue = [[NSOperationQueue alloc] init];
        _pendingOperations = [NSMutableArray array];
        _socketOpen = NO;
        _requestSerializer = [RBKSocketStringRequestSerializer serializer];
        _responseSerializer = [RBKSocketStringResponseSerializer serializer];
        [self openSocket];
    }
    return self;
}

- (void)setRequestSerializer:(RBKSocketRequestSerializer <RBKSocketRequestSerialization> *)requestSerializer {
    NSParameterAssert(requestSerializer);

    _requestSerializer = requestSerializer;
}

- (void)setResponseSerializer:(RBKSocketResponseSerializer <RBKSocketResponseSerialization> *)responseSerializer {
    NSParameterAssert(responseSerializer);

    _responseSerializer = responseSerializer;
}

- (RBKSocketOperation *)socketOperationWithFrame:(id)frame
                                         success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                         failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {

    BOOL expectResponse = NO;
    if (success || failure) {
        expectResponse = YES;
    }

    RBKSocketOperation *operation = [self.requestSerializer requestOperationWithFrame:frame expectResponse:expectResponse];

    operation.responseSerializer = self.responseSerializer;
    // operation.shouldUseCredentialStorage = self.shouldUseCredentialStorage;
    // operation.credential = self.credential;
    // operation.securityPolicy = self.securityPolicy;

    // give the operation the socket to use?
    operation.socket = self.socket;
    if (expectResponse) {
        [operation setCompletionBlockWithSuccess:success failure:failure];
    }

    return operation;
}

- (RBKSocketOperation *)sendSocketOperationWithFrame:(id)frame
                                             success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                             failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {
    RBKSocketOperation *operation = [self socketOperationWithFrame:frame success:success failure:failure];

    if (!operation) {
        NSLog(@"Failed to create a socket operation");
        NSError *error = [NSError errorWithDomain:RBKSocketNetworkingErrorDomain code:-1 userInfo:nil];
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

- (RBKSocketOperation *)sendSocketOperationWithFrame:(id)frame {
    return [self sendSocketOperationWithFrame:frame success:nil failure:nil];
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

#pragma mark - RBKSocketFrameDelegate

- (void)webSocket:(RoboSocket *)webSocket didReceiveFrame:(id)message {

    NSError *error = nil;
    [self.responseSerializer responseObjectForResponseFrame:message error:&error];
    if (error) {
        NSLog(@"Serializer error: %@", [error localizedDescription]);
    }
}
- (void)webSocket:(RoboSocket *)webSocket didFailWithError:(NSError *)error {
    if (self.failureBlock) {
        self.failureBlock(error);
    }
}
@end