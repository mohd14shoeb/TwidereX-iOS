//
//  TwitterUserEntities.swift
//  CoreDataStack
//
//  Created by Cirno MainasuK on 2020-11-26.
//  Copyright © 2020 Twidere. All rights reserved.
//

import Foundation
import CoreData
import TwitterSDK

final public class TwitterUserEntities: NSManagedObject {
    
    @NSManaged public private(set) var identifier: UUID
    @NSManaged public private(set) var createdAt: Date
    
    // one-to-one relationship
    @NSManaged public private(set) var user: TwitterUser?
    
    // one-to-many relationship
    @NSManaged public private(set) var urls: Set<TwitterUserEntitiesURL>?
    
}

extension TwitterUserEntities {
    
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        identifier = UUID()
        createdAt = Date()
    }
    
    @discardableResult
    public static func insert(
        into context: NSManagedObjectContext,
        urls: [TwitterUserEntitiesURL]?
    ) -> TwitterUserEntities {
        let entities: TwitterUserEntities = context.insertObject()
        
        if let urls = urls {
            entities.mutableSetValue(forKey: #keyPath(TwitterUserEntities.urls)).addObjects(from: urls)
        }
        
        return entities
    }

}

extension TwitterUserEntities: Managed {
    public static var defaultSortDescriptors: [NSSortDescriptor] {
        return [NSSortDescriptor(keyPath: \TwitterUserEntities.createdAt, ascending: false)]
    }
}
