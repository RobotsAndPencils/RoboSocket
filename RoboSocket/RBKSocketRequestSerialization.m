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

#import "RBKSocketRequestSerialization.h"
#import "RBKSocketOperation.h"
#import "RBKStompFrame.h"

typedef NSString * (^RBKQueryStringSerializationBlock)(NSURLRequest *request, NSDictionary *parameters, NSError *__autoreleasing *error);

static NSString * RBKBase64EncodedStringFromString(NSString *string) {
    NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    NSUInteger length = [data length];
    NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];

    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];

    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }

        static uint8_t const kRBKBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kRBKBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kRBKBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kRBKBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kRBKBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }

    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

static NSString * const kRBKCharactersToBeEscapedInQueryString = @":/?&=;+!@#$()',*";

static NSString * RBKPercentEscapedQueryStringKeyFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
    static NSString * const kRBKCharactersToLeaveUnescapedInQueryStringPairKey = @"[].";

	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, (__bridge CFStringRef)kRBKCharactersToLeaveUnescapedInQueryStringPairKey, (__bridge CFStringRef)kRBKCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

static NSString * RBKPercentEscapedQueryStringValueFromStringWithEncoding(NSString *string, NSStringEncoding encoding) {
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)string, NULL, (__bridge CFStringRef)kRBKCharactersToBeEscapedInQueryString, CFStringConvertNSStringEncodingToEncoding(encoding));
}

#pragma mark -

@interface RBKQueryStringPair : NSObject
@property (readwrite, nonatomic, strong) id field;
@property (readwrite, nonatomic, strong) id value;

- (id)initWithField:(id)field value:(id)value;

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding;
@end

@implementation RBKQueryStringPair

- (id)initWithField:(id)field value:(id)value {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.field = field;
    self.value = value;

    return self;
}

- (NSString *)URLEncodedStringValueWithEncoding:(NSStringEncoding)stringEncoding {
    if (!self.value || [self.value isEqual:[NSNull null]]) {
        return RBKPercentEscapedQueryStringKeyFromStringWithEncoding([self.field description], stringEncoding);
    } else {
        return [NSString stringWithFormat:@"%@=%@", RBKPercentEscapedQueryStringKeyFromStringWithEncoding([self.field description], stringEncoding), RBKPercentEscapedQueryStringValueFromStringWithEncoding([self.value description], stringEncoding)];
    }
}

@end

#pragma mark -

extern NSArray * RBKQueryStringPairsFromDictionary(NSDictionary *dictionary);
extern NSArray * RBKQueryStringPairsFromKeyAndValue(NSString *key, id value);

//static NSString * RBKQueryStringFromParametersWithEncoding(NSDictionary *parameters, NSStringEncoding stringEncoding) {
//    NSMutableArray *mutablePairs = [NSMutableArray array];
//    for (RBKQueryStringPair *pair in RBKQueryStringPairsFromDictionary(parameters)) {
//        [mutablePairs addObject:[pair URLEncodedStringValueWithEncoding:stringEncoding]];
//    }
//
//    return [mutablePairs componentsJoinedByString:@"&"];
//}

NSArray * RBKQueryStringPairsFromDictionary(NSDictionary *dictionary) {
    return RBKQueryStringPairsFromKeyAndValue(nil, dictionary);
}

NSArray * RBKQueryStringPairsFromKeyAndValue(NSString *key, id value) {
    NSMutableArray *mutableQueryStringComponents = [NSMutableArray array];

    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dictionary = value;
        // Sort dictionary keys to ensure consistent ordering in query string, which is important when deserializing potentially ambiguous sequences, such as an array of dictionaries
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"description" ascending:YES selector:@selector(caseInsensitiveCompare:)];
        for (id nestedKey in [dictionary.allKeys sortedArrayUsingDescriptors:@[ sortDescriptor ]]) {
            id nestedValue = [dictionary objectForKey:nestedKey];
            if (nestedValue) {
                [mutableQueryStringComponents addObjectsFromArray:RBKQueryStringPairsFromKeyAndValue((key ? [NSString stringWithFormat:@"%@[%@]", key, nestedKey] : nestedKey), nestedValue)];
            }
        }
    } else if ([value isKindOfClass:[NSArray class]]) {
        NSArray *array = value;
        for (id nestedValue in array) {
            [mutableQueryStringComponents addObjectsFromArray:RBKQueryStringPairsFromKeyAndValue([NSString stringWithFormat:@"%@[]", key], nestedValue)];
        }
    } else if ([value isKindOfClass:[NSSet class]]) {
        NSSet *set = value;
        for (id obj in set) {
            [mutableQueryStringComponents addObjectsFromArray:RBKQueryStringPairsFromKeyAndValue(key, obj)];
        }
    } else {
        [mutableQueryStringComponents addObject:[[RBKQueryStringPair alloc] initWithField:key value:value]];
    }
    
    return mutableQueryStringComponents;
}

#pragma mark -

@interface RBKSocketStreamingMultipartFormData : NSObject <RBKMultipartFormData>
- (instancetype)initWithURLRequest:(NSMutableURLRequest *)urlRequest
                    stringEncoding:(NSStringEncoding)encoding;

- (NSMutableURLRequest *)requestByFinalizingMultipartFormData;
@end

#pragma mark -

