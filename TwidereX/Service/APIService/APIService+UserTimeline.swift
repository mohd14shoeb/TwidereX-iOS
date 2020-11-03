//
//  APIService+UserTimeline.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-9-28.
//

import Foundation
import Combine
import CoreData
import CoreDataStack
import CommonOSLog
import TwitterAPI

extension APIService {

    func twitterUserTimeline(
        count: Int = 200,
        userID: String,
        maxID: String? = nil,
        authorization: Twitter.API.OAuth.Authorization,
        requestTwitterUserID: TwitterUser.ID
    ) -> AnyPublisher<Twitter.Response.Content<[Twitter.Entity.Tweet]>, Error> {
        let query = Twitter.API.Timeline.Query(count: count, userID: userID, maxID: maxID, excludeReplies: false)
        return Twitter.API.Timeline.userTimeline(session: session, authorization: authorization, query: query)
            .map { response -> AnyPublisher<Twitter.Response.Content<[Twitter.Entity.Tweet]>, Error> in
                let log = OSLog.api

                return APIService.Persist.persistTimeline(
                    managedObjectContext: self.backgroundManagedObjectContext,
                    query: query,
                    response: response,
                    persistType: .userTimeline,
                    requestTwitterUserID: requestTwitterUserID,
                    log: log
                )
                .setFailureType(to: Error.self)
                .tryMap { result -> Twitter.Response.Content<[Twitter.Entity.Tweet]> in
                    switch result {
                    case .success:
                        return response
                    case .failure(let error):
                        throw error
                    }
                }
                .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
}
