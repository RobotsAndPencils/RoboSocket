//
//  RoboSocket.h
//  RoboSocket
//
//  Created by David Anderson on 10/16/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - SRWebSocketDelegate

@class RoboSocket;

@protocol RBKSocketMessageDelegate <NSObject>

// message will either be an NSString if the server is using text
// or NSData if the server is using binary.
- (void)webSocket:(RoboSocket *)webSocket didReceiveMessage:(id)message;

@optional

- (void)webSocket:(RoboSocket *)webSocket didFailWithError:(NSError *)error;

@end


@protocol RBKSocketControlDelegate <NSObject>

- (void)webSocketDidOpen:(RoboSocket *)webSocket;
- (void)webSocket:(RoboSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean;

@end


@interface RoboSocket : NSObject

@property (weak, nonatomic) id<RBKSocketMessageDelegate> messageDelegate;
@property (weak, nonatomic) id<RBKSocketControlDelegate> controlDelegate;

- (instancetype)initWithSocketURL:(NSURL *)socketURL;
- (void)openSocket;
- (void)closeSocket;
- (void)sendMessage:(NSString *)message;

@end
