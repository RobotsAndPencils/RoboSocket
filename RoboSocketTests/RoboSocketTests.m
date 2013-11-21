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
#import "RBKStompFrame.h"

#import <SocketRocket/SRServerSocket.h>
#import <SocketRocket/SRWebSocket.h>

typedef NS_ENUM(NSUInteger, RBKTestScenario) {
    RBKTestScenarioNone = 0,
    RBKTestScenarioStompConnect,
    RBKTestScenarioStompSubscribe,
    RBKTestScenarioStompSubscribeClientAck,
    RBKTestScenarioStompSubscribeClientNack,
    RBKTestScenarioStompAck,
    RBKTestScenarioStompNack,
    RBKTestScenarioStompSend,
    RBKTestScenarioStompUnsubscribe,
};


// NSString * const hostURL = @"ws://echo.websocket.org";
NSString * const hostURL = @"ws://localhost";

@interface RoboSocketTests : XCTestCase <SRWebSocketDelegate>

@property (strong, nonatomic) RBKSocketManager *socketManager;
@property (strong, nonatomic) SRServerSocket *stubSocket;

@property (assign, nonatomic, getter = isFinished) BOOL socketOpen;
@property (assign, nonatomic) RBKTestScenario currentScenario;
@property (assign, nonatomic, getter = isCurrentScenarioSuccessful) BOOL currentScenarioSuccessful;

@end

