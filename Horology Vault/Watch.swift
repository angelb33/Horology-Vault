//
//  Watch.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/10/26.
//

import Foundation
import SwiftData

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

    init(
        brand: String,
        model: String,
        referenceNumber: String? = nil,
        complications: [String] = [],
        caseDiameterMM: Double,
        lugToLugMM: Double,
        lugWidthMM: Double,
        acquisitionDate: Date = Date(),
        photoData: Data? = nil
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
}
