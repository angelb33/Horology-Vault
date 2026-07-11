//
//  ContentView.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/10/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VaultGridView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Watch.self, inMemory: true)
}
