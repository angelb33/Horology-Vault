//
//  WatchModelTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData
import Testing
@testable import Horology_Vault

/// Tests for `Watch`'s model-level invariants: the service-due date math shared with
/// `NotificationManager`/`MaintenanceView`, and SwiftData's cascade-delete / nullify-on-delete
/// relationship behavior declared on `Watch`'s `@Relationship` properties.
@MainActor
struct WatchModelTests {

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Watch.self, Strap.self, ServiceRecord.self, WearLog.self, ProvenanceDoc.self, WindLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeWatch(acquisitionDate: Date = .now) -> Watch {
        Watch(
            brand: "Omega",
            model: "Seamaster",
            caseDiameterMM: 42,
            lugToLugMM: 48,
            lugWidthMM: 20,
            acquisitionDate: acquisitionDate
        )
    }

    // MARK: - serviceDueDate / isServiceDue: no service records (falls back to acquisitionDate)

    @Test("With no service records, serviceDueDate falls back to the default 5 years after acquisitionDate")
    func serviceDueDateFallsBackToAcquisitionDate() {
        let acquisition = Date(timeIntervalSince1970: 0)
        let watch = makeWatch(acquisitionDate: acquisition)

        let expected = Calendar.current.date(byAdding: .year, value: 5, to: acquisition)
        #expect(watch.serviceDueDate == expected)
        #expect(watch.lastServiceDate == nil)
    }

    @Test("A watch acquired more than 5 years ago with no service records is service due")
    func watchWithNoServiceOlderThan3YearsIsDue() {
        let acquisition = Calendar.current.date(byAdding: .year, value: -6, to: .now)!
        let watch = makeWatch(acquisitionDate: acquisition)
        #expect(watch.isServiceDue == true)
    }

    @Test("A watch acquired less than 5 years ago with no service records is not service due")
    func watchWithNoServiceWithin3YearsIsNotDue() {
        let acquisition = Calendar.current.date(byAdding: .year, value: -1, to: .now)!
        let watch = makeWatch(acquisitionDate: acquisition)
        #expect(watch.isServiceDue == false)
    }

    // MARK: - serviceDueDate / isServiceDue: uses the most recent ServiceRecord

    @Test("serviceDueDate uses the most recent ServiceRecord's date, not acquisitionDate, when records exist")
    func serviceDueDateUsesMostRecentServiceRecord() {
        let acquisition = Calendar.current.date(byAdding: .year, value: -10, to: .now)!
        let watch = makeWatch(acquisitionDate: acquisition)

        let olderService = Date(timeIntervalSince1970: 1_000)
        let newerService = Date(timeIntervalSince1970: 2_000)
        watch.serviceRecords = [
            ServiceRecord(datePerformed: olderService, serviceType: "Full Service", accuracyDeltaSPD: 2),
            ServiceRecord(datePerformed: newerService, serviceType: "Battery", accuracyDeltaSPD: 0),
        ]

        #expect(watch.lastServiceDate == newerService)
        let expected = Calendar.current.date(byAdding: .year, value: 5, to: newerService)
        #expect(watch.serviceDueDate == expected)
    }

    @Test("Logging a recent service resets the due clock so an otherwise-overdue watch is no longer due")
    func recentServiceResetsDueClock() {
        let acquisition = Calendar.current.date(byAdding: .year, value: -10, to: .now)!
        let watch = makeWatch(acquisitionDate: acquisition)
        watch.serviceRecords = [
            ServiceRecord(datePerformed: .now, serviceType: "Full Service", accuracyDeltaSPD: 1)
        ]
        #expect(watch.isServiceDue == false)
    }

