//
//  OEXRegisteringUserDetails.h
//  edXVideoLocker
//
//  Created by Akiva Leffert on 3/26/15.
//  Copyright (c) 2015-2016 edX. All rights reserved.
//

@import Foundation;

NS_ASSUME_NONNULL_BEGIN

@interface OEXRegisteringUserDetails : NSObject

@property (copy, nonatomic) NSString* name;
@property (copy, nonatomic) NSString* email;
@property (assign, nonatomic) NSString* birthYear;

@end

NS_ASSUME_NONNULL_END