@interface RBKSocketRequestSerializer ()
@property (readwrite, nonatomic, strong) NSMutableDictionary *mutableHTTPRequestHeaders;
@property (readwrite, nonatomic, assign) RBKSocketRequestQueryStringSerializationStyle queryStringSerializationStyle;
@property (readwrite, nonatomic, copy) RBKQueryStringSerializationBlock queryStringSerialization;
@end

@implementation RBKSocketRequestSerializer

+ (instancetype)serializer {
    return [[self alloc] init];
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.stringEncoding = NSUTF8StringEncoding;

    self.mutableHTTPRequestHeaders = [NSMutableDictionary dictionary];

    // Accept-Language HTTP Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.4
    NSMutableArray *acceptLanguagesComponents = [NSMutableArray array];
    [[NSLocale preferredLanguages] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        float q = 1.0f - (idx * 0.1f);
        [acceptLanguagesComponents addObject:[NSString stringWithFormat:@"%@;q=%0.1g", obj, q]];
        *stop = q <= 0.5f;
    }];
    [self setValue:[acceptLanguagesComponents componentsJoinedByString:@", "] forHTTPHeaderField:@"Accept-Language"];

    NSString *userAgent = nil;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
#if defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    // User-Agent Header; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html#sec14.43
    userAgent = [NSString stringWithFormat:@"%@/%@ (%@; iOS %@; Scale/%0.2f)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleExecutableKey] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey], (__bridge id)CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), kCFBundleVersionKey) ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey], [[UIDevice currentDevice] model], [[UIDevice currentDevice] systemVersion], ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f)];
#elif defined(__MAC_OS_X_VERSION_MIN_REQUIRED)
    userAgent = [NSString stringWithFormat:@"%@/%@ (Mac OS X %@)", [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleExecutableKey] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleIdentifierKey], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"] ?: [[[NSBundle mainBundle] infoDictionary] objectForKey:(__bridge NSString *)kCFBundleVersionKey], [[NSProcessInfo processInfo] operatingSystemVersionString]];
#endif
#pragma clang diagnostic pop
    if (userAgent) {
        if (![userAgent canBeConvertedToEncoding:NSASCIIStringEncoding]) {
            NSMutableString *mutableUserAgent = [userAgent mutableCopy];
            CFStringTransform((__bridge CFMutableStringRef)(mutableUserAgent), NULL, (__bridge CFStringRef)@"Any-Latin; Latin-ASCII; [:^ASCII:] Remove", false);
            userAgent = mutableUserAgent;
        }
        [self setValue:userAgent forHTTPHeaderField:@"User-Agent"];
    }

    // HTTP Method Definitions; see http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html
    self.HTTPMethodsEncodingParametersInURI = [NSSet setWithObjects:@"GET", @"HEAD", @"DELETE", nil];

    return self;
}

#pragma mark -

- (NSDictionary *)HTTPRequestHeaders {
    return [NSDictionary dictionaryWithDictionary:self.mutableHTTPRequestHeaders];
}

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
	[self.mutableHTTPRequestHeaders setValue:value forKey:field];
}

- (void)setAuthorizationHeaderFieldWithUsername:(NSString *)username password:(NSString *)password {
	NSString *basicAuthCredentials = [NSString stringWithFormat:@"%@:%@", username, password];
    [self setValue:[NSString stringWithFormat:@"Basic %@", RBKBase64EncodedStringFromString(basicAuthCredentials)] forHTTPHeaderField:@"Authorization"];
}

- (void)setAuthorizationHeaderFieldWithToken:(NSString *)token {
    [self setValue:[NSString stringWithFormat:@"Token token=\"%@\"", token] forHTTPHeaderField:@"Authorization"];
}

- (void)clearAuthorizationHeader {
	[self.mutableHTTPRequestHeaders removeObjectForKey:@"Authorization"];
}

#pragma mark -

- (void)setQueryStringSerializationWithStyle:(RBKSocketRequestQueryStringSerializationStyle)style {
    self.queryStringSerializationStyle = style;
    self.queryStringSerialization = nil;
}

- (void)setQueryStringSerializationWithBlock:(NSString *(^)(NSURLRequest *, NSDictionary *, NSError *__autoreleasing *))block {
    self.queryStringSerialization = block;
}

#pragma mark -

- (RBKSocketOperation *)requestOperationWithFrame:(id)frame expectResponse:(BOOL)expectResponse {
    RBKSocketOperation *request = [[RBKSocketOperation alloc] initWithRequestFrame:frame];
    NSParameterAssert(frame);

    request = [self requestBySerializingRequest:request expectResponse:expectResponse withParameters:nil error:nil];
    return request;

}

#pragma mark - RBKURLRequestSerialization

- (RBKSocketOperation *)requestBySerializingRequest:(RBKSocketOperation *)request
                                     expectResponse:(BOOL)expectResponse
                                     withParameters:(NSDictionary *)parameters
                                              error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(request);

    // DWA: not sure if this is even needed as a base implementation
    
