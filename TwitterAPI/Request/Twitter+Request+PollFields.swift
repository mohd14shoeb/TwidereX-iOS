//
//  Twitter+Request+PollFields.swift
//  TwitterAPI
//
//  Created by Cirno MainasuK on 2020-9-16.
//

import Foundation

extension Twitter.Request {
    public enum PollFields: String, CaseIterable {
        case durationMinutes = "duration_minutes"
        case endDatetime = "end_datetime"
        case id = "id"
        case options = "options"
        case votingStatus = "voting_status"
        
        public static var allCasesQueryItem: URLQueryItem {
            let value = TwitterFields.allCases.map { $0.rawValue }.joined(separator: ",")
            return URLQueryItem(name: "poll.fields", value: value)
        }
    }
}
