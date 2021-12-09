//
//  Persistence.swift
//  Persistence
//
//  Created by Cirno MainasuK on 2021-8-18.
//  Copyright © 2021 Twidere. All rights reserved.
//

import Foundation

public enum Persistence { }

extension Persistence {
    public enum Twitter { }
    public enum TwitterUser { }
    public enum TwitterStatus { }
}

extension Persistence {
    public enum MastodonUser { }
    public enum MastodonStatus { }
    public enum MastodonNotification { }
    public enum MastodonPoll { }
    public enum MastodonPollOption { }
}

extension Persistence {
    public class PersistCache<T> {
        var dictionary: [String : T] = [:]
        
        public init(dictionary: [String : T] = [:]) {
            self.dictionary = dictionary
        }
    }
}