//    NSMutableURLRequest *mutableRequest = [request mutableCopy];
//
//    [self.HTTPRequestHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
//        if (![request valueForHTTPHeaderField:field]) {
//            [mutableRequest setValue:value forHTTPHeaderField:field];
//        }
//    }];
//
//    if (!parameters) {
//        return mutableRequest;
//    }
//
//    NSString *query = nil;
//    if (self.queryStringSerialization) {
//        query = self.queryStringSerialization(request, parameters, error);
//    } else {
//        switch (self.queryStringSerializationStyle) {
//            case RBKSocketRequestQueryStringDefaultStyle:
//                query = RBKQueryStringFromParametersWithEncoding(parameters, self.stringEncoding);
//                break;
//            default:
//                break;
//        }
//    }
//
//    if ([self.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
//        mutableRequest.URL = [NSURL URLWithString:[[mutableRequest.URL absoluteString] stringByAppendingFormat:mutableRequest.URL.query ? @"&%@" : @"?%@", RBKQueryStringFromParametersWithEncoding(parameters, self.stringEncoding)]];
//    } else {
//        NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(self.stringEncoding));
//        [mutableRequest setValue:[NSString stringWithFormat:@"application/x-www-form-urlencoded; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
//        [mutableRequest setHTTPBody:[query dataUsingEncoding:self.stringEncoding]];
//    }

    NSLog(@"DWA: need to build our request correctly");
    
    return nil; // mutableRequest;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [self init];
    if (!self) {
        return nil;
    }

    self.mutableHTTPRequestHeaders = [decoder decodeObjectForKey:NSStringFromSelector(@selector(mutableHTTPRequestHeaders))];
    self.queryStringSerializationStyle = (RBKSocketRequestQueryStringSerializationStyle)[decoder decodeIntegerForKey:NSStringFromSelector(@selector(queryStringSerializationStyle))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.mutableHTTPRequestHeaders forKey:NSStringFromSelector(@selector(mutableHTTPRequestHeaders))];
    [coder encodeInteger:self.queryStringSerializationStyle forKey:NSStringFromSelector(@selector(queryStringSerializationStyle))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketRequestSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.mutableHTTPRequestHeaders = [self.mutableHTTPRequestHeaders mutableCopyWithZone:zone];
    serializer.queryStringSerializationStyle = self.queryStringSerializationStyle;
    serializer.queryStringSerialization = self.queryStringSerialization;
    
    return serializer;
}

@end

#pragma mark -

static NSString * const kRBKMultipartFormBoundary = @"Boundary+0xAbCdEfGbOuNdArY";

static NSString * const kRBKMultipartFormCRLF = @"\r\n";

static NSInteger const kRBKStreamToStreamBufferSize = 1024 * 1024; //1 meg default

static inline NSString * RBKMultipartFormInitialBoundary() {
    return [NSString stringWithFormat:@"--%@%@", kRBKMultipartFormBoundary, kRBKMultipartFormCRLF];
}

static inline NSString * RBKMultipartFormEncapsulationBoundary() {
    return [NSString stringWithFormat:@"%@--%@%@", kRBKMultipartFormCRLF, kRBKMultipartFormBoundary, kRBKMultipartFormCRLF];
}

static inline NSString * RBKMultipartFormFinalBoundary() {
    return [NSString stringWithFormat:@"%@--%@--%@", kRBKMultipartFormCRLF, kRBKMultipartFormBoundary, kRBKMultipartFormCRLF];
}

static inline NSString * RBKContentTypeForPathExtension(NSString *extension) {
#ifdef __UTTYPE__
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
    if (!contentType) {
        return @"application/octet-stream";
    } else {
        return contentType;
    }
#else
    return @"application/octet-stream";
#endif
}

NSUInteger const kRBKUploadStream3GSuggestedPacketSize = 1024 * 16;
NSTimeInterval const kRBKUploadStream3GSuggestedDelay = 0.2;

@interface RBKSocketBodyPart : NSObject
@property (nonatomic, assign) NSStringEncoding stringEncoding;
@property (nonatomic, strong) NSDictionary *headers;
@property (nonatomic, strong) id body;
@property (nonatomic, assign) unsigned long long bodyContentLength;
@property (nonatomic, strong) NSInputStream *inputStream;

@property (nonatomic, assign) BOOL hasInitialBoundary;
@property (nonatomic, assign) BOOL hasFinalBoundary;

@property (nonatomic, readonly, getter = hasBytesAvailable) BOOL bytesAvailable;
@property (nonatomic, readonly) unsigned long long contentLength;

- (NSInteger)read:(uint8_t *)buffer
        maxLength:(NSUInteger)length;
@end

@interface RBKSocketMultipartBodyStream : NSInputStream <NSStreamDelegate>
@property (nonatomic, assign) NSUInteger numberOfBytesInPacket;
@property (nonatomic, assign) NSTimeInterval delay;
@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic, readonly) unsigned long long contentLength;
@property (nonatomic, readonly, getter = isEmpty) BOOL empty;

- (id)initWithStringEncoding:(NSStringEncoding)encoding;
- (void)setInitialAndFinalBoundaries;
- (void)appendHTTPBodyPart:(RBKSocketBodyPart *)bodyPart;
@end

#pragma mark -

@interface RBKSocketStreamingMultipartFormData ()
@property (readwrite, nonatomic, copy) NSMutableURLRequest *request;
@property (readwrite, nonatomic, strong) RBKSocketMultipartBodyStream *bodyStream;
@property (readwrite, nonatomic, assign) NSStringEncoding stringEncoding;
@end

@implementation RBKSocketStreamingMultipartFormData

