//
//  ProfileViewModel.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-9-27.
//

import os.log
import Foundation
import Combine
import CoreDataStack
import TwitterAPI

// please override this base class
class ProfileViewModel: NSObject {
    
    var disposeBag = Set<AnyCancellable>()
    private var twitterUserObserver: AnyCancellable?
    private var currentTwitterUserObserver: AnyCancellable?
    
    // input
    let twitterUser: CurrentValueSubject<TwitterUser?, Never>
    let currentTwitterUser = CurrentValueSubject<TwitterUser?, Never>(nil)
        
    // output
    let userID: CurrentValueSubject<String?, Never>
    let bannerImageURL: CurrentValueSubject<URL?, Never>
    let avatarImageURL: CurrentValueSubject<URL?, Never>
    let protected: CurrentValueSubject<Bool?, Never>
    let verified: CurrentValueSubject<Bool?, Never>
    let name: CurrentValueSubject<String?, Never>
    let username: CurrentValueSubject<String?, Never>
    let bioDescription: CurrentValueSubject<String?, Never>
    let url: CurrentValueSubject<String?, Never>
    let location: CurrentValueSubject<String?, Never>
    let friendsCount: CurrentValueSubject<Int?, Never>
    let followersCount: CurrentValueSubject<Int?, Never>
    let listedCount: CurrentValueSubject<Int?, Never>

    let friendship: CurrentValueSubject<Friendship?, Never>
    
    override init() {
        self.twitterUser = CurrentValueSubject(nil)
        self.userID = CurrentValueSubject(nil)
        self.bannerImageURL = CurrentValueSubject(nil)
        self.avatarImageURL = CurrentValueSubject(nil)
        self.protected = CurrentValueSubject(nil)
        self.verified = CurrentValueSubject(nil)
        self.name = CurrentValueSubject(nil)
        self.username = CurrentValueSubject(nil)
        self.bioDescription = CurrentValueSubject(nil)
        self.url = CurrentValueSubject(nil)
        self.location = CurrentValueSubject(nil)
        self.friendsCount = CurrentValueSubject(nil)
        self.followersCount = CurrentValueSubject(nil)
        self.listedCount = CurrentValueSubject(nil)
        self.friendship = CurrentValueSubject(nil)
        super.init()

        setup()
    }
    
    init(twitterUser: TwitterUser) {
        self.twitterUser = CurrentValueSubject(twitterUser)
        self.userID = CurrentValueSubject(twitterUser.id)
        self.bannerImageURL = CurrentValueSubject(twitterUser.profileBannerURL.flatMap { URL(string: $0) })
        self.avatarImageURL = CurrentValueSubject(twitterUser.avatarImageURL(size: .original))
        self.protected = CurrentValueSubject(twitterUser.protected)
        self.verified = CurrentValueSubject(twitterUser.verified)
        self.name = CurrentValueSubject(twitterUser.name)
        self.username = CurrentValueSubject(twitterUser.username)
        self.bioDescription = CurrentValueSubject(twitterUser.bioDescription)
        self.url = CurrentValueSubject(twitterUser.url)
        self.location = CurrentValueSubject(twitterUser.location)
        self.friendsCount = CurrentValueSubject(twitterUser.metrics?.followingCount.flatMap { Int(truncating: $0) })
        self.followersCount = CurrentValueSubject(twitterUser.metrics?.followersCount.flatMap { Int(truncating: $0) })
        self.listedCount = CurrentValueSubject(twitterUser.metrics?.listedCount.flatMap{ Int(truncating: $0) })
        self.friendship = CurrentValueSubject(nil)
        super.init()
        
        setup()
    }
    
    deinit {
        os_log("%{public}s[%{public}ld], %{public}s", ((#file as NSString).lastPathComponent), #line, #function)
    }
}

extension ProfileViewModel {
    
    enum Friendship {
        case following
        case pending
        case none
    }
    
}

extension ProfileViewModel {
    private func setup() {
        Publishers.CombineLatest(
            twitterUser.eraseToAnyPublisher(),
            currentTwitterUser.eraseToAnyPublisher()
        )
        .sink { [weak self] twitterUser, currentTwitterUser in
            guard let self = self else { return }
            self.update(twitterUser: twitterUser)
            self.update(twitterUser: twitterUser, currentTwitterUser: currentTwitterUser)
            
            if let twitterUser = twitterUser {
                // setup observer
                self.twitterUserObserver = ManagedObjectObserver.observe(object: twitterUser)
                    .sink { completion in
                        
                    } receiveValue: { [weak self] change in
                        guard let self = self else { return }
                        guard let changeType = change.changeType else { return }
                        switch changeType {
                        case .update:
                            self.update(twitterUser: twitterUser)
                            self.update(twitterUser: twitterUser, currentTwitterUser: currentTwitterUser)
                        case .delete:
                            // TODO:
                            break
                        }
                    }
                
            } else {
                self.twitterUserObserver = nil
            }
            
            if let currentTwitterUser = currentTwitterUser {
                // setup observer
                self.twitterUserObserver = ManagedObjectObserver.observe(object: currentTwitterUser)
                    .sink { completion in
                        
                    } receiveValue: { [weak self] change in
                        guard let self = self else { return }
                        guard let changeType = change.changeType else { return }
                        switch changeType {
                        case .update:
                            self.update(twitterUser: twitterUser, currentTwitterUser: currentTwitterUser)
                        case .delete:
                            // TODO:
                            break
                        }
                    }
            } else {
                self.currentTwitterUserObserver = nil
            }
        }
        .store(in: &disposeBag)
    }
    
    private func update(twitterUser: TwitterUser?) {
        self.userID.value = twitterUser?.id
        self.bannerImageURL.value = twitterUser?.profileBannerURL.flatMap { URL(string: $0) }
        self.avatarImageURL.value = twitterUser?.avatarImageURL(size: .original)
        self.protected.value = twitterUser?.protected
        self.verified.value = twitterUser?.verified
        self.name.value = twitterUser?.name
        self.username.value = twitterUser?.username
        self.bioDescription.value = twitterUser?.bioDescription
        self.url.value = twitterUser?.url
        self.location.value = twitterUser?.location
        self.friendsCount.value = twitterUser?.metrics?.followingCount.flatMap { Int(truncating: $0) }
        self.followersCount.value = twitterUser?.metrics?.followersCount.flatMap { Int(truncating: $0) }
        self.listedCount.value = twitterUser?.metrics?.listedCount.flatMap{ Int(truncating: $0) }
    }
    
    private func update(twitterUser: TwitterUser?, currentTwitterUser: TwitterUser?) {
        guard let twitterUser = twitterUser else {
            self.friendship.value = nil
            return
        }
        
        guard let currentTwitterUser = currentTwitterUser else {
            return
        }
        
        if twitterUser == currentTwitterUser {
            self.friendship.value = nil
        } else {
            let isFollowing = twitterUser.followingFrom.flatMap { $0.contains(currentTwitterUser) } ?? false
            let isPending = twitterUser.followRequestSentFrom.flatMap { $0.contains(currentTwitterUser) } ?? false
            self.friendship.value = isPending ? .pending : (isFollowing) ? .following : ProfileViewModel.Friendship.none
        }
    }
}