//
//  WearLog.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/13/26.
//

import Foundation
import SwiftData

@Model
final class WearLog {
    var dateWorn: Date
    var notes: String?
    var watch: Watch?

    init(dateWorn: Date = Date(), notes: String? = nil, watch: Watch? = nil) {
        self.dateWorn = dateWorn
        self.notes = notes
        self.watch = watch
    }
}
