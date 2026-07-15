//
//  ScheduledBackupManagerTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 2026-07-15.
//

import Foundation
import Testing
@testable import Horology_Vault

/// Covers only `ScheduledBackupManager.isBackupDue` — the pure due-date math. Deliberately does
/// not attempt to test `BGTaskScheduler`, `NSBackgroundActivityScheduler`, Keychain, or real file
/// I/O, matching this project's established precedent (see CLAUDE.md's Test frameworks section —
/// same reasoning already applied to StoreKit's live system calls) for not unit-testing live
/// system APIs.
struct ScheduledBackupManagerTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_800_000_000) // fixed reference instant

    @Test("Never run before is always due, regardless of frequency", arguments: ScheduledBackupManager.BackupFrequency.allCases)
    func neverRunBeforeIsAlwaysDue(frequency: ScheduledBackupManager.BackupFrequency) {
        #expect(ScheduledBackupManager.isBackupDue(frequency: frequency, lastRunDate: nil, now: now, calendar: calendar) == true)
    }

    @Test("Run one hour ago is not due, for every frequency", arguments: ScheduledBackupManager.BackupFrequency.allCases)
    func runOneHourAgoIsNotDue(frequency: ScheduledBackupManager.BackupFrequency) {
        let lastRun = now.addingTimeInterval(-3_600)
        #expect(ScheduledBackupManager.isBackupDue(frequency: frequency, lastRunDate: lastRun, now: now, calendar: calendar) == false)
    }

    @Test("Daily: due once a full day has passed, not due just before")
    func dailyBoundary() {
        let justOverADayAgo = calendar.date(byAdding: .hour, value: -25, to: now)!
        let justUnderADayAgo = calendar.date(byAdding: .hour, value: -23, to: now)!
        #expect(ScheduledBackupManager.isBackupDue(frequency: .daily, lastRunDate: justOverADayAgo, now: now, calendar: calendar) == true)
        #expect(ScheduledBackupManager.isBackupDue(frequency: .daily, lastRunDate: justUnderADayAgo, now: now, calendar: calendar) == false)
    }

    @Test("Weekly: due once a full week has passed, not due just before")
    func weeklyBoundary() {
        let justOverAWeekAgo = calendar.date(byAdding: .day, value: -8, to: now)!
        let justUnderAWeekAgo = calendar.date(byAdding: .day, value: -6, to: now)!
        #expect(ScheduledBackupManager.isBackupDue(frequency: .weekly, lastRunDate: justOverAWeekAgo, now: now, calendar: calendar) == true)
        #expect(ScheduledBackupManager.isBackupDue(frequency: .weekly, lastRunDate: justUnderAWeekAgo, now: now, calendar: calendar) == false)
    }

    @Test("Monthly: due once a full calendar month has passed, not due just before")
    func monthlyBoundary() {
        let justOverAMonthAgo = calendar.date(byAdding: .day, value: -32, to: now)!
        let justUnderAMonthAgo = calendar.date(byAdding: .day, value: -20, to: now)!
        #expect(ScheduledBackupManager.isBackupDue(frequency: .monthly, lastRunDate: justOverAMonthAgo, now: now, calendar: calendar) == true)
        #expect(ScheduledBackupManager.isBackupDue(frequency: .monthly, lastRunDate: justUnderAMonthAgo, now: now, calendar: calendar) == false)
    }

    @Test("Exactly one interval later is due (boundary is inclusive)")
    func exactlyOneIntervalLaterIsDue() {
        let exactlyOneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
        #expect(ScheduledBackupManager.isBackupDue(frequency: .weekly, lastRunDate: exactlyOneWeekAgo, now: now, calendar: calendar) == true)
    }
}
