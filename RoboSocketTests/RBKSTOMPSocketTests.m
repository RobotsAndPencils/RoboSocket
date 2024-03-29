//
//  RBKSTOMPSocketTests.m
//  RBKSTOMPSocketTests
//
//  Created by David Anderson on 10/16/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#define EXP_SHORTHAND YES
#import <Expecta/Expecta.h>

#import "RBKSTOMPSocket.h"

#import <SocketRocket/SRServerSocket.h>
#import <SocketRocket/SRWebSocket.h>

typedef NS_ENUM(NSUInteger, RBKTestScenario) {
    RBKTestScenarioNone = 0,
    RBKTestScenarioStompConnect,
    RBKTestScenarioStompConnectServerHeartbeat,
    RBKTestScenarioStompConnectClientHeartbeat,
    RBKTestScenarioStompSubscribe,
    RBKTestScenarioStompSubscribeClientAck,
    RBKTestScenarioStompSubscribeClientNack,
    RBKTestScenarioStompAck,
    RBKTestScenarioStompNack,
    RBKTestScenarioStompSend,
    RBKTestScenarioStompUnsubscribe,
    RBKTestScenarioStompServerHeartbeat,
    RBKTestScenarioStompClientHeartbeat,
};

//    NSString * const hostURL = @"ws://echo.websocket.org";
NSString * const hostURL = @"ws://localhost";

@interface RBKSTOMPSocketTests : XCTestCase <SRWebSocketDelegate>

@property (strong, nonatomic) RBKSTOMPSocket *stompSocket;
@property (strong, nonatomic) SRServerSocket *stubSocket;

@property (assign, nonatomic, getter = isFinished) BOOL socketOpen;
@property (assign, nonatomic) RBKTestScenario currentScenario;
@property (assign, nonatomic, getter = isCurrentScenarioSuccessful) BOOL currentScenarioSuccessful;

@end

@implementation RBKSTOMPSocketTests

- (void)setUp {
    [super setUp];

    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:5.0];

    self.currentScenario = RBKTestScenarioNone;
    self.currentScenarioSuccessful = NO;
    self.socketOpen = NO;
    self.stubSocket = [[SRServerSocket alloc] initWithURL:[NSURL URLWithString:hostURL]];
    self.stubSocket.delegate = self;

    NSUInteger port = [self.stubSocket serverSocketPort];
    // get the port that we're listening on and provide it to the client socket
    NSString *hostWithPort = [NSString stringWithFormat:@"%@:%d", hostURL, port];
    // NSLog(@"Server-style websocket listing on port %@", hostWithPort);
    
    self.stompSocket = [[RBKSTOMPSocket alloc] initWithSocketURL:[NSURL URLWithString:hostWithPort]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    
    [self.stubSocket close];
    
    while (self.socketOpen && [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]]); // don't advance until the socket has closed completely

    [super tearDown];
}

