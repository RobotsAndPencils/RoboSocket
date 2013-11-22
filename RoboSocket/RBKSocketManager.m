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

@interface RBKSocketManager () <RBKSocketControlDelegate, RBKSocketFrameDelegate>

@property (strong, nonatomic) NSOperationQueue *operationQueue;
@property (strong, nonatomic) RoboSocket *socket;
@property (strong, nonatomic) NSMutableArray *pendingOperations;
@property (assign, nonatomic, getter = socketIsOpen) BOOL socketOpen;

@property (strong, nonatomic) NSMutableDictionary *subscriptionHandlers;
@property (strong, nonatomic) NSMutableDictionary *subscriptionAcknowledgementModes;

@property (assign, nonatomic) NSUInteger heartbeatReceivedCounter;
@property (strong, nonatomic) NSDate *previousReceivedHeartbeatDate;
@property (strong, nonatomic) NSDate *mostRecentlyReceivedHeartbeatDate;

@property (assign, nonatomic) NSUInteger heartbeatSentCounter;
@property (assign, nonatomic) NSTimeInterval heartbeatInterval;
@property (strong, nonatomic) dispatch_source_t heartbeatTimer;

@end


@implementation RBKSocketManager

- (instancetype)initWithSocketURL:(NSURL *)socketURL {
    self = [super init];
    if (self) {
        _socket = [[RoboSocket alloc] initWithSocketURL:socketURL];
        _socket.controlDelegate = self;
        _socket.defaultFrameDelegate = self;
        _operationQueue = [[NSOperationQueue alloc] init];
        _pendingOperations = [NSMutableArray array];
        _socketOpen = NO;
        _requestSerializer = [RBKSocketStringRequestSerializer serializer];
        _responseSerializer = [RBKSocketStringResponseSerializer serializer];
        _subscriptionHandlers = [NSMutableDictionary dictionary];
        _subscriptionAcknowledgementModes = [NSMutableDictionary dictionary];
        _heartbeatReceivedCounter = 0;
        _previousReceivedHeartbeatDate = [NSDate distantPast];
        _mostRecentlyReceivedHeartbeatDate = [NSDate distantPast];
        _heartbeatSentCounter = 0;
        _heartbeatInterval = 0;
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
    RBKSocketOperation *operation = [self sendSocketOperationWithFrame:frame success:nil failure:nil];
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

- (NSUInteger)numberOfReceivedHeartbeats {
    return self.heartbeatReceivedCounter;
}

- (NSTimeInterval)timeSinceMostRecentHeartbeat {
    return [[NSDate date] timeIntervalSinceDate:self.mostRecentlyReceivedHeartbeatDate];
}

- (NSTimeInterval)timeIntervalBetweenPreviousHeartbeats {
    return [self.mostRecentlyReceivedHeartbeatDate timeIntervalSinceDate:self.previousReceivedHeartbeatDate];
}

- (NSUInteger)numberOfSentHeartbeats {
    return self.heartbeatSentCounter;
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


#pragma mark - RBKSocketStompRequestSerializerDelegate

- (void)subscribedToDestination:(NSString *)destination subscriptionID:(NSString *)subscriptionID acknowledgeMode:(NSString *)acknowledgeMode messageHandler:(RBKStompFrameHandler)messageHandler {
    // remember either the subscription ID and the destination as well as the handler
    
    if (messageHandler) {
        if (!self.subscriptionHandlers[destination]) {
            self.subscriptionHandlers[destination] = [NSMutableDictionary dictionary];
        }
        self.subscriptionHandlers[destination][subscriptionID] = messageHandler;
    }
    
    if ([acknowledgeMode isEqualToString:RBKStompAckClient] || [acknowledgeMode isEqualToString:RBKStompAckClientIndividual]) {
        if (!self.subscriptionAcknowledgementModes[destination]) {
            self.subscriptionAcknowledgementModes[destination] = [NSMutableDictionary dictionary];
        }
        self.subscriptionAcknowledgementModes[destination][subscriptionID] = acknowledgeMode;
    }
}

- (void)unsubscribedFromDestination:(NSString *)destination subscriptionID:(NSString *)subscriptionID {
    if (self.subscriptionHandlers[destination][subscriptionID]) {
        [self.subscriptionHandlers[destination] removeObjectForKey:subscriptionID];
    }
    if (self.subscriptionAcknowledgementModes[destination][subscriptionID]) {
        [self.subscriptionAcknowledgementModes[destination] removeObjectForKey:subscriptionID];
    }
}

- (void)heartbeatSent {
    self.heartbeatSentCounter += 1;
    [self rescheduleHeartbeatTimer];
}

#pragma mark - RBKSocketStompResponseSerializerDelegate

- (void)messageForDestination:(NSString *)destination responseFrame:(RBKStompFrame *)responseFrame {
    // use the stored destination, subscriptionID and handler
    // for each subscription, call its frameHandler
    NSDictionary *subscriptions = self.subscriptionHandlers[destination];
    [subscriptions enumerateKeysAndObjectsUsingBlock:^(NSString *subscriptionID, RBKStompFrameHandler frameHandler, BOOL *stop) {
        
        if (frameHandler) {
            frameHandler(responseFrame);
        }
    }];
}

- (BOOL)shouldAcknowledgeMessageForDestination:(NSString *)destination responseFrame:(RBKStompFrame *)responseFrame {
    // check if we need to ack any of these messages
    __block BOOL shouldAcknowldge = NO;
    NSDictionary *subscriptionsToAcknowledge = self.subscriptionAcknowledgementModes[destination];
    [subscriptionsToAcknowledge enumerateKeysAndObjectsUsingBlock:^(NSString *subscriptionID, NSString *acknowledgeMode, BOOL *stop) {
        if ([subscriptionID isEqualToString:[responseFrame headerValueForKey:RBKStompHeaderSubscription]]) {
            shouldAcknowldge = YES;
            *stop = YES;
        }
    }];
    return shouldAcknowldge;
}

- (BOOL)shouldNackMessageForDestination:(NSString *)destination responseFrame:(RBKStompFrame *)responseFrame {
    // check if we need to ack any of these messages
    __block BOOL shouldNack = YES; // guilty until proven innocent
    
    // see if this is any of our subscriptions, if it is, then don't NACK
    NSDictionary *subscriptionsToAcknowledge = self.subscriptionAcknowledgementModes[destination];
    if (!subscriptionsToAcknowledge) {
        // either we're not subscribed or this is an ack mode of auto
        shouldNack = NO;
    }
    [subscriptionsToAcknowledge enumerateKeysAndObjectsUsingBlock:^(NSString *subscriptionID, NSString *acknowledgeMode, BOOL *stop) {
        if ([subscriptionID isEqualToString:[responseFrame headerValueForKey:RBKStompHeaderSubscription]]) {
            shouldNack = NO; // this is a destination we've subscribed to but this message doesn't have our subscriptionID
            *stop = YES;
        }
    }];
    return shouldNack;
}

- (RBKSocketOperation *)sendAckOrNackFrame:(RBKStompFrame *)frame {
    
    RBKSocketOperation *operation = [self sendSocketOperationWithFrame:frame success:^(RBKSocketOperation *operation, id responseObject) {
        NSLog(@"sent frame");
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        NSLog(@"failed to send frame");
    }];
    return operation;
}

- (void)heartbeatReceived {
    // keep track of when the last heartbeat was received.
    self.heartbeatReceivedCounter += 1;
    self.previousReceivedHeartbeatDate = self.mostRecentlyReceivedHeartbeatDate;
    self.mostRecentlyReceivedHeartbeatDate = [NSDate date];
}

/** 
 @param interval The interval within which a heartbeat should be sent, in seconds.
 */
- (void)sendHeartbeatWithInterval:(NSTimeInterval)interval {
    
    // schedule a heartbeat to be sent in the interval, unless we send a message before that interval expires, at which point we should cancel our scheduled interval and reschedule another one
    self.heartbeatInterval = interval;
    [self rescheduleHeartbeatTimer];
}

#pragma mark - Private

- (void)rescheduleHeartbeatTimer {
    
    if (self.heartbeatTimer) {
        dispatch_source_cancel(self.heartbeatTimer);
    }
    if (self.heartbeatInterval <= 0) {
        return;
    }
    
    // Instead of an NSTimer (which needs a runloop) use a dispatch_source
    // use 5% leeway
    uint64_t leeway = self.heartbeatInterval / 5.0 * NSEC_PER_SEC;
    self.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, socket_operation_processing_queue());

    // set the timer to fire once.  Set the start time but set the interval to forever
    dispatch_source_set_timer(self.heartbeatTimer,
                              dispatch_time(DISPATCH_TIME_NOW, self.heartbeatInterval * NSEC_PER_SEC),
                              DISPATCH_TIME_FOREVER,
                              leeway);
    
    __weak typeof(self)weakSelf = self;
    dispatch_source_set_event_handler(self.heartbeatTimer, ^{
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        [strongSelf sendHeartbeat];
        dispatch_source_cancel(strongSelf.heartbeatTimer); // after firing once, don't fire again

    });
    
    // start the timer
    dispatch_resume(self.heartbeatTimer);
}

- (void)sendHeartbeat {
    RBKStompFrame *heartbeatFrame = [RBKStompFrame heartbeatFrame];
    [self sendSocketOperationWithFrame:heartbeatFrame];
}


@end
