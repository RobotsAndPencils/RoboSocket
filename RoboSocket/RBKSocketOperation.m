//
//  RBKSocketOperation.m
//  RoboSocket
//
//  Created by David Anderson on 11/1/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import "RBKSocketOperation.h"

typedef NS_ENUM(NSInteger, RBKSocketOperationState) {
    RBKSocketOperationPausedState      = -1,
    RBKSocketOperationReadyState       = 1,
    RBKSocketOperationExecutingState   = 2,
    RBKSocketOperationFinishedState    = 3,
};


static dispatch_queue_t http_request_operation_processing_queue() {
    static dispatch_queue_t af_http_request_operation_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_http_request_operation_processing_queue = dispatch_queue_create("com.robotsandpencils.networking.websocket.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return af_http_request_operation_processing_queue;
}

static dispatch_group_t http_request_operation_completion_group() {
    static dispatch_group_t af_http_request_operation_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        af_http_request_operation_completion_group = dispatch_group_create();
    });
    
    return af_http_request_operation_completion_group;
}

static NSString * const kRBKSocketNetworkingLockName = @"com.robotsandpencils.networking.operation.lock";

NSString * const RBKSocketNetworkingErrorDomain = @"RBKSocketNetworkingErrorDomain";
NSString * const RBKSocketNetworkingOperationFailingURLRequestErrorKey = @"RBKSocketNetworkingOperationFailingURLRequestErrorKey";
NSString * const RBKSocketNetworkingOperationFailingURLResponseErrorKey = @"RBKSocketNetworkingOperationFailingURLResponseErrorKey";

NSString * const RBKSocketOperationDidStartNotification = @"com.robotsandpencils.networking.operation.start";
NSString * const RBKSocketOperationDidFinishNotification = @"com.robotsandpencils.networking.operation.finish";

static inline NSString * RBKSocketKeyPathFromOperationState(RBKSocketOperationState state) {
    switch (state) {
        case RBKSocketOperationReadyState:
            return @"isReady";
        case RBKSocketOperationExecutingState:
            return @"isExecuting";
        case RBKSocketOperationFinishedState:
            return @"isFinished";
        case RBKSocketOperationPausedState:
            return @"isPaused";
        default:
            return @"state";
    }
}

static inline BOOL RBKSocketStateTransitionIsValid(RBKSocketOperationState fromState, RBKSocketOperationState toState, BOOL isCancelled) {
    switch (fromState) {
        case RBKSocketOperationReadyState:
            switch (toState) {
                case RBKSocketOperationPausedState:
                case RBKSocketOperationExecutingState:
                    return YES;
                case RBKSocketOperationFinishedState:
                    return isCancelled;
                default:
                    return NO;
            }
        case RBKSocketOperationExecutingState:
            switch (toState) {
                case RBKSocketOperationPausedState:
                case RBKSocketOperationFinishedState:
                    return YES;
                default:
                    return NO;
            }
        case RBKSocketOperationFinishedState:
            return NO;
        case RBKSocketOperationPausedState:
            return toState == RBKSocketOperationReadyState;
        default:
            return YES;
    }
}



@interface RBKSocketOperation () <RBKSocketMessageDelegate>

@property (readwrite, nonatomic, assign) RBKSocketOperationState state;
@property (readwrite, nonatomic, assign, getter = isCancelled) BOOL cancelled;
@property (readwrite, nonatomic, strong) id requestMessage;
@property (readwrite, nonatomic, strong) id response; // need to deprecate this?
@property (readwrite, nonatomic, strong) id responseObject;

@property (readwrite, nonatomic, strong) NSError *error;
@property (readwrite, nonatomic, strong) NSData *responseData; // deprecate?
@property (readwrite, nonatomic, copy) id responseMessage;
@property (readwrite, nonatomic, copy) NSString *responseString; // deprecate?

@property (readwrite, nonatomic, strong) NSError *responseSerializationError;
@property (readwrite, nonatomic, strong) NSRecursiveLock *lock;

@end


@implementation RBKSocketOperation

+ (void)networkRequestThreadEntryPoint:(id)__unused object {
    @autoreleasepool {
        [[NSThread currentThread] setName:@"RBKSocket"];
        
        NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
        [runLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        [runLoop run];
    }
}

+ (NSThread *)networkRequestThread {
    static NSThread *_networkRequestThread = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _networkRequestThread = [[NSThread alloc] initWithTarget:self selector:@selector(networkRequestThreadEntryPoint:) object:nil];
        [_networkRequestThread start];
    });
    
    return _networkRequestThread;
}

- (instancetype)initWithRequestMessage:(id)message {
    NSParameterAssert(message);
    
    self = [super init];
    if (!self) {
		return nil;
    }
    
    self.lock = [[NSRecursiveLock alloc] init];
    self.lock.name = kRBKSocketNetworkingLockName;
    
    self.runLoopModes = [NSSet setWithObject:NSRunLoopCommonModes];
    
    self.requestMessage = message;
    
    // self.shouldUseCredentialStorage = YES;
    
    self.state = RBKSocketOperationReadyState;
    
    // self.securityPolicy = [AFSecurityPolicy defaultPolicy];
    
    return self;
}

