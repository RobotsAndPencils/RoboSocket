//
// Created by Michael Beauregard on 2014-03-07.
// Copyright (c) 2014 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RBKSocketRequestSerialization.h"
#import "RBKSocketResponseSerialization.h"


@interface RBKWebSocket : NSObject

/**
 Requests created with `requestWithMethod:URLString:parameters:` & `multipartFormRequestWithMethod:URLString:parameters:constructingBodyWithBlock:` are constructed with a set of default headers using a parameter serialization specified by this property. By default, this is set to an instance of `RBKHTTPRequestSerializer`, which serializes query string parameters for `GET`, `HEAD`, and `DELETE` requests, or otherwise URL-form-encodes HTTP message bodies.

 @warning `requestSerializer` must not be `nil`.
 */
@property (nonatomic, strong) RBKSocketRequestSerializer <RBKSocketRequestSerialization> * requestSerializer;
/**
 Responses sent from the server in data tasks created with `dataTaskWithRequest:success:failure:` and run using the `GET` / `POST` / et al. convenience methods are automatically validated and serialized by the response serializer. By default, this property is set to a JSON serializer, which serializes data from responses with a `application/json` MIME type, and falls back to the raw data object. The serializer validates the status code to be in the `2XX` range, denoting success. If the response serializer generates an error in `-responseObjectForResponse:data:error:`, the `failure` callback of the session task or request operation will be executed; otherwise, the `success` callback will be executed.

 @warning `responseSerializer` must not be `nil`.
 */
@property (nonatomic, strong) RBKSocketResponseSerializer <RBKSocketResponseSerialization> * responseSerializer;
@property (assign, nonatomic, getter = socketIsOpen) BOOL socketOpen;
- (instancetype)initWithSocketURL:(NSURL *)socketURL;
/**
 Inclusion of success and/or failure block indicates that this operation expects a response as part of the operation
 */
- (RBKSocketOperation *)socketOperationWithFrame:(id)frame
                                         success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                         failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;
/**
 Inclusion of success and/or failure block indicates that this operation expects a response as part of the operation
 */
- (RBKSocketOperation *)sendSocketOperationWithFrame:(id)frame
                                             success:(void (^)(RBKSocketOperation *operation, id responseObject))success
                                             failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;
/**
 Lack of success and/or failure block indicates that this operation does not expect a response as part of the operation. Responses may come outside the operation
 */
- (RBKSocketOperation *)sendSocketOperationWithFrame:(id)frame;
- (void)closeSocket;

@end
