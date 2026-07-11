//
//  WatchCardView.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct WatchCardView: View {
    let watch: Watch

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

            VStack(alignment: .leading, spacing: 2) {
                Text(watch.brand)
                    .font(.headline)
                Text(watch.model)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = watch.photoData, let image = platformImage(from: data) {
            image
                .resizable()
                .aspectRatio(1, contentMode: .fill)
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

#Preview {
    WatchCardView(watch: Watch(brand: "Omega", model: "Speedmaster", caseDiameterMM: 42, lugToLugMM: 48, lugWidthMM: 20))
        .frame(width: 160)
        .padding()
}
