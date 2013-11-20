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

@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) RoboSocket *socket;
@property (strong, nonatomic) NSMutableArray *pendingOperations;
@property (assign, nonatomic, getter = socketIsOpen) BOOL socketOpen;

@property (strong, nonatomic) NSMutableDictionary *subscriptions;

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
        _subscriptions = [NSMutableDictionary dictionary];
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

- (RBKSocketOperation *)socketOperationWithFrame:(id)frame
                                         success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                         failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure {
    
    
    RBKSocketOperation *operation = [self.requestSerializer requestOperationWithFrame:frame];
    
    operation.responseSerializer = self.responseSerializer;
    // operation.shouldUseCredentialStorage = self.shouldUseCredentialStorage;
    // operation.credential = self.credential;
    // operation.securityPolicy = self.securityPolicy;
    
    // give the operation the socket to use?
    operation.socket = self.socket;
    [operation setCompletionBlockWithSuccess:success failure:failure];

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

#pragma mark - RBKSocketStompRequestSerializerDelegate

- (void)subscribedToDestination:(NSString *)destination subscriptionID:(NSString *)subscriptionID messageHandler:(RBKStompFrameHandler)messageHandler {
    // remember either the subscription ID and the destination as well as the handler
    
    if (messageHandler) {
        if (!self.subscriptions[destination]) {
            self.subscriptions[destination] = [NSMutableDictionary dictionary];
        }
        self.subscriptions[destination][subscriptionID] = messageHandler;
    }
}

#pragma mark - RBKSocketStompResponseSerializerDelegate

- (void)messageForDestination:(NSString *)destination responseFrame:(RBKStompFrame *)responseFrame {
    // use the stored destination, subscriptionID and handler
    // for each subscription, call its frameHandler
    NSDictionary *subscriptions = self.subscriptions[destination];
    [subscriptions enumerateKeysAndObjectsUsingBlock:^(NSString *subscriptionID, RBKStompFrameHandler frameHandler, BOOL *stop) {
        
        if (frameHandler) {
            frameHandler(responseFrame);
        }
    }];
}


@end
