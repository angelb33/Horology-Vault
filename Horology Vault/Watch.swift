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

/// What accessories/documentation accompany the watch — a commonly-tracked field across watch
/// collection apps since it directly affects resale value (a "full set" can add 10-25% over a
/// watch-only sale, per collector/insurance sources).
enum BoxAndPapersStatus: String, Codable, CaseIterable, Identifiable {
    case fullSet = "Full Set"
    case watchOnly = "Watch Only"
    case boxOnly = "Box Only"
    case papersOnly = "Papers Only"

    var id: String { rawValue }
}

/// Subjective condition grading, the same rough scale used across the secondary watch market.
enum WatchCondition: String, Codable, CaseIterable, Identifiable {
    case new = "New"
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

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
    var windReminderLeadTimeHours: Double?
    var serviceIntervalYears: Int?
    var isServiceDueReminderEnabled: Bool?
    var isWindReminderEnabled: Bool?

    // Collector/insurance detail fields, added 2026-07-17 after a review of what comparable
    // watch-collection apps and horology/insurance sources commonly track (see CLAUDE.md for
    // sourcing) — all plain additive optionals, same zero-migration-risk pattern as every field
    // above. `serialNumber` identifies this individual unit (vs. `referenceNumber`, which
    // identifies the model); `caliber` is the specific movement designation (e.g. "ETA 2824-2"),
    // more granular than `movementType`'s manual/automatic/quartz classification.
    var serialNumber: String?
    var caliber: String?
    var caseMaterial: String?
    var dialColor: String?
    var waterResistanceMeters: Int?
    var boxAndPapersStatus: BoxAndPapersStatus?
    var condition: WatchCondition?
    var warrantyExpirationDate: Date?
    var insuredValue: Double?
    var appraisalDate: Date?

