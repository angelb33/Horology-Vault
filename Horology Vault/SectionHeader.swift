//
//  SectionHeader.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/15/26.
//

import SwiftUI

/// Shared, app-wide style for `Form`/`List` section headers and `DisclosureGroup`
/// labels: centered and noticeably larger than the platform default (which is small,
/// uppercased, left-aligned, and secondary-styled). Use this everywhere a section title
/// is shown so the app reads with one consistent header voice.
///
/// Usage:
///   Section {
///       ...
///   } header: {
///       SectionHeader("Details")
///   }
struct SectionHeader: View {
    private let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            // .textCase(nil) opts out of the platform's automatic uppercasing of
            // grouped-section headers; the larger font is meant to be read as words.
            .textCase(nil)
            .font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    Form {
        Section {
            LabeledContent("Brand", value: "Rolex")
            LabeledContent("Model", value: "Submariner")
        } header: {
            SectionHeader("Overview")
        }

        Section {
            LabeledContent("Case", value: "40 mm")
        } header: {
            SectionHeader("Measurements")
        }
    }
    #if os(macOS)
    .formStyle(.grouped)
    #endif
}
