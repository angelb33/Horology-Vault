//
//  WatchCardView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData
import Vision
import ImageIO

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WatchCardView: View {
    let watch: Watch

    @Query private var entitlements: [Entitlements]
    @State private var focusPoint: UnitPoint = .center

    // User-facing on/off switch in Settings' Appearance section — same literal-string-key
    // pattern as `colorSchemePreference`/`accentColorOption` there, since this is a plain
    // display preference with no dedicated "manager" type to centralize the key on.
    @AppStorage("isPowerReserveBarEnabled") private var isPowerReserveBarEnabled = true

    private var isUnlocked: Bool {
        entitlements.first?.isLifetimeUnlocked ?? false
    }

    /// The power reserve bar is a full-version-only *addition* alongside the free depleted/
    /// not-depleted badge (see `WatchCardView`'s badge overlay below), not a replacement for it —
    /// free users keep exactly what they have today, and unlocked users get the bar's richer
    /// "how much is left" signal on top of the same unambiguous depleted badge everyone sees,
    /// matching how every other paid feature in this app is scoped as additive, never a
    /// regression. Also respects the user's own Settings toggle — turning it off falls back to
    /// just the badge, same as a locked user, rather than leaving an otherwise-reserved empty slot.
    private var showsPowerReserveBar: Bool {
        isUnlocked && isPowerReserveBarEnabled && watch.powerReserveRemainingFraction != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            photoSquare
                .overlay(alignment: .topTrailing) {
                    // A watch already checked in for maintenance doesn't need a "service due"
                    // nag too — the maintenance badge takes precedence over showing both.
                    if watch.isOutForMaintenance {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption)
                            .padding(6)
                            .background(.blue, in: Circle())
                            .foregroundStyle(.white)
                            .padding(6)
                    } else if watch.isServiceDue {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption)
                            .padding(6)
                            .background(.orange, in: Circle())
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                }
                .overlay(alignment: .topLeading) {
                    // Shown whenever depleted, regardless of whether the premium bar is also
                    // showing — an empty bar alone read as too easy to miss at a glance, so the
                    // badge now gives every user (free or unlocked) the same unambiguous "needs
                    // winding now" signal, with the bar (when present) still doing the extra job
                    // of showing exactly how depleted watches got there relative to non-depleted ones.
                    if watch.isPowerReserveDepleted {
                        Image(systemName: "gauge.with.needle")
                            .font(.caption)
                            .padding(6)
                            .background(.red, in: Circle())
                            .foregroundStyle(.white)
                            .padding(6)
                    }
                }

            // Reserves this row's height even when the current watch has no bar to show
            // (quartz, no movement type set yet), so a mixed row of mechanical and quartz
            // watches — or any row at all once more watches are added — stays the same height
            // instead of the row growing/shrinking to whichever cell happens to have a bar.
            // Free (not-unlocked) users never see a bar on any card, so nothing is reserved for
            // them — reserving dead space for a feature they can't see would be worse, not better.
            // Same reasoning applies when the user has switched the feature off in Settings: the
            // slot goes away entirely rather than reserving dead space for a hidden feature.
            if isUnlocked && isPowerReserveBarEnabled {
                ZStack {
                    if let fraction = watch.powerReserveRemainingFraction {
                        PowerReserveBarView(fraction: fraction)
                    }
                }
                .frame(height: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(watch.brand)
                    .font(.headline)
                    .lineLimit(1)
                // Reserve 2 lines' worth of height regardless of actual length — without this, a
                // long model name wrapping to a second line grows that card's cell in the
                // LazyVGrid, which grows the whole row (rows share height across their cells) and
                // throws off alignment with shorter, single-line neighbors in the same row.
                Text(watch.model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
            }
        }
        .task(id: watch.photoData) {
            focusPoint = await saliencyFocusPoint(from: watch.photoData) ?? .center
        }
    }

    /// `Color.clear` sized to a square via `.aspectRatio(1, contentMode: .fit)` — unlike sizing
    /// the photo/placeholder content directly, this square's size is derived purely from the
    /// width the `LazyVGrid` column offers, never from leftover space in the card's `VStack`.
    /// That decoupling is what makes the photo immune to height variance introduced by anything
    /// else in the card (the power-reserve bar's presence, a wrapped title, a future badge row)
    /// — the previous approach of applying `.aspectRatio` directly to the image/placeholder let
    /// row-height changes elsewhere in the grid feed back into the photo's own size.
    private var photoSquare: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { photoContent }
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var photoContent: some View {
        if let data = watch.photoData,
           let image = platformImage(from: data),
           let pixelSize = uprightPixelSize(from: data) {
            SmartCroppedImage(image: image, pixelSize: pixelSize, focusPoint: focusPoint)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

/// A minimalist fuel-gauge-style bar for a watch's power reserve — thin, color-coded by
/// remaining fraction (green when comfortable, yellow when getting low, red when nearly or
/// fully depleted), replacing a numeric readout with something scannable across a whole grid
/// of cards at a glance.
private struct PowerReserveBarView: View {
    /// 0...1 remaining, per `Watch.powerReserveRemainingFraction`.
    let fraction: Double

    private var tint: Color {
        switch fraction {
        case ..<0.15: .red
        case ..<0.4: .yellow
        default: .green
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.quaternary)
                // Genuinely empty at fraction 0 — the depleted badge (shown alongside this bar,
                // see WatchCardView's badge overlay) now owns the "it's empty" signal, so this no
                // longer needs an artificial minimum-width sliver just to stay visible.
                Capsule()
                    .fill(tint)
                    .frame(width: geometry.size.width * fraction)
            }
        }
        .frame(height: 4)
    }
}

/// Renders `image` scaled to fill a square, offset so `focusPoint` (in the image's own
/// upright coordinate space, 0...1 with y measured from the top) lands at the center of
/// the visible square instead of the frame's geometric center — this is what lets the
/// crop track the subject instead of always cutting evenly from every side.
private struct SmartCroppedImage: View {
    let image: Image
    let pixelSize: CGSize
    let focusPoint: UnitPoint

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let scale = max(side / pixelSize.width, side / pixelSize.height)
            let scaledWidth = pixelSize.width * scale
            let scaledHeight = pixelSize.height * scale

            let overflowX = max(scaledWidth - side, 0)
            let overflowY = max(scaledHeight - side, 0)

            let idealOffsetX = scaledWidth * focusPoint.x - side / 2
            let idealOffsetY = scaledHeight * focusPoint.y - side / 2

            let offsetX = min(max(idealOffsetX, 0), overflowX)
            let offsetY = min(max(idealOffsetY, 0), overflowY)

            image
                .resizable()
                .frame(width: scaledWidth, height: scaledHeight)
                .offset(x: -offsetX, y: -offsetY)
                .frame(width: side, height: side, alignment: .topLeading)
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(.easeInOut(duration: 0.3), value: focusPoint)
    }
}

