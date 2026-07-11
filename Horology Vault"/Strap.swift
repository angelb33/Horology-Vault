//
//  Strap.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

@Model
final class Strap {
    var material: String
    var widthMM: Double
    var attachedWatch: Watch?

    init(material: String, widthMM: Double, attachedWatch: Watch? = nil) {
        self.material = material
        self.widthMM = widthMM
        self.attachedWatch = attachedWatch
    }
}
