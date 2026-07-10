//
//  Item.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
