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

@interface RoboSocketTests : XCTestCase

@property (strong, nonatomic) RBKSocketManager *socketManager;

@end

@implementation RoboSocketTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    [Expecta setAsynchronousTestTimeout:60.0];

    self.socketManager = [[RBKSocketManager alloc] initWithSocketURL:[NSURL URLWithString:@"ws://echo.websocket.org"]];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    
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

@end
