//
//  WindLog.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/17/26.
//

import Foundation
import SwiftData

@Model
final class WindLog {
    var dateWound: Date
    var watch: Watch?

    init(dateWound: Date = Date(), watch: Watch? = nil) {
        self.dateWound = dateWound
        self.watch = watch
    }
}
