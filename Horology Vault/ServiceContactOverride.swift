//
//  ServiceContactOverride.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData

/// A user edit to one of `OfficialServiceDirectory`'s bundled manufacturer entries, keyed by
/// `brand` (the bundled list's own stable identity). Only present when a user has actually
/// edited that entry — "Reset to Default" just deletes the row, since the bundled contact is
/// always the fallback for any field.
@Model
final class ServiceContactOverride {
    var brand: String
    var name: String
    var website: String
    var notes: String

    init(brand: String, name: String, website: String, notes: String) {
        self.brand = brand
        self.name = name
        self.website = website
        self.notes = notes
    }
}