@implementation RoboSocketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:500.0];

    self.currentScenario = RBKTestScenarioNone;
    self.currentScenarioSuccessful = NO;
    self.socketOpen = NO;
    self.stubSocket = [[SRServerSocket alloc] initWithURL:[NSURL URLWithString:hostURL]];
    self.stubSocket.delegate = self;

    NSUInteger port = [self.stubSocket serverSocketPort];
    // get the port that we're listening on and provide it to the client socket
    NSString *hostWithPort = [NSString stringWithFormat:@"%@:%d", hostURL, port];
    // NSLog(@"Server-style websocket listing on port %@", hostWithPort);
    
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
    [self.socketManager sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
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
    [self.socketManager sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
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
    [self.socketManager sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
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
    [self.socketManager sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
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
    [self.socketManager sendSocketOperationWithFrame:sentMessage success:^(RBKSocketOperation *operation, id responseObject) {
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
    
    self.currentScenario = RBKTestScenarioStompConnect;

    self.socketManager.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    self.socketManager.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    
    RBKStompFrame *connectMessage = [RBKStompFrame connectFrameWithLogin:@"username" passcode:@"passcode" host:[[NSURL URLWithString:hostURL] host]];
    
    __block BOOL success = NO;
    __block RBKStompFrame *responseMessage = nil;
    [self.socketManager sendSocketOperationWithFrame:connectMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([responseMessage frameData]).willNot.equal([connectMessage frameData]); // connect message should get connection response
    expect(responseMessage.command).will.equal(RBKStompCommandConnected);
    expect([responseMessage headerValueForKey:RBKStompHeaderVersion]).will.equal(RBKStompVersion1_2);
}

// Connection:
// heart beat is not tested
// negotiation error is not tested

- (void)testSocketSTOMPSubscribe {
    
    self.currentScenario = RBKTestScenarioStompSubscribe;

    self.socketManager.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.socketManager.requestSerializer;
    requestSerializer.delegate = self.socketManager;
    self.socketManager.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.socketManager.responseSerializer;
    responseSerializer.delegate = self.socketManager;
    
    __block BOOL subscriptionHandlerCalled = NO;
    __block RBKStompFrame *subscriptionResponseFrame = nil;

    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalled = YES;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
        // NSLog(@"--- %@", [responseFrame frameString]);
    }];
    
    __block BOOL success = NO;
    [self.socketManager sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(subscriptionHandlerCalled).will.beTruthy();
    expect([subscriptionResponseFrame headerValueForKey:RBKStompHeaderDestination]).will.equal([subscriptionFrame headerValueForKey:RBKStompHeaderDestination]);
    expect([subscriptionResponseFrame headerValueForKey:RBKStompHeaderSubscription]).will.equal([subscriptionFrame headerValueForKey:RBKStompHeaderID]);
    expect([subscriptionResponseFrame bodyValue]).will.equal(@"Message for you sir");
    expect([subscriptionResponseFrame frameData]).willNot.equal([subscriptionFrame frameData]); // subscribe message should get no immediate response, but for now give it a message response
}

- (void)testSocketSTOMPSubscribeClientAck {
    
    self.currentScenario = RBKTestScenarioStompSubscribeClientAck;
    
    self.socketManager.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.socketManager.requestSerializer;
    requestSerializer.delegate = self.socketManager;
    self.socketManager.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.socketManager.responseSerializer;
    responseSerializer.delegate = self.socketManager;
    
    __block BOOL subscriptionHandlerCalled = NO;
    __block RBKStompFrame *subscriptionResponseFrame = nil;
    
    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345", @"ack": @"client"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalled = YES;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
        // NSLog(@"--- %@", [responseFrame frameString]);
    }];
    
    __block BOOL success = NO;
    [self.socketManager sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(self.isCurrentScenarioSuccessful).will.beTruthy(); // indicates that the ack was successful
}

- (void)testSocketSTOMPSubscribeClientNack {
    
    self.currentScenario = RBKTestScenarioStompSubscribeClientNack;
    
    self.socketManager.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.socketManager.requestSerializer;
    requestSerializer.delegate = self.socketManager;
    self.socketManager.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.socketManager.responseSerializer;
    responseSerializer.delegate = self.socketManager;
    
    __block BOOL subscriptionHandlerCalled = NO;
    __block RBKStompFrame *subscriptionResponseFrame = nil;
    
    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345", @"ack": @"client"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalled = YES;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
        // NSLog(@"--- %@", [responseFrame frameString]);
    }];
    
    __block BOOL success = NO;
    [self.socketManager sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(self.isCurrentScenarioSuccessful).will.beTruthy(); // indicates that the ack was successful
}



// Subscription:
// subscription error is not tested


- (void)testSocketSTOMPSend {
    
    self.currentScenario = RBKTestScenarioStompSend;
    
    self.socketManager.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.socketManager.requestSerializer;
    requestSerializer.delegate = self.socketManager;
    self.socketManager.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.socketManager.responseSerializer;
    responseSerializer.delegate = self.socketManager;
    
    NSString *sendBody = @"Message for you sir";
    
    RBKStompFrame *sendFrame = [RBKStompFrame sendFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"} body:sendBody];
    __block BOOL success = NO;
    __block RBKStompFrame *responseFrame = nil;
    [self.socketManager sendSocketOperationWithFrame:sendFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseFrame = responseObject; // probably isn't echo'd per the standard, but this at least validates that send messages are being sent
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([responseFrame headerValueForKey:RBKStompHeaderDestination]).will.equal([sendFrame headerValueForKey:RBKStompHeaderDestination]);
    expect([responseFrame headerValueForKey:RBKStompHeaderSubscription]).will.equal(@"sub-0");
    expect([responseFrame bodyValue]).will.equal(sendBody);
    expect([responseFrame frameData]).willNot.equal([sendFrame frameData]); // subscribe message should get no immediate response, but for now give it a message response
}

- (void)testSocketSTOMPUnsubscribe {
    
    self.currentScenario = RBKTestScenarioStompSubscribe;
    
    self.socketManager.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.socketManager.requestSerializer;
    requestSerializer.delegate = self.socketManager;
    self.socketManager.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.socketManager.responseSerializer;
    responseSerializer.delegate = self.socketManager;
    
    __block NSUInteger subscriptionHandlerCalledCounter = 0;
    __block RBKStompFrame *subscriptionResponseFrame = nil;
    
    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalledCounter += 1;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
    }];
    
    RBKStompFrame *unsubscribeFrame = [RBKStompFrame unsubscribeFrameWithDestination:@"/foo/bar" subscriptionID:subscriptionFrame.subscription.identifier headers:nil];
    
    __block BOOL success = NO;
    __weak typeof(self)weakSelf = self;
    [self.socketManager sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        
        // now that we've subscribed, unsubscribe
        weakSelf.currentScenario = RBKTestScenarioStompUnsubscribe;
        
        [weakSelf.socketManager sendSocketOperationWithFrame:unsubscribeFrame success:^(RBKSocketOperation *operation, id responseObject) {
            success = YES;
        } failure:^(RBKSocketOperation *operation, NSError *error) {
            success = NO;
        }];

        
    } failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    
    expect(success).will.beTruthy();
    expect(subscriptionHandlerCalledCounter).will.beLessThanOrEqualTo(1); // the subscription message handler should only get called once
    expect([subscriptionResponseFrame headerValueForKey:RBKStompHeaderDestination]).will.equal([subscriptionFrame headerValueForKey:RBKStompHeaderDestination]);
    expect([subscriptionResponseFrame headerValueForKey:RBKStompHeaderSubscription]).will.equal([subscriptionFrame headerValueForKey:RBKStompHeaderID]);
    expect([subscriptionResponseFrame bodyValue]).will.equal(@"Message for you sir");
    expect([subscriptionResponseFrame frameData]).willNot.equal([subscriptionFrame frameData]); // subscribe message should get no immediate response, but for now give it a message response
}


#pragma mark - Private

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message; {
    // specific responses
    switch (self.currentScenario) {
        case RBKTestScenarioStompConnect:
            [webSocket send:[[self connectedFrameForConnectFrameData:message] frameData]];
            return;

        case RBKTestScenarioStompSubscribe:
            [webSocket send:[[self messageFrame:@"Message for you sir" forSubscribeFrameData:message] frameData]];
            return;
            
        case RBKTestScenarioStompSubscribeClientAck:
            [webSocket send:[[self messageFrame:@"Message for you sir" forSubscribeFrameData:message] frameData]];
            self.currentScenario = RBKTestScenarioStompAck; // switch this so we don't try to echo the ack
            return;
            
        case RBKTestScenarioStompSubscribeClientNack:
            [webSocket send:[[self incorrectMessageFrame:@"Message for you sir" forSubscribeFrameData:message] frameData]];
            self.currentScenario = RBKTestScenarioStompNack; // switch this so we don't try to echo the nack
            return;
            
        case RBKTestScenarioStompAck:
            NSLog(@"received ack");
            self.currentScenarioSuccessful = YES;
            return;
            
        case RBKTestScenarioStompNack:
            NSLog(@"received nack");
            self.currentScenarioSuccessful = YES;
            return;

            
        case RBKTestScenarioStompSend:
            [webSocket send:[[self messageFrame:@"Message for you sir" forSendFrameData:message] frameData]];
            return;
            
        case RBKTestScenarioStompUnsubscribe:
            [webSocket send:[[self messageFrame:@"Message for you sir" forSendFrameData:message] frameData]];
            return;

        default:
            break;
    }
    // or echo it back
    [webSocket send:message];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket; {
    self.socketOpen = YES;
}


- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    self.socketOpen = NO;
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    self.socketOpen = NO;
}

#pragma mark - STOMP Response Messages

- (RBKStompFrame *)connectedFrameForConnectFrameData:(NSData *)receivedMessageData {
    RBKStompFrame *receivedFrame = [RBKStompFrame responseFrameFromData:receivedMessageData];

    NSString *acceptedVersion = [receivedFrame headerValueForKey:RBKStompHeaderAcceptVersion];
    
    RBKStompFrame *connectedFrame = [RBKStompFrame connectedFrameWithVersion:acceptedVersion];
    return connectedFrame;
}

- (RBKStompFrame *)messageFrame:(NSString *)messageBody forSubscribeFrameData:(NSData *)receivedMessageData {
    RBKStompFrame *receivedFrame = [RBKStompFrame responseFrameFromData:receivedMessageData];
    
    NSString *destination = [receivedFrame headerValueForKey:RBKStompHeaderDestination];
    NSString *subscriptionID = [receivedFrame headerValueForKey:RBKStompHeaderID];
    NSDictionary *headers = nil;
    // if the subscription includes an ack value of client or client-... then our message frame needs to have an ack value
    NSString *acknowledgeMode = [receivedFrame headerValueForKey:RBKStompHeaderAck];
    if ([acknowledgeMode isEqualToString:RBKStompAckClient] || [acknowledgeMode isEqualToString:RBKStompAckClientIndividual]) {
        // Need to include an arbitrary value for an ack header
        headers = @{RBKStompHeaderAck: [[NSUUID UUID] UUIDString]};
    }
    
    RBKStompFrame *messageFrame = [RBKStompFrame messageFrameWithDestination:destination headers:headers body:messageBody subscription:subscriptionID];
    return messageFrame;
}

// used for Nack testing so that the server sends the client something it doesn't expect and the client does a Nack
- (RBKStompFrame *)incorrectMessageFrame:(NSString *)messageBody forSubscribeFrameData:(NSData *)receivedMessageData {
    RBKStompFrame *receivedFrame = [RBKStompFrame responseFrameFromData:receivedMessageData];
    
    NSString *destination = [receivedFrame headerValueForKey:RBKStompHeaderDestination];
    NSString *subscriptionID = [[NSUUID UUID] UUIDString]; // incorrect subscription id
    NSDictionary *headers = nil;
    // if the subscription includes an ack value of client or client-... then our message frame needs to have an ack value
    NSString *acknowledgeMode = [receivedFrame headerValueForKey:RBKStompHeaderAck];
    if ([acknowledgeMode isEqualToString:RBKStompAckClient] || [acknowledgeMode isEqualToString:RBKStompAckClientIndividual]) {
        // Need to include an arbitrary value for an ack header
        headers = @{RBKStompHeaderAck: [[NSUUID UUID] UUIDString]};
    }
    
    RBKStompFrame *messageFrame = [RBKStompFrame messageFrameWithDestination:destination headers:headers body:messageBody subscription:subscriptionID];
    return messageFrame;
}

- (RBKStompFrame *)messageFrame:(NSString *)messageBody forSendFrameData:(NSData *)receivedMessageData {
    RBKStompFrame *receivedFrame = [RBKStompFrame responseFrameFromData:receivedMessageData];
    
    NSString *destination = [receivedFrame headerValueForKey:RBKStompHeaderDestination];
    NSString *subscriptionID = @"sub-0"; // because we're just testing receiving a SEND frame and returning a MESSAGE frame (without actually subscribing, use a fake subscription
    
    // should this message have some of the same custom headers?
    
    RBKStompFrame *messageFrame = [RBKStompFrame messageFrameWithDestination:destination headers:nil body:messageBody subscription:subscriptionID];
    return messageFrame;
}



@end
