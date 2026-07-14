//
//  Strap.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

@Model
final class Strap {
    var name: String?
    var material: String
    var widthMM: Double
    var lengthMM: Double?
    var notes: String?
    var attachedWatch: Watch?

    init(
        name: String? = nil,
        material: String,
        widthMM: Double,
        lengthMM: Double? = nil,
        notes: String? = nil,
        attachedWatch: Watch? = nil
    ) {
        self.name = name
        self.material = material
        self.widthMM = widthMM
        self.lengthMM = lengthMM
        self.notes = notes
        self.attachedWatch = attachedWatch
    }

    /// A short label combining name (if set) with material and width, for use in
    /// pickers and summary rows across the app.
    var summary: String {
        let namePart = name?.trimmingCharacters(in: .whitespaces)
        if let namePart, !namePart.isEmpty {
            return "\(namePart) \u{b7} \(material) \u{b7} \(widthMM.formatted()) mm"
        }
        return "\(material) \u{b7} \(widthMM.formatted()) mm"
    }
}
