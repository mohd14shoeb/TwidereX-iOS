//
//  APIService+Lookup.swift
//  TwidereX
//
//  Created by Cirno MainasuK on 2020-9-16.
//

import Foundation
import Combine
import TwitterAPI
import CoreDataStack
import CommonOSLog

extension APIService {

    // V2
    func tweets(tweetIDs: [Twitter.Entity.V2.Tweet.ID], authorization: Twitter.API.OAuth.Authorization, twitterUserID: TwitterUser.ID) -> AnyPublisher<Twitter.Response.Content<Twitter.API.Lookup.Content>, Error> {
        return Twitter.API.Lookup.tweets(tweetIDs: tweetIDs, session: session, authorization: authorization)
            .handleEvents(receiveOutput: { [weak self] response in
                guard let self = self else { return }
                let content = response.value
                
                // TODO: merge tweets
            })
            .eraseToAnyPublisher()
            
    }
    
}