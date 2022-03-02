//
//  APIService+User+List.swift
//  
//
//  Created by MainasuK on 2022-3-1.
//

import Foundation
import CoreDataStack
import TwitterSDK

extension APIService {
    public func twitterUserOwnedLists(
        user: ManagedObjectRecord<TwitterUser>,
        query: Twitter.API.V2.User.List.OwnedListsQuery,
        authenticationContext: TwitterAuthenticationContext
    ) async throws -> Twitter.Response.Content<Twitter.API.V2.User.List.OwnedListsContent> {
        let managedObjectContext = backgroundManagedObjectContext
        
        let _userID: TwitterUser.ID? = await managedObjectContext.perform {
            guard let user = user.object(in: managedObjectContext) else { return nil }
            return user.id
        }
        guard let userID = _userID else {
            throw AppError.implicit(.badRequest)
        }
        
        let response = try await Twitter.API.V2.User.List.onwedLists(
            session: session,
            userID: userID,
            query: query,
            authorization: authenticationContext.authorization
        )
        
        try await managedObjectContext.performChanges {
            for list in response.value.data ?? [] {
                guard let owner = response.value.includes?.users.first(where: { $0.id == list.ownerID }) else {
                    continue
                }
                
                _ = Persistence.TwitterList.createOrMerge(
                    in: managedObjectContext,
                    context: Persistence.TwitterList.PersistContext(
                        entity: Persistence.TwitterList.PersistContext.Entity(
                            list: list,
                            owner: owner
                        ),
                        networkDate: response.networkDate
                    )
                )
            }   // for … in …
        }   // end managedObjectContext.performChanges
        
        return response
    }
}
