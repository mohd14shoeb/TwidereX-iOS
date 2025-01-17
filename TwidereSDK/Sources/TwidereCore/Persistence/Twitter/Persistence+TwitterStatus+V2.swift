//
//  Persistence+TwitterStatus+V2.swift
//  Persistence+TwitterStatus+V2
//
//  Created by Cirno MainasuK on 2021-8-31.
//  Copyright © 2021 Twidere. All rights reserved.
//

import CoreData
import CoreDataStack
import Foundation
import TwitterSDK
import os.log

extension Persistence.TwitterStatus {

    public struct PersistContextV2 {
        public let entity: Entity
        public let repost: Entity?     // status.repost
        public let quote: Entity?
        public let replyTo: Entity?
        
        public let dictionary: Twitter.Response.V2.DictContent
        
        public let me: TwitterUser?
        public let statusCache: Persistence.PersistCache<TwitterStatus>?
        public let userCache: Persistence.PersistCache<TwitterUser>?
        public let networkDate: Date
        public let log = OSLog.api
        
        public init(
            entity: Persistence.TwitterStatus.PersistContextV2.Entity,
            repost: Persistence.TwitterStatus.PersistContextV2.Entity?,
            quote: Persistence.TwitterStatus.PersistContextV2.Entity?,
            replyTo: Persistence.TwitterStatus.PersistContextV2.Entity?,
            dictionary: Twitter.Response.V2.DictContent,
            me: TwitterUser?,
            statusCache: Persistence.PersistCache<TwitterStatus>?,
            userCache: Persistence.PersistCache<TwitterUser>?,
            networkDate: Date
        ) {
            self.entity = entity
            self.repost = repost
            self.quote = quote
            self.replyTo = replyTo
            self.dictionary = dictionary
            self.me = me
            self.statusCache = statusCache
            self.userCache = userCache
            self.networkDate = networkDate
        }
        
        public struct Entity {
            public let status: Twitter.Entity.V2.Tweet
            public let author: Twitter.Entity.V2.User
            
            public init(
                status: Twitter.Entity.V2.Tweet,
                author: Twitter.Entity.V2.User
            ) {
                self.status = status
                self.author = author
            }
        }
        
        public func entity(statusID: Twitter.Entity.V2.Tweet.ID) -> Entity? {
            guard let status = dictionary.tweetDict[statusID],
                  let authorID = status.authorID,
                  let user = dictionary.userDict[authorID]
            else { return nil }
            return Entity(
                status: status,
                author: user
            )
        }
    }
    
    public static func createOrMerge(
        in managedObjectContext: NSManagedObjectContext,
        context: PersistContextV2
    ) -> PersistResult {
                
        // build tree

        let replyTo = context.replyTo.flatMap { entity -> TwitterStatus in
            let result = createOrMerge(
                in: managedObjectContext,
                context: PersistContextV2(
                    entity: entity,
                    repost: nil,
                    quote: nil,
                    replyTo: nil,
                    dictionary: context.dictionary,
                    me: context.me,
                    statusCache: context.statusCache,
                    userCache: context.userCache,
                    networkDate: context.networkDate
                )
            )
            return result.status
        }
        
        let repost = context.repost.flatMap { entity -> TwitterStatus in
            let result = createOrMerge(
                in: managedObjectContext,
                context: PersistContextV2(
                    entity: entity,
                    repost: nil,
                    quote: context.quote,
                    replyTo: nil,
                    dictionary: context.dictionary,
                    me: context.me,
                    statusCache: context.statusCache,
                    userCache: context.userCache,
                    networkDate: context.networkDate
                )
            )
            return result.status
        }
        
        let quote: TwitterStatus? = {
            guard repost == nil else { return nil }
            return context.quote.flatMap { entity -> TwitterStatus in
                let result = createOrMerge(
                    in: managedObjectContext,
                    context: PersistContextV2(
                        entity: entity,
                        repost: nil,
                        quote: nil,
                        replyTo: nil,
                        dictionary: context.dictionary,
                        me: context.me,
                        statusCache: context.statusCache,
                        userCache: context.userCache,
                        networkDate: context.networkDate
                    )
                )
                return result.status
            }
        }()
        
        if let old = fetch(in: managedObjectContext, context: context) {
            merge(twitterStatus: old, context: context)
            return .init(status: old, isNewInsertion: false, isNewInsertionAuthor: false)
        } else {
            let poll: TwitterPoll? = {
                guard let entity = context.dictionary.poll(for: context.entity.status) else { return nil }
                let result = Persistence.TwitterPoll.createOrMerge(
                    in: managedObjectContext,
                    context: .init(
                        entity: entity,
                        me: context.me,
                        networkDate: context.networkDate
                    )
                )
                return result.poll
            }()
            let authorResult = Persistence.TwitterUser.createOrMerge(
                in: managedObjectContext,
                context: Persistence.TwitterUser.PersistContextV2(
                    entity: context.entity.author,
                    me: context.me,
                    cache: context.userCache,
                    networkDate: context.networkDate
                )
            )
            let author = authorResult.user
            context.userCache?.dictionary[author.id] = author
            let relationship = TwitterStatus.Relationship(
                poll: poll,
                author: author,
                repost: repost,
                quote: quote,
                replyTo: replyTo
            )
            let status = create(in: managedObjectContext, context: context, relationship: relationship)
            context.statusCache?.dictionary[status.id] = status
            return .init(status: status, isNewInsertion: true, isNewInsertionAuthor: authorResult.isNewInsertion)
        }
    }
    
}

extension Persistence.TwitterStatus {
    
    public static func fetch(
        in managedObjectContext: NSManagedObjectContext,
        context: PersistContextV2
    ) -> TwitterStatus? {
        if let cache = context.statusCache {
            return cache.dictionary[context.entity.status.id]
        } else {
            let request = TwitterStatus.sortedFetchRequest
            request.predicate = TwitterStatus.predicate(id: context.entity.status.id)
            request.fetchLimit = 1
            do {
                return try managedObjectContext.fetch(request).first
            } catch {
                assertionFailure(error.localizedDescription)
                return nil
            }
        }
    }
    
    @discardableResult
    public static func create(
        in managedObjectContext: NSManagedObjectContext,
        context: PersistContextV2,
        relationship: TwitterStatus.Relationship
    ) -> TwitterStatus {
        let property = TwitterStatus.Property(
            status: context.entity.status,
            author: context.entity.author,
            place: context.dictionary.place(for: context.entity.status),
            media: context.dictionary.media(for: context.entity.status) ?? [],
            networkDate: context.networkDate
        )
        let status = TwitterStatus.insert(
            into: managedObjectContext,
            property: property,
            relationship: relationship
        )
        update(twitterStatus: status, context: context)
        return status
    }
    
    public static func merge(
        twitterStatus status: TwitterStatus,
        context: PersistContextV2
    ) {
        guard context.networkDate > status.updatedAt else { return }

        let property = TwitterStatus.Property(
            status: context.entity.status,
            author: context.entity.author,
            place: context.dictionary.place(for: context.entity.status),
            media: context.dictionary.media(for: context.entity.status) ?? [],
            networkDate: context.networkDate
        )
        status.update(property: property)
        
        if let entity = context.dictionary.poll(for: context.entity.status),
           let managedObjectContext = status.managedObjectContext
        {
            // status created from v1 not has a poll
            // create or merge the poll and attach it to status
            let result = Persistence.TwitterPoll.createOrMerge(
                in: managedObjectContext,
                context: .init(
                    entity: entity,
                    me: context.me,
                    networkDate: context.networkDate
                )
            )
            status.attach(poll: result.poll)
        }
        
        update(twitterStatus: status, context: context)
        
        // merge user
        Persistence.TwitterUser.merge(
            twitterUser: status.author,
            context: Persistence.TwitterUser.PersistContextV2(
                entity: context.entity.author,
                me: context.me,
                cache: context.userCache,
                networkDate: context.networkDate
            )
        )
    }
    
    private static func update(
        twitterStatus status: TwitterStatus,
        context: PersistContextV2
    ) {
        // entities
        status.update(entities: TwitterEntity(entity: context.entity.status.entities))
        
        // replySettings (v2 only)
        let _replySettings = context.entity.status.replySettings.flatMap {
            TwitterReplySettings(value: $0.rawValue)
        }
        if let replySettings = _replySettings {
            status.update(replySettings: replySettings)            
        }
        
        // conversationID (v2 only)
        context.entity.status.conversationID.flatMap { status.update(conversationID: $0) }
        
        // replyCount, quoteCount (v2 only)
        context.entity.status.publicMetrics.flatMap { metrics in
            status.update(replyCount: Int64(metrics.replyCount))
            status.update(replyCount: Int64(metrics.quoteCount))
        }
        
        // media (not stable: URL may updated)
        context.dictionary.media(for: context.entity.status)
            .flatMap { media in
                // https://twittercommunity.com/t/how-to-get-video-from-media-key/152449/6
                // V2 API missing video asset URL
                // do not update video & GIFV attachments except isEmpty
                let isVideo = media.contains(where: { $0.type == TwitterAttachment.Kind.animatedGIF.rawValue || $0.type == TwitterAttachment.Kind.video.rawValue })
                if isVideo {
                    let isEmpty = status.attachments.isEmpty
                    if !isEmpty {
                        return
                    }
                }
                
                let attachments = media.compactMap { $0.twitterAttachment }
                status.update(attachments: attachments)
            }
        
        // place (not stable: geo may erased)
        context.dictionary.place(for: context.entity.status)
            .flatMap { place in
                status.update(location: place.twitterLocation)
            }
    }
    
}
