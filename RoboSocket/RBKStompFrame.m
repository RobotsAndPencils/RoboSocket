//
//  RBKStompFrame.m
//  RoboSocket
//
//  Created by David Anderson on 11/14/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import "RBKStompFrame.h"

NSString * const RBKStompVersion1_2 = @"1.2";
// NSString * const RBKStompNoHeartBeat = @"0,0";

NSString * const RBKStompCommandAbort = @"ABORT";
NSString * const RBKStompCommandAck = @"ACK";
NSString * const RBKStompCommandBegin = @"BEGIN";
NSString * const RBKStompCommandCommit = @"COMMIT";
NSString * const RBKStompCommandStompConnect = @"STOMP"; // v1.2
NSString * const RBKStompCommandConnect = @"CONNECT"; // pre 1.2
NSString * const RBKStompCommandConnected = @"CONNECTED";
NSString * const RBKStompCommandDisconnect = @"DISCONNECT";
NSString * const RBKStompCommandError = @"ERROR";
NSString * const RBKStompCommandMessage = @"MESSAGE";
NSString * const RBKStompCommandNack = @"NACK";
NSString * const RBKStompCommandReceipt = @"RECEIPT";
NSString * const RBKStompCommandSend = @"SEND";
NSString * const RBKStompCommandSubscribe = @"SUBSCRIBE";
NSString * const RBKStompCommandUnsubscribe = @"UNSUBSCRIBE";

// all caps STOMP vs lowercase Stomp

NSString * const RBKStompLineFeed = @"\x0A";
NSString * const RBKStompNullCharString = @"\x00";
unichar const RBKStompNullChar = '\x00';
NSString * const RBKStompHeaderSeparator = @":";

NSString * const RBKStompHeaderAcceptVersion = @"accept-version";
NSString * const RBKStompHeaderVersion = @"version";
NSString * const RBKStompHeaderAck = @"ack";
NSString * const RBKStompHeaderContentType = @"content-type";
NSString * const RBKStompHeaderContentLength = @"content-length";
NSString * const RBKStompHeaderDestination = @"destination";
NSString * const RBKStompHeaderHeartBeat = @"heart-beat";
NSString * const RBKStompHeaderHost = @"host";
NSString * const RBKStompHeaderID = @"id";
NSString * const RBKStompHeaderLogin = @"login";
NSString * const RBKStompHeaderMessage = @"message";
NSString * const RBKStompHeaderMessageID = @"message-id";
NSString * const RBKStompHeaderPasscode = @"passcode";
NSString * const RBKStompHeaderReceipt = @"receipt";
NSString * const RBKStompHeaderReceiptID = @"receipt-id";
NSString * const RBKStompHeaderSession = @"session";
NSString * const RBKStompHeaderSubscription = @"subscription";
NSString * const RBKStompHeaderTransaction = @"transaction";

#pragma mark Ack Header Values

NSString * const RBKStompAckAuto = @"auto"; // the client does not need to send the server ACK frames for the messages it receives.
NSString * const RBKStompAckClient = @"client"; // client MUST send the server ACK frames for the messages it processes. If the connection fails before a client sends an ACK frame for the message the server will assume the message has not been processed and MAY redeliver the message to another client. The ACK frames sent by the client will be treated as a cumulative acknowledgment. This means the acknowledgment operates on the message specified in the ACK frame and all messages sent to the subscription before the ACK'ed message.
NSString * const RBKStompAckClientIndividual = @"client-individual"; // the acknowledgment operates just like the client acknowledgment mode except that the ACK or NACK frames sent by the client are not cumulative. This means that an ACK or NACK frame for a subsequent message MUST NOT cause a previous message to get acknowledged.

const RBKStompHeartbeat RBKStompHeartbeatZero = {0,0};

NSString *NSStringFromStompHeartbeat(RBKStompHeartbeat heartbeat) {
    return [NSString stringWithFormat:@"%d,%d", heartbeat.transmitIntervalMinimum, heartbeat.desiredReceptionIntervalMinimum];
}

RBKStompHeartbeat RBKStompHeartbeatFromString(NSString *heartbeatString) {
    
    NSArray *heartbeatComponents = [heartbeatString componentsSeparatedByString:@","];
    if ([heartbeatComponents count] != 2) {
        NSLog(@"invalid heartbeat input");
        RBKStompHeartbeat heartbeat = {0, 0};
        return heartbeat;
    }
    RBKStompHeartbeat heartbeat = {[[heartbeatComponents firstObject] unsignedIntegerValue], [[heartbeatComponents lastObject] unsignedIntegerValue]};
    return heartbeat;
}


@interface RBKStompSubscription ()

@property (nonatomic, strong) NSString *identifier;
// message handler?

@end


@implementation RBKStompSubscription


+ (RBKStompSubscription *)subscriptionWithIdentifier:(NSString *)subscriptionIdentifier { // needs a message handler
    return [[RBKStompSubscription alloc] initSubscriptionWithIdentifier:subscriptionIdentifier];
}

