//
//  ServiceRecord.swift
//  Horology Vault
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
    /// Marks this entry as a quartz battery replacement — a structured signal (not a guess from
    /// `serviceType`'s free text) that `Watch.lastBatteryReplacementDate` filters on to drive
    /// quartz power-reserve tracking. `nil`/`false` for every other kind of service.
    var isBatteryReplacement: Bool?
    var watch: Watch?

    init(datePerformed: Date, serviceType: String, accuracyDeltaSPD: Double, isBatteryReplacement: Bool? = nil, watch: Watch? = nil) {
        self.datePerformed = datePerformed
        self.serviceType = serviceType
        self.accuracyDeltaSPD = accuracyDeltaSPD
        self.isBatteryReplacement = isBatteryReplacement
        self.watch = watch
    }
}
