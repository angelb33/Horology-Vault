//
//  CustomServiceCenter.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData

/// A user-added entry in the Service Centers directory — a local watchmaker, an
/// independent repair shop, anything not covered by `OfficialServiceDirectory`'s
/// manufacturer-support list.
@Model
final class CustomServiceCenter {
    var name: String
    var brand: String?
    var phone: String?
    var website: String?
    var address: String?
    var notes: String?

    init(
        name: String,
        brand: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        address: String? = nil,
        notes: String? = nil
    ) {
        self.name = name
        self.brand = brand
        self.phone = phone
        self.website = website
        self.address = address
        self.notes = notes
    }
}
