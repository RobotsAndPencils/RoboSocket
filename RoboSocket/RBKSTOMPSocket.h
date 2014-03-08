//
//  RBKSTOMPSocket.h
//  RoboSocket
//
//  Created by David Anderson on 11/1/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RBKWebSocket.h"

@interface RBKSTOMPSocket : RBKWebSocket<RBKSocketStompRequestSerializerDelegate, RBKSocketStompResponseSerializerDelegate>

- (NSUInteger)numberOfReceivedHeartbeats;
- (NSTimeInterval)timeSinceMostRecentHeartbeat;
- (NSTimeInterval)timeIntervalBetweenPreviousHeartbeats;
- (NSUInteger)numberOfSentHeartbeats;

@end