- (id)initWithURLRequest:(NSMutableURLRequest *)urlRequest
          stringEncoding:(NSStringEncoding)encoding
{
    self = [super init];
    if (!self) {
        return nil;
    }

    self.request = urlRequest;
    self.stringEncoding = encoding;
    self.bodyStream = [[RBKSocketMultipartBodyStream alloc] initWithStringEncoding:encoding];

    return self;
}

- (BOOL)appendPartWithFileURL:(NSURL *)fileURL
                         name:(NSString *)name
                        error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(fileURL);
    NSParameterAssert(name);

    NSString *fileName = [fileURL lastPathComponent];
    NSString *mimeType = RBKContentTypeForPathExtension([fileURL pathExtension]);

    return [self appendPartWithFileURL:fileURL name:name fileName:fileName mimeType:mimeType error:error];
}

- (BOOL)appendPartWithFileURL:(NSURL *)fileURL
                         name:(NSString *)name
                     fileName:(NSString *)fileName
                     mimeType:(NSString *)mimeType
                        error:(NSError * __autoreleasing *)error
{
    NSParameterAssert(fileURL);
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);

    if (![fileURL isFileURL]) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"Expected URL to be a file URL", @"RBKNetworking", nil) forKey:NSLocalizedFailureReasonErrorKey];
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:RBKSocketNetworkingErrorDomain code:NSURLErrorBadURL userInfo:userInfo];
        }

        return NO;
    } else if ([fileURL checkResourceIsReachableAndReturnError:error] == NO) {
        NSDictionary *userInfo = [NSDictionary dictionaryWithObject:NSLocalizedStringFromTable(@"File URL not reachable.", @"RBKNetworking", nil) forKey:NSLocalizedFailureReasonErrorKey];
        if (error != NULL) {
            *error = [[NSError alloc] initWithDomain:RBKSocketNetworkingErrorDomain code:NSURLErrorBadURL userInfo:userInfo];
        }

        return NO;
    }

    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];

    RBKSocketBodyPart *bodyPart = [[RBKSocketBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = mutableHeaders;
    bodyPart.body = fileURL;

    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[fileURL path] error:nil];
    bodyPart.bodyContentLength = [[fileAttributes objectForKey:NSFileSize] unsignedLongLongValue];

    [self.bodyStream appendHTTPBodyPart:bodyPart];

    return YES;
}


- (void)appendPartWithInputStream:(NSInputStream *)inputStream
                             name:(NSString *)name
                         fileName:(NSString *)fileName
                           length:(int64_t)length
                         mimeType:(NSString *)mimeType
{
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);

    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];


    RBKSocketBodyPart *bodyPart = [[RBKSocketBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = mutableHeaders;
    bodyPart.body = inputStream;

    bodyPart.bodyContentLength = length;

    [self.bodyStream appendHTTPBodyPart:bodyPart];
}

- (void)appendPartWithFileData:(NSData *)data
                          name:(NSString *)name
                      fileName:(NSString *)fileName
                      mimeType:(NSString *)mimeType
{
    NSParameterAssert(name);
    NSParameterAssert(fileName);
    NSParameterAssert(mimeType);

    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"; filename=\"%@\"", name, fileName] forKey:@"Content-Disposition"];
    [mutableHeaders setValue:mimeType forKey:@"Content-Type"];

    [self appendPartWithHeaders:mutableHeaders body:data];
}

- (void)appendPartWithFormData:(NSData *)data
                          name:(NSString *)name
{
    NSParameterAssert(name);

    NSMutableDictionary *mutableHeaders = [NSMutableDictionary dictionary];
    [mutableHeaders setValue:[NSString stringWithFormat:@"form-data; name=\"%@\"", name] forKey:@"Content-Disposition"];

    [self appendPartWithHeaders:mutableHeaders body:data];
}

- (void)appendPartWithHeaders:(NSDictionary *)headers
                         body:(NSData *)body
{
    NSParameterAssert(body);

    RBKSocketBodyPart *bodyPart = [[RBKSocketBodyPart alloc] init];
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = headers;
    bodyPart.bodyContentLength = [body length];
    bodyPart.body = body;

    [self.bodyStream appendHTTPBodyPart:bodyPart];
}

- (void)throttleBandwidthWithPacketSize:(NSUInteger)numberOfBytes
                                  delay:(NSTimeInterval)delay
{
    self.bodyStream.numberOfBytesInPacket = numberOfBytes;
    self.bodyStream.delay = delay;
}

- (NSMutableURLRequest *)requestByFinalizingMultipartFormData {
    if ([self.bodyStream isEmpty]) {
        return self.request;
    }

    // Reset the initial and final boundaries to ensure correct Content-Length
    [self.bodyStream setInitialAndFinalBoundaries];
    [self.request setHTTPBodyStream:self.bodyStream];

    [self.request setValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@", kRBKMultipartFormBoundary] forHTTPHeaderField:@"Content-Type"];
    [self.request setValue:[NSString stringWithFormat:@"%llu", [self.bodyStream contentLength]] forHTTPHeaderField:@"Content-Length"];

    return self.request;
}

@end

#pragma mark -

@interface RBKSocketMultipartBodyStream () <NSCopying>
@property (nonatomic, assign) NSStreamStatus streamStatus;
@property (nonatomic, strong) NSError *streamError;
@property (nonatomic, assign) NSStringEncoding stringEncoding;
@property (nonatomic, strong) NSMutableArray *HTTPBodyParts;
@property (nonatomic, strong) NSEnumerator *HTTPBodyPartEnumerator;
@property (nonatomic, strong) RBKSocketBodyPart *currentHTTPBodyPart;
@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, strong) NSMutableData *buffer;
@end