private func platformImage(from data: Data) -> Image? {
    #if os(iOS)
    guard let uiImage = UIImage(data: data) else { return nil }
    return Image(uiImage: uiImage)
    #elseif os(macOS)
    guard let nsImage = NSImage(data: data) else { return nil }
    return Image(nsImage: nsImage)
    #else
    return nil
    #endif
}

/// The image's upright (orientation-corrected) pixel size — matches the coordinate space
/// `saliencyFocusPoint` reports its result in, since both account for EXIF orientation.
private func uprightPixelSize(from data: Data) -> CGSize? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }

    let width = CGFloat(cgImage.width)
    let height = CGFloat(cgImage.height)
    switch imageOrientation(from: source) {
    case .left, .leftMirrored, .right, .rightMirrored:
        return CGSize(width: height, height: width)
    default:
        return CGSize(width: width, height: height)
    }
}

private func imageOrientation(from source: CGImageSource) -> CGImagePropertyOrientation {
    guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let raw = properties[kCGImagePropertyOrientation] as? UInt32,
          let orientation = CGImagePropertyOrientation(rawValue: raw)
    else { return .up }
    return orientation
}

/// Uses Vision's on-device attention-based saliency detection to find the most visually
/// important region of the photo, so the square thumbnail crop can track the watch
/// instead of always cutting evenly from the frame's geometric center. Runs off the main
/// thread since a saliency pass takes noticeably longer than a plain image decode.
private func saliencyFocusPoint(from data: Data?) async -> UnitPoint? {
    guard let data,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { return nil }
    let orientation = imageOrientation(from: source)

    return await Task.detached(priority: .userInitiated) {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first as? VNSaliencyImageObservation,
              let salientObject = observation.salientObjects?.max(by: { $0.confidence < $1.confidence })
        else { return nil }

        let box = salientObject.boundingBox
        return UnitPoint(x: box.midX, y: 1 - box.midY)
    }.value
}

#Preview {
    WatchCardView(watch: Watch(brand: "Omega", model: "Speedmaster", caseDiameterMM: 42, lugToLugMM: 48, lugWidthMM: 20))
        .frame(width: 160)
        .padding()
        .modelContainer(for: [Watch.self, Entitlements.self], inMemory: true)
}
