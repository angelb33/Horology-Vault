//
//  FitCalculatorTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/14/26.
//

import Testing
@testable import Horology_Vault

/// Pure geometry tests for `FitCalculator`, the math backing `FitDiagramView`'s fit verdict.
/// Per the monetization plan's Phase 9 priorities, this is the highest-value thing to unit test
/// since it's pure and has no SwiftData/StoreKit dependency to fake.
struct FitCalculatorTests {

    @Test("Watch narrower than wrist fits with zero overhang")
    func watchSmallerThanWristFits() {
        let result = FitCalculator.evaluate(lugToLugMM: 44, wristTopWidthCM: 6.5)
        #expect(result.wristWidthMM == 65)
        #expect(result.overhangMM == 0)
        #expect(result.fits == true)
    }

    @Test("Watch wider than wrist overhangs by the exact difference")
    func watchLargerThanWristOverhangs() {
        let result = FitCalculator.evaluate(lugToLugMM: 50, wristTopWidthCM: 4.0)
        #expect(result.wristWidthMM == 40)
        #expect(result.overhangMM == 10)
        #expect(result.fits == false)
    }

    @Test("Exact boundary — lug-to-lug equal to wrist width fits, no overhang")
    func exactBoundaryFits() {
        // wristTopWidthCM * 10 == lugToLugMM exactly.
        let result = FitCalculator.evaluate(lugToLugMM: 65, wristTopWidthCM: 6.5)
        #expect(result.wristWidthMM == 65)
        #expect(result.overhangMM == 0)
        #expect(result.fits == true)
    }

    @Test("Just barely over the boundary overhangs by a tiny fractional amount")
    func justOverBoundaryOverhangs() {
        let result = FitCalculator.evaluate(lugToLugMM: 65.1, wristTopWidthCM: 6.5)
        #expect(result.fits == false)
        #expect(abs(result.overhangMM - 0.1) < 0.0001)
    }

    @Test("Zero lug-to-lug always fits any non-negative wrist")
    func zeroLugToLugFits() {
        let result = FitCalculator.evaluate(lugToLugMM: 0, wristTopWidthCM: 6.5)
        #expect(result.fits == true)
        #expect(result.overhangMM == 0)
    }

    @Test("Zero wrist width with a positive watch overhangs by the full lug-to-lug length")
    func zeroWristWidthOverhangsFully() {
        let result = FitCalculator.evaluate(lugToLugMM: 44, wristTopWidthCM: 0)
        #expect(result.wristWidthMM == 0)
        #expect(result.overhangMM == 44)
        #expect(result.fits == false)
    }

    @Test("Zero lug-to-lug and zero wrist width both fit (no overhang)")
    func bothZeroFits() {
        let result = FitCalculator.evaluate(lugToLugMM: 0, wristTopWidthCM: 0)
        #expect(result.fits == true)
        #expect(result.overhangMM == 0)
    }

    @Test("Overhang is clamped at zero, never negative, when the watch is much smaller than the wrist")
    func overhangNeverNegative() {
        let result = FitCalculator.evaluate(lugToLugMM: 10, wristTopWidthCM: 10)
        #expect(result.overhangMM >= 0)
        #expect(result.fits == true)
    }

    @Test("Negative lug-to-lug (invalid input) is still clamped to a non-negative overhang")
    func negativeLugToLugClampsOverhang() {
        // Not a realistic real-world measurement, but the math shouldn't produce a negative
        // overhang regardless of what's passed in.
        let result = FitCalculator.evaluate(lugToLugMM: -5, wristTopWidthCM: 6.5)
        #expect(result.overhangMM == 0)
        #expect(result.fits == true)
    }

    @Test("Extreme oversized watch on a very narrow wrist overhangs by a large, precise amount")
    func extremeOversizedWatch() {
        let result = FitCalculator.evaluate(lugToLugMM: 200, wristTopWidthCM: 5.0)
        #expect(result.wristWidthMM == 50)
        #expect(result.overhangMM == 150)
        #expect(result.fits == false)
    }
}
