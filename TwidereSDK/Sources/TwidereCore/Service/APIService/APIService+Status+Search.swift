//
//  APIService+Tweet+Search.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-10-16.
//  Copyright © 2020 Twidere. All rights reserved.
//

import os.log
import Foundation
import Combine
import CoreDataStack
import Alamofire
import TwitterSDK
import MastodonSDK
import func QuartzCore.CACurrentMediaTime

extension APIService {
    
    static let defaultSearchCount = 20
    static let conversationSearchCount = 50
    
}

// MARK: - Twitter V1
extension APIService {
    
    // for thread
    public func searchTwitterStatusV1(
        conversationRootTweetID: Twitter.Entity.Tweet.ID,
        authorUsername: String,
        maxID: String?,
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> Twitter.Response.Content<Twitter.API.Search.Content> {
        let query = Twitter.API.Statuses.Timeline.TimelineQuery(
            count: APIService.conversationSearchCount,
            maxID: maxID,
            sinceID: conversationRootTweetID,
            query: "to:\(authorUsername) OR from:\(authorUsername) -filter:retweets"
        )
        return try await searchTwitterStatusV1(
            query: query,
            authenticationContext: authenticationContext
        )
    }
    
    // for search
    public func searchTwitterStatusV1(
        query: Twitter.API.Statuses.Timeline.TimelineQuery,
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> Twitter.Response.Content<Twitter.API.Search.Content> {
        let response = try await Twitter.API.Search.tweets(
            session: session,
            query: query,
            authorization: authenticationContext.authorization
        )
        
        let statusIDs: [Twitter.Entity.V2.Tweet.ID] = (response.value.statuses ?? []).map { $0.idStr }
        let _lookupResponse = try? await twitterBatchLookupV2(
            statusIDs: statusIDs,
            authenticationContext: authenticationContext
        )
        
        #if DEBUG
        // log time cost
        let start = CACurrentMediaTime()
        defer {
            // log rate limit
            response.logRateLimit()
            
            let end = CACurrentMediaTime()
            os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: persist cost %.2fs", ((#file as NSString).lastPathComponent), #line, #function, end - start)
        }
        #endif
        
        let managedObjectContext = backgroundManagedObjectContext
        try await managedObjectContext.performChanges {
            let me = authenticationContext.authenticationRecord.object(in: managedObjectContext)?.user
         
            var statusArray: [TwitterStatus] = []
            for entity in response.value.statuses ?? [] {
                let result = Persistence.TwitterStatus.createOrMerge(
                    in: managedObjectContext,
                    context: .init(
                        entity: entity,
                        me: me,
                        statusCache: nil,
                        userCache: nil,
                        networkDate: response.networkDate
                    )
                )
                statusArray.append(result.status)
            }   // end for in
            
            // amend the v2 only properties
            if let lookupResponse = _lookupResponse, let me = me {
                lookupResponse.update(statuses: statusArray, me: me)
            }
        }

        return response
    }
    
}

// MARK: - Twitter V2
extension APIService {
    
    // for search
    func searchTwitterStatus(
        searchText: String,
        nextToken: String?,
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> Twitter.Response.Content<Twitter.API.V2.Search.Content> {
        let query = Twitter.API.V2.Search.RecentTweetQuery(
            query: searchText,
            maxResults: APIService.defaultSearchCount,
            sinceID: nil,
            startTime: nil,
            nextToken: nextToken
        )
        return try await searchTwitterStatus(
            query: query,
            authenticationContext: authenticationContext
        )
    }
    
    // for thread
    public func searchTwitterStatus(
        conversationID: Twitter.Entity.V2.Tweet.ConversationID,
        authorID: Twitter.Entity.User.ID,
        sinceID: Twitter.Entity.V2.Tweet.ID?,
        startTime: Date?,
        nextToken: String?,
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> Twitter.Response.Content<Twitter.API.V2.Search.Content> {
        let query = Twitter.API.V2.Search.RecentTweetQuery(
            query: "conversation_id:\(conversationID) (to:\(authorID) OR from:\(authorID))",
            maxResults: APIService.conversationSearchCount,
            sinceID: sinceID,
            startTime: startTime,
            nextToken: nextToken
        )
        return try await searchTwitterStatus(
            query: query,
            authenticationContext: authenticationContext
        )
    }
    
    public func searchTwitterStatus(
        query: Twitter.API.V2.Search.RecentTweetQuery,
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> Twitter.Response.Content<Twitter.API.V2.Search.Content> {
        let response = try await Twitter.API.V2.Search.recentTweet(
            session: session,
            query: query,
            authorization: authenticationContext.authorization
        )
        
        #if DEBUG
        // log time cost
        let start = CACurrentMediaTime()
        defer {
            // log rate limit
            response.logRateLimit()
            
            let end = CACurrentMediaTime()
            os_log(.info, log: .debug, "%{public}s[%{public}ld], %{public}s: persist cost %.2fs", ((#file as NSString).lastPathComponent), #line, #function, end - start)
        }
        #endif
        
        let content = response.value
        let dictionary = Twitter.Response.V2.DictContent(
            tweets: [content.data, content.includes?.tweets].compactMap { $0 }.flatMap { $0 },
            users: content.includes?.users ?? [],
            media: content.includes?.media ?? [],
            places: content.includes?.places ?? [],
            polls: content.includes?.polls ?? []
        )

        let managedObjectContext = backgroundManagedObjectContext
        try await managedObjectContext.performChanges {
            let me = authenticationContext.authenticationRecord.object(in: managedObjectContext)?.user
            
            _ = Persistence.Twitter.persist(
                in: managedObjectContext,
                context: Persistence.Twitter.PersistContextV2(
                    dictionary: dictionary,
                    me: me,
                    networkDate: response.networkDate
                )
            )
        }   // end .performChanges { … }
        
        // query and update entity video/GIF attribute from V1 API
        do {
            let statusIDs: [Twitter.Entity.Tweet.ID] = {
                var statusIDs: Set<Twitter.Entity.Tweet.ID> = Set()
                for status in response.value.data ?? [] {
                    guard let mediaKeys = status.attachments?.mediaKeys else { continue }
                    for mediaKey in mediaKeys {
                        guard let media = dictionary.mediaDict[mediaKey],
                              media.attachmentKind == .video || media.attachmentKind == .animatedGIF
                        else { continue }
                        
                        statusIDs.insert(status.id)
                    }
                }
                return Array(statusIDs)
            }()
            if !statusIDs.isEmpty {
                logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fetch \(statusIDs.count) missing assetURL from V1 API…")
                _ = try await twitterStatusV1(
                    statusIDs: statusIDs,
                    authenticationContext: authenticationContext
                )
                logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fetch missing assetURL from V1 API success")
            }
        } catch {
            logger.log(level: .debug, "\((#file as NSString).lastPathComponent, privacy: .public)[\(#line, privacy: .public)], \(#function, privacy: .public): fetch missing assetURL from V1 API fail: \(error.localizedDescription)")
        }
        
        return response
    }
    
}
