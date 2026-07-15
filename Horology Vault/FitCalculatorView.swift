//
//  FitCalculatorView.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/13/26.
//

import SwiftUI
import SwiftData

struct FitCalculatorView: View {
    @Query private var watches: [Watch]
    @Query private var userProfiles: [UserProfile]

    @State private var selectedWatch: Watch?

    var body: some View {
        NavigationStack {
            Group {
                if watches.isEmpty {
                    ContentUnavailableView(
                        "No Watches Yet",
                        systemImage: "clock",
                        description: Text("Add a watch to your Vault to preview its fit.")
                    )
                } else if let profile = userProfiles.first {
                    Form {
                        Section {
                            Picker("Watch", selection: $selectedWatch) {
                                Text("Select a Watch").tag(Watch?.none)
                                ForEach(watches) { watch in
                                    Text("\(watch.brand) \(watch.model)").tag(Watch?.some(watch))
                                }
                            }
                        } header: {
                            SectionHeader("Watch")
                        }

                        if let selectedWatch {
                            Section {
                                FitDiagramView(
                                    lugToLugMM: selectedWatch.lugToLugMM,
                                    wristTopWidthCM: profile.wristTopWidthCM
                                )
                            } header: {
                                SectionHeader("Fit Preview")
                            }
                        }
                    }
                    #if os(macOS)
                    .formStyle(.grouped)
                    #endif
                } else {
                    ContentUnavailableView(
                        "No Wrist Profile",
                        systemImage: "ruler",
                        description: Text("Add your wrist measurements in Settings to preview fit.")
                    )
                }
            }
            .navigationTitle("Fit Calculator")
            .onAppear {
                if selectedWatch == nil {
                    selectedWatch = watches.first
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Watch.self, UserProfile.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(UserProfile(wristTopWidthCM: 6.5, wristSideDepthCM: 4.0))
    container.mainContext.insert(Watch(brand: "Rolex", model: "Explorer", caseDiameterMM: 36, lugToLugMM: 44, lugWidthMM: 19))

    return FitCalculatorView()
        .modelContainer(container)
}
