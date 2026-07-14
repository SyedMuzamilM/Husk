//
//  CancelFlag.swift
//  Husk
//

import Foundation

/// Thread-safe cancel flag shared across concurrent sizing tasks.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value || Task.isCancelled
    }

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        value = false
        lock.unlock()
    }
}
