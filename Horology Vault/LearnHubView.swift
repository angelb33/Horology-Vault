//
//  LearnHubView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/15/26.
//

import SwiftUI
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct LearnHubView: View {
    @State private var searchText = ""

    private var filteredTopics: [LearnTopic] {
        guard !searchText.isEmpty else { return LearnHubContent.topics }
        return LearnHubContent.topics.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func topics(in category: LearnCategory) -> [LearnTopic] {
        filteredTopics.filter { $0.category == category }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filteredTopics.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(LearnCategory.allCases) { category in
                            let categoryTopics = topics(in: category)
                            if !categoryTopics.isEmpty {
                                Section {
                                    ForEach(categoryTopics) { topic in
                                        LearnTopicRow(topic: topic)
                                    }
                                } header: {
                                    SectionHeader(category.rawValue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Learn Hub")
            .searchable(text: $searchText)
            .navigationDestination(for: LearnTopic.self) { topic in
                LearnTopicDetailView(topic: topic)
            }
            .navigationDestination(for: Watch.self) { watch in
                WatchDetailView(watch: watch)
            }
        }
    }
}

private struct LearnTopicRow: View {
    let topic: LearnTopic

    @AppStorage("accentColorOption") private var accentColorOption: AccentColorOption = .blue

    var body: some View {
        NavigationLink(value: topic) {
            HStack(spacing: 12) {
                Image(systemName: topic.displaySystemImage)
                    .font(.title3)
                    .foregroundStyle(accentColorOption.color)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.headline)
                    Text(topic.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct LearnTopicDetailView: View {
    let topic: LearnTopic
    @Query private var watches: [Watch]

    private var bodyParagraphs: [String] {
        topic.body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var relatedWatches: [Watch] {
        guard let complicationName = topic.complicationName else { return [] }
        return watches.filter { $0.complications.contains(complicationName) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CategoryChip(category: topic.category)

                VStack(alignment: .leading, spacing: 6) {
                    Text(topic.title)
                        .font(.largeTitle)
                        .bold()
                    Text(topic.summary)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(bodyParagraphs, id: \.self) { paragraph in
                        Text(paragraph)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }

                if !relatedWatches.isEmpty {
                    InYourVaultCard(watches: relatedWatches)
                }
            }
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(topic.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct CategoryChip: View {
    let category: LearnCategory

    @AppStorage("accentColorOption") private var accentColorOption: AccentColorOption = .blue

    var body: some View {
        Label(category.rawValue, systemImage: category.systemImage)
            .font(.footnote.weight(.medium))
            .foregroundStyle(accentColorOption.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(accentColorOption.color.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(accentColorOption.color.opacity(0.3)))
    }
}

/// The complication cross-link, styled as a highlight rather than an afterthought: the
/// user just read about a complication and this shows it's literally on their wrist.
private struct InYourVaultCard: View {
    let watches: [Watch]

    @AppStorage("accentColorOption") private var accentColorOption: AccentColorOption = .blue

    private var countText: String {
        watches.count == 1
            ? "You own 1 watch with this complication."
            : "You own \(watches.count) watches with this complication."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("In Your Vault", systemImage: "star.fill")
                .font(.headline)
                .foregroundStyle(accentColorOption.color)

            Text(countText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(watches.enumerated()), id: \.element.id) { index, watch in
                    if index > 0 {
                        Divider()
                    }
                    NavigationLink(value: watch) {
                        HStack(spacing: 12) {
                            WatchThumbnail(watch: watch)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(watch.brand)
                                    .font(.headline)
                                Text(watch.model)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(accentColorOption.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(accentColorOption.color.opacity(0.3)))
        .accessibilityElement(children: .combine)
    }
}

private struct WatchThumbnail: View {
    let watch: Watch

    private var image: Image? {
        guard let data = watch.photoData else { return nil }
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

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Watch.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let chrono = Watch(
        brand: "Omega", model: "Speedmaster", complications: ["Chronograph"],
        caseDiameterMM: 42, lugToLugMM: 48, lugWidthMM: 20
    )
    container.mainContext.insert(chrono)

    return LearnHubView()
        .modelContainer(container)
}
