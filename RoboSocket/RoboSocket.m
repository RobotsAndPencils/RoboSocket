//
//  RoboSocket.m
//  RoboSocket
//
//  Created by David Anderson on 10/16/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import "RoboSocket.h"

#import <SocketRocket/SRWebSocket.h>

@interface RoboSocket () <SRWebSocketDelegate>

@property (strong, nonatomic) SRWebSocket *socket;

@end


@implementation RoboSocket

- (instancetype)init {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:[NSString stringWithFormat:@"%@ Failed to call designated initializer. Invoke `initWithSocketURL:` instead.", NSStringFromClass([self class])] userInfo:nil];
}

- (instancetype)initWithSocketURL:(NSURL *)socketURL {
    self = [super init];
    if (self) {
        _socket = [[SRWebSocket alloc] initWithURL:socketURL];
        _socket.delegate = self;
    }
    return self;
}

- (void)openSocket {
    [self.socket open];
}

- (void)closeSocket {
    [self.socket close];
}

- (void)sendFrame:(id)frame {
    [self.socket send:frame];
}

#pragma mark - SRWebSocketDelegate

// RoboSocket needs two delegates - one for messages and one for control
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)frame {
    // NSLog(@"received frame %@", frame);
    [self.frameDelegate webSocket:self didReceiveFrame:frame];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    // NSLog(@"socket opened");
    [self.controlDelegate webSocketDidOpen:self];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    // NSLog(@"socket failed");
    [self.frameDelegate webSocket:self didFailWithError:error];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    // NSLog(@"socket closed");
    [self.controlDelegate webSocket:self didCloseWithCode:code reason:reason wasClean:wasClean];

}


@end
