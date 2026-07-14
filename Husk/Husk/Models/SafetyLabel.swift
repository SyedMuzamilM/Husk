//
//  SafetyLabel.swift
//  Husk
//

import SwiftUI

enum SafetyLabel: String, CaseIterable, Sendable, Comparable {
    case safe
    case review
    case caution
    case protected

    var title: String {
        switch self {
        case .safe: "Safe"
        case .review: "Review"
        case .caution: "Caution"
        case .protected: "Protected"
        }
    }

    var systemImage: String {
        switch self {
        case .safe: "checkmark.shield.fill"
        case .review: "eye.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .protected: "lock.shield.fill"
        }
    }

    var color: Color {
        switch self {
        case .safe: Color.safeLabel
        case .review: Color.reviewLabel
        case .caution: Color.cautionLabel
        case .protected: Color.protectedLabel
        }
    }

    var sortRank: Int {
        switch self {
        case .safe: 0
        case .review: 1
        case .caution: 2
        case .protected: 3
        }
    }

    var isSelectable: Bool { self != .protected }

    static func < (lhs: SafetyLabel, rhs: SafetyLabel) -> Bool {
        lhs.sortRank < rhs.sortRank
    }
}
