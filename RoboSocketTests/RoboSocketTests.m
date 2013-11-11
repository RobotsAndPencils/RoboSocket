//
//  RoboSocketTests.m
//  RoboSocketTests
//
//  Created by David Anderson on 10/16/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#define EXP_SHORTHAND YES
#import <Expecta/Expecta.h>

#import "RBKSocketManager.h"
#import <SocketRocket/SRServerSocket.h>
#import <SocketRocket/SRWebSocket.h>

// NSString * const hostURL = @"ws://echo.websocket.org";
NSString * const hostURL = @"ws://localhost";

@interface RoboSocketTests : XCTestCase <SRWebSocketDelegate>

@property (strong, nonatomic) RBKSocketManager *socketManager;
@property (strong, nonatomic) SRServerSocket *stubSocket;

@property (assign, nonatomic, getter = isFinished) BOOL finished;

@end

@implementation RoboSocketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:300.0];

    self.finished = NO;
    self.stubSocket = [[SRServerSocket alloc] initWithURL:[NSURL URLWithString:hostURL]];
    self.stubSocket.delegate = self;

    NSUInteger port = [self.stubSocket serverSocketPort];
    // get the port that we're listening on and provide it to the client socket
    NSString *hostWithPort = [NSString stringWithFormat:@"%@:%d", hostURL, port];
    NSLog(@"Server-style websocket listing on port %@", hostWithPort);
    
    self.socketManager = [[RBKSocketManager alloc] initWithSocketURL:[NSURL URLWithString:hostWithPort]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSocketEcho {
    
    __block BOOL success = NO;
    NSString *sentMessage = @"Hello, World!";
    __block NSString *responseMessage = nil;
    [self.socketManager sendSocketOperationWithMessage:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).will.equal(sentMessage);
}

#pragma mark - Private

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message; {
    NSLog(@"Received message %@", message);
    // now echo it back?
    
    [webSocket send:message];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket; {
    NSLog(@"Opened stub socket");
    self.finished = YES;
}


- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"failed");
    
    self.finished = YES;
}


@end
