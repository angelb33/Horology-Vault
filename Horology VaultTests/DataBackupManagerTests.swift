//
//  DataBackupManagerTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/17/26.
//

import Foundation
import SwiftData
import Testing
@testable import Horology_Vault

/// Guards the encrypted backup/restore round trip — added after discovering `WatchBackup` was
/// silently missing several `Watch` fields (Winding Log's movement/reminder fields, plus every
/// new collector/insurance detail field), meaning a restore would quietly drop that data even
/// though the feature is documented as capturing "the entire collection." This test exists so
/// that gap can't reopen unnoticed if a future field is added to `Watch` without also touching
/// `WatchBackup`.
@MainActor
struct DataBackupManagerTests {

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Watch.self, Strap.self, ServiceRecord.self, WearLog.self, ProvenanceDoc.self,
            WindLog.self, WishlistItem.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test("Encrypted backup round trip preserves every Watch field, including Winding Log and collector-detail fields")
    func encryptedBackupRoundTripPreservesAllWatchFields() throws {
        let sourceContext = try makeInMemoryContext()

        let acquisitionDate = Date(timeIntervalSince1970: 1_000_000)
        let warrantyDate = Date(timeIntervalSince1970: 2_000_000)
        let appraisalDate = Date(timeIntervalSince1970: 3_000_000)
        let windDate = Date(timeIntervalSince1970: 4_000_000)

        let watch = Watch(
            brand: "Omega",
            model: "Seamaster",
            referenceNumber: "210.30.42.20.01.001",
            caseDiameterMM: 42,
            lugToLugMM: 48,
            lugWidthMM: 20,
            acquisitionDate: acquisitionDate,
            purchasePrice: 4500,
            movementType: .automatic,
            powerReserveHours: 55,
            windReminderLeadTimeHours: 6,
            serialNumber: "12345678",
            caliber: "8800",
            caseMaterial: "Stainless Steel",
            dialColor: "Blue Sunburst",
            waterResistanceMeters: 300,
            boxAndPapersStatus: .fullSet,
            condition: .excellent,
            warrantyExpirationDate: warrantyDate,
            insuredValue: 6000,
            appraisalDate: appraisalDate
        )
        watch.serviceIntervalYears = 4
        watch.isServiceDueReminderEnabled = false
        watch.isWindReminderEnabled = true
        sourceContext.insert(watch)
        sourceContext.insert(WindLog(dateWound: windDate, watch: watch))

        let data = try DataBackupManager.exportEncryptedBackup(context: sourceContext, passphrase: "test-passphrase")

        let destinationContext = try makeInMemoryContext()
        let summary = try DataBackupManager.importEncryptedBackup(data, passphrase: "test-passphrase", context: destinationContext)
        #expect(summary.watchesRestored == 1)

        let restored = try #require(try destinationContext.fetch(FetchDescriptor<Watch>()).first)

        #expect(restored.brand == "Omega")
        #expect(restored.model == "Seamaster")
        #expect(restored.referenceNumber == "210.30.42.20.01.001")
        #expect(restored.caseDiameterMM == 42)
        #expect(restored.lugToLugMM == 48)
        #expect(restored.lugWidthMM == 20)
        #expect(restored.acquisitionDate == acquisitionDate)
        #expect(restored.purchasePrice == 4500)
        #expect(restored.movementType == .automatic)
        #expect(restored.powerReserveHours == 55)
        #expect(restored.windReminderLeadTimeHours == 6)
        #expect(restored.serviceIntervalYears == 4)
        #expect(restored.isServiceDueReminderEnabled == false)
        #expect(restored.isWindReminderEnabled == true)
        #expect(restored.serialNumber == "12345678")
        #expect(restored.caliber == "8800")
        #expect(restored.caseMaterial == "Stainless Steel")
        #expect(restored.dialColor == "Blue Sunburst")
        #expect(restored.waterResistanceMeters == 300)
        #expect(restored.boxAndPapersStatus == .fullSet)
        #expect(restored.condition == .excellent)
        #expect(restored.warrantyExpirationDate == warrantyDate)
        #expect(restored.insuredValue == 6000)
        #expect(restored.appraisalDate == appraisalDate)
        #expect(restored.windLogs.count == 1)
        #expect(restored.windLogs.first?.dateWound == windDate)
    }
}
