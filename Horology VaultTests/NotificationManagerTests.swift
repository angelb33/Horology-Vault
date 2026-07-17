//
//  NotificationManagerTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/17/26.
//

import Foundation
import Testing
@testable import Horology_Vault

/// Tests the pure gating-decision functions extracted from `NotificationManager`'s
/// `scheduleServiceDueReminder`/`scheduleWindReminder`/`schedulePickupReminder` — before this
/// extraction, this logic was inline alongside `UNUserNotificationCenter` calls and had zero
/// test coverage (only the `Watch` computed properties it reads, like `serviceDueDate`, were
/// tested). Same reasoning `FitCalculator`/`PurchaseManager.updateEntitlementsRecord` were
/// extracted for.
struct NotificationManagerTests {

    private let future = Date(timeIntervalSinceNow: 3600)
    private let past = Date(timeIntervalSinceNow: -3600)

    // MARK: - resolvedServiceDueDate

    @Test("resolvedServiceDueDate returns the due date when every gate passes")
    func serviceDueResolvesWhenAllGatesPass() {
        let resolved = NotificationManager.resolvedServiceDueDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, dueDate: future
        )
        #expect(resolved == future)
    }

    @Test("resolvedServiceDueDate is nil when not unlocked, even if every other gate passes")
    func serviceDueNilWhenLocked() {
        let resolved = NotificationManager.resolvedServiceDueDate(
            isUnlocked: false, globallyEnabled: true, perWatchEnabled: true, dueDate: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedServiceDueDate is nil when the app-wide master switch is off")
    func serviceDueNilWhenGloballyDisabled() {
        let resolved = NotificationManager.resolvedServiceDueDate(
            isUnlocked: true, globallyEnabled: false, perWatchEnabled: true, dueDate: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedServiceDueDate is nil when this watch's own toggle is off")
    func serviceDueNilWhenPerWatchDisabled() {
        let resolved = NotificationManager.resolvedServiceDueDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: false, dueDate: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedServiceDueDate is nil when there's no due date to schedule for")
    func serviceDueNilWithoutDueDate() {
        let resolved = NotificationManager.resolvedServiceDueDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, dueDate: nil
        )
        #expect(resolved == nil)
    }

    @Test("resolvedServiceDueDate is nil once the due date is already in the past")
    func serviceDueNilWhenAlreadyPast() {
        let resolved = NotificationManager.resolvedServiceDueDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, dueDate: past
        )
        #expect(resolved == nil)
    }

    // MARK: - resolvedWindReminderDate

    @Test("resolvedWindReminderDate returns the reminder date when every gate passes")
    func windReminderResolvesWhenAllGatesPass() {
        let resolved = NotificationManager.resolvedWindReminderDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, windReminderDate: future
        )
        #expect(resolved == future)
    }

    @Test("resolvedWindReminderDate is nil when not unlocked")
    func windReminderNilWhenLocked() {
        let resolved = NotificationManager.resolvedWindReminderDate(
            isUnlocked: false, globallyEnabled: true, perWatchEnabled: true, windReminderDate: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedWindReminderDate is nil when the app-wide master switch is off")
    func windReminderNilWhenGloballyDisabled() {
        let resolved = NotificationManager.resolvedWindReminderDate(
            isUnlocked: true, globallyEnabled: false, perWatchEnabled: true, windReminderDate: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedWindReminderDate is nil when this watch's own toggle is off")
    func windReminderNilWhenPerWatchDisabled() {
        let resolved = NotificationManager.resolvedWindReminderDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: false, windReminderDate: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedWindReminderDate is nil without a reminder date (e.g. quartz, or no power reserve spec yet)")
    func windReminderNilWithoutDate() {
        let resolved = NotificationManager.resolvedWindReminderDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, windReminderDate: nil
        )
        #expect(resolved == nil)
    }

    @Test("resolvedWindReminderDate is nil once the reminder date is already in the past")
    func windReminderNilWhenAlreadyPast() {
        let resolved = NotificationManager.resolvedWindReminderDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, windReminderDate: past
        )
        #expect(resolved == nil)
    }

    // MARK: - resolvedPowerReserveDepletedDate

    @Test("resolvedPowerReserveDepletedDate returns the expiry date when every gate passes")
    func powerReserveDepletedResolvesWhenAllGatesPass() {
        let resolved = NotificationManager.resolvedPowerReserveDepletedDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, powerReserveExpiresAt: future
        )
        #expect(resolved == future)
    }

    @Test("resolvedPowerReserveDepletedDate is nil when not unlocked")
    func powerReserveDepletedNilWhenLocked() {
        let resolved = NotificationManager.resolvedPowerReserveDepletedDate(
            isUnlocked: false, globallyEnabled: true, perWatchEnabled: true, powerReserveExpiresAt: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedPowerReserveDepletedDate is nil when the app-wide master switch is off")
    func powerReserveDepletedNilWhenGloballyDisabled() {
        let resolved = NotificationManager.resolvedPowerReserveDepletedDate(
            isUnlocked: true, globallyEnabled: false, perWatchEnabled: true, powerReserveExpiresAt: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedPowerReserveDepletedDate is nil when this watch's own toggle is off")
    func powerReserveDepletedNilWhenPerWatchDisabled() {
        let resolved = NotificationManager.resolvedPowerReserveDepletedDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: false, powerReserveExpiresAt: future
        )
        #expect(resolved == nil)
    }

    @Test("resolvedPowerReserveDepletedDate is nil without an expiry date (e.g. quartz, or no power reserve spec yet)")
    func powerReserveDepletedNilWithoutDate() {
        let resolved = NotificationManager.resolvedPowerReserveDepletedDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, powerReserveExpiresAt: nil
        )
        #expect(resolved == nil)
    }

    @Test("resolvedPowerReserveDepletedDate is nil once the expiry date is already in the past")
    func powerReserveDepletedNilWhenAlreadyPast() {
        let resolved = NotificationManager.resolvedPowerReserveDepletedDate(
            isUnlocked: true, globallyEnabled: true, perWatchEnabled: true, powerReserveExpiresAt: past
        )
        #expect(resolved == nil)
    }

    // MARK: - resolvedPickupReminderDate

    @Test("resolvedPickupReminderDate returns the pickup date when unlocked and it's in the future")
    func pickupReminderResolvesWhenUnlockedAndFuture() {
        let resolved = NotificationManager.resolvedPickupReminderDate(isUnlocked: true, expectedPickupDate: future)
        #expect(resolved == future)
    }

    @Test("resolvedPickupReminderDate is nil when not unlocked, even with a future pickup date")
    func pickupReminderNilWhenLocked() {
        let resolved = NotificationManager.resolvedPickupReminderDate(isUnlocked: false, expectedPickupDate: future)
        #expect(resolved == nil)
    }

    @Test("resolvedPickupReminderDate is nil without an expected pickup date")
    func pickupReminderNilWithoutDate() {
        let resolved = NotificationManager.resolvedPickupReminderDate(isUnlocked: true, expectedPickupDate: nil)
        #expect(resolved == nil)
    }

    @Test("resolvedPickupReminderDate is nil once the expected pickup date is already in the past")
    func pickupReminderNilWhenAlreadyPast() {
        let resolved = NotificationManager.resolvedPickupReminderDate(isUnlocked: true, expectedPickupDate: past)
        #expect(resolved == nil)
    }
}