- (RBKStompSubscription *)initSubscriptionWithIdentifier:(NSString *)subscriptionIdentifier { // needs a message handler
    self = [super init];
    if (self) {
        _identifier = subscriptionIdentifier;
    }
    return self;
    
}

@end


@interface RBKStompFrame ()

@property (strong, nonatomic) NSString *destination;
@property (strong, nonatomic) NSDictionary *headers;
@property (strong, nonatomic) NSString *command;
@property (strong, nonatomic) NSString *body;

@property (strong, nonatomic, readwrite) RBKStompSubscription *subscription;
@property (strong, nonatomic) RBKStompFrameHandler responseFrameHandler;

@end

static NSUInteger headerIdentifier;
static NSUInteger messageIdentifier;

@implementation RBKStompFrame

+ (instancetype)responseFrameFromData:(NSData *)data {

    NSString *frameAsString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // NSLog(@"<<<\n%@", frameAsString);
    
    NSMutableArray *contents = [[frameAsString componentsSeparatedByString:RBKStompLineFeed] mutableCopy];
    // skip initial if its an empty string
    if ([[contents firstObject] isEqualToString:@""]) {
        [contents removeObject:[contents firstObject]];
    }
    // get our command
    NSString *command = [[contents firstObject] copy];
    [contents removeObject:[contents firstObject]];
    
    // get headers and body
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    NSMutableString *body = [NSMutableString string];
    BOOL haveParsedHeaders = NO;
    
    for (NSString *line in contents) {
        if (haveParsedHeaders) {
            
            // find an alternative mechanism?
            for (NSUInteger idx=0; idx < [line length]; idx++) {
                unichar c = [line characterAtIndex:idx];
                if (c != RBKStompNullChar) {
                    [body appendString:[NSString stringWithFormat:@"%c", c]];
                }
            }
        } else {
            if ([line isEqualToString:@""]) {
                haveParsedHeaders = YES;
            } else {
                NSMutableArray *headerEntry = [NSMutableArray arrayWithArray:[line componentsSeparatedByString:RBKStompHeaderSeparator]];
				// key ist the first part
				NSString *key = headerEntry[0];
                [headerEntry removeObjectAtIndex:0];
                headers[key] = [headerEntry componentsJoinedByString:RBKStompHeaderSeparator];
            }
        }
    }
    
    return [[RBKStompFrame alloc] initFrameWithCommand:command headers:headers body:body];
}

- (instancetype)initFrameWithCommand:(NSString *)command headers:(NSDictionary *)headers body:(NSString *)body {
    self = [super init];
    if (self) {
        _command = command;
        _headers = headers;
        _body = body;
    }
    return self;

}

#pragma mark - Connect

+ (instancetype)connectFrameWithLogin:(NSString *)login passcode:(NSString *)passcode host:(NSString *)host { // heartbeat?  handlers?
    
    return [RBKStompFrame connectMessageHeaders:@{RBKStompHeaderLogin: login, RBKStompHeaderPasscode: passcode, RBKStompHeaderHost: host}];
}

+ (instancetype)connectMessageHeaders:(NSDictionary *)headers { // heartbeat?
    
    return [[RBKStompFrame alloc] initConnectMessageHeaders:headers];
}

- (instancetype)initConnectMessageHeaders:(NSDictionary *)headers {
    NSMutableDictionary *connectHeaders = [NSMutableDictionary dictionaryWithDictionary:headers];
    connectHeaders[RBKStompHeaderAcceptVersion] = RBKStompVersion1_2;
    
    if (!connectHeaders[RBKStompHeaderHeartBeat]) {
        connectHeaders[RBKStompHeaderHeartBeat] = NSStringFromStompHeartbeat(RBKStompHeartbeatZero); // no heart beat
    }

    return [[RBKStompFrame alloc] initFrameWithCommand:RBKStompCommandStompConnect headers:connectHeaders body:nil];
}


#pragma mark - Connected

+ (instancetype)connectedFrameWithVersion:(NSString *)version {
    
    return [RBKStompFrame connectedMessageWithHeaders:@{RBKStompHeaderVersion: version}];
}

+ (instancetype)connectedMessageWithHeaders:(NSDictionary *)headers {
    
    return [[RBKStompFrame alloc] initConnectedMessageWithHeaders:headers];
}

- (instancetype)initConnectedMessageWithHeaders:(NSDictionary *)headers {
    NSMutableDictionary *connectHeaders = [NSMutableDictionary dictionaryWithDictionary:headers];
    
    if (!connectHeaders[RBKStompHeaderVersion]) {
        connectHeaders[RBKStompHeaderVersion] = RBKStompVersion1_2;
    }
    
    if (!connectHeaders[RBKStompHeaderHeartBeat]) {
        connectHeaders[RBKStompHeaderHeartBeat] = NSStringFromStompHeartbeat(RBKStompHeartbeatZero); // no heart beat
    }
    
    return [[RBKStompFrame alloc] initFrameWithCommand:RBKStompCommandConnected headers:connectHeaders body:nil];
}



#pragma mark - Subscription

