//
//  WatchCardView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import Vision
import ImageIO

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WatchCardView: View {
    let watch: Watch

    @State private var focusPoint: UnitPoint = .center

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                photo
                if watch.isServiceDue {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.caption)
                        .padding(6)
                        .background(.orange, in: Circle())
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
            .overlay(alignment: .topLeading) {
                if watch.isPowerReserveDepleted {
                    Image(systemName: "gauge.with.needle")
                        .font(.caption)
                        .padding(6)
                        .background(.red, in: Circle())
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(watch.brand)
                    .font(.headline)
                Text(watch.model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: watch.photoData) {
            focusPoint = await saliencyFocusPoint(from: watch.photoData) ?? .center
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = watch.photoData,
           let image = platformImage(from: data),
           let pixelSize = uprightPixelSize(from: data) {
            SmartCroppedImage(image: image, pixelSize: pixelSize, focusPoint: focusPoint)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
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
}
