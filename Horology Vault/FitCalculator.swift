//
//  FitCalculator.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation

/// Pure geometry behind `FitDiagramView`'s "does this watch fit my wrist" verdict, pulled out
/// of the View so it's unit-testable without instantiating SwiftUI. Keep this side-effect free —
/// `FitDiagramView` and any future callers (e.g. a batch "check my wishlist against my wrist"
/// feature) should be able to call this from a plain Swift Testing test.
enum FitCalculator {
    struct Result: Equatable {
        /// The wrist's top-down width, converted from the stored cm measurement to mm so it's
        /// directly comparable to `lugToLugMM`.
        let wristWidthMM: Double
        /// How far the watch case extends past the wrist edge on each side, in mm. Zero (never
        /// negative) when the watch is narrower than or equal to the wrist.
        let overhangMM: Double
        /// `true` when the watch's lug-to-lug length is within the wrist's top width.
        let fits: Bool
    }

    /// - Parameters:
    ///   - lugToLugMM: The watch case's lug-to-lug length, in millimeters.
    ///   - wristTopWidthCM: The wearer's wrist top width, in centimeters (as stored on
    ///     `UserProfile`).
    static func evaluate(lugToLugMM: Double, wristTopWidthCM: Double) -> Result {
        let wristWidthMM = wristTopWidthCM * 10
        let overhangMM = max(0, lugToLugMM - wristWidthMM)
        let fits = overhangMM <= 0
        return Result(wristWidthMM: wristWidthMM, overhangMM: overhangMM, fits: fits)
    }
}