@implementation RBKSocketMultipartBodyStream

- (id)initWithStringEncoding:(NSStringEncoding)encoding {
    self = [super init];
    if (!self) {
        return nil;
    }

    self.stringEncoding = encoding;
    self.HTTPBodyParts = [NSMutableArray array];
    self.numberOfBytesInPacket = NSIntegerMax;

    return self;
}

- (void)setInitialAndFinalBoundaries {
    if ([self.HTTPBodyParts count] > 0) {
        for (RBKSocketBodyPart *bodyPart in self.HTTPBodyParts) {
            bodyPart.hasInitialBoundary = NO;
            bodyPart.hasFinalBoundary = NO;
        }

        [[self.HTTPBodyParts objectAtIndex:0] setHasInitialBoundary:YES];
        [[self.HTTPBodyParts lastObject] setHasFinalBoundary:YES];
    }
}

- (void)appendHTTPBodyPart:(RBKSocketBodyPart *)bodyPart {
    [self.HTTPBodyParts addObject:bodyPart];
}

- (BOOL)isEmpty {
    return [self.HTTPBodyParts count] == 0;
}

#pragma mark - NSInputStream

- (NSInteger)read:(uint8_t *)buffer
        maxLength:(NSUInteger)length
{
    if ([self streamStatus] == NSStreamStatusClosed) {
        return 0;
    }

    NSInteger totalNumberOfBytesRead = 0;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    while ((NSUInteger)totalNumberOfBytesRead < MIN(length, self.numberOfBytesInPacket)) {
        if (!self.currentHTTPBodyPart || ![self.currentHTTPBodyPart hasBytesAvailable]) {
            if (!(self.currentHTTPBodyPart = [self.HTTPBodyPartEnumerator nextObject])) {
                break;
            }
        } else {
            NSUInteger maxLength = length - (NSUInteger)totalNumberOfBytesRead;
            NSInteger numberOfBytesRead = [self.currentHTTPBodyPart read:&buffer[totalNumberOfBytesRead] maxLength:maxLength];
            if (numberOfBytesRead == -1) {
                self.streamError = self.currentHTTPBodyPart.inputStream.streamError;
                break;
            } else {
                totalNumberOfBytesRead += numberOfBytesRead;

                if (self.delay > 0.0f) {
                    [NSThread sleepForTimeInterval:self.delay];
                }
            }
        }
    }
#pragma clang diagnostic pop

    return totalNumberOfBytesRead;
}

- (BOOL)getBuffer:(__unused uint8_t **)buffer
           length:(__unused NSUInteger *)len
{
    return NO;
}

- (BOOL)hasBytesAvailable {
    return [self streamStatus] == NSStreamStatusOpen;
}

#pragma mark - NSStream

- (void)open {
    if (self.streamStatus == NSStreamStatusOpen) {
        return;
    }

    self.streamStatus = NSStreamStatusOpen;

    [self setInitialAndFinalBoundaries];
    self.HTTPBodyPartEnumerator = [self.HTTPBodyParts objectEnumerator];
}

- (void)close {
    self.streamStatus = NSStreamStatusClosed;
}

- (id)propertyForKey:(__unused NSString *)key {
    return nil;
}

- (BOOL)setProperty:(__unused id)property
             forKey:(__unused NSString *)key
{
    return NO;
}

- (void)scheduleInRunLoop:(__unused NSRunLoop *)aRunLoop
                  forMode:(__unused NSString *)mode
{}

- (void)removeFromRunLoop:(__unused NSRunLoop *)aRunLoop
                  forMode:(__unused NSString *)mode
{}

- (unsigned long long)contentLength {
    unsigned long long length = 0;
    for (RBKSocketBodyPart *bodyPart in self.HTTPBodyParts) {
        length += [bodyPart contentLength];
    }

    return length;
}

#pragma mark - Undocumented CFReadStream Bridged Methods

- (void)_scheduleInCFRunLoop:(__unused CFRunLoopRef)aRunLoop
                     forMode:(__unused CFStringRef)aMode
{}

- (void)_unscheduleFromCFRunLoop:(__unused CFRunLoopRef)aRunLoop
                         forMode:(__unused CFStringRef)aMode
{}

- (BOOL)_setCFClientFlags:(__unused CFOptionFlags)inFlags
                 callback:(__unused CFReadStreamClientCallBack)inCallback
                  context:(__unused CFStreamClientContext *)inContext {
    return NO;
}

#pragma mark - NSCopying

-(id)copyWithZone:(NSZone *)zone {
    RBKSocketMultipartBodyStream *bodyStreamCopy = [[[self class] allocWithZone:zone] initWithStringEncoding:self.stringEncoding];

    for (RBKSocketBodyPart *bodyPart in self.HTTPBodyParts) {
        [bodyStreamCopy appendHTTPBodyPart:[bodyPart copy]];
    }

    [bodyStreamCopy setInitialAndFinalBoundaries];

    return bodyStreamCopy;
}

@end

#pragma mark -

typedef enum {
    RBKEncapsulationBoundaryPhase = 1,
    RBKHeaderPhase                = 2,
    RBKBodyPhase                  = 3,
    RBKFinalBoundaryPhase         = 4,
} RBKHTTPBodyPartReadPhase;

