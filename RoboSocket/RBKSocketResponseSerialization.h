// AFSerialization.h
//
// Copyright (c) 2013 AFNetworking (http://afnetworking.com)
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

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

#import "RBKStompFrame.h"

/**
 The `AFURLResponseSerialization` protocol is adopted by an object that decodes data into a more useful object representation, according to details in the server response. Response serializers may additionally perform validation on the incoming response and data.

 For example, a JSON response serializer may check for an acceptable status code (`2XX` range) and content type (`application/json`), decoding a valid JSON response into an object.
 */
@protocol RBKSocketResponseSerialization <NSObject, NSCoding, NSCopying>

/**
 The response object decoded from the data associated with a specified response.

 @param response The response to be processed.
 @param data The response data to be decoded.
 @param error The error that occurred while attempting to decode the response data.

 @return The object decoded from the specified response data.
 */
- (id)responseObjectForResponseFrame:(id)responseFrame
                               error:(NSError *__autoreleasing *)error;

@end

#pragma mark -

/**
 `AFHTTPResponseSerializer` conforms to the `AFURLRequestSerialization` & `AFURLResponseSerialization` protocols, offering a concrete base implementation of query string / URL form-encoded parameter serialization and default request headers, as well as response status code and content type validation.

 Any request or response serializer dealing with HTTP is encouraged to subclass `AFHTTPResponseSerializer` in order to ensure consistent default behavior.
 */
@interface RBKSocketResponseSerializer : NSObject <RBKSocketResponseSerialization>

/**
 The string encoding used to serialize parameters.
 */
@property (nonatomic, assign) NSStringEncoding stringEncoding;

/**
 Creates and returns a serializer with default configuration.
 */
+ (instancetype)serializer;

///-----------------------------------------
/// @name Configuring Response Serialization
///-----------------------------------------

/**
 The acceptable HTTP status codes for responses. When non-`nil`, responses with status codes not contained by the set will result in an error during validation.

 See http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
 */
@property (nonatomic, strong) NSIndexSet *acceptableStatusCodes;


/**
 Validates the specified response and data.

 In its base implementation, this method checks for an acceptable status code and content type. Subclasses may wish to add other domain-specific checks.

 @param response The response to be validated.
 @param data The data associated with the response.
 @param error The error that occurred while attempting to validate the response.

 @return `YES` if the response is valid, otherwise `NO`.
 */
- (BOOL)validateResponse:(NSHTTPURLResponse *)response
                    data:(NSData *)data
                   error:(NSError *__autoreleasing *)error;

@end

#pragma mark -


/**
 `RBKSocketStringResponseSerializer` is a subclass of `AFHTTPResponseSerializer` that validates and decodes NSString responses.
 */
@interface RBKSocketStringResponseSerializer : RBKSocketResponseSerializer

/**
 Options for reading the response NSString data and creating the Foundation objects.
 */
@property (nonatomic, assign) NSUInteger readingOptions;

/**
 Creates and returns a NSString serializer with specified reading and writing options.
 
 @param readingOptions The specified string reading options. `0` by default.
 */
+ (instancetype)serializerWithReadingOptions:(NSUInteger)readingOptions;

@end

/**
 `RBKSocketDataResponseSerializer` is a subclass of `AFHTTPResponseSerializer` that validates and decodes NSData responses.
 */
@interface RBKSocketDataResponseSerializer : RBKSocketResponseSerializer

/**
 Options for reading the response NSData data and creating the Foundation objects.
 */
@property (nonatomic, assign) NSInteger readingOptions;

/**
 Creates and returns a NSData serializer with specified reading and writing options.
 
 @param readingOptions The specified string reading options. `0` by default.
 */
+ (instancetype)serializerWithReadingOptions:(NSUInteger)readingOptions;

@end



/**
 `RBKSocketJSONResponseSerializer` is a subclass of `AFHTTPResponseSerializer` that validates and decodes JSON responses.

 */
@interface RBKSocketJSONResponseSerializer : RBKSocketResponseSerializer

/**
 Options for reading the response JSON data and creating the Foundation objects. For possible values, see the `NSJSONSerialization` documentation section "NSJSONReadingOptions". `0` by default.
 */
@property (nonatomic, assign) NSJSONReadingOptions readingOptions;

/**
 Creates and returns a JSON serializer with specified reading and writing options.

 @param readingOptions The specified JSON reading options.
 */
+ (instancetype)serializerWithReadingOptions:(NSJSONReadingOptions)readingOptions;

@end

#pragma mark -

/**
 `AFXMLParserSerializer` is a subclass of `AFHTTPResponseSerializer` that validates and decodes XML responses as an `NSXMLParser` objects.

 By default, `AFXMLParserSerializer` accepts the following MIME types, which includes the official standard, `application/xml`, as well as other commonly-used types:

 - `application/xml`
 - `text/xml`
 */
@interface RBKSocketXMLParserResponseSerializer : RBKSocketResponseSerializer

@end

#pragma mark -

/**
 `AFPropertyListSerializer` is a subclass of `AFHTTPResponseSerializer` that validates and decodes XML responses as an `NSXMLDocument` objects.

 By default, `AFPropertyListSerializer` accepts the following MIME types:

 - `application/x-plist`
 */
@interface RBKSocketPropertyListResponseSerializer : RBKSocketResponseSerializer

/**
 The property list format. Possible values are described in "NSPropertyListFormat".
 */
@property (nonatomic, assign) NSPropertyListFormat format;

/**
 The property list reading options. Possible values are described in "NSPropertyListMutabilityOptions."
 */
@property (nonatomic, assign) NSPropertyListReadOptions readOptions;

/**
 Creates and returns a property list serializer with a specified format, read options, and write options.

 @param format The property list format.
 @param readOptions The property list reading options.
 */
+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format
                         readOptions:(NSPropertyListReadOptions)readOptions;

@end

#pragma mark -

@protocol RBKSocketStompResponseSerializerDelegate <NSObject>

- (void)messageForDestination:(NSString *)destination responseFrame:(RBKStompFrame *)responseFrame;

@end

/**
 `RBKSocketStompResponseSerializer` is a subclass of `RBKSocketResponseSerializer` that validates and decodes STOMP responses.
 
 */
@interface RBKSocketStompResponseSerializer : RBKSocketResponseSerializer

/**
 The delegate used to call subscription handlers
 */
@property (weak, nonatomic) id<RBKSocketStompResponseSerializerDelegate> delegate;

/**
 The property list format. Possible values are described in "NSPropertyListFormat".
 */
@property (nonatomic, assign) NSPropertyListFormat format;

/**
 The STOMP reading options.
 */
@property (nonatomic, assign) NSUInteger readingOptions;

/**
 Creates and returns a STOMP serializer with specified reading and writing options.
 
 @param readingOptions The specified string reading options. `0` by default.
 */
+ (instancetype)serializerWithReadingOptions:(NSUInteger)readingOptions;

@end

