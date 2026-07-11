//
//  ServiceRecord.swift
//  Horology Vault"
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

@Model
final class ServiceRecord {
    var datePerformed: Date
    var serviceType: String
    var accuracyDeltaSPD: Double
    var watch: Watch?

    init(datePerformed: Date, serviceType: String, accuracyDeltaSPD: Double, watch: Watch? = nil) {
        self.datePerformed = datePerformed
        self.serviceType = serviceType
        self.accuracyDeltaSPD = accuracyDeltaSPD
        self.watch = watch
    }
}
