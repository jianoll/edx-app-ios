//
//  UserProfileManager.swift
//  edX
//
//  Created by Akiva Leffert on 10/28/15.
//  Copyright © 2015 edX. All rights reserved.
//

import Foundation


public class UserProfileManager : NSObject {
    
    private let networkManager : NetworkManager
    private let session: OEXSession
    private let currentUserFeed = BackedFeed<UserProfile>()
    private let currentUserUpdateStream = Sink<UserProfile>()
    private let cache = LiveObjectCache<Feed<UserProfile>>()
    
    public init(networkManager : NetworkManager, session : OEXSession) {
        self.networkManager = networkManager
        self.session = session
        
        super.init()
        
        self.currentUserFeed.backingStream.addBackingStream(currentUserUpdateStream)
        
        NSNotificationCenter.defaultCenter().oex_addObserver(self, name: OEXSessionEndedNotification) { (_, owner, _) -> Void in
            owner.sessionChanged()
        }
        NSNotificationCenter.defaultCenter().oex_addObserver(self, name: OEXSessionStartedNotification) { (_, owner, _) -> Void in
            owner.sessionChanged()
        }
        self.sessionChanged()
    }
    
    public func feedForUser(username : String) -> Feed<UserProfile> {
        return self.cache.objectForKey(username) {
            let request = ProfileAPI.profileRequest(username)
            return Feed(request: request, manager: self.networkManager)
        }
    }
    
    private func sessionChanged() {
        if let username = self.session.currentUser?.username {
            self.currentUserFeed.backWithFeed(self.feedForUser(username))
        }
        else {
            self.currentUserFeed.removeBacking()
            // clear the stream
            self.currentUserUpdateStream.send(NSError.oex_unknownError())
        }
        if self.session.currentUser == nil {
            self.cache.empty()
        }
    }
    
    // Feed that updates if the current user changes
    public func feedForCurrentUser() -> Feed<UserProfile> {
        return currentUserFeed
    }
    
    public func updateCurrentUserProfile(profile : UserProfile, handler : Result<UserProfile> -> Void) {
        let request = ProfileAPI.profileUpdateRequest(profile)
        self.networkManager.taskForRequest(request) { result -> Void in
            if let data = result.data {
                self.currentUserUpdateStream.send(Success(data))
            }
            handler(result.data.toResult(result.error))
        }
    }
}