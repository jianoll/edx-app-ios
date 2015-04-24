//
//  OEXEnvironment.m
//  edXVideoLocker
//
//  Created by Akiva Leffert on 12/29/14.
//  Copyright (c) 2014 edX. All rights reserved.
//

#import "OEXEnvironment.h"

#import "OEXAnalytics.h"
#import "OEXConfig.h"
#import "OEXInterface.h"
#import "OEXPushNotificationManager.h"
#import "OEXPushNotificationProcessor.h"
#import "OEXPushSettingsManager.h"
#import "OEXRouter.h"
#import "OEXSegmentAnalyticsTracker.h"
#import "OEXSegmentConfig.h"
#import "OEXSession.h"
#import "OEXStyles.h"

@interface OEXEnvironment ()

@property (strong, nonatomic) OEXAnalytics* analytics;
@property (strong, nonatomic) OEXConfig* config;
@property (strong, nonatomic) OEXPushNotificationManager* pushNotificationManager;
@property (strong, nonatomic) OEXPushSettingsManager* pushSettingsManager;
@property (strong, nonatomic) OEXRouter* router;
@property (strong, nonatomic) OEXSession* session;
@property (strong, nonatomic) OEXStyles* styles;

/// Array of actions to be executed once all the objects are wired up
/// Used to resolve what would be otherwise be circular dependencies
@property (strong, nonatomic) NSMutableArray* postSetupActions;

@end

@implementation OEXEnvironment

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static OEXEnvironment* shared = nil;
    dispatch_once(&onceToken, ^{
        shared = [[OEXEnvironment alloc] init];
    });
    return shared;
}

- (id)init {
    self = [super init];
    if(self != nil) {
        self.postSetupActions = [[NSMutableArray alloc] init];
        
        self.analyticsBuilder = ^(OEXEnvironment* env){
            OEXAnalytics* analytics = [[OEXAnalytics alloc] init];
            OEXSegmentConfig* segmentConfig = [[OEXConfig sharedConfig] segmentConfig];
            if(segmentConfig.apiKey != nil && segmentConfig.isEnabled) {
                [analytics addTracker:[[OEXSegmentAnalyticsTracker alloc] init]];
            }
            return analytics;
        };
        self.configBuilder = ^(OEXEnvironment* env){
            return [[OEXConfig alloc] initWithAppBundleData];
        };
        self.pushNotificationManagerBuilder = ^OEXPushNotificationManager*(OEXEnvironment* env) {
            if(env.config.pushNotificationsEnabled) {
                OEXPushNotificationManager* manager = [[OEXPushNotificationManager alloc] initWithSettingsManager:env.pushSettingsManager];
                [manager addProvidersForConfiguration:env.config withSession:env.session];
                
                if(env.config.pushNotificationsEnabled) {
                    [env.postSetupActions addObject:^(OEXEnvironment* env) {
                        OEXPushNotificationProcessorEnvironment* pushEnvironment = [[OEXPushNotificationProcessorEnvironment alloc] initWithAnalytics:env.analytics router:env.router];
                        [env.pushNotificationManager addListener:[[OEXPushNotificationProcessor alloc] initWithEnvironment:pushEnvironment]];
                    }];
                }
                
                return manager;
            }
            else {
                return nil;
            }
        };
        self.pushSettingsBuilder = ^(OEXEnvironment* env) {
            return [[OEXPushSettingsManager alloc] init];
        };
        self.routerBuilder = ^(OEXEnvironment* env) {
            OEXRouterEnvironment* routerEnv = [[OEXRouterEnvironment alloc]
                                               initWithAnalytics:env.analytics
                                               config:env.config
                                               interface:[OEXInterface sharedInterface]
                                               pushSettingsManager:env.pushSettingsManager
                                               session:env.session
                                               styles:env.styles];
            return [[OEXRouter alloc] initWithEnvironment:routerEnv];
            
        };
        self.stylesBuilder = ^(OEXEnvironment* env){
            return [[OEXStyles alloc] init];
        };
        self.sessionBuilder = ^(OEXEnvironment* env){
            OEXSession* session = [[OEXSession alloc] init];
            [env.postSetupActions addObject: ^(OEXEnvironment* env) {
                [env.session loadTokenFromStore];
            }];
            return session;
        };
    }
    return self;
}

- (void)setupEnvironment {
    // TODO: automatically order by dependencies
    // For now, make sure this is the right order for dependencies
    self.pushSettingsManager = self.pushSettingsBuilder(self);
    self.config = self.configBuilder(self);
    self.analytics = self.analyticsBuilder(self);
    self.pushNotificationManager = self.pushNotificationManagerBuilder(self);
    
    self.session = self.sessionBuilder(self);
    self.styles = self.stylesBuilder(self);
    self.router = self.routerBuilder(self);
    
    // We should minimize the use of these singletons and mostly use explicitly passed in dependencies
    // But occasionally that's very inconvenient and also much existing code is not structured to deal with that
    [OEXConfig setSharedConfig:self.config];
    [OEXRouter setSharedRouter:self.router];
    [OEXAnalytics setSharedAnalytics:self.analytics];
    [OEXSession setSharedSession:self.session];
    [OEXStyles setSharedStyles:self.styles];
    
    for(void (^action)(OEXEnvironment*) in self.postSetupActions) {
        action(self);
    }
    
    [self.postSetupActions removeAllObjects];
}

@end