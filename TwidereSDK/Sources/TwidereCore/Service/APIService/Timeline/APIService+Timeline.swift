//
//  APIService+Timeline.swift
//  
//
//  Created by MainasuK on 2022-1-13.
//

import os.log
import Foundation
import CoreDataStack
import TwitterSDK
import MastodonSDK
import func QuartzCore.CACurrentMediaTime

extension APIService {
    
    struct TimelinePersistContext {
        let kind: Feed.Kind
        let maxID: Mastodon.Entity.Status.ID?
        let authenticationContext: MastodonAuthenticationContext
    }
    
    func persistMastodonTimelineResponse(
        response: Mastodon.Response.Content<[Mastodon.Entity.Status]>,
        persistContext: TimelinePersistContext
    ) async throws {
        #if DEBUG
        // log time cost
        let start = CACurrentMediaTime()
        defer {
            // log rate limit
            // response.logRateLimit()
            
            let end = CACurrentMediaTime()
            os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: persist cost %.2fs", ((#file as NSString).lastPathComponent), #line, #function, end - start)
        }
        #endif
        
        let managedObjectContext = backgroundManagedObjectContext
        try await managedObjectContext.performChanges {
            let me = persistContext.authenticationContext.authenticationRecord.object(in: managedObjectContext)?.user
            
            // persist MastodonStatus
            var statusArray: [MastodonStatus] = []
            for entity in response.value {
                let persistContext = Persistence.MastodonStatus.PersistContext(
                    domain: persistContext.authenticationContext.domain,
                    entity: entity,
                    me: me,
                    statusCache: nil,   // TODO:
                    userCache: nil,
                    networkDate: response.networkDate
                )
                
                let result = Persistence.MastodonStatus.createOrMerge(
                    in: managedObjectContext,
                    context: persistContext
                )
                let status = result.status
                statusArray.append(status)
                
                #if DEBUG
                result.log()
                #endif
            }   // end for … in
            
            // locate anchor status
            let anchorStatus: MastodonStatus? = {
                guard let maxID = persistContext.maxID else { return nil }
                let request = MastodonStatus.sortedFetchRequest
                request.predicate = MastodonStatus.predicate(
                    domain: persistContext.authenticationContext.domain,
                    id: maxID
                )
                request.fetchLimit = 1
                return try? managedObjectContext.fetch(request).first
            }()
            // update hasMore flag for anchor status
            let acct = Feed.Acct.mastodon(
                domain: persistContext.authenticationContext.domain,
                userID: persistContext.authenticationContext.userID
            )
            if let anchorStatus = anchorStatus,
               let feed = anchorStatus.feed(kind: persistContext.kind, acct: acct) {
                feed.update(hasMore: false)
            }
            
            switch persistContext.kind {
            case .home:
                // persist relationship
                let sortedStatuses = statusArray.sorted(by: { $0.createdAt < $1.createdAt })
                let oldestStatus = sortedStatuses.first
                for status in sortedStatuses {
                    // set friendship
                    if let me = me {
                        status.author.update(isFollow: true, by: me)
                    }
                    
                    // attach to Feed
                    let _feed = status.feed(kind: persistContext.kind, acct: acct)
                    if let feed = _feed {
                        feed.update(updatedAt: response.networkDate)
                    } else {
                        let feedProperty = Feed.Property(
                            acct: acct,
                            kind: persistContext.kind,
                            hasMore: false,
                            createdAt: status.createdAt,
                            updatedAt: response.networkDate
                        )
                        let feed = Feed.insert(into: managedObjectContext, property: feedProperty)
                        status.attach(feed: feed)
                        
                        // set hasMore on oldest status if is new feed
                        if status === oldestStatus {
                            feed.update(hasMore: true)
                        }
                    }
                }   // end for … in

            default:
                break
            }

            
        }   // end managedObjectContext.performChanges
    }   // end func
}

// Fetch v1 API again to update v2 missing properies
extension APIService {
    
    public struct TwitterBatchLookupResponse {
        let logger = Logger(subsystem: "APIService", category: "TwitterBatchLookupResponse")
        
        public var lookupDict: [Twitter.Entity.Tweet.ID: Twitter.Entity.Tweet] = [:]
        
        public func update(status: TwitterStatus, me: TwitterUser) {
            guard let lookupStatus = lookupDict[status.id] else { return }
            
            // like state
            lookupStatus.favorited.flatMap {
                status.update(isLike: $0, by: me)
            }
            // repost state
            lookupStatus.retweeted.flatMap {
                status.update(isRepost: $0, by: me)
            }
            // media
            if let twitterAttachments = lookupStatus.twitterAttachments {
                // gif
                let isGIF = twitterAttachments.contains(where: { $0.kind == .animatedGIF })
                if isGIF {
                    logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fix GIF missing")
                    status.update(attachments: twitterAttachments)
                    return
                }
                // media missing bug
                if status.attachments.isEmpty {
                    logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fix media missing")
                    status.update(attachments: twitterAttachments)
                    return
                }
            }
        }
        
        public func update(statuses: [TwitterStatus], me: TwitterUser) {
            for status in statuses {
                update(status: status, me: me)
            }
        }
    }
    
    public func twitterBatchLookupResponses(
        statusIDs: [Twitter.Entity.Tweet.ID],
        authenticationContext: TwitterAuthenticationContext
    ) async -> [Twitter.Response.Content<[Twitter.Entity.Tweet]>] {
        let chunks = stride(from: 0, to: statusIDs.count, by: 100).map {
            statusIDs[$0..<Swift.min(statusIDs.count, $0 + 100)]
        }
        
        let _responses = await chunks.parallelMap { chunk -> Twitter.Response.Content<[Twitter.Entity.Tweet]>? in
            let query = Twitter.API.Lookup.LookupQuery(ids: Array(chunk))
            let response = try? await Twitter.API.Lookup.tweets(
                session: self.session,
                query: query,
                authorization: authenticationContext.authorization
            )
            return response
        }
        
        return _responses.compactMap { $0 }
    }
    
    public func twitterBatchLookupResponses(
        content: Twitter.API.V2.User.Timeline.HomeContent,
        authenticationContext: TwitterAuthenticationContext
    ) async -> [Twitter.Response.Content<[Twitter.Entity.Tweet]>] {
        let statusIDs: [Twitter.Entity.Tweet.ID] = {
            var ids: [Twitter.Entity.Tweet.ID] = []
            ids.append(contentsOf: content.data?.map { $0.id } ?? [])
            ids.append(contentsOf: content.includes?.tweets?.map { $0.id } ?? [])
            return ids
        }()
        
        let responses = await twitterBatchLookupResponses(
            statusIDs: statusIDs,
            authenticationContext: authenticationContext
        )
        
        return responses
    }
    
    public func twitterBatchLookup(
        statusIDs: [Twitter.Entity.Tweet.ID],
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> TwitterBatchLookupResponse {
        let responses = await twitterBatchLookupResponses(
            statusIDs: statusIDs,
            authenticationContext: authenticationContext
        )
        
        var lookupDict: [Twitter.Entity.Tweet.ID: Twitter.Entity.Tweet] = [:]
        for response in responses {
            for status in response.value {
                lookupDict[status.idStr] = status
            }
        }
        
        return .init(lookupDict: lookupDict)
    }
    
}

// Fetch v2 API again to update v2 only properies
extension APIService {
    
    public struct TwitterBatchLookupResponseV2 {
        let logger = Logger(subsystem: "APIService", category: "TwitterBatchLookupResponseV2")
        
        let dictionary: Twitter.Response.V2.DictContent
        
        public func update(status: TwitterStatus, me: TwitterUser) {
            guard let lookupStatus = dictionary.tweetDict[status.id] else { return }
            guard let managedObjectContext = status.managedObjectContext else { return }
            
            let now = Date()
            
            // poll
            if let poll = dictionary.poll(for: lookupStatus) {
                let result = Persistence.TwitterPoll.createOrMerge(
                    in: managedObjectContext,
                    context: .init(
                        entity: poll,
                        me: me,
                        networkDate: now
                    )
                )
                status.attach(poll: result.poll)
            }
            
            // reply settings
            if let value = lookupStatus.replySettings {
                let replySettings = TwitterReplySettings(value: value.rawValue)
                status.update(replySettings: replySettings)
            }
        }
        
        public func update(statuses: [TwitterStatus], me: TwitterUser) {
            for status in statuses {
                update(status: status, me: me)
            }
        }
    }
    
    public func twitterBatchLookupResponsesV2(
        statusIDs: [Twitter.Entity.V2.Tweet.ID],
        authenticationContext: TwitterAuthenticationContext
    ) async -> [Twitter.Response.Content<Twitter.API.V2.Lookup.Content>] {
        let chunks = stride(from: 0, to: statusIDs.count, by: 100).map {
            statusIDs[$0..<Swift.min(statusIDs.count, $0 + 100)]
        }

        let _responses = await chunks.parallelMap { chunk -> Twitter.Response.Content<Twitter.API.V2.Lookup.Content>? in
            let response = try? await Twitter.API.V2.Lookup.statuses(
                session: self.session,
                query: .init(statusIDs: Array(chunk)),
                authorization: authenticationContext.authorization
            )
            return response
        }

        return _responses.compactMap { $0 }
    }

    public func twitterBatchLookupV2(
        statusIDs: [Twitter.Entity.V2.Tweet.ID],
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> TwitterBatchLookupResponseV2 {
        let responses = await twitterBatchLookupResponsesV2(
            statusIDs: statusIDs,
            authenticationContext: authenticationContext
        )

        var tweets: [Twitter.Entity.V2.Tweet] = []
        var users: [Twitter.Entity.V2.User] = []
        var media: [Twitter.Entity.V2.Media] = []
        var places: [Twitter.Entity.V2.Place] = []
        var polls: [Twitter.Entity.V2.Tweet.Poll] = []
        
        for response in responses {
            if let value = response.value.data {
                tweets.append(contentsOf: value)
            }
            if let value = response.value.includes?.tweets {
                tweets.append(contentsOf: value)
            }
            if let value = response.value.includes?.users {
                users.append(contentsOf: value)
            }
            if let value = response.value.includes?.media {
                media.append(contentsOf: value)
            }
            if let value = response.value.includes?.places {
                places.append(contentsOf: value)
            }
            if let value = response.value.includes?.polls {
                polls.append(contentsOf: value)
            }
        }

        let dictionary = Twitter.Response.V2.DictContent(
            tweets: tweets,
            users: users,
            media: media,
            places: places,
            polls: polls
        )
        
        return .init(dictionary: dictionary)
    }
    
}