+ (instancetype)subscribeFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers messageHandler:(RBKStompFrameHandler)messageHandler {
    return [[RBKStompFrame alloc] initSubscribeMessageWithDestination:destination headers:headers messageHandler:messageHandler];
}

- (instancetype)initSubscribeMessageWithDestination:(NSString *)destination headers:(NSDictionary *)headers messageHandler:(RBKStompFrameHandler)messageHandler {

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        headerIdentifier = 0;
    });
    
    NSMutableDictionary *mutableHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    mutableHeaders[RBKStompHeaderDestination] = destination;
    NSString *identifier = mutableHeaders[RBKStompHeaderID];
    if (!identifier) {
        identifier = [NSString stringWithFormat:@"sub-%d", headerIdentifier++];
        mutableHeaders[RBKStompHeaderID] = identifier;
    }

    self = [self initFrameWithCommand:RBKStompCommandSubscribe headers:mutableHeaders body:nil];
    if (self) {
        _destination = destination; // might not need to store this, its in the header
        _responseFrameHandler = messageHandler;
        // self.subscriptions[identifier] = handler; // what does the scope of this handler need to be?
        _subscription = [RBKStompSubscription subscriptionWithIdentifier:identifier];
    }
    
    return self;
}

#pragma mark - Message

+ (instancetype)messageFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body subscription:(NSString *)subscription { // messageHandler
    return [[RBKStompFrame alloc] initMessageFrameWithDestination:destination headers:headers body:body subscription:subscription];
}

- (instancetype)initMessageFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body subscription:(NSString *)subscription {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        messageIdentifier = 0;
    });

    
    NSMutableDictionary *mutableHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    mutableHeaders[RBKStompHeaderDestination] = destination;
    mutableHeaders[RBKStompHeaderSubscription] = subscription;
    NSString *identifier = mutableHeaders[RBKStompHeaderMessageID];
    if (!identifier) {
        identifier = [NSString stringWithFormat:@"msg-%d", messageIdentifier++];
        mutableHeaders[RBKStompHeaderMessageID] = identifier;
    }
    
    self = [self initFrameWithCommand:RBKStompCommandMessage headers:mutableHeaders body:body];
    
    return self;
}


#pragma mark - Send

+ (instancetype)sendFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body { // messageHandler
    return [[RBKStompFrame alloc] initSendFrameWithDestination:destination headers:headers body:body];
}

- (instancetype)initSendFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body {
    
    NSMutableDictionary *mutableHeaders = [[NSMutableDictionary alloc] initWithDictionary:headers];
    mutableHeaders[RBKStompHeaderDestination] = destination;
    NSString *identifier = mutableHeaders[RBKStompHeaderMessageID];
    if (!identifier) {
        identifier = [NSString stringWithFormat:@"msg-%d", messageIdentifier++];
        mutableHeaders[RBKStompHeaderMessageID] = identifier;
    }
    
    self = [self initFrameWithCommand:RBKStompCommandSend headers:mutableHeaders body:body];
    
    return self;
}


#pragma mark - Public

- (NSString *)frameString {
    NSMutableString *frameString = [NSMutableString stringWithString:[self.command stringByAppendingString:RBKStompLineFeed]];
    NSMutableDictionary *mutableHeaders = [self.headers mutableCopy];
    // include content-type and content-length if we have a body
    if (self.body && [self commandPermitsBody:self.command]) {
        if (![self headerValueForKey:RBKStompHeaderContentType]) {
            mutableHeaders[RBKStompHeaderContentType] = @"text/plain";
        }
        if (![self headerValueForKey:RBKStompHeaderContentLength]) {
            NSUInteger bodyLength = [self.body length];
            mutableHeaders[RBKStompHeaderContentLength] = @(bodyLength);
        }
    }
    
    [mutableHeaders enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        
        // TODO: escape any carriage return, line feed or colon found in the resulting UTF-8 encoded headers
        [frameString appendString:[NSString stringWithFormat:@"%@%@%@%@", key, RBKStompHeaderSeparator, obj, RBKStompLineFeed]];
    }];
    [frameString appendString:RBKStompLineFeed];

	// include body if we can
    if (self.body && [self commandPermitsBody:self.command]) {
		[frameString appendString:self.body];
	}
    [frameString appendString:RBKStompNullCharString];
    
    // NSLog(@">>>\n%@", frameString);
    return frameString;
}

- (NSData *)frameData {
    
    return [[self frameString] dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)headerValueForKey:(NSString *)key {
    return self.headers[key];
}

- (NSString *)bodyValue {
    // should only return a string if our content-type is a string
    return self.body;
}

#pragma mark - Private

-(BOOL)commandPermitsBody:(NSString *)command {
    // Only the SEND, MESSAGE, and ERROR frames MAY have a body. All other frames MUST NOT have a body.
    if ([command isEqualToString:RBKStompCommandSend] ||
        [command isEqualToString:RBKStompCommandMessage] ||
        [command isEqualToString:RBKStompCommandError]) {
        return YES;
    }
    return NO;
}


@end

