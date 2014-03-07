// RBKSerialization.h
//
// Copyright (c) 2013 RBKNetworking (http://afnetworking.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "RBKSocketResponseSerialization.h"
#import "RBKStompFrame.h"

extern NSString * const RBKSocketNetworkingErrorDomain;
extern NSString * const RBKSocketNetworkingOperationFailingURLResponseErrorKey;

#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
#import <UIKit/UIKit.h>
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
#import <Cocoa/Cocoa.h>
#endif

@implementation RBKSocketResponseSerializer

+ (instancetype)serializer {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.stringEncoding = NSUTF8StringEncoding;

    self.acceptableStatusCodes = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(200, 100)];

    return self;
}

#pragma mark -

- (BOOL)validateResponse:(NSHTTPURLResponse *)response
                    data:(NSData *)data
                   error:(NSError *__autoreleasing *)error
{
//    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
//        if (self.acceptableStatusCodes && ![self.acceptableStatusCodes containsIndex:(NSUInteger)response.statusCode]) {
//            NSDictionary *userInfo = @{
//                                       NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: %@ (%d)", @"RBKNetworking", nil), [NSHTTPURLResponse localizedStringForStatusCode:response.statusCode], response.statusCode],
//                                       NSURLErrorFailingURLErrorKey:[response URL],
//                                       RBKSocketNetworkingOperationFailingURLResponseErrorKey: response
//                                       };
//            if (error) {
//                *error = [[NSError alloc] initWithDomain:RBKSocketNetworkingErrorDomain code:NSURLErrorBadServerResponse userInfo:userInfo];
//            }
//
//            return NO;
//        } else if (self.acceptableContentTypes && ![self.acceptableContentTypes containsObject:[response MIMEType]]) {
//            // Don't invalidate content type if there is no content
//            if ([data length] > 0) {
//                NSDictionary *userInfo = @{
//                                           NSLocalizedDescriptionKey: [NSString stringWithFormat:NSLocalizedStringFromTable(@"Request failed: unacceptable content-type: %@", @"RBKNetworking", nil), [response MIMEType]],
//                                           NSURLErrorFailingURLErrorKey:[response URL],
//                                           RBKSocketNetworkingOperationFailingURLResponseErrorKey: response
//                                           };
//                if (error) {
//                    *error = [[NSError alloc] initWithDomain:RBKSocketNetworkingErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:userInfo];
//                }
//
//                return NO;
//            }
//        }
//    }

//    NSLog(@"DWA: Need to validate the response ?");
    
    return YES;
}

#pragma mark - RBKSocketResponseSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    [self validateResponse:nil data:responseFrame error:error];

    return responseFrame;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    if (!self) {
        return nil;
    }

    self.acceptableStatusCodes = [decoder decodeObjectForKey:NSStringFromSelector(@selector(acceptableStatusCodes))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.acceptableStatusCodes forKey:NSStringFromSelector(@selector(acceptableStatusCodes))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.acceptableStatusCodes = [self.acceptableStatusCodes copyWithZone:zone];

    return serializer;
}

@end









#pragma mark -

@implementation RBKSocketStringResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithReadingOptions:0];
}

+ (instancetype)serializerWithReadingOptions:(NSUInteger)readingOptions {
    RBKSocketStringResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;
    
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    return self;
}

#pragma mark - RBKSocketRequestSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:nil data:responseFrame error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }
    
    if (!responseFrame) {
        NSLog(@"Did not receive response frame");
        return nil;
    }
    
    if ([responseFrame isKindOfClass:[NSString class]]) {
        return responseFrame;
    }

    if ([responseFrame isKindOfClass:[NSData class]]) {
        NSString *responseString = [[NSString alloc] initWithData:responseFrame encoding:NSUTF8StringEncoding];
        return responseString;
    }
    
    NSLog(@"Unsupported response frame type %@ for serialization as string", NSStringFromClass([responseFrame class]));
    return nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.readingOptions = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(readingOptions))];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeInteger:self.readingOptions forKey:NSStringFromSelector(@selector(readingOptions))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketStringResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.readingOptions = self.readingOptions;
    
    return serializer;
}

