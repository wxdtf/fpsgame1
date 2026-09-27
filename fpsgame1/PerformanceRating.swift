//
//  PerformanceRating.swift
//  fpsgame1
//
//  The rating on the level and campaign summaries. It borrows DOOM's skill names
//  and keeps their order: the harder the skill the rating is named after, the
//  better the run. The tiers, worst to best:
//
//    I'M TOO YOUNG TO DIE   under half the enemies killed
//    HEY, NOT TOO ROUGH     at least half
//    HURT ME PLENTY         at least 80%
//    ULTRA-VIOLENCE         every enemy killed, slower than par
//    NIGHTMARE!             every enemy killed, faster than par
//

import Foundation

enum PerformanceRating: Int, CaseIterable, Comparable {
    case tooYoungToDie = 0
    case notTooRough
    case hurtMePlenty
    case ultraViolence
    case nightmare

    /// Kill fractions that unlock the three lower tiers
    static let notTooRoughKills = 0.5
    static let hurtMePlentyKills = 0.8

    var title: String {
        switch self {
        case .tooYoungToDie: return "I'M TOO YOUNG TO DIE"
        case .notTooRough: return "HEY, NOT TOO ROUGH"
        case .hurtMePlenty: return "HURT ME PLENTY"
        case .ultraViolence: return "ULTRA-VIOLENCE"
        case .nightmare: return "NIGHTMARE!"
        }
    }

    /// Rate a run: kills decide the tier, and a full clear is split by the par time.
    /// A level with no enemies rates on time alone, so a quick run of it is still
    /// rewarded.
    static func rate(kills: Int, totalEnemies: Int, time: Double, parTime: Double) -> PerformanceRating {
        let killFraction = totalEnemies > 0 ? Double(kills) / Double(totalEnemies) : 1
        if killFraction >= 1 { return time < parTime ? .nightmare : .ultraViolence }
        if killFraction >= hurtMePlentyKills { return .hurtMePlenty }
        if killFraction >= notTooRoughKills { return .notTooRough }
        return .tooYoungToDie
    }

    static func < (lhs: PerformanceRating, rhs: PerformanceRating) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The rating's title, for the summary screens
func performanceRating(kills: Int, totalEnemies: Int, time: Double, parTime: Double) -> String {
    PerformanceRating.rate(kills: kills, totalEnemies: totalEnemies, time: time, parTime: parTime).title
}
