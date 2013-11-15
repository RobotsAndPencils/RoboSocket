//
//  RBKSTOMPMessage.h
//  RoboSocket
//
//  Created by David Anderson on 11/14/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const RBKSTOMPVersion1_2;

extern NSString * const RBKSTOMPCommandAbort;
extern NSString * const RBKSTOMPCommandAck;
extern NSString * const RBKSTOMPCommandBegin;
extern NSString * const RBKSTOMPCommandCommit;
extern NSString * const RBKSTOMPCommandStompConnect;
extern NSString * const RBKSTOMPCommandConnect;
extern NSString * const RBKSTOMPCommandConnected;
extern NSString * const RBKSTOMPCommandDisconnect;
extern NSString * const RBKSTOMPCommandError;
extern NSString * const RBKSTOMPCommandMessage;
extern NSString * const RBKSTOMPCommandNack;
extern NSString * const RBKSTOMPCommandReceipt;
extern NSString * const RBKSTOMPCommandSend;
extern NSString * const RBKSTOMPCommandSubscribe;
extern NSString * const RBKSTOMPCommandUnsubscribe;

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

struct RBKSTOMPHeartbeat {
    NSUInteger transmitIntervalMinimum; // 0 for can't send, otherwise smallest number of milliseconds between heart-beats that it can guarantee
    NSUInteger desiredReceptionIntervalMinimum; // 0 for doesn't want, otherwise desired number of milliseconds between heart-beats
};
typedef struct RBKSTOMPHeartbeat RBKSTOMPHeartbeat;

@interface RBKSTOMPSubscription : NSObject

@end

@interface RBKSTOMPMessage : NSObject

@property (nonatomic, strong, readonly) RBKSTOMPSubscription *subscription;
@property (nonatomic, strong, readonly) NSString *command;


+ (instancetype)responseMessageFromData:(NSData *)data;

#pragma mark - Connect

+ (instancetype)connectMessageWithLogin:(NSString *)login passcode:(NSString *)passcode host:(NSString *)host;

#pragma mark - Connected

+ (instancetype)connectedMessageWithVersion:(NSString *)version;

#pragma mark - Subscription

+ (instancetype)subscribeMessageWithDestination:(NSString *)destination headers:(NSDictionary *)headers;

#pragma mark - Message

+ (instancetype)messageMessageWithDestination:(NSString *)destination headers:(NSDictionary *)headers body:(NSString *)body subscription:(NSString *)subscription;

#pragma mark - Public

- (NSData *)frameData;
- (NSString *)headerValueForKey:(NSString *)key;
- (NSString *)bodyValue;



@end