@end







#pragma mark -

@implementation RBKSocketDataResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithReadingOptions:0];
}

+ (instancetype)serializerWithReadingOptions:(NSUInteger)readingOptions {
    RBKSocketDataResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;
    
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    return self;
}

#pragma mark - RBKSocketRequestSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:nil data:responseFrame error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }
    
    if (!responseFrame) {
        NSLog(@"Did not receive response frame");
        return nil;
    }
    
    if ([responseFrame isKindOfClass:[NSString class]]) {
        return [responseFrame dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    if ([responseFrame isKindOfClass:[NSData class]]) {
        if ([responseFrame length] <= 0) {
            NSLog(@"Did received response frame of 0 length");
            return nil;
        }
        return responseFrame;
    }

    NSLog(@"Unsupported response frame type %@ for serialization as data", NSStringFromClass([responseFrame class]));
    return nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.readingOptions = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(readingOptions))];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeInteger:self.readingOptions forKey:NSStringFromSelector(@selector(readingOptions))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketDataResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.readingOptions = self.readingOptions;
    
    return serializer;
}

@end

















#pragma mark -

@implementation RBKSocketJSONResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithReadingOptions:0];
}

+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions {
    RBKSocketJSONResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;

    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    return self;
}

#pragma mark - RBKSocketRequestSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:nil data:responseFrame error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }
    
    NSString *responseString;
    if ([responseFrame isKindOfClass:[NSString class]]) {
        responseString = responseFrame;
    }
    else {
        responseString = [[NSString alloc] initWithData:responseFrame encoding:NSUTF8StringEncoding];
    }

    if (responseString && ![responseString isEqualToString:@" "]) {
        // Workaround for a bug in NSJSONSerialization when Unicode character escape codes are used instead of the actual character
        // See http://stackoverflow.com/a/12843465/157142
        responseFrame = [responseString dataUsingEncoding:NSUTF8StringEncoding];

        if (responseFrame) {
            if ([responseFrame length] > 0) {
                return [NSJSONSerialization JSONObjectWithData:responseFrame options:self.readingOptions error:error];
            } else {
                return nil;
            }
        } else {
            NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
            [userInfo setValue:NSLocalizedStringFromTable(@"Data failed decoding as a UTF-8 string", nil, @"RBKNetworking") forKey:NSLocalizedDescriptionKey];
            [userInfo setValue:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not decode string: %@", nil, @"RBKNetworking"), responseString] forKey:NSLocalizedFailureReasonErrorKey];
            if (error) {
                *error = [[NSError alloc] initWithDomain:RBKSocketNetworkingErrorDomain code:NSURLErrorCannotDecodeContentData userInfo:userInfo];
            }
        }
    }

    return nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }

    self.readingOptions = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(readingOptions))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeInteger:self.readingOptions forKey:NSStringFromSelector(@selector(readingOptions))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketJSONResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.readingOptions = self.readingOptions;

    return serializer;
}

@end

#pragma mark -

@implementation RBKSocketXMLParserResponseSerializer

+ (instancetype)serializer {
    RBKSocketXMLParserResponseSerializer *serializer = [[self alloc] init];

    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    return self;
}

#pragma mark - RBKSocketURLResponseSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:nil data:responseFrame error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }

    return [[NSXMLParser alloc] initWithData:responseFrame];
}

@end

#pragma mark -

@implementation RBKSocketPropertyListResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithFormat:NSPropertyListXMLFormat_v1_0 readOptions:0];
}

+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format
                         readOptions:(NSPropertyListReadOptions)readOptions
{
    RBKSocketPropertyListResponseSerializer *serializer = [[self alloc] init];
    serializer.format = format;
    serializer.readOptions = readOptions;

    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    return self;
}

+ (NSSet *)acceptablePathExtensions {
    static NSSet * _acceptablePathExtension = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _acceptablePathExtension = [[NSSet alloc] initWithObjects:@"plist", nil];
    });

    return _acceptablePathExtension;
}