    // Out-for-maintenance tracking, added 2026-07-17. `maintenanceDropOffDate` non-nil is what
    // it means for a watch to currently be "out for maintenance" — see `isOutForMaintenance`.
    // Not `init(...)` parameters, same reasoning as `serviceIntervalYears`/the reminder-enabled
    // toggles above: these are only ever set later via the Workbench's Maintenance section, never
    // at watch-creation time.
    var maintenanceDropOffDate: Date?
    var maintenanceExpectedPickupDate: Date?
    var maintenanceNotes: String?

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
        powerReserveHours: Double? = nil,
        windReminderLeadTimeHours: Double? = nil,
        serialNumber: String? = nil,
        caliber: String? = nil,
        caseMaterial: String? = nil,
        dialColor: String? = nil,
        waterResistanceMeters: Int? = nil,
        boxAndPapersStatus: BoxAndPapersStatus? = nil,
        condition: WatchCondition? = nil,
        warrantyExpirationDate: Date? = nil,
        insuredValue: Double? = nil,
        appraisalDate: Date? = nil
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
        self.windReminderLeadTimeHours = windReminderLeadTimeHours
        self.serialNumber = serialNumber
        self.caliber = caliber
        self.caseMaterial = caseMaterial
        self.dialColor = dialColor
        self.waterResistanceMeters = waterResistanceMeters
        self.boxAndPapersStatus = boxAndPapersStatus
        self.condition = condition
        self.warrantyExpirationDate = warrantyExpirationDate
        self.insuredValue = insuredValue
        self.appraisalDate = appraisalDate
    }

    var lastServiceDate: Date? {
        serviceRecords.map(\.datePerformed).max()
    }

    /// Mechanical watches are typically serviced every 3-5 years; the interval is user-configurable
    /// three ways, checked in order: this watch's own `serviceIntervalYears` override (set on the
    /// Workbench's Reminders section), then the app-wide Settings default (`UserDefaults`, since
    /// `Watch` is a SwiftData model and can't hold `@AppStorage` — same direct-read pattern
    /// `ScheduledBackupManager` already uses), then `NotificationManager.defaultServiceIntervalYears`.
    /// The resulting date is what crossing marks the watch as due, falling back to the acquisition
    /// date for watches that have never been serviced. Shared by `isServiceDue` and
    /// `NotificationManager` so the maintenance list and the reminder notification never disagree.
    var serviceDueDate: Date? {
        let intervalYears = serviceIntervalYears
            ?? UserDefaults.standard.object(forKey: NotificationManager.serviceIntervalYearsKey) as? Int
            ?? NotificationManager.defaultServiceIntervalYears
        return Calendar.current.date(byAdding: .year, value: intervalYears, to: lastServiceDate ?? acquisitionDate)
    }

    var isServiceDue: Bool {
        guard let serviceDueDate else { return false }
        return serviceDueDate < Date()
    }

    /// Whether the watch is currently checked in at a service center, set by the Workbench's
    /// "Drop Off for Maintenance" action and cleared by "Mark Picked Up". A watch out for
    /// maintenance is, by definition, already being addressed — `WatchCardView`'s badge and
    /// `MaintenanceView`'s grouping both treat this as taking precedence over `isServiceDue`
    /// rather than showing both states at once.
    var isOutForMaintenance: Bool {
        maintenanceDropOffDate != nil
    }

    // MARK: - Notifications panel digest predicates
    //
    // These back the free, live-computed Notifications panel (`NotificationsPanelView`) —
    // deliberately defined once here rather than duplicated inline in both the panel and
    // `ContentView`'s badge count, so the two can't silently disagree. Each mirrors a signal
    // that's already free elsewhere in the app (the Vault card badges, `MaintenanceView`'s
    // grouping) — the panel is a convenience aggregation over already-free facts, not new
    // information, and deliberately only reflects what's already true rather than predicting
    // what's coming up (that lead-time-warning behavior stays exclusive to the paid Reminders
    // feature). See CLAUDE.md for the full reasoning behind this scope boundary.

    /// Mirrors the free depleted badge on `WatchCardView`.
    var hasOpenPowerReserveNotification: Bool {
        isPowerReserveDepleted
    }

    /// Same filter `MaintenanceView` uses for its "Service Due" bucket — excludes watches
    /// already out for maintenance, since that's already being addressed.
    var hasOpenServiceNotification: Bool {
        isServiceDue && !isOutForMaintenance
    }

    /// A watch out for maintenance whose expected pickup date has already passed — ready (or
    /// overdue) to be picked up. Watches with no expected pickup date set never trigger this,
    /// since there's no date to compare against.
    var hasOpenPickupNotification: Bool {
        guard isOutForMaintenance, let maintenanceExpectedPickupDate else { return false }
        return maintenanceExpectedPickupDate <= Date()
    }

    /// Total open notification-worthy issues for this watch (0–2 in practice — a watch can be
    /// simultaneously out of power and overdue for service, but service-due and pickup-ready are
    /// mutually exclusive since the latter requires already being out for maintenance). Backs the
    /// Notifications panel's toolbar badge count.
    var openNotificationCount: Int {
        [hasOpenPowerReserveNotification, hasOpenServiceNotification, hasOpenPickupNotification]
            .filter { $0 }
            .count
    }

    /// One stable string per currently-open issue (not per watch) — lets
    /// `NotificationsAcknowledgment` track exactly which issues the user has already seen,
    /// separately from how many are currently open. Recomputed fresh every time (never stored),
    /// so a resolved-then-reopened issue naturally gets a "new" key again the next time this is
    /// read — nothing to reconcile or expire manually.
    ///
    /// Known, accepted limitation: `String(describing: persistentModelID)` only becomes
    /// genuinely unique per watch once SwiftData has actually saved it — an unsaved model's
    /// identifier prints as a generic placeholder string shared by every other unsaved model
    /// (confirmed by direct experimentation; `PersistentIdentifier`'s own `==`/`Hashable` are
    /// correct pre-save, only its `description` isn't). In practice this only matters for a
    /// narrow, self-correcting window — two brand-new watches created in the same moment, both
    /// immediately having an identical open-issue type, before the next autosave — after which
    /// the IDs resolve to their real, stable values. Not worth extra complexity to close; see
    /// `NotificationsAcknowledgmentTests` for how this was diagnosed.
    var openNotificationKeys: [String] {
        let id = String(describing: persistentModelID)
        var keys: [String] = []
        if hasOpenPowerReserveNotification { keys.append("\(id)-power") }
        if hasOpenServiceNotification { keys.append("\(id)-service") }
        if hasOpenPickupNotification { keys.append("\(id)-pickup") }
        return keys
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

    /// Fraction of the power reserve remaining, from `1.0` (just wound/worn) down to `0.0`
    /// (fully depleted) — clamped so an overdue watch reads as exactly empty rather than
    /// negative. `nil` for the same reasons `powerReserveExpiresAt` is nil (quartz, unset
    /// movement, or no power-reserve spec yet). Backs the Vault grid's power reserve bar, a
    /// full-version-only upgrade over the free depleted/not-depleted badge — see
    /// `WatchCardView`.
    var powerReserveRemainingFraction: Double? {
        guard let lastPoweredDate, let powerReserveHours, powerReserveHours > 0 else { return nil }
        let elapsedHours = Date().timeIntervalSince(lastPoweredDate) / 3600
        let remainingFraction = 1 - (elapsedHours / powerReserveHours)
        return min(max(remainingFraction, 0), 1)
    }

    /// Whole days elapsed since `powerReserveExpiresAt`, or `nil` if the watch isn't currently
    /// depleted (or isn't trackable at all). Backs the Insights dashboard's "Depleted Watches"
    /// chart — see `DepletedWatchesChartView`.
    var daysSincePowerReserveDepleted: Int? {
        guard isPowerReserveDepleted, let powerReserveExpiresAt else { return nil }
        return Calendar.current.dateComponents([.day], from: powerReserveExpiresAt, to: Date()).day
    }

    /// When the wind reminder notification should fire — `powerReserveExpiresAt` minus the
    /// user-entered `windReminderLeadTimeHours` lead time. `nil` if either is missing, which
    /// also covers quartz/unset movements (no `powerReserveExpiresAt`) without a separate check.
    var windReminderDate: Date? {
        guard let powerReserveExpiresAt, let windReminderLeadTimeHours else { return nil }
        return powerReserveExpiresAt.addingTimeInterval(-windReminderLeadTimeHours * 3600)
    }

    /// The canonical complication vocabulary — shared by `AddWatchView`'s toggle list and
    /// `LearnHubContent`'s per-complication topics, so the two can't drift into mismatched
    /// spellings and silently break the Learn Hub cross-link to a user's own watches.
    static let commonComplications = [
        "Date", "Day-Date", "Chronograph", "GMT", "Moonphase",
        "Power Reserve", "World Time", "Perpetual Calendar", "Tourbillon", "Alarm"
    ]
}