@interface RBKSocketBodyPart () <NSCopying> {
    RBKHTTPBodyPartReadPhase _phase;
    NSInputStream *_inputStream;
    unsigned long long _phaseReadOffset;
}

- (BOOL)transitionToNextPhase;
- (NSInteger)readData:(NSData *)data
           intoBuffer:(uint8_t *)buffer
            maxLength:(NSUInteger)length;
@end

@implementation RBKSocketBodyPart

- (id)init {
    self = [super init];
    if (!self) {
        return nil;
    }

    [self transitionToNextPhase];

    return self;
}

- (void)dealloc {
    if (_inputStream) {
        [_inputStream close];
        _inputStream = nil;
    }
}

- (NSInputStream *)inputStream {
    if (!_inputStream) {
        if ([self.body isKindOfClass:[NSData class]]) {
            _inputStream = [NSInputStream inputStreamWithData:self.body];
        } else if ([self.body isKindOfClass:[NSURL class]]) {
            _inputStream = [NSInputStream inputStreamWithURL:self.body];
        } else if ([self.body isKindOfClass:[NSInputStream class]]) {
            _inputStream = self.body;
        }
    }

    return _inputStream;
}

- (NSString *)stringForHeaders {
    NSMutableString *headerString = [NSMutableString string];
    for (NSString *field in [self.headers allKeys]) {
        [headerString appendString:[NSString stringWithFormat:@"%@: %@%@", field, [self.headers valueForKey:field], kRBKMultipartFormCRLF]];
    }
    [headerString appendString:kRBKMultipartFormCRLF];

    return [NSString stringWithString:headerString];
}

- (unsigned long long)contentLength {
    unsigned long long length = 0;

    NSData *encapsulationBoundaryData = [([self hasInitialBoundary] ? RBKMultipartFormInitialBoundary() : RBKMultipartFormEncapsulationBoundary()) dataUsingEncoding:self.stringEncoding];
    length += [encapsulationBoundaryData length];

    NSData *headersData = [[self stringForHeaders] dataUsingEncoding:self.stringEncoding];
    length += [headersData length];

    length += _bodyContentLength;

    NSData *closingBoundaryData = ([self hasFinalBoundary] ? [RBKMultipartFormFinalBoundary() dataUsingEncoding:self.stringEncoding] : [NSData data]);
    length += [closingBoundaryData length];

    return length;
}