- (id)responseObject {
    [self.lock lock];
    if (!_responseObject && [self isFinished] && !self.error) {
        NSError *error = nil;
        self.responseObject = [self.responseSerializer responseObjectForResponseMessage:self.responseMessage error:&error];
        if (error) {
            self.responseSerializationError = error;
        }
    }
    [self.lock unlock];
    
    return _responseObject;
}

- (void)setState:(RBKSocketOperationState)state {
    if (!RBKSocketStateTransitionIsValid(self.state, state, [self isCancelled])) {
        return;
    }
    
    [self.lock lock];
    NSString *oldStateKey = RBKSocketKeyPathFromOperationState(self.state);
    NSString *newStateKey = RBKSocketKeyPathFromOperationState(state);
    
    [self willChangeValueForKey:newStateKey];
    [self willChangeValueForKey:oldStateKey];
    _state = state;
    [self didChangeValueForKey:oldStateKey];
    [self didChangeValueForKey:newStateKey];
    [self.lock unlock];
}


#pragma mark - RBKSocketOperation

- (void)setCompletionBlockWithSuccess:(void (^)(RBKSocketOperation *operation, id responseObject))success
                              failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure
{
    // completionBlock is manually nilled out in AFURLConnectionOperation to break the retain cycle.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
#pragma clang diagnostic ignored "-Wgnu"
    self.completionBlock = ^{
        if (self.completionGroup) {
            dispatch_group_enter(self.completionGroup);
        }
        
        dispatch_async(http_request_operation_processing_queue(), ^{
            if (self.error) {
                if (failure) {
                    dispatch_group_async(self.completionGroup ?: http_request_operation_completion_group(), self.completionQueue ?: dispatch_get_main_queue(), ^{
                        failure(self, self.error);
                    });
                }
            } else {
                id responseObject = self.responseObject;
                if (self.error) {
                    if (failure) {
                        dispatch_group_async(self.completionGroup ?: http_request_operation_completion_group(), self.completionQueue ?: dispatch_get_main_queue(), ^{
                            failure(self, self.error);
                        });
                    }
                } else {
                    if (success) {
                        dispatch_group_async(self.completionGroup ?: http_request_operation_completion_group(), self.completionQueue ?: dispatch_get_main_queue(), ^{
                            success(self, responseObject);
                        });
                    }
                }
            }
            
            if (self.completionGroup) {
                dispatch_group_leave(self.completionGroup);
            }
        });
    };
#pragma clang diagnostic pop
}


#pragma mark - NSOperation

- (BOOL)isReady {
    return self.state == RBKSocketOperationReadyState && [super isReady];
}

- (BOOL)isExecuting {
    return self.state == RBKSocketOperationExecutingState;
}

- (BOOL)isFinished {
    return self.state == RBKSocketOperationFinishedState;
}

- (BOOL)isConcurrent {
    return YES;
}

- (void)start {
    [self.lock lock];
    if ([self isReady]) {
        self.state = RBKSocketOperationExecutingState;
        
        [self performSelector:@selector(operationDidStart) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    }
    [self.lock unlock];
}

- (void)operationDidStart {
    [self.lock lock];
    if (! [self isCancelled]) {
        
        // NSLog(@"start socket operation");
        
        self.socket.messageDelegate = self;
        [self.socket sendMessage:self.requestMessage];
        
    }
    [self.lock unlock];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:RBKSocketOperationDidStartNotification object:self];
    });
    
    if ([self isCancelled]) {
        [self finish];
    }
}

- (void)finish {
    self.state = RBKSocketOperationFinishedState;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:RBKSocketOperationDidFinishNotification object:self];
    });
}

- (void)cancel {
    [self.lock lock];
    if (![self isFinished] && ![self isCancelled]) {
        [self willChangeValueForKey:@"isCancelled"];
        _cancelled = YES;
        [super cancel];
        [self didChangeValueForKey:@"isCancelled"];
        
        // Cancel the connection on the thread it runs on to prevent race conditions
        [self performSelector:@selector(cancelConnection) onThread:[[self class] networkRequestThread] withObject:nil waitUntilDone:NO modes:[self.runLoopModes allObjects]];
    }
    [self.lock unlock];
}

- (void)cancelConnection {
    NSDictionary *userInfo = nil;
    
    // instead of a request, we have a message
    
    if (0 /*[self.request URL]*/) {
        userInfo = [NSDictionary dictionaryWithObject:@"our-socket?" /*[self.request URL]*/ forKey:NSURLErrorFailingURLErrorKey];
    }
    // NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:userInfo];
    
    if (![self isFinished] /*&& self.connection*/) {
        // [self.connection cancel];
        // [self performSelector:@selector(connection:didFailWithError:) withObject:self.connection withObject:error];
    }
}

#pragma mark - RBKSocketMessageDelegate

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(RoboSocket *)webSocket didReceiveMessage:(id)message {
    NSLog(@"received Message");
    self.responseMessage = message;
    
    [self finish];
    
    self.socket.messageDelegate = nil;
    self.socket = nil;

}

- (void)webSocket:(RoboSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"failed");
    
    self.error = error;
    
    [self finish];
    
    self.socket.messageDelegate = nil;
    self.socket = nil;
}

@end
