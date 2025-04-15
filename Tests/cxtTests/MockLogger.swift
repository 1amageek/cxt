//
//  MockLogger.swift
//  cxt
//
//  Created by Norikazu Muramoto on 2025/04/15.
//


import Foundation

/// Mock logger for testing
class MockLogger {
    private var logs: [String] = []
    
    func log(_ message: String) {
        logs.append(message)
    }
    
    func contains(_ substring: String) -> Bool {
        return logs.contains { log in
            log.contains(substring)
        }
    }
    
    func clear() {
        logs.removeAll()
    }
    
    var messages: [String] {
        return logs
    }
}
