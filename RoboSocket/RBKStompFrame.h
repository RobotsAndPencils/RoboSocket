//
//  RBKStompFrame.h
//  RoboSocket
//
//  Created by David Anderson on 11/14/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const RBKStompVersion1_2;

extern NSString * const RBKStompCommandAbort;
extern NSString * const RBKStompCommandAck;
extern NSString * const RBKStompCommandBegin;
extern NSString * const RBKStompCommandCommit;
extern NSString * const RBKStompCommandStompConnect;
extern NSString * const RBKStompCommandConnect;
extern NSString * const RBKStompCommandConnected;
extern NSString * const RBKStompCommandDisconnect;
extern NSString * const RBKStompCommandError;
extern NSString * const RBKStompCommandMessage;
extern NSString * const RBKStompCommandNack;
extern NSString * const RBKStompCommandReceipt;
extern NSString * const RBKStompCommandSend;
extern NSString * const RBKStompCommandSubscribe;
extern NSString * const RBKStompCommandUnsubscribe;
extern NSString * const RBKStompCommandHeartbeat; // NOT A REAL COMMAND: results in a frame containing only EOL

extern NSString * const RBKStompLineFeed;
extern NSString * const RBKStompNullCharString;
extern unichar const RBKStompNullChar;
extern NSString * const RBKStompHeaderSeparator;

extern NSString * const RBKStompHeaderAcceptVersion;
extern NSString * const RBKStompHeaderVersion;
extern NSString * const RBKStompHeaderAck;
extern NSString * const RBKStompHeaderContentType;
extern NSString * const RBKStompHeaderContentLength;
extern NSString * const RBKStompHeaderDestination;
extern NSString * const RBKStompHeaderHeartBeat;
extern NSString * const RBKStompHeaderHost;
extern NSString * const RBKStompHeaderID;
extern NSString * const RBKStompHeaderLogin;
extern NSString * const RBKStompHeaderMessage;
extern NSString * const RBKStompHeaderMessageID;
extern NSString * const RBKStompHeaderPasscode;
extern NSString * const RBKStompHeaderReceipt;
extern NSString * const RBKStompHeaderReceiptID;
extern NSString * const RBKStompHeaderSession;
extern NSString * const RBKStompHeaderSubscription;
extern NSString * const RBKStompHeaderTransaction;

extern NSString * const RBKStompAckAuto;
extern NSString * const RBKStompAckClient;
extern NSString * const RBKStompAckClientIndividual;

struct RBKStompHeartbeat {
    NSUInteger supportedTransmitIntervalMinimum; // 0 for can't send, otherwise smallest number of milliseconds between heart-beats that it can guarantee
    NSUInteger desiredReceptionIntervalMinimum; // 0 for doesn't want, otherwise desired number of milliseconds between heart-beats
};
typedef struct RBKStompHeartbeat RBKStompHeartbeat;

extern const RBKStompHeartbeat RBKStompHeartbeatZero;
NSString *NSStringFromStompHeartbeat(RBKStompHeartbeat heartbeat);
RBKStompHeartbeat RBKStompHeartbeatFromString(NSString *heartbeatString);

@class RBKStompFrame;

typedef void (^RBKStompFrameHandler)(RBKStompFrame *responseFrame);


@interface RBKStompSubscription : NSObject

@property (strong, nonatomic, readonly) NSString *identifier;

@end

@interface RBKStompFrame : NSObject

@property (strong, nonatomic, readonly) RBKStompSubscription *subscription;
@property (strong, nonatomic, readonly) NSString *command;
@property (strong, nonatomic, readonly) RBKStompFrameHandler responseFrameHandler;

+ (instancetype)responseFrameFromData:(NSData *)data;

#pragma mark - Connect

+ (instancetype)connectFrameWithLogin:(NSString *)login passcode:(NSString *)passcode host:(NSString *)host;
+ (instancetype)connectFrameWithLogin:(NSString *)login passcode:(NSString *)passcode host:(NSString *)host supportedOutgoingHeartbeat:(NSUInteger)outgoingHeartbeat desiredIncomingHeartbeat:(NSUInteger)incomingHeartbeat;

#pragma mark - Connected

+ (instancetype)connectedFrameWithVersion:(NSString *)version;
+ (instancetype)connectedFrameWithVersion:(NSString *)version heartbeat:(RBKStompHeartbeat)heartbeat;

#pragma mark - Subscription

+ (instancetype)subscribeFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers messageHandler:(RBKStompFrameHandler)messageHandler;

#pragma mark - Subscription

+ (instancetype)unsubscribeFrameWithDestination:(NSString *)destination subscriptionID:(NSString *)subscriptionID headers:(NSDictionary *)headers;

#pragma mark - Message

+ (instancetype)messageFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body subscription:(NSString *)subscription;

#pragma mark - Send

+ (instancetype)sendFrameWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body;

#pragma mark - Ack

+ (instancetype)ackFrameWithIdentifier:(NSString *)identifier;

#pragma mark - Nack

+ (instancetype)nackFrameWithIdentifier:(NSString *)identifier;

#pragma mark - Heartbeat

+ (instancetype)heartbeatFrame;

#pragma mark - Public

- (NSString *)frameString;
- (NSData *)frameData;
- (NSString *)headerValueForKey:(NSString *)key;
- (NSString *)bodyValue;



@end
