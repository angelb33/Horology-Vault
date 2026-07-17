//
//  Watch.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

enum MovementType: String, Codable, CaseIterable, Identifiable {
    case manual = "Manual"
    case automatic = "Automatic"
    case quartz = "Quartz"

    var id: String { rawValue }
}

@Model
final class Watch {
    var brand: String
    var model: String
    var referenceNumber: String?
    var complications: [String]
    var caseDiameterMM: Double
    var lugToLugMM: Double
    var lugWidthMM: Double
    var acquisitionDate: Date
    var purchasePrice: Double?
    var movementType: MovementType?
    var powerReserveHours: Double?

    @Attribute(.externalStorage)
    var photoData: Data?

    @Relationship(deleteRule: .nullify, inverse: \Strap.attachedWatch)
    var attachedStrap: Strap?

    @Relationship(deleteRule: .cascade, inverse: \ServiceRecord.watch)
    var serviceRecords: [ServiceRecord] = []

    @Relationship(deleteRule: .cascade, inverse: \WearLog.watch)
    var wearLogs: [WearLog] = []

    @Relationship(deleteRule: .cascade, inverse: \ProvenanceDoc.watch)
    var provenanceDocs: [ProvenanceDoc] = []

    @Relationship(deleteRule: .cascade, inverse: \WindLog.watch)
    var windLogs: [WindLog] = []

    init(
        brand: String,
        model: String,
        referenceNumber: String? = nil,
        complications: [String] = [],
        caseDiameterMM: Double,
        lugToLugMM: Double,
        lugWidthMM: Double,
        acquisitionDate: Date = Date(),
        photoData: Data? = nil,
        purchasePrice: Double? = nil,
        movementType: MovementType? = nil,
        powerReserveHours: Double? = nil
    ) {
        self.brand = brand
        self.model = model
        self.referenceNumber = referenceNumber
        self.complications = complications
        self.caseDiameterMM = caseDiameterMM
        self.lugToLugMM = lugToLugMM
        self.lugWidthMM = lugWidthMM
        self.acquisitionDate = acquisitionDate
        self.photoData = photoData
        self.purchasePrice = purchasePrice
        self.movementType = movementType
        self.powerReserveHours = powerReserveHours
    }

    var lastServiceDate: Date? {
        serviceRecords.map(\.datePerformed).max()
    }

    /// Mechanical watches are typically serviced every 3-5 years; this is the date that
    /// crossing marks the watch as due, falling back to the acquisition date for watches
    /// that have never been serviced. Shared by `isServiceDue` and `NotificationManager`
    /// so the maintenance list and the reminder notification never disagree.
    var serviceDueDate: Date? {
        Calendar.current.date(byAdding: .year, value: 3, to: lastServiceDate ?? acquisitionDate)
    }

    var isServiceDue: Bool {
        guard let serviceDueDate else { return false }
        return serviceDueDate < Date()
    }

    /// Wear entries logged since the watch's last service (or since acquisition, if it's never been
    /// serviced) — surfaces watches accumulating wear without a matching service interval. Shared so the
    /// Insights dashboard's wear-vs-maintenance chart and any future consumer can't disagree, same reasoning
    /// as `serviceDueDate`.
    var wearCountSinceLastService: Int {
        let since = lastServiceDate ?? acquisitionDate
        return wearLogs.filter { $0.dateWorn > since }.count
    }

    /// `nil` unless both a purchase price is set and the watch has actually been worn at least
    /// once — avoids a divide-by-zero and avoids implying "$0/wear" for a watch that's never left
    /// the box. Deliberately not shown on `WatchDetailView`: this derived insight stays exclusive
    /// to the paywalled Insights dashboard (`CostPerWearChartView`), which is the point of adding
    /// it — the raw `purchasePrice` itself is free to view there instead.
    var costPerWear: Double? {
        guard let purchasePrice, !wearLogs.isEmpty else { return nil }
        return purchasePrice / Double(wearLogs.count)
    }

    /// The most recent `WindLog` entry's date, if any.
    var lastWoundDate: Date? {
        windLogs.map(\.dateWound).max()
    }

    /// The date power was last put into the movement. For `.manual` movements this is only
    /// ever an explicit wind; for `.automatic` movements, wearing the watch also recharges
    /// the mainspring via wrist motion, so the most recent `WearLog` entry counts too.
    /// `.quartz` (and unset) movements don't track power reserve at all. Note: an automatic
    /// sitting in a watch winder — not worn, not explicitly wound — isn't visible to the app
    /// and will read as depleted even if it isn't; a known limitation rather than a bug.
    var lastPoweredDate: Date? {
        guard let movementType else { return nil }
        switch movementType {
        case .manual:
            return lastWoundDate
        case .automatic:
            return [lastWoundDate, wearLogs.map(\.dateWorn).max()].compactMap { $0 }.max()
        case .quartz:
            return nil
        }
    }

    /// When the mainspring is expected to run down, derived from `lastPoweredDate` plus the
    /// user-entered `powerReserveHours` spec. `nil` if either is missing.
    var powerReserveExpiresAt: Date? {
        guard let lastPoweredDate, let powerReserveHours else { return nil }
        return lastPoweredDate.addingTimeInterval(powerReserveHours * 3600)
    }

    var isPowerReserveDepleted: Bool {
        guard let powerReserveExpiresAt else { return false }
        return powerReserveExpiresAt < Date()
    }

    /// The canonical complication vocabulary — shared by `AddWatchView`'s toggle list and
    /// `LearnHubContent`'s per-complication topics, so the two can't drift into mismatched
    /// spellings and silently break the Learn Hub cross-link to a user's own watches.
    static let commonComplications = [
        "Date", "Day-Date", "Chronograph", "GMT", "Moonphase",
        "Power Reserve", "World Time", "Perpetual Calendar", "Tourbillon", "Alarm"
    ]
}
