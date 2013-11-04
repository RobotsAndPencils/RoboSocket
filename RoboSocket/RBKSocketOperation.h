//
//  RBKSocketOperation.h
//  RoboSocket
//
//  Created by David Anderson on 11/1/2013.
//  Copyright (c) 2013 Robots and Pencils Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RBKSocketResponseSerialization.h"
#import "RoboSocket.h"

@interface RBKSocketOperation : NSOperation

///-------------------------------
/// @name Accessing Run Loop Modes
///-------------------------------

/**
 The run loop modes in which the operation will run on the network thread. By default, this is a single-member set containing `NSRunLoopCommonModes`.
 */
@property (nonatomic, strong) NSSet *runLoopModes;

/**
 The error, if any, that occurred in the lifecycle of the request.
 */
@property (readonly, nonatomic, strong) NSError *error;

/**
 The dispatch queue for `completionBlock`. If `NULL` (default), the main queue is used.
 */
@property (nonatomic, strong) dispatch_queue_t completionQueue;

/**
 The dispatch group for `completionBlock`. If `NULL` (default), a private dispatch group is used.
 */
@property (nonatomic, strong) dispatch_group_t completionGroup;


/**
 Responses sent from the server in data tasks created with `dataTaskWithRequest:success:failure:` and run using the `GET` / `POST` / et al. convenience methods are automatically validated and serialized by the response serializer. By default, this property is set to an AFHTTPResoinse serializer, which uses the raw data as its response object. The serializer validates the status code to be in the `2XX` range, denoting success. If the response serializer generates an error in `-responseObjectForResponse:data:error:`, the `failure` callback of the session task or request operation will be executed; otherwise, the `success` callback will be executed.
 
 @warning `responseSerializer` must not be `nil`. Setting a response serializer will clear out any cached value
 */
@property (nonatomic, strong) RBKSocketResponseSerializer <RBKSocketResponseSerialization> * responseSerializer;

/**
 An object constructed by the `responseSerializer` from the response and response data. Returns `nil` unless the operation `isFinished`, has a `response`, and has `responseData` with non-zero content length. If an error occurs during serialization, `nil` will be returned, and the `error` property will be populated with the serialization error.
 */
@property (readonly, nonatomic, strong) id responseObject;

///----------------------------
/// @name Getting Response Data
///----------------------------

/**
 The data received during the request.
 */
@property (readonly, nonatomic, strong) NSData *responseData;

/**
 The string representation of the response data.
 */
@property (readonly, nonatomic, copy) NSString *responseString;

/**
 The string encoding of the response.
 
 If the response does not specify a valid string encoding, `responseStringEncoding` will return `NSUTF8StringEncoding`.
 */
@property (readonly, nonatomic, assign) NSStringEncoding responseStringEncoding;


///--------------------
/// @name Notifications
///--------------------

/**
 Posted when an operation begins executing.
 */
extern NSString * const RBKSocketOperationDidStartNotification;

/**
 Posted when an operation finishes.
 */
extern NSString * const RBKSocketOperationDidFinishNotification;


///

@property (nonatomic, strong) RoboSocket *socket;


- (instancetype)initWithRequestMessage:(NSString *)message;

- (void)setCompletionBlockWithSuccess:(void (^)(RBKSocketOperation *operation, id responseObject))success
                              failure:(void (^)(RBKSocketOperation *operation, NSError *error))failure;
@end
