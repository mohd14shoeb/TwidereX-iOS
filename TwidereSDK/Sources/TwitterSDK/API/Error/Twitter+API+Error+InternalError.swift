//
//  Twitter+API+Error+InternalError.swift
//  
//
//  Created by Cirno MainasuK on 2020-12-25.
//

import Foundation

extension Twitter.API.Error {
    public struct InternalError: Error, LocalizedError {
        let message: String
        
        public init(message: String) {
            self.message = message
        }
        
        public var errorDescription: String? {
            return "Internal Error"
        }
        
        public var failureReason: String? {
            return message
        }
    }
}
