//
//  Wishlist.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/11/26.
//

import Foundation
import SwiftData

@Model
final class WishlistItem {
    var brand: String
    var model: String
    var targetPrice: Double
    var notes: String
    var priceAlertEnabled: Bool

    init(
        brand: String,
        model: String,
        targetPrice: Double,
        notes: String = "",
        priceAlertEnabled: Bool = false
    ) {
        self.brand = brand
        self.model = model
        self.targetPrice = targetPrice
        self.notes = notes
        self.priceAlertEnabled = priceAlertEnabled
    }
}