    @Test("A service record exactly 5 years old crosses the due boundary")
    func serviceExactlyThreeYearsAgoIsDue() {
        let acquisition = Calendar.current.date(byAdding: .year, value: -10, to: .now)!
        let watch = makeWatch(acquisitionDate: acquisition)
        let fiveYearsAgo = Calendar.current.date(byAdding: .year, value: -5, to: .now)!
        // Push it a little further back so it's unambiguously past the boundary (avoids test
        // flakiness from the few milliseconds elapsed between computing `fiveYearsAgo` and the
        // `isServiceDue` check inside the test).
        let justOverFiveYearsAgo = Calendar.current.date(byAdding: .day, value: -1, to: fiveYearsAgo)!
        watch.serviceRecords = [
            ServiceRecord(datePerformed: justOverFiveYearsAgo, serviceType: "Full Service", accuracyDeltaSPD: 0)
        ]
        #expect(watch.isServiceDue == true)
    }

    @Test("serviceDueDate uses the user-configured interval from UserDefaults instead of the default")
    func serviceDueDateUsesConfiguredInterval() {
        let key = NotificationManager.serviceIntervalYearsKey
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(2, forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        let acquisition = Date(timeIntervalSince1970: 0)
        let watch = makeWatch(acquisitionDate: acquisition)
        let expected = Calendar.current.date(byAdding: .year, value: 2, to: acquisition)
        #expect(watch.serviceDueDate == expected)
    }

    @Test("serviceDueDate prefers the watch's own serviceIntervalYears override over the global UserDefaults default")
    func serviceDueDateUsesPerWatchOverrideOverGlobalDefault() {
        let key = NotificationManager.serviceIntervalYearsKey
        let previous = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(2, forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }

        let acquisition = Date(timeIntervalSince1970: 0)
        let watch = makeWatch(acquisitionDate: acquisition)
        watch.serviceIntervalYears = 7
        let expected = Calendar.current.date(byAdding: .year, value: 7, to: acquisition)
        #expect(watch.serviceDueDate == expected)
    }

    // MARK: - wearCountSinceLastService (Insights dashboard's wear-vs-maintenance chart)

    @Test("With no wear logs, wearCountSinceLastService is 0")
    func wearCountSinceLastServiceIsZeroWithNoWearLogs() {
        let watch = makeWatch()
        #expect(watch.wearCountSinceLastService == 0)
    }

    @Test("Wear logged entirely before the last service does not count")
    func wearCountSinceLastServiceExcludesWearBeforeService() {
        let watch = makeWatch(acquisitionDate: Date(timeIntervalSince1970: 0))
        let service = Date(timeIntervalSince1970: 10_000)
        watch.serviceRecords = [
            ServiceRecord(datePerformed: service, serviceType: "Full Service", accuracyDeltaSPD: 0)
        ]
        watch.wearLogs = [
            WearLog(dateWorn: Date(timeIntervalSince1970: 1_000)),
            WearLog(dateWorn: Date(timeIntervalSince1970: 5_000)),
        ]
        #expect(watch.wearCountSinceLastService == 0)
    }

    @Test("Wear logged after the last service counts, and wear split across the boundary only counts the later entries")
    func wearCountSinceLastServiceCountsOnlyWearAfterService() {
        let watch = makeWatch(acquisitionDate: Date(timeIntervalSince1970: 0))
        let service = Date(timeIntervalSince1970: 10_000)
        watch.serviceRecords = [
            ServiceRecord(datePerformed: service, serviceType: "Full Service", accuracyDeltaSPD: 0)
        ]
        watch.wearLogs = [
            WearLog(dateWorn: Date(timeIntervalSince1970: 5_000)),   // before service
            WearLog(dateWorn: Date(timeIntervalSince1970: 11_000)),  // after service
            WearLog(dateWorn: Date(timeIntervalSince1970: 12_000)),  // after service
        ]
        #expect(watch.wearCountSinceLastService == 2)
    }

    @Test("With no service records, wearCountSinceLastService falls back to counting wear since acquisitionDate")
    func wearCountSinceLastServiceFallsBackToAcquisitionDate() {
        let acquisition = Date(timeIntervalSince1970: 10_000)
        let watch = makeWatch(acquisitionDate: acquisition)
        watch.wearLogs = [
            WearLog(dateWorn: Date(timeIntervalSince1970: 5_000)),   // before acquisition
            WearLog(dateWorn: Date(timeIntervalSince1970: 11_000)),  // after acquisition
        ]
        #expect(watch.wearCountSinceLastService == 1)
    }

    // MARK: - costPerWear (Insights dashboard's paywalled cost-per-wear chart)

    @Test("With no purchase price set, costPerWear is nil")
    func costPerWearIsNilWithNoPurchasePrice() {
        let watch = makeWatch()
        watch.wearLogs = [WearLog(dateWorn: .now)]
        #expect(watch.costPerWear == nil)
    }

    @Test("With a purchase price but no wear logs, costPerWear is nil (avoids divide-by-zero)")
    func costPerWearIsNilWithNoWearLogs() {
        let watch = makeWatch()
        watch.purchasePrice = 5_000
        #expect(watch.costPerWear == nil)
    }

    @Test("With a purchase price and wear logs, costPerWear divides price by wear count")
    func costPerWearDividesPriceByWearCount() {
        let watch = makeWatch()
        watch.purchasePrice = 1_000
        watch.wearLogs = [
            WearLog(dateWorn: Date(timeIntervalSince1970: 1_000)),
            WearLog(dateWorn: Date(timeIntervalSince1970: 2_000)),
            WearLog(dateWorn: Date(timeIntervalSince1970: 3_000)),
            WearLog(dateWorn: Date(timeIntervalSince1970: 4_000)),
        ]
        #expect(watch.costPerWear == 250)
    }

    // MARK: - lastPoweredDate / powerReserveExpiresAt / isPowerReserveDepleted

    @Test("With no movementType set, lastPoweredDate is nil regardless of logs")
    func lastPoweredDateIsNilWithNoMovementType() {
        let watch = makeWatch()
        watch.windLogs = [WindLog(dateWound: .now)]
        watch.wearLogs = [WearLog(dateWorn: .now)]
        #expect(watch.lastPoweredDate == nil)
    }

    @Test("For a manual movement, lastPoweredDate only considers WindLog entries, not WearLog")
    func lastPoweredDateForManualIgnoresWearLogs() {
        let watch = makeWatch()
        watch.movementType = .manual
        let wound = Date(timeIntervalSince1970: 1_000)
        watch.windLogs = [WindLog(dateWound: wound)]
        watch.wearLogs = [WearLog(dateWorn: Date(timeIntervalSince1970: 5_000))]
        #expect(watch.lastPoweredDate == wound)
    }

    @Test("For an automatic movement, lastPoweredDate is the more recent of the last wind or the last wear")
    func lastPoweredDateForAutomaticUsesMostRecentOfWindOrWear() {
        let watch = makeWatch()
        watch.movementType = .automatic

        let earlierWind = Date(timeIntervalSince1970: 1_000)
        let laterWear = Date(timeIntervalSince1970: 5_000)
        watch.windLogs = [WindLog(dateWound: earlierWind)]
        watch.wearLogs = [WearLog(dateWorn: laterWear)]
        #expect(watch.lastPoweredDate == laterWear)

        let laterWind = Date(timeIntervalSince1970: 9_000)
        watch.windLogs = [WindLog(dateWound: laterWind)]
        #expect(watch.lastPoweredDate == laterWind)
    }

    @Test("For a quartz movement, lastPoweredDate is always nil")
    func lastPoweredDateForQuartzIsAlwaysNil() {
        let watch = makeWatch()
        watch.movementType = .quartz
        watch.windLogs = [WindLog(dateWound: .now)]
        watch.wearLogs = [WearLog(dateWorn: .now)]
        #expect(watch.lastPoweredDate == nil)
    }

    @Test("powerReserveExpiresAt is nil when powerReserveHours isn't set, even with a wind logged")
    func powerReserveExpiresAtIsNilWithoutPowerReserveHours() {
        let watch = makeWatch()
        watch.movementType = .manual
        watch.windLogs = [WindLog(dateWound: .now)]
        #expect(watch.powerReserveExpiresAt == nil)
        #expect(watch.isPowerReserveDepleted == false)
    }

    @Test("powerReserveExpiresAt is lastPoweredDate plus powerReserveHours converted to seconds")
    func powerReserveExpiresAtAddsHoursToLastPoweredDate() {
        let watch = makeWatch()
        watch.movementType = .manual
        let wound = Date(timeIntervalSince1970: 0)
        watch.windLogs = [WindLog(dateWound: wound)]
        watch.powerReserveHours = 42
        #expect(watch.powerReserveExpiresAt == wound.addingTimeInterval(42 * 3600))
    }

    @Test("A watch is power-reserve depleted once now is past powerReserveExpiresAt")
    func isPowerReserveDepletedWhenPastExpiration() {
        let watch = makeWatch()
        watch.movementType = .manual
        watch.windLogs = [WindLog(dateWound: Calendar.current.date(byAdding: .hour, value: -50, to: .now)!)]
        watch.powerReserveHours = 42
        #expect(watch.isPowerReserveDepleted == true)
    }

    @Test("A watch is not power-reserve depleted while still within its reserve window")
    func isPowerReserveDepletedFalseWithinWindow() {
        let watch = makeWatch()
        watch.movementType = .manual
        watch.windLogs = [WindLog(dateWound: Calendar.current.date(byAdding: .hour, value: -2, to: .now)!)]
        watch.powerReserveHours = 42
        #expect(watch.isPowerReserveDepleted == false)
    }

    // MARK: - windReminderDate

    @Test("windReminderDate is nil without a lead time, even with powerReserveExpiresAt set")
    func windReminderDateIsNilWithoutLeadTime() {
        let watch = makeWatch()
        watch.movementType = .manual
        watch.windLogs = [WindLog(dateWound: .now)]
        watch.powerReserveHours = 42
        #expect(watch.windReminderDate == nil)
    }

    @Test("windReminderDate is nil without powerReserveExpiresAt, even with a lead time set")
    func windReminderDateIsNilWithoutPowerReserveExpiresAt() {
        let watch = makeWatch()
        watch.movementType = .manual
        watch.windReminderLeadTimeHours = 6
        #expect(watch.windReminderDate == nil)
    }

    @Test("windReminderDate subtracts the lead time from powerReserveExpiresAt")
    func windReminderDateSubtractsLeadTimeFromExpiration() {
        let watch = makeWatch()
        watch.movementType = .manual
        let wound = Date(timeIntervalSince1970: 0)
        watch.windLogs = [WindLog(dateWound: wound)]
        watch.powerReserveHours = 42
        watch.windReminderLeadTimeHours = 6
        #expect(watch.windReminderDate == wound.addingTimeInterval((42 - 6) * 3600))
    }

    // MARK: - Cascade delete: ServiceRecord, WearLog, ProvenanceDoc

    @Test("Deleting a Watch cascade-deletes its ServiceRecords")
    func deletingWatchCascadeDeletesServiceRecords() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        context.insert(watch)
        watch.serviceRecords = [
            ServiceRecord(datePerformed: .now, serviceType: "Full Service", accuracyDeltaSPD: 0, watch: watch)
        ]
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ServiceRecord>()).count == 1)

        context.delete(watch)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Watch>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ServiceRecord>()).isEmpty)
    }

    @Test("Deleting a Watch cascade-deletes its WearLogs")
    func deletingWatchCascadeDeletesWearLogs() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        context.insert(watch)
        watch.wearLogs = [WearLog(dateWorn: .now, watch: watch)]
        try context.save()
        #expect(try context.fetch(FetchDescriptor<WearLog>()).count == 1)

        context.delete(watch)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<WearLog>()).isEmpty)
    }

    @Test("Deleting a Watch cascade-deletes its WindLogs")
    func deletingWatchCascadeDeletesWindLogs() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        context.insert(watch)
        watch.windLogs = [WindLog(dateWound: .now, watch: watch)]
        try context.save()
        #expect(try context.fetch(FetchDescriptor<WindLog>()).count == 1)

        context.delete(watch)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<WindLog>()).isEmpty)
    }

    @Test("Deleting a Watch cascade-deletes its ProvenanceDocs")
    func deletingWatchCascadeDeletesProvenanceDocs() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        context.insert(watch)
        watch.provenanceDocs = [
            ProvenanceDoc(docType: .receipt, fileData: Data([0x01, 0x02]), watch: watch)
        ]
        try context.save()
        #expect(try context.fetch(FetchDescriptor<ProvenanceDoc>()).count == 1)

        context.delete(watch)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ProvenanceDoc>()).isEmpty)
    }

    @Test("Deleting a Watch with all five relationship kinds attached cascades four and nullifies the strap in one shot")
    func deletingWatchCascadesAllChildrenTogether() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        let strap = Strap(material: "Leather", widthMM: 20)
        context.insert(watch)
        context.insert(strap)

        watch.attachedStrap = strap
        watch.serviceRecords = [ServiceRecord(datePerformed: .now, serviceType: "Service", accuracyDeltaSPD: 0, watch: watch)]
        watch.wearLogs = [WearLog(dateWorn: .now, watch: watch)]
        watch.provenanceDocs = [ProvenanceDoc(docType: .warranty, fileData: Data(), watch: watch)]
        watch.windLogs = [WindLog(dateWound: .now, watch: watch)]
        try context.save()

        context.delete(watch)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<ServiceRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WearLog>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ProvenanceDoc>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WindLog>()).isEmpty)

        // The strap itself must survive — only its back-reference is nullified.
        let straps = try context.fetch(FetchDescriptor<Strap>())
        #expect(straps.count == 1)
        #expect(straps[0].attachedWatch == nil)
    }

    // MARK: - Nullify: Strap survives Watch deletion

    @Test("Deleting a Watch nullifies (does not delete) its attached Strap")
    func deletingWatchNullifiesAttachedStrap() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        let strap = Strap(name: "NATO", material: "Nylon", widthMM: 20)
        context.insert(watch)
        context.insert(strap)
        watch.attachedStrap = strap
        try context.save()

        #expect(strap.attachedWatch === watch)

        context.delete(watch)
        try context.save()

        let straps = try context.fetch(FetchDescriptor<Strap>())
        #expect(straps.count == 1, "Strap must not be deleted when its watch is deleted")
        #expect(straps[0].attachedWatch == nil)
    }

    // MARK: - Standard SwiftData read/write

    @Test("A Watch inserted into a context can be fetched back with the same field values")
    func basicInsertAndFetchRoundTrips() throws {
        let context = try makeInMemoryContext()
        let acquisition = Date(timeIntervalSince1970: 12_345)
        let watch = Watch(
            brand: "Rolex",
            model: "Explorer",
            referenceNumber: "214270",
            complications: ["Date"],
            caseDiameterMM: 39,
            lugToLugMM: 47,
            lugWidthMM: 20,
            acquisitionDate: acquisition
        )
        context.insert(watch)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Watch>())
        #expect(fetched.count == 1)
        #expect(fetched[0].brand == "Rolex")
        #expect(fetched[0].model == "Explorer")
        #expect(fetched[0].referenceNumber == "214270")
        #expect(fetched[0].complications == ["Date"])
        #expect(fetched[0].caseDiameterMM == 39)
        #expect(fetched[0].lugToLugMM == 47)
        #expect(fetched[0].lugWidthMM == 20)
        #expect(fetched[0].acquisitionDate == acquisition)
    }

    @Test("Updating a fetched Watch's fields persists after a second fetch")
    func updateThenRefetchPersistsChanges() throws {
        let context = try makeInMemoryContext()
        let watch = makeWatch()
        context.insert(watch)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Watch>())
        fetched[0].brand = "Updated Brand"
        try context.save()

        let refetched = try context.fetch(FetchDescriptor<Watch>())
        #expect(refetched.count == 1)
        #expect(refetched[0].brand == "Updated Brand")
    }
}