- (void)testSocketSTOMPConnect {
    
    self.currentScenario = RBKTestScenarioStompConnect;

    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    
    RBKStompFrame *connectMessage = [RBKStompFrame connectFrameWithLogin:@"username" passcode:@"passcode" host:[[NSURL URLWithString:hostURL] host]];
    
    __block BOOL success = NO;
    __block RBKStompFrame *responseMessage = nil;
    [self.stompSocket sendSocketOperationWithFrame:connectMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject; // This response object will be a CONNECTED frame
    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([responseMessage frameData]).willNot.equal([connectMessage frameData]); // connect message should get connection response
    expect(responseMessage.command).will.equal(RBKStompCommandConnected);
    expect([responseMessage headerValueForKey:RBKStompHeaderVersion]).will.equal(RBKStompVersion1_2);
}

- (void)testSocketSTOMPConnectServerHeartbeat {
    
    self.currentScenario = RBKTestScenarioStompConnectServerHeartbeat;
    
    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    RBKStompFrame *connectMessage = [RBKStompFrame connectFrameWithLogin:@"username" passcode:@"passcode" host:[[NSURL URLWithString:hostURL] host] supportedOutgoingHeartbeat:0 desiredIncomingHeartbeat:1000];
    
    __block BOOL success = NO;
    __block RBKStompFrame *responseMessage = nil;
    __block NSDate *dateSinceLastResponse = [NSDate distantPast];
    [self.stompSocket sendSocketOperationWithFrame:connectMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject; // This response object will be a CONNECTED frame
        dateSinceLastResponse = [NSDate date];
    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([self.stompSocket numberOfReceivedHeartbeats]).will.beGreaterThanOrEqualTo(2);
    
    // this is a block just so we can see (during development of the tests) the difference between the expected heartbeat interval and when the block gets called
    NSTimeInterval(^expectedInterval)(void) = ^(void) {
        // NSTimeInterval actual = [self.webSocket timeIntervalBetweenPreviousHeartbeats];
        NSTimeInterval expected = [[NSDate date] timeIntervalSinceDate:dateSinceLastResponse];
        // NSLog(@"actual interval: %f\nexpected interval: %f", actual, expected);
        return expected;
    };
    
    expect([self.stompSocket timeIntervalBetweenPreviousHeartbeats]).will.beCloseToWithin(expectedInterval(), 0.1);
}

- (void)testSocketSTOMPConnectClientHeartbeat {
    
    self.currentScenario = RBKTestScenarioStompConnectClientHeartbeat;
    
    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    RBKStompFrame *connectMessage = [RBKStompFrame connectFrameWithLogin:@"username" passcode:@"passcode" host:[[NSURL URLWithString:hostURL] host] supportedOutgoingHeartbeat:1000 desiredIncomingHeartbeat:0];
    
    __block BOOL success = NO;
    __block RBKStompFrame *responseMessage = nil;
    __block NSDate *dateSinceLastResponse = [NSDate distantPast];
    [self.stompSocket sendSocketOperationWithFrame:connectMessage success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseMessage = responseObject; // This response object will be a CONNECTED frame

        dateSinceLastResponse = [NSDate date];
    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect([self.stompSocket numberOfSentHeartbeats]).will.beGreaterThanOrEqualTo(2);
    expect(self.isCurrentScenarioSuccessful).will.beTruthy(); // indicates that the client heartbeat was received
}


// Connection:
// client heartbeat is not tested
// unreceived client/server heartbeat is not tested
// negotiation error is not tested

- (void)testSocketSTOMPSubscribe {
    
    self.currentScenario = RBKTestScenarioStompSubscribe;

    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    __block BOOL subscriptionHandlerCalled = NO;
    __block RBKStompFrame *subscriptionResponseFrame = nil;

    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalled = YES;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
        // NSLog(@"--- %@", [responseFrame frameString]);
    }];
    
    __block BOOL success = NO;
    [self.stompSocket sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;

    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
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
    
    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    __block BOOL subscriptionHandlerCalled = NO;
    __block RBKStompFrame *subscriptionResponseFrame = nil;
    
    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345", @"ack": @"client"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalled = YES;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
        // NSLog(@"--- %@", [responseFrame frameString]);
    }];
    
    __block BOOL success = NO;
    [self.stompSocket sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;

    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(self.isCurrentScenarioSuccessful).will.beTruthy(); // indicates that the ack was successful
}

- (void)testSocketSTOMPSubscribeClientNack {
    
    self.currentScenario = RBKTestScenarioStompSubscribeClientNack;
    
    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    __block BOOL subscriptionHandlerCalled = NO;
    __block RBKStompFrame *subscriptionResponseFrame = nil;
    
    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345", @"ack": @"client"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalled = YES;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
        // NSLog(@"--- %@", [responseFrame frameString]);
    }];
    
    __block BOOL success = NO;
    [self.stompSocket sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;

    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
        success = NO;
    }];
    expect(success).will.beTruthy();
    expect(self.isCurrentScenarioSuccessful).will.beTruthy(); // indicates that the ack was successful
}



// Subscription:
// subscription error is not tested


