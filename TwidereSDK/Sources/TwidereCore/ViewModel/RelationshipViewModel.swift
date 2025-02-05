//
//  RelationshipViewModel.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2021-10-19.
//  Copyright © 2021 Twidere. All rights reserved.
//

import Foundation
import CoreData
import Combine
import CoreDataStack
import TwidereLocalization

// Relationship in order
// The high priority in the last
public enum Relationship: Int, CaseIterable {
    case isMyself
    case followingBy
    case none       // set hide from UI
    case follow
    case request
    case pending
    case following
    case muting
    case blockingBy
    case blocking
    case suspended
    
    public var option: RelationshipOptionSet {
        return RelationshipOptionSet(rawValue: 1 << rawValue)
    }
    
    public var title: String {
        switch self {
        case .isMyself: return ""
        case .followingBy: return L10n.Common.Controls.Friendship.followsYou
        case .none: return " "
        case .follow: return L10n.Common.Controls.Friendship.Actions.follow
        case .request: return L10n.Common.Controls.Friendship.Actions.request
        case .pending: return L10n.Common.Controls.Friendship.Actions.pending
        case .following: return L10n.Common.Controls.Friendship.Actions.following
        case .muting: return L10n.Common.Controls.Friendship.Actions.unmute    // muting
        case .blockingBy: return L10n.Common.Controls.Friendship.Actions.follow   // blocked by user, button should disabled
        case .blocking: return L10n.Common.Controls.Friendship.Actions.blocked
        case .suspended: return L10n.Common.Controls.Friendship.Actions.follow
        }
    }
    
}

// construct option set on the enum for safe iterator
public struct RelationshipOptionSet: OptionSet {
    
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let isMyself = Relationship.isMyself.option
    public static let followingBy = Relationship.followingBy.option
    public static let none = Relationship.none.option
    public static let follow = Relationship.follow.option
    public static let request = Relationship.request.option
    public static let pending = Relationship.pending.option
    public static let following = Relationship.following.option
    public static let muting = Relationship.muting.option
    public static let blockingBy = Relationship.blockingBy.option
    public static let blocking = Relationship.blocking.option
    public static let suspended = Relationship.suspended.option
    
    
    public func relationship(except optionSet: RelationshipOptionSet) -> Relationship? {
        let set = subtracting(optionSet)
        for action in Relationship.allCases.reversed() where set.contains(action.option) {
            return action
        }
        
        return nil
    }
}

public final class RelationshipViewModel {
    
    var disposeBag = Set<AnyCancellable>()
    
    public var userObserver: AnyCancellable?
    public var meObserver: AnyCancellable?
    
    // input
    @Published public var user: UserObject?
    @Published public var me: UserObject?
    public let relationshipUpdatePublisher = CurrentValueSubject<Void, Never>(Void())  // needs initial event
    
    // output
    @Published public var isMyself = false
    @Published public var optionSet: RelationshipOptionSet?
    
    @Published public var isFollowing = false
    @Published public var isFollowingBy = false
    @Published public var isMuting = false
    @Published public var isBlocking = false
    @Published public var isBlockingBy = false
    
    public init() {
        Publishers.CombineLatest3(
            $user,
            $me,
            relationshipUpdatePublisher
        )
        .sink { [weak self] user, me, _ in
            guard let self = self else { return }
            self.update(user: user, me: me)
            
            guard let user = user, let me = me else {
                self.userObserver = nil
                self.meObserver = nil
                return
            }
            
            // do not modify object to prevent infinity loop
            self.userObserver = RelationshipViewModel.createObjectChangePublisher(user: user)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.relationshipUpdatePublisher.send()
                }
                
            self.meObserver = RelationshipViewModel.createObjectChangePublisher(user: me)
                .sink { [weak self] _ in
                    guard let self = self else { return }
                    self.relationshipUpdatePublisher.send()
                }
        }
        .store(in: &disposeBag)
    }
    
}

extension RelationshipViewModel {
    
    public static func createObjectChangePublisher(user: UserObject) -> AnyPublisher<Void, Never> {
        switch user {
        case .twitter(let object):
            return ManagedObjectObserver
                .observe(object: object)
                .map { _ in Void() }
                .catch { error in
                    return Just(Void())
                }
                .eraseToAnyPublisher()

        case .mastodon(let object):
            return ManagedObjectObserver
                .observe(object: object)
                .map { _ in Void() }
                .catch { error in
                    return Just(Void())
                }
                .eraseToAnyPublisher()
        }
    }
    
}

extension RelationshipViewModel {
    private func update(user: UserObject?, me: UserObject?) {
        guard let user = user,
              let me = me
        else {
            reset()
            return
        }
        
        let optionSet = RelationshipViewModel.optionSet(user: user, me: me)

        self.isMyself = optionSet.contains(.isMyself)
        self.isFollowingBy = optionSet.contains(.followingBy)
        self.isFollowing = optionSet.contains(.following)
        self.isMuting = optionSet.contains(.muting)
        self.isBlockingBy = optionSet.contains(.blockingBy)
        self.isBlocking = optionSet.contains(.blocking)

        
        self.optionSet = optionSet
    }
    
    private func reset() {
        isMyself = false
        isFollowingBy = false
        isFollowing = false
        isMuting = false
        isBlockingBy = false
        isBlocking = false
        optionSet = nil
    }
}

extension RelationshipViewModel {

    public static func optionSet(user: UserObject, me: UserObject) -> RelationshipOptionSet {
        let isMyself: Bool
        let isProtected: Bool
        let isFollowingBy: Bool
        let isFollowing: Bool
        let isPending: Bool
        let isMuting: Bool
        let isBlockingBy: Bool
        let isBlocking: Bool
        
        switch (user, me) {
        case (.twitter(let user), .twitter(let me)):
            isMyself = user.id == me.id
            guard !isMyself else {
                return [.isMyself]
            }
            
            isProtected = user.protected
            isFollowingBy = me.followingBy.contains(user)
            isFollowing = user.followingBy.contains(me)
            isPending = user.followRequestSentFrom.contains(me)
            isMuting = user.mutingBy.contains(me)
            isBlockingBy = me.blockingBy.contains(user)
            isBlocking = user.blockingBy.contains(me)
            
        case (.mastodon(let user), .mastodon(let me)):
            isMyself = user.id == me.id && user.domain == me.domain
            guard !isMyself else {
                return [.isMyself]
            }
            
            isProtected = user.locked
            isFollowingBy = me.followingBy.contains(user)
            isFollowing = user.followingBy.contains(me)
            isPending = user.followRequestSentFrom.contains(me)
            isMuting = user.mutingBy.contains(me)
            isBlockingBy = me.blockingBy.contains(user)
            isBlocking = user.blockingBy.contains(me)
        default:
            return [.none]
        }
        
        var optionSet: RelationshipOptionSet = [.follow]
        
        if isMyself {
            optionSet.insert(.isMyself)
        }
        
        if isProtected {
            optionSet.insert(.request)
        }
        
        if isFollowingBy {
            optionSet.insert(.followingBy)
        }
        
        if isFollowing {
            optionSet.insert(.following)
        }
        
        if isPending {
            optionSet.insert(.pending)
        }
        
        if isMuting {
            optionSet.insert(.muting)
        }
        
        if isBlockingBy {
            optionSet.insert(.blockingBy)
        }

        if isBlocking {
            optionSet.insert(.blocking)
        }
                
        return optionSet
    }
}
