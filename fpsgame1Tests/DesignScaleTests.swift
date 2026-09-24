//
//  DesignScaleTests.swift
//  fpsgame1Tests
//
//  The 960×600 layouts shrink to fit smaller hosts (phones, a small Mac window)
//  and are left alone on larger ones.
//

import XCTest
@testable import fpsgame1

final class DesignScaleTests: XCTestCase {

    func testDesignSizeMatchesTheWindow() {
        XCTAssertEqual(FitDesignSize.designWidth, 960)
        XCTAssertEqual(FitDesignSize.designHeight, 600)
    }

    func testLargerHostsAreNotScaled() {
        XCTAssertEqual(FitDesignSize.scale(for: CGSize(width: 960, height: 600)), 1)
        XCTAssertEqual(FitDesignSize.scale(for: CGSize(width: 1920, height: 1200)), 1)
        XCTAssertEqual(FitDesignSize.scale(for: CGSize(width: 1180, height: 820)), 1, "iPad landscape")
    }

    func testSmallerHostsShrinkToTheTighterAxis() {
        // iPhone landscape: the height is the constraint
        XCTAssertEqual(FitDesignSize.scale(for: CGSize(width: 852, height: 393)), 393.0 / 600.0, accuracy: 1e-9)
        // a narrow Mac window: the width is
        XCTAssertEqual(FitDesignSize.scale(for: CGSize(width: 800, height: 600)), 800.0 / 960.0, accuracy: 1e-9)
    }

    func testDegenerateSizesAreSafe() {
        XCTAssertEqual(FitDesignSize.scale(for: .zero), 1)
        XCTAssertEqual(FitDesignSize.scale(for: CGSize(width: 100, height: 0)), 1)
    }
}
