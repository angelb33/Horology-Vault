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
    var phone: String?
    var address: String?
    var secondaryWebsite: String?

    init(
        brand: String,
        name: String,
        website: String,
        notes: String,
        phone: String? = nil,
        address: String? = nil,
        secondaryWebsite: String? = nil
    ) {
        self.brand = brand
        self.name = name
        self.website = website
        self.notes = notes
        self.phone = phone
        self.address = address
        self.secondaryWebsite = secondaryWebsite
    }
}