#pragma mark - RBKURLResponseSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:nil data:responseFrame error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }

    return [NSPropertyListSerialization propertyListWithData:responseFrame options:self.readOptions format:NULL error:error];
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }

    self.format = (NSPropertyListFormat)[decoder decodeIntegerForKey:NSStringFromSelector(@selector(format))];
    self.readOptions = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(readOptions))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeInteger:self.format forKey:NSStringFromSelector(@selector(format))];
    [coder encodeInteger:(NSInteger)self.readOptions forKey:NSStringFromSelector(@selector(readOptions))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketPropertyListResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.format = self.format;
    serializer.readOptions = self.readOptions;

    return serializer;
}

@end

#pragma mark -

@implementation RBKSocketStompResponseSerializer

+ (instancetype)serializer {
    return [self serializerWithReadingOptions:0];
}

+ (instancetype)serializerWithReadingOptions:(NSUInteger)readingOptions {
    RBKSocketStompResponseSerializer *serializer = [[self alloc] init];
    serializer.readingOptions = readingOptions;
    
    return serializer;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
        
    return self;
}

#pragma mark - RBKSocketRequestSerialization

- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error
{
    if (![self validateResponse:nil data:responseFrame error:error]) {
        if ([(NSError *)(*error) code] == NSURLErrorCannotDecodeContentData) {
            return nil;
        }
    }
    
    if (!responseFrame) {
        NSLog(@"Did not receive response frame");
        return nil;
    }
    
    if ([responseFrame isKindOfClass:[NSString class]]) {
        responseFrame = [responseFrame dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (![responseFrame isKindOfClass:[NSData class]]) {
        NSLog(@"Unsupported response frame type %@ for serialization as data", NSStringFromClass([responseFrame class]));
        return nil;
    }
    
    RBKStompFrame *stompFrame = [RBKStompFrame responseFrameFromData:responseFrame];
    
    [self.delegate heartbeatReceived]; // any time we receive a frame, consider it a heartbeat
    // if this is a MESSAGE frame then we need to tell our delegate so the response frame handler can be called
    if ([stompFrame.command isEqualToString:RBKStompCommandMessage]) {
        
        NSString *destination = [stompFrame headerValueForKey:RBKStompHeaderDestination];
        [self.delegate messageForDestination:destination responseFrame:stompFrame];
        
        // if we need to acknowledge it, then do so
        if ([self.delegate shouldAcknowledgeMessageForDestination:destination responseFrame:stompFrame]) {
            NSString *ackIdentifier = [stompFrame headerValueForKey:RBKStompHeaderAck];
            // Now we send our acknowledgement
            RBKStompFrame *acknowledgeFrame = [RBKStompFrame ackFrameWithIdentifier:ackIdentifier];
            [self.delegate sendAckOrNackFrame:acknowledgeFrame];
        } else if ([self.delegate shouldNackMessageForDestination:destination responseFrame:stompFrame]) {
            NSString *ackIdentifier = [stompFrame headerValueForKey:RBKStompHeaderAck];
            // Now we send our acknowledgement
            RBKStompFrame *nackFrame = [RBKStompFrame nackFrameWithIdentifier:ackIdentifier];
            [self.delegate sendAckOrNackFrame:nackFrame];
        }
    } else if ([stompFrame.command isEqualToString:RBKStompCommandConnected]) {
        // check our connected frame to see if we need to support a heartbeat
        NSString *heartbeatString = [stompFrame headerValueForKey:RBKStompHeaderHeartBeat];
        RBKStompHeartbeat heartbeat = RBKStompHeartbeatFromString(heartbeatString);
        if (heartbeat.desiredReceptionIntervalMinimum > 0) { // assume that we can support the desired interval
            // desiredReceptionIntervalMinimum is in milliseconds, but we'll deal in seconds
            // tell our delegate that we need to send a heartbeat every interval
            [self.delegate sendHeartbeatWithInterval:heartbeat.desiredReceptionIntervalMinimum / 1000.0];
        }
    }
    
    return stompFrame;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.readingOptions = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(readingOptions))];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    
    [coder encodeInteger:self.readingOptions forKey:NSStringFromSelector(@selector(readingOptions))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketDataResponseSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.readingOptions = self.readingOptions;
    
    return serializer;
}

@end
