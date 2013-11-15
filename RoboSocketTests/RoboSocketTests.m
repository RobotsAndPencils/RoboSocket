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
#import "RBKSocketRequestSerialization.h"
#import "RBKSocketResponseSerialization.h"
#import "RBKSTOMPMessage.h"

#import <SocketRocket/SRServerSocket.h>
#import <SocketRocket/SRWebSocket.h>

typedef NS_ENUM(NSUInteger, RBKTestScenario) {
    RBKTestScenarioNone = 0,
    RBKTestScenarioSTOMPConnect,
    RBKTestScenarioSTOMPSubscribe,
};


// NSString * const hostURL = @"ws://echo.websocket.org";
NSString * const hostURL = @"ws://localhost";

@interface RoboSocketTests : XCTestCase <SRWebSocketDelegate>

@property (strong, nonatomic) RBKSocketManager *socketManager;
@property (strong, nonatomic) SRServerSocket *stubSocket;

@property (assign, nonatomic, getter = isFinished) BOOL socketOpen;
@property (assign, nonatomic) RBKTestScenario currentScenario;

@end

@implementation RoboSocketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:5.0];

    self.currentScenario = RBKTestScenarioNone;
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

- (void)testSocketEchoDataToString {
    
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

- (void)testSocketEchoData {
    
    self.socketManager.requestSerializer = [RBKSocketDataRequestSerializer serializer];
    self.socketManager.responseSerializer = [RBKSocketDataResponseSerializer serializer];
    
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
    expect(responseMessage).will.equal(sentMessage); // using data serializers, we can feed it data, and we get a data response
    expect(responseMessage).willNot.equal(stringMessage);
}

- (void)testSocketEchoStringToData {
    
    self.socketManager.requestSerializer = [RBKSocketDataRequestSerializer serializer];
    self.socketManager.responseSerializer = [RBKSocketDataResponseSerializer serializer];
    
    __block BOOL success = NO;
    NSString *sentMessage = @"Hello, World!";
    NSData *dataMessage = [sentMessage dataUsingEncoding:NSUTF8StringEncoding];
    __block NSData *responseMessage = nil;
    [self.socketManager sendSocketOperationWithMessage:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
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
    
    self.socketManager.requestSerializer = [RBKSocketJSONRequestSerializer serializer];
    self.socketManager.responseSerializer = [RBKSocketJSONResponseSerializer serializer];
    
    __block BOOL success = NO;
    NSDictionary *sentMessage = @{@"key": @"value"};
    __block NSDictionary *responseMessage = nil;
    [self.socketManager sendSocketOperationWithMessage:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject;
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(responseMessage).will.equal(sentMessage); // using JSON serializers, we can feed it JSON, and we get a JSON response
}

// JSON:
// data to JSON
// string to JSON
// JSON to string?
// JSON to data?

- (void)testSocketEchoSTOMPConnect {
    
    self.currentScenario = RBKTestScenarioSTOMPConnect;

    self.socketManager.requestSerializer = [RBKSocketSTOMPRequestSerializer serializer];
    self.socketManager.responseSerializer = [RBKSocketSTOMPResponseSerializer serializer];
    
    RBKSTOMPMessage *connectMessage = [RBKSTOMPMessage connectMessageWithLogin:@"username" passcode:@"passcode" host:[[NSURL URLWithString:hostURL] host]];
    
    __block BOOL success = NO;
    __block RBKSTOMPMessage *responseMessage = nil;
    [self.socketManager sendSocketOperationWithMessage:connectMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKSTOMPMessage
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([responseMessage frameData]).willNot.equal([connectMessage frameData]); // connect message should get connection response
    expect(responseMessage.command).will.equal(RBKSTOMPCommandConnected);
    expect([responseMessage headerValueForKey:RBKStompHeaderVersion]).will.equal(RBKSTOMPVersion1_2);
}

// Connection:
// heart beat is not tested
// negotiation error is not tested

- (void)testSocketEchoSTOMPSubscribe {
    
    self.currentScenario = RBKTestScenarioSTOMPSubscribe;

    self.socketManager.requestSerializer = [RBKSocketSTOMPRequestSerializer serializer];
    self.socketManager.responseSerializer = [RBKSocketSTOMPResponseSerializer serializer];
    
    RBKSTOMPMessage *subscriptionMessage = [RBKSTOMPMessage subscribeMessageWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"}];
    
    __block BOOL success = NO;
    __block RBKSTOMPMessage *responseMessage = nil;
    [self.socketManager sendSocketOperationWithMessage:subscriptionMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        
        // subscriptions arent' echoed per the standard. Send a message that matches the subscription
        
        responseMessage = responseObject; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKSTOMPMessage
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([responseMessage headerValueForKey:RBKStompHeaderDestination]).will.equal([subscriptionMessage headerValueForKey:RBKStompHeaderDestination]);
    expect([responseMessage headerValueForKey:RBKStompHeaderSubscription]).will.equal([subscriptionMessage headerValueForKey:RBKStompHeaderID]);
    expect([responseMessage bodyValue]).will.equal(@"Message for you sir");
    expect([responseMessage frameData]).willNot.equal([subscriptionMessage frameData]); // subscribe message should get no immediate response, but for now give it a message response
}

// Subscription:
// subscription error is not tested


#pragma mark - Private

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message; {
    NSLog(@"Received message %@", message);
    // specific responses
    switch (self.currentScenario) {
        case RBKTestScenarioSTOMPConnect:
            [webSocket send:[[self connectedMessageForConnectMessageData:message] frameData]];
            return;

        case RBKTestScenarioSTOMPSubscribe:
            [webSocket send:[[self messageMessage:@"Message for you sir" forSubscribeMessageData:message] frameData]];
            return;

        default:
            break;
    }
    // or echo it back
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

#pragma mark - STOMP Response Messages

- (RBKSTOMPMessage *)connectedMessageForConnectMessageData:(NSData *)receivedMessageData {
    RBKSTOMPMessage *receivedMessage = [RBKSTOMPMessage responseMessageFromData:receivedMessageData];

    NSString *acceptedVersion = [receivedMessage headerValueForKey:RBKStompHeaderAcceptVersion];
    
    RBKSTOMPMessage *connectedMessage = [RBKSTOMPMessage connectedMessageWithVersion:acceptedVersion];
    return connectedMessage;
}

- (RBKSTOMPMessage *)messageMessage:(NSString *)messageBody forSubscribeMessageData:(NSData *)receivedMessageData { // change our internal "message" to "frame"
    RBKSTOMPMessage *receivedMessage = [RBKSTOMPMessage responseMessageFromData:receivedMessageData];
    
    NSString *destination = [receivedMessage headerValueForKey:RBKStompHeaderDestination];
    NSString *subscriptionID = [receivedMessage headerValueForKey:RBKStompHeaderID];
    
    RBKSTOMPMessage *messageMessage = [RBKSTOMPMessage messageMessageWithDestination:destination headers:nil body:messageBody subscription:subscriptionID];
    return messageMessage;
}


@end
