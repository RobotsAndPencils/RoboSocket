//
//  RoboSocket.h
//  RoboSocket
//
//  Created by David Anderson on 10/16/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RoboSocket : NSObject

- (instancetype)initWithSocketURL:(NSURL *)socketURL;
- (void)openSocket;
- (void)closeSocket;
- (void)sendMessage:(NSString *)message;

@end
