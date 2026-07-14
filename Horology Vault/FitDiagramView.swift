//
//  FitDiagramView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/13/26.
//

import SwiftUI

/// A top-down 2D comparison of a watch case's lug-to-lug length against the user's
/// wrist width, so a collector can see whether the watch will overhang the wrist edge
/// before buying or wearing it — the same read a caliper measurement would give, just
/// visual instead of a table of numbers.
struct FitDiagramView: View {
    let lugToLugMM: Double
    let wristTopWidthCM: Double

    private var wristWidthMM: Double { wristTopWidthCM * 10 }
    private var overhangMM: Double { max(0, lugToLugMM - wristWidthMM) }
    private var fits: Bool { overhangMM <= 0 }

    var body: some View {
        VStack(spacing: 12) {
            Canvas { context, size in
                let padding: CGFloat = 20
                let maxWidth = size.width - padding * 2
                let longestMM = max(lugToLugMM, wristWidthMM, 1)
                let scale = maxWidth / CGFloat(longestMM)

                let wristWidthPoints = CGFloat(wristWidthMM) * scale
                let watchWidthPoints = CGFloat(lugToLugMM) * scale

                let centerX = size.width / 2
                let centerY = size.height / 2

                let wristRect = CGRect(
                    x: centerX - wristWidthPoints / 2,
                    y: centerY - 18,
                    width: wristWidthPoints,
                    height: 36
                )
                context.fill(Path(roundedRect: wristRect, cornerRadius: 18), with: .color(.brown.opacity(0.3)))

                let watchRect = CGRect(
                    x: centerX - watchWidthPoints / 2,
                    y: centerY - 32,
                    width: watchWidthPoints,
                    height: 64
                )
                let watchColor: Color = fits ? .green : .red
                context.stroke(Path(roundedRect: watchRect, cornerRadius: 14), with: .color(watchColor), lineWidth: 3)
            }
            .frame(height: 140)

            if fits {
                Label("Fits within your wrist", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label(
                    "Overhangs by \(overhangMM.formatted(.number.precision(.fractionLength(1)))) mm",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        FitDiagramView(lugToLugMM: 44, wristTopWidthCM: 6.5)
        FitDiagramView(lugToLugMM: 50, wristTopWidthCM: 6.0)
    }
    .padding()
}
