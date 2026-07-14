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

    /// Mechanical watches are typically serviced every 3-5 years; flag anything past 3 as due,
    /// falling back to the acquisition date for watches that have never been serviced.
    var isServiceDue: Bool {
        let referenceDate = lastServiceDate ?? acquisitionDate
        guard let threshold = Calendar.current.date(byAdding: .year, value: 3, to: referenceDate) else {
            return false
        }
        return threshold < Date()
    }
}