- (void)testSocketSTOMPSend {
    
    self.currentScenario = RBKTestScenarioStompSend;
    
    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    NSString *sendBody = @"Message for you sir";
    
    RBKStompFrame *sendFrame = [RBKStompFrame sendFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"} body:sendBody];
    __block BOOL success = NO;
    __block RBKStompFrame *responseFrame = nil;
    [self.stompSocket sendSocketOperationWithFrame:sendFrame success:^(RBKSocketOperation *operation, id responseObject) {
        success = YES;
        responseFrame = responseObject; // probably isn't echo'd per the standard, but this at least validates that send messages are being sent
    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
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
    
    self.stompSocket.requestSerializer = [RBKSocketStompRequestSerializer serializer];
    RBKSocketStompRequestSerializer *requestSerializer = (id)self.stompSocket.requestSerializer;
    requestSerializer.delegate = self.stompSocket;
    self.stompSocket.responseSerializer = [RBKSocketStompResponseSerializer serializer];
    RBKSocketStompResponseSerializer *responseSerializer = (id)self.stompSocket.responseSerializer;
    responseSerializer.delegate = self.stompSocket;
    
    __block NSUInteger subscriptionHandlerCalledCounter = 0;
    __block RBKStompFrame *subscriptionResponseFrame = nil;
    
    RBKStompFrame *subscriptionFrame = [RBKStompFrame subscribeFrameWithDestination:@"/foo/bar" headers:@{@"x-test": @"12345"} messageHandler:^(RBKStompFrame *responseFrame) {
        subscriptionHandlerCalledCounter += 1;
        subscriptionResponseFrame = responseFrame; // probably isn't echo'd per the standard, but this at least validates the conversion to/from RBKStompMessage
    }];
    
    RBKStompFrame *unsubscribeFrame = [RBKStompFrame unsubscribeFrameWithDestination:@"/foo/bar" subscriptionID:subscriptionFrame.subscription.identifier headers:nil];
    
    __block BOOL success = NO;
    __weak typeof(self)weakSelf = self;
    [self.stompSocket sendSocketOperationWithFrame:subscriptionFrame success:^(RBKSocketOperation *operation, id responseObject) {

        // now that we've subscribed, unsubscribe
        weakSelf.currentScenario = RBKTestScenarioStompUnsubscribe;

        [weakSelf.stompSocket sendSocketOperationWithFrame:unsubscribeFrame success:^(RBKSocketOperation *operation, id responseObject) {
            success = YES;
        }                                          failure:^(RBKSocketOperation *operation, NSError *error) {
            success = NO;
        }];

    }                                      failure:^(RBKSocketOperation *operation, NSError *error) {
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
            
        case RBKTestScenarioStompConnectServerHeartbeat: {
            RBKStompFrame *connectedFrame = [self connectedFrameForConnectFrameData:message];
            [webSocket send:[connectedFrame frameData]];
            // schedule a heartbeat to be sent
            NSString *heartbeatString = [connectedFrame headerValueForKey:RBKStompHeaderHeartBeat];
            RBKStompHeartbeat heartbeat = RBKStompHeartbeatFromString(heartbeatString);
            
            if (heartbeat.supportedTransmitIntervalMinimum > 0) {
                // send a heartbeat in the supported interval
                self.currentScenario = RBKTestScenarioStompServerHeartbeat;
                __weak typeof(self)weakSelf = self;
                double delayInSeconds = heartbeat.supportedTransmitIntervalMinimum/1000.0;
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [webSocket send:[[weakSelf heartbeatFrame] frameData]];
                });
            }
            
            // NSLog(@"change the mode to watch for a heartbeat");
            return;
        }
        case RBKTestScenarioStompConnectClientHeartbeat: {
            RBKStompFrame *connectedFrame = [self connectedFrameForConnectFrameData:message];
            [webSocket send:[connectedFrame frameData]];
            // schedule a heartbeat to be sent
            NSString *heartbeatString = [connectedFrame headerValueForKey:RBKStompHeaderHeartBeat];
            RBKStompHeartbeat heartbeat = RBKStompHeartbeatFromString(heartbeatString);
            
            if (heartbeat.desiredReceptionIntervalMinimum > 0) {
                // then wait for the heartbeat
                self.currentScenario = RBKTestScenarioStompClientHeartbeat;
            }
            return;
        }
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
            // NSLog(@"received ack");
            self.currentScenarioSuccessful = YES;
            return;
            
        case RBKTestScenarioStompNack:
            // NSLog(@"received nack");
            self.currentScenarioSuccessful = YES;
            return;
            
        case RBKTestScenarioStompSend:
            [webSocket send:[[self messageFrame:@"Message for you sir" forSendFrameData:message] frameData]];
            return;
            
        case RBKTestScenarioStompUnsubscribe:
            [webSocket send:[[self messageFrame:@"Message for you sir" forSendFrameData:message] frameData]];
            return;
            
        case RBKTestScenarioStompServerHeartbeat:
            // NSLog(@"received Server Heartbeat");
            self.currentScenarioSuccessful = YES; // this is never going to fire because its the client receiving the heartbeat, not us
            return;
            
        case RBKTestScenarioStompClientHeartbeat:
            self.currentScenarioSuccessful = YES; // this will fire once the client sends the heartbeat
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
    NSString *heartbeatString = [receivedFrame headerValueForKey:RBKStompHeaderHeartBeat];
    
    RBKStompFrame *connectedFrame = nil;
    if (heartbeatString) {
        RBKStompHeartbeat heartbeat = RBKStompHeartbeatFromString(heartbeatString);
        // check if we need to include heartbeat
        
        if (heartbeat.supportedTransmitIntervalMinimum <= 0 && heartbeat.desiredReceptionIntervalMinimum <= 0) {
            // no heartbeat needed
            connectedFrame = [RBKStompFrame connectedFrameWithVersion:acceptedVersion];
        } else {
            RBKStompHeartbeat serverHeartbeat = RBKStompHeartbeatZero;
            if (heartbeat.supportedTransmitIntervalMinimum > 0) {
                serverHeartbeat.desiredReceptionIntervalMinimum = heartbeat.supportedTransmitIntervalMinimum; // just match what the client asks for now
            }
            if (heartbeat.desiredReceptionIntervalMinimum > 0) {
                serverHeartbeat.supportedTransmitIntervalMinimum = heartbeat.desiredReceptionIntervalMinimum; // just match what the client asks for now
            }
            // server heartbeat to match the client
            connectedFrame = [RBKStompFrame connectedFrameWithVersion:acceptedVersion heartbeat:serverHeartbeat];
        }
    } else {
        // no heartbeat needed
        connectedFrame = [RBKStompFrame connectedFrameWithVersion:acceptedVersion];
    }
    
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

- (RBKStompFrame *)heartbeatFrame {
    
    RBKStompFrame *heartbeatFrame = [RBKStompFrame heartbeatFrame];
    return heartbeatFrame;
}


@end
