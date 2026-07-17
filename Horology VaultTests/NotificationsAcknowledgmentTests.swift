//
//  NotificationsAcknowledgmentTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/17/26.
//

import Foundation
import SwiftData
import Testing
@testable import Horology_Vault

/// Brackets `NotificationsAcknowledgment`'s UserDefaults key with save/restore via `defer`, same
/// pattern `WatchModelTests.serviceDueDateUsesConfiguredInterval` established, so these tests
/// can't leak state into others. `.serialized` guards against racing other suites (e.g.
/// `WatchModelTests`) that touch a different but overlapping UserDefaults key concurrently.
///
/// Every watch here is inserted *and saved* into a real in-memory `ModelContext` before use —
/// unlike `WatchModelTests`, which mostly tests un-inserted `Watch()` instances directly, this
/// suite needs genuinely distinct `persistentModelID`s to test cross-watch behavior. Confirmed by
/// direct experimentation that `PersistentIdentifier`'s `==`/`Hashable` conformance is correct
/// even pre-save (two unsaved instances do compare unequal), but its `String(describing:)`
/// representation collapses to the same generic string for every unsaved model (it just prints
/// the wrapper type name, `TemporaryPersistentIdentifierImplementation`, not a per-instance
/// discriminator) — only after an actual save does the description include a genuinely unique,
/// per-row identifier. `Watch.openNotificationKeys` uses that string form, so this suite's tests
/// must save before comparing two different watches (a single-watch test never hit this, which is
/// why only the two-watch comparison test failed — and did so consistently, not flakily).
@Suite(.serialized)
@MainActor
struct NotificationsAcknowledgmentTests {

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Watch.self, ServiceRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeWatch(in context: ModelContext, acquisitionDate: Date = .now) -> Watch {
        let watch = Watch(
            brand: "Omega",
            model: "Seamaster",
            caseDiameterMM: 42,
            lugToLugMM: 48,
            lugWidthMM: 20,
            acquisitionDate: acquisitionDate
        )
        context.insert(watch)
        // Forces a permanent persistentModelID now rather than leaving it in the temporary
        // pre-save state — see the type's doc comment for why that matters here.
        try? context.save()
        return watch
    }

    private func withCleanAcknowledgmentState<T>(_ body: () throws -> T) rethrows -> T {
        let key = NotificationsAcknowledgment.acknowledgedKeysStorageKey
        let previous = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        defer {
            if let previous { UserDefaults.standard.set(previous, forKey: key) }
            else { UserDefaults.standard.removeObject(forKey: key) }
        }
        return try body()
    }

    @Test("unacknowledgedCount matches the total open count before anything has been acknowledged")
    func unacknowledgedCountMatchesTotalBeforeAcknowledging() throws {
        try withCleanAcknowledgmentState {
            let context = try makeInMemoryContext()
            let watch = makeWatch(in: context, acquisitionDate: Calendar.current.date(byAdding: .year, value: -6, to: .now)!)
            #expect(NotificationsAcknowledgment.unacknowledgedCount(for: [watch]) == watch.openNotificationCount)
        }
    }

    @Test("acknowledgeAll drops the count to 0 for issues that were open at the time")
    func acknowledgeAllDropsCountToZero() throws {
        try withCleanAcknowledgmentState {
            let context = try makeInMemoryContext()
            let watch = makeWatch(in: context, acquisitionDate: Calendar.current.date(byAdding: .year, value: -6, to: .now)!)
            NotificationsAcknowledgment.acknowledgeAll([watch])
            #expect(NotificationsAcknowledgment.unacknowledgedCount(for: [watch]) == 0)
        }
    }

    @Test("A new issue on a different watch still counts after acknowledging an unrelated watch")
    func newIssueOnAnotherWatchStillCounts() throws {
        try withCleanAcknowledgmentState {
            let context = try makeInMemoryContext()
            let acknowledgedWatch = makeWatch(in: context, acquisitionDate: Calendar.current.date(byAdding: .year, value: -6, to: .now)!)
            NotificationsAcknowledgment.acknowledgeAll([acknowledgedWatch])

            let newWatch = makeWatch(in: context, acquisitionDate: Calendar.current.date(byAdding: .year, value: -6, to: .now)!)
            #expect(NotificationsAcknowledgment.unacknowledgedCount(for: [acknowledgedWatch, newWatch]) == newWatch.openNotificationCount)
        }
    }

    @Test("An issue that resolves and later reopens counts as new again, not still-acknowledged")
    func resolvedThenReopenedIssueCountsAsNewAgain() throws {
        try withCleanAcknowledgmentState {
            let context = try makeInMemoryContext()
            let watch = makeWatch(in: context, acquisitionDate: Calendar.current.date(byAdding: .year, value: -6, to: .now)!)
            #expect(watch.hasOpenServiceNotification == true)
            NotificationsAcknowledgment.acknowledgeAll([watch])
            #expect(NotificationsAcknowledgment.unacknowledgedCount(for: [watch]) == 0)

            // Resolve it (log a service today), then acknowledge again — the acknowledged
            // snapshot should now be empty for this watch since nothing is open.
            watch.serviceRecords = [
                ServiceRecord(datePerformed: .now, serviceType: "Full Service", accuracyDeltaSPD: 0)
            ]
            #expect(watch.hasOpenServiceNotification == false)
            NotificationsAcknowledgment.acknowledgeAll([watch])

            // Reopen it — same watch, same identity/key, issue becomes true again.
            watch.serviceRecords = []
            #expect(watch.hasOpenServiceNotification == true)
            #expect(NotificationsAcknowledgment.unacknowledgedCount(for: [watch]) == 1)
        }
    }
}
