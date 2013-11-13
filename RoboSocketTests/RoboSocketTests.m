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

@property (assign, nonatomic, getter = isFinished) BOOL socketOpen;

@end

@implementation RoboSocketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:300.0];

    self.socketOpen = NO;
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
    
    [self.stubSocket close];
    
    while (self.socketOpen && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]); // don't advance until the socket has closed completely

    [super tearDown];
}

- (void)testSocketEchoString {
    
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

- (void)testSocketEchoData {
    
    __block BOOL success = NO;
    NSString *stringMessage = @"Hello, World!";
    NSData *sentMessage = [stringMessage dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *responseMessage = nil;
    [self.socketManager sendSocketOperationWithMessage:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).willNot.equal(sentMessage); // using string serializers, we can feed it data, it gets converted to string, and we get a string response
    expect(responseMessage).will.equal(stringMessage);
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
    self.socketOpen = YES;
}


- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    NSLog(@"failed");
    
    self.socketOpen = NO;
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    NSLog(@"closed");

    self.socketOpen = NO;

}


@end
