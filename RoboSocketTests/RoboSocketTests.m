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

#import "RoboSocket.h"

@interface RoboSocketTests : XCTestCase

@property (strong, nonatomic) RoboSocket *socket;

@end

@implementation RoboSocketTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    self.socket = [[RoboSocket alloc] initWithSocketURL:[NSURL URLWithString:@"ws://echo.websocket.org"]];
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    // XCTFail(@"No implementation for \"%s\"", __PRETTY_FUNCTION__);
    
    [self.socket sendMessageToSocket:@"hello"];
    
}

@end
