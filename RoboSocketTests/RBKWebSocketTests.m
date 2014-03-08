//
//  RBKWebSocketTests.m
//  RBKWebSocketTests
//
//  Created by David Anderson on 10/16/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#define EXP_SHORTHAND YES
#import <Expecta/Expecta.h>

#import "RBKWebSocket.h"
#import <SocketRocket/SRServerSocket.h>
#import <SocketRocket/SRWebSocket.h>

@interface RBKWebSocketTests : XCTestCase <SRWebSocketDelegate>

@property (strong, nonatomic) RBKWebSocket *webSocket;
@property (strong, nonatomic) SRServerSocket *stubSocket;

@end

@implementation RBKWebSocketTests

- (void)setUp {
    [super setUp];

//    NSString * const hostURL = @"ws://echo.websocket.org";
    NSString * const hostURL = @"ws://localhost";

    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:5.0];

    self.stubSocket = [[SRServerSocket alloc] initWithURL:[NSURL URLWithString:hostURL]];
    self.stubSocket.delegate = self;

    NSUInteger port = [self.stubSocket serverSocketPort];
    // get the port that we're listening on and provide it to the client socket
    NSString *hostWithPort = [NSString stringWithFormat:@"%@:%d", hostURL, port];
    // NSLog(@"Server-style websocket listing on port %@", hostWithPort);
    
    self.webSocket = [[RBKWebSocket alloc] initWithSocketURL:[NSURL URLWithString:hostWithPort]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    
    [self.stubSocket close];
    
    while (self.webSocket.socketOpen && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]); // don't advance until the socket has closed completely

    [super tearDown];
}

- (void)testSocketEchoString {
    
    __block BOOL success = NO;
    NSString *sentMessage = @"Hello, World!";
    __block NSString *responseMessage = nil;
    [self.webSocket sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).will.equal(sentMessage);
}

- (void)testSocketEchoDataToString {
    
    __block BOOL success = NO;
    NSString *stringMessage = @"Hello, World!";
    NSData *sentMessage = [stringMessage dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *responseMessage = nil;
    [self.webSocket sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).willNot.equal(sentMessage); // using string serializers, we can feed it data, it gets converted to string, and we get a string response
    expect(responseMessage).will.equal(stringMessage);
}

- (void)testSocketEchoData {
    
    self.webSocket.requestSerializer = [RBKSocketDataRequestSerializer serializer];
    self.webSocket.responseSerializer = [RBKSocketDataResponseSerializer serializer];
    
    __block BOOL success = NO;
    NSString *stringMessage = @"Hello, World!";
    NSData *sentMessage = [stringMessage dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *responseMessage = nil;
    [self.webSocket sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).will.equal(sentMessage); // using data serializers, we can feed it data, and we get a data response
    expect(responseMessage).willNot.equal(stringMessage);
}

- (void)testSocketEchoStringToData {
    
    self.webSocket.requestSerializer = [RBKSocketDataRequestSerializer serializer];
    self.webSocket.responseSerializer = [RBKSocketDataResponseSerializer serializer];
    
    __block BOOL success = NO;
    NSString *sentMessage = @"Hello, World!";
    NSData *dataMessage = [sentMessage dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *responseMessage = nil;
    [self.webSocket sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).will.equal(dataMessage); // using data serializers, we can feed it data, and we get a data response
    expect(responseMessage).willNot.equal(sentMessage);
}


- (void)testSocketEchoJSON {
    
    self.webSocket.requestSerializer = [RBKSocketJSONRequestSerializer serializer];
    self.webSocket.responseSerializer = [RBKSocketJSONResponseSerializer serializer];
    
    __block BOOL success = NO;
    NSDictionary *sentMessage = @{@"key": @"value"};
    __block NSDictionary *responseMessage = nil;
    [self.webSocket sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).will.equal(sentMessage); // using JSON serializers, we can feed it JSON, and we get a JSON response
}

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message; {
    // echo
    [webSocket send:message];
}

@end
