//
//  PerformanceRatingTests.swift
//  fpsgame1Tests
//
//  The summary rating borrows DOOM's skill names in DOOM's order: a full clear
//  under par earns the top tier, NIGHTMARE!, and the tiers below fall with the
//  kill percentage.
//

import XCTest
@testable import fpsgame1

final class PerformanceRatingTests: XCTestCase {

    private func rate(kills: Int, of total: Int = 10, time: Double = 100, par: Double = 120) -> PerformanceRating {
        PerformanceRating.rate(kills: kills, totalEnemies: total, time: time, parTime: par)
    }

    func testAFullClearUnderParIsNightmareAndOverParIsUltraViolence() {
        XCTAssertEqual(rate(kills: 10, time: 100, par: 120), .nightmare)
        XCTAssertEqual(rate(kills: 10, time: 120, par: 120), .ultraViolence, "par itself is not beaten")
        XCTAssertEqual(rate(kills: 10, time: 300, par: 120), .ultraViolence)
    }

    func testTheLowerTiersFollowTheKillPercentage() {
        XCTAssertEqual(rate(kills: 9), .hurtMePlenty)
        XCTAssertEqual(rate(kills: 8), .hurtMePlenty)
        XCTAssertEqual(rate(kills: 7), .notTooRough)
        XCTAssertEqual(rate(kills: 5), .notTooRough)
        XCTAssertEqual(rate(kills: 4), .tooYoungToDie)
        XCTAssertEqual(rate(kills: 0), .tooYoungToDie)
    }

    func testTimeOnlyMattersForAFullClear() {
        XCTAssertEqual(rate(kills: 9, time: 10), .hurtMePlenty)
        XCTAssertEqual(rate(kills: 5, time: 10), .notTooRough)
    }

    func testALevelWithoutEnemiesRatesOnTimeAlone() {
        XCTAssertEqual(rate(kills: 0, of: 0, time: 100, par: 120), .nightmare)
        XCTAssertEqual(rate(kills: 0, of: 0, time: 200, par: 120), .ultraViolence)
    }

    func testTheTiersAreOrderedWorstToBest() {
        XCTAssertEqual(PerformanceRating.allCases, [.tooYoungToDie, .notTooRough, .hurtMePlenty, .ultraViolence, .nightmare])
        XCTAssertLessThan(PerformanceRating.ultraViolence, .nightmare)
        XCTAssertLessThan(PerformanceRating.tooYoungToDie, .notTooRough)
    }

    func testTitlesMatchTheSkillNames() {
        // The four tiers that share a name with a skill spell it the same way
        XCTAssertEqual(PerformanceRating.tooYoungToDie.title, Difficulty.easy.name)
        XCTAssertEqual(PerformanceRating.hurtMePlenty.title, Difficulty.normal.name)
        XCTAssertEqual(PerformanceRating.ultraViolence.title, Difficulty.hard.name)
        XCTAssertEqual(PerformanceRating.nightmare.title, Difficulty.nightmare.name)
        XCTAssertEqual(PerformanceRating.notTooRough.title, "HEY, NOT TOO ROUGH")
        XCTAssertEqual(performanceRating(kills: 10, totalEnemies: 10, time: 60, parTime: 120), "NIGHTMARE!")
    }
}