- (BOOL)hasBytesAvailable {
    // Allows `read:maxLength:` to be called again if `RBKMultipartFormFinalBoundary` doesn't fit into the available buffer
    if (_phase == RBKFinalBoundaryPhase) {
        return YES;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcovered-switch-default"
    switch (self.inputStream.streamStatus) {
        case NSStreamStatusNotOpen:
        case NSStreamStatusOpening:
        case NSStreamStatusOpen:
        case NSStreamStatusReading:
        case NSStreamStatusWriting:
            return YES;
        case NSStreamStatusAtEnd:
        case NSStreamStatusClosed:
        case NSStreamStatusError:
        default:
            return NO;
    }
#pragma clang diagnostic pop
}

- (NSInteger)read:(uint8_t *)buffer
        maxLength:(NSUInteger)length
{
    NSInteger totalNumberOfBytesRead = 0;

    if (_phase == RBKEncapsulationBoundaryPhase) {
        NSData *encapsulationBoundaryData = [([self hasInitialBoundary] ? RBKMultipartFormInitialBoundary() : RBKMultipartFormEncapsulationBoundary()) dataUsingEncoding:self.stringEncoding];
        totalNumberOfBytesRead += [self readData:encapsulationBoundaryData intoBuffer:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
    }

    if (_phase == RBKHeaderPhase) {
        NSData *headersData = [[self stringForHeaders] dataUsingEncoding:self.stringEncoding];
        totalNumberOfBytesRead += [self readData:headersData intoBuffer:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
    }

    if (_phase == RBKBodyPhase) {
        NSInteger numberOfBytesRead = 0;

        numberOfBytesRead = [self.inputStream read:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
        if (numberOfBytesRead == -1) {
            return -1;
        } else {
            totalNumberOfBytesRead += numberOfBytesRead;

            if ([self.inputStream streamStatus] >= NSStreamStatusAtEnd) {
                [self transitionToNextPhase];
            }
        }
    }

    if (_phase == RBKFinalBoundaryPhase) {
        NSData *closingBoundaryData = ([self hasFinalBoundary] ? [RBKMultipartFormFinalBoundary() dataUsingEncoding:self.stringEncoding] : [NSData data]);
        totalNumberOfBytesRead += [self readData:closingBoundaryData intoBuffer:&buffer[totalNumberOfBytesRead] maxLength:(length - (NSUInteger)totalNumberOfBytesRead)];
    }

    return totalNumberOfBytesRead;
}

- (NSInteger)readData:(NSData *)data
           intoBuffer:(uint8_t *)buffer
            maxLength:(NSUInteger)length
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    NSRange range = NSMakeRange((NSUInteger)_phaseReadOffset, MIN([data length] - ((NSUInteger)_phaseReadOffset), length));
    [data getBytes:buffer range:range];
#pragma clang diagnostic pop

    _phaseReadOffset += range.length;

    if (((NSUInteger)_phaseReadOffset) >= [data length]) {
        [self transitionToNextPhase];
    }

    return (NSInteger)range.length;
}

- (BOOL)transitionToNextPhase {
    if (![[NSThread currentThread] isMainThread]) {
        [self performSelectorOnMainThread:@selector(transitionToNextPhase) withObject:nil waitUntilDone:YES];
        return YES;
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wcovered-switch-default"
    switch (_phase) {
        case RBKEncapsulationBoundaryPhase:
            _phase = RBKHeaderPhase;
            break;
        case RBKHeaderPhase:
            [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
            [self.inputStream open];
            _phase = RBKBodyPhase;
            break;
        case RBKBodyPhase:
            [self.inputStream close];
            _phase = RBKFinalBoundaryPhase;
            break;
        case RBKFinalBoundaryPhase:
        default:
            _phase = RBKEncapsulationBoundaryPhase;
            break;
    }
    _phaseReadOffset = 0;
#pragma clang diagnostic pop

    return YES;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKSocketBodyPart *bodyPart = [[[self class] allocWithZone:zone] init];
    
    bodyPart.stringEncoding = self.stringEncoding;
    bodyPart.headers = self.headers;
    bodyPart.bodyContentLength = self.bodyContentLength;
    bodyPart.body = self.body;
    
    return bodyPart;
}

@end




#pragma mark -

@implementation RBKSocketStringRequestSerializer

+ (instancetype)serializer {
    return [self serializerWithWritingOptions:0];
}

+ (instancetype)serializerWithWritingOptions:(NSUInteger)writingOptions
{
    RBKSocketStringRequestSerializer *serializer = [[self alloc] init];
    serializer.writingOptions = writingOptions;
    
    return serializer;
}

#pragma mark - RBKURLRequestSerialization

- (RBKSocketOperation *)requestBySerializingRequest:(RBKSocketOperation *)request
                                     expectResponse:(BOOL)expectResponse
                                     withParameters:(NSDictionary *)parameters
                                              error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(request);
    
    id frame = request.requestFrame;
    
    if ([frame isKindOfClass:[NSString class]]) {
        return request;
    }
    
    if ([frame isKindOfClass:[NSData class]]) {
        NSString *frameAsString = [[NSString alloc] initWithData:frame encoding:NSUTF8StringEncoding];;
        return [[RBKSocketOperation alloc] initWithRequestFrame:frameAsString expectResponse:expectResponse];
    }
    
    // not sure how to (or if we should) coerce other formats into a string
    NSLog(@"Unsupported request frame type %@ for serialization as a string", NSStringFromClass([frame class]));
    return nil;
}

@end






#pragma mark -

@implementation RBKSocketDataRequestSerializer

+ (instancetype)serializer {
    return [self serializerWithWritingOptions:0];
}

+ (instancetype)serializerWithWritingOptions:(NSUInteger)writingOptions
{
    RBKSocketDataRequestSerializer *serializer = [[self alloc] init];
    serializer.writingOptions = writingOptions;
    
    return serializer;
}

#pragma mark - RBKURLRequestSerialization

- (RBKSocketOperation *)requestBySerializingRequest:(RBKSocketOperation *)request
                                     expectResponse:(BOOL)expectResponse
                                     withParameters:(NSDictionary *)parameters
                                              error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(request);
    
    id frame = request.requestFrame;
    
    if ([frame isKindOfClass:[NSData class]]) {
        return request;
    }
    
    if ([frame isKindOfClass:[NSString class]]) {
        NSData *frameAsData = [frame dataUsingEncoding:NSUTF8StringEncoding];
        return [[RBKSocketOperation alloc] initWithRequestFrame:frameAsData expectResponse:expectResponse];
    }
    
    // not sure how to (or if we should) coerce other formats into a string
    NSLog(@"Unsupported request frame type %@ for serialization as data", NSStringFromClass([frame class]));
    return nil;
}

@end








#pragma mark -

@implementation RBKSocketJSONRequestSerializer

+ (instancetype)serializer {
    return [self serializerWithWritingOptions:0];
}

+ (instancetype)serializerWithWritingOptions:(NSJSONWritingOptions)writingOptions
{
    RBKSocketJSONRequestSerializer *serializer = [[self alloc] init];
    serializer.writingOptions = writingOptions;

    return serializer;
}

#pragma mark - RBKURLRequestSerialization

- (RBKSocketOperation *)requestBySerializingRequest:(RBKSocketOperation *)request
                                     expectResponse:(BOOL)expectResponse
                                     withParameters:(NSDictionary *)parameters
                                              error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(request);

    id frame = request.requestFrame;
    
    if (![frame isKindOfClass:[NSDictionary class]]) {
        // not sure how to (or if we should) coerce other formats into a JSON
        NSLog(@"Unsupported request frame type %@ for serialization as JSON", NSStringFromClass([frame class]));
        return nil;
    }

    NSData *frameAsJSONData = [NSJSONSerialization dataWithJSONObject:frame options:self.writingOptions error:error];
    return [[RBKSocketOperation alloc] initWithRequestFrame:frameAsJSONData expectResponse:expectResponse];
}

@end

#pragma mark -

@implementation RBKPropertyListRequestSerializer

+ (instancetype)serializer {
    return [self serializerWithFormat:NSPropertyListXMLFormat_v1_0 writeOptions:0];
}

+ (instancetype)serializerWithFormat:(NSPropertyListFormat)format
                        writeOptions:(NSPropertyListWriteOptions)writeOptions
{
    RBKPropertyListRequestSerializer *serializer = [[self alloc] init];
    serializer.format = format;
    serializer.writeOptions = writeOptions;

    return serializer;
}

#pragma mark - RBKURLRequestSerializer

- (RBKSocketOperation *)requestBySerializingRequest:(RBKSocketOperation *)request
                                     expectResponse:(BOOL)expectResponse
                                     withParameters:(NSDictionary *)parameters
                                              error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(request);

//    if ([self.HTTPMethodsEncodingParametersInURI containsObject:[[request HTTPMethod] uppercaseString]]) {
//        return [super requestBySerializingRequest:request withParameters:parameters error:error];
//    }
//
//    NSMutableURLRequest *mutableRequest = [request mutableCopy];
//
//    [self.HTTPRequestHeaders enumerateKeysAndObjectsUsingBlock:^(id field, id value, BOOL * __unused stop) {
//        if (![request valueForHTTPHeaderField:field]) {
//            [mutableRequest setValue:value forHTTPHeaderField:field];
//        }
//    }];
//
//    NSString *charset = (__bridge NSString *)CFStringConvertEncodingToIANACharSetName(CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
//
//    [mutableRequest setValue:[NSString stringWithFormat:@"application/x-plist; charset=%@", charset] forHTTPHeaderField:@"Content-Type"];
//    [mutableRequest setHTTPBody:[NSPropertyListSerialization dataWithPropertyList:parameters format:self.format options:self.writeOptions error:error]];
//
//    return mutableRequest;
    
    
    NSLog(@"Figure out plist serializer");
    
    return nil;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder {
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }

    self.format = (NSPropertyListFormat)[decoder decodeIntegerForKey:NSStringFromSelector(@selector(format))];
    self.writeOptions = [decoder decodeIntegerForKey:NSStringFromSelector(@selector(writeOptions))];

    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];

    [coder encodeInteger:self.format forKey:NSStringFromSelector(@selector(format))];
    [coder encodeInteger:(NSInteger)self.writeOptions forKey:NSStringFromSelector(@selector(writeOptions))];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone {
    RBKPropertyListRequestSerializer *serializer = [[[self class] allocWithZone:zone] init];
    serializer.format = self.format;
    serializer.writeOptions = self.writeOptions;

    return serializer;
}

@end





#pragma mark -

@implementation RBKSocketStompRequestSerializer

+ (instancetype)serializer {
    return [self serializerWithWritingOptions:0];
}

+ (instancetype)serializerWithWritingOptions:(NSUInteger)writingOptions
{
    RBKSocketStompRequestSerializer *serializer = [[self alloc] init];
    serializer.writingOptions = writingOptions;
    
    return serializer;
}

#pragma mark - RBKURLRequestSerialization

- (RBKSocketOperation *)requestBySerializingRequest:(RBKSocketOperation *)request
                                     expectResponse:(BOOL)expectResponse
                                     withParameters:(NSDictionary *)parameters
                                              error:(NSError *__autoreleasing *)error
{
    NSParameterAssert(request);
    
    id frame = request.requestFrame;
    
    if (![frame isKindOfClass:[RBKStompFrame class]]) {
        // not sure how to (or if we should) coerce other formats into a JSON
        NSLog(@"Unsupported request frame type %@ for serialization as JSON", NSStringFromClass([frame class]));
        return nil;
    }
    
    RBKStompFrame *stompFrame = (RBKStompFrame *)frame;
    [self.delegate heartbeatSent]; // well, the heartbeat isn't actually sent, but it will be
    
    // if this is a SUBSCRIBE frame then we need to tell our delegate of our response frame handler so it can get called when we get Messages
    if ([stompFrame.command isEqualToString:RBKStompCommandSubscribe]) {
        RBKStompFrameHandler frameHandler = stompFrame.responseFrameHandler;
        
        NSString *destination = [stompFrame headerValueForKey:RBKStompHeaderDestination];
        NSString *subscriptionID = [stompFrame headerValueForKey:RBKStompHeaderID];
        
        // if the client is subscribing and the ack mode is client or client-individual, we need to track this so we can ack appropriately
        NSString *acknowledgeMode = [stompFrame headerValueForKey:RBKStompHeaderAck];
        if ([acknowledgeMode isEqualToString:RBKStompAckAuto]) {
            acknowledgeMode = nil;
        }// otherwise pass our acknowledgeMode on, where nil is the same as auto
        
        [self.delegate subscribedToDestination:destination subscriptionID:subscriptionID acknowledgeMode:acknowledgeMode messageHandler:frameHandler];
    }
    // if this is an UNSUBSCRIBE frame then we need to tell our delegate so it can remove our response frame handler
    else if ([stompFrame.command isEqualToString:RBKStompCommandUnsubscribe]) {
        
        NSString *destination = [stompFrame headerValueForKey:RBKStompHeaderDestination];
        NSString *subscriptionID = [stompFrame headerValueForKey:RBKStompHeaderID];
        [self.delegate unsubscribedFromDestination:destination subscriptionID:subscriptionID];
    }
    
    NSData *frameAsData = [stompFrame frameData];
    return [[RBKSocketOperation alloc] initWithRequestFrame:frameAsData expectResponse:expectResponse];
}

@end
