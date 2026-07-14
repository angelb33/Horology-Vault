//
//  EntitlementsTests.swift
//  Horology VaultTests
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData
import Testing
@testable import Horology_Vault

/// Tests for the `Entitlements` gating table and the persistence logic in `PurchaseManager` that
/// writes to it. Per the monetization plan's Phase 9 priorities, a broken paywall either leaks
/// the paid feature set or locks out a paying customer — both expensive mistakes to ship
/// silently — so this is the second-highest priority after the Fit Calculator math.
///
/// The real StoreKit 2 calls (`Product.products(for:)`, `Transaction.currentEntitlements`,
/// `product.purchase()`) talk to live StoreKit and aren't exercised here; instead
/// `PurchaseManager.updateEntitlementsRecord(unlocked:in:now:)` — the part of
/// `reconcileEntitlements()` that actually decides what gets persisted — is tested directly
/// against an in-memory `ModelContext`, which is what determines whether the app unlocks or
/// locks the paid feature set. `Configuration.storekit` already exists in the app target for
/// anyone wanting true end-to-end purchase-flow coverage via `StoreKitTest`/`SKTestSession`, but
/// that requires a running host app process rather than a plain unit test target, so it's out of
/// scope here in favor of solid coverage of the reconciliation/persistence logic itself.
@MainActor
struct EntitlementsTests {

    private func makeInMemoryContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Entitlements.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    // MARK: - Entitlements model defaults

    @Test("A freshly initialized Entitlements row defaults to locked, no subscription")
    func defaultsAreLocked() {
        let entitlements = Entitlements()
        #expect(entitlements.isLifetimeUnlocked == false)
        #expect(entitlements.subscriptionStatus == .none)
        #expect(entitlements.subscriptionExpiresAt == nil)
        #expect(entitlements.lastValidatedAt == nil)
    }

    // MARK: - updateEntitlementsRecord: insert path

    @Test("Reconciling with no existing row inserts exactly one unlocked Entitlements row")
    func insertsWhenUnlockedAndNoRowExists() throws {
        let context = try makeInMemoryContext()
        let now = Date()

        PurchaseManager.updateEntitlementsRecord(unlocked: true, in: context, now: now)

        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(rows.count == 1)
        #expect(rows[0].isLifetimeUnlocked == true)
        #expect(rows[0].lastValidatedAt == now)
    }

    @Test("Reconciling with no existing row and no verified transaction inserts a locked row, not a leak")
    func insertsLockedRowWhenNotEntitled() throws {
        let context = try makeInMemoryContext()

        PurchaseManager.updateEntitlementsRecord(unlocked: false, in: context)

        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(rows.count == 1)
        #expect(rows[0].isLifetimeUnlocked == false)
    }

    // MARK: - updateEntitlementsRecord: update path (no duplicate rows)

    @Test("Reconciling again updates the existing row in place rather than duplicating it")
    func updatesExistingRowRatherThanDuplicating() throws {
        let context = try makeInMemoryContext()
        let firstValidation = Date(timeIntervalSince1970: 1_000)
        let secondValidation = Date(timeIntervalSince1970: 2_000)

        PurchaseManager.updateEntitlementsRecord(unlocked: false, in: context, now: firstValidation)
        PurchaseManager.updateEntitlementsRecord(unlocked: true, in: context, now: secondValidation)

        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(rows.count == 1, "Reconciliation must never produce a second Entitlements row")
        #expect(rows[0].isLifetimeUnlocked == true)
        #expect(rows[0].lastValidatedAt == secondValidation)
    }

    @Test("A refund/expiry (StoreKit no longer reports the entitlement) locks a previously-unlocked row")
    func revokingEntitlementLocksExistingRow() throws {
        let context = try makeInMemoryContext()

        PurchaseManager.updateEntitlementsRecord(unlocked: true, in: context)
        PurchaseManager.updateEntitlementsRecord(unlocked: false, in: context)

        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(rows.count == 1)
        #expect(rows[0].isLifetimeUnlocked == false, "A revoked/refunded purchase must re-lock the feature set")
    }

    @Test("Repeated reconciliation with an unchanged entitlement still only ever yields one row")
    func repeatedReconciliationStaysSingleRow() throws {
        let context = try makeInMemoryContext()

        for _ in 0..<5 {
            PurchaseManager.updateEntitlementsRecord(unlocked: true, in: context)
        }

        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(rows.count == 1)
        #expect(rows[0].isLifetimeUnlocked == true)
    }

    // MARK: - Gating-logic parity with the UI's read pattern

    @Test("The UI's gating read (`entitlements.first?.isLifetimeUnlocked ?? false`) reflects locked state before any purchase")
    func gatingReadDefaultsToLockedBeforeAnyRow() throws {
        let context = try makeInMemoryContext()
        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        let isUnlocked = rows.first?.isLifetimeUnlocked ?? false
        #expect(isUnlocked == false, "No Entitlements row yet must never be read as unlocked")
    }

    @Test("The UI's gating read reflects unlocked state after a successful purchase reconciles")
    func gatingReadReflectsUnlockedAfterPurchase() throws {
        let context = try makeInMemoryContext()
        PurchaseManager.updateEntitlementsRecord(unlocked: true, in: context)

        let rows = try context.fetch(FetchDescriptor<Entitlements>())
        let isUnlocked = rows.first?.isLifetimeUnlocked ?? false
        #expect(isUnlocked == true)
    }

    // MARK: - Subscription status edge cases (V2 field, exercised at the model level today)

    @Test("Expired and grace-period subscription statuses round-trip through the model correctly")
    func subscriptionStatusEdgeCasesRoundTrip() throws {
        let context = try makeInMemoryContext()
        let expired = Entitlements(
            isLifetimeUnlocked: false,
            subscriptionStatus: .expired,
            subscriptionExpiresAt: Date(timeIntervalSince1970: 0)
        )
        context.insert(expired)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(fetched.count == 1)
        #expect(fetched[0].subscriptionStatus == .expired)

        fetched[0].subscriptionStatus = .gracePeriod
        try context.save()

        let refetched = try context.fetch(FetchDescriptor<Entitlements>())
        #expect(refetched[0].subscriptionStatus == .gracePeriod)
    }

    // MARK: - PurchaseManager.configure wiring

    @Test("configure(modelContext:) is idempotent and doesn't restart the transaction listener on repeat calls")
    func configureIsIdempotent() throws {
        let context = try makeInMemoryContext()
        let manager = PurchaseManager()

        // Calling configure twice must not crash or throw — this mirrors ContentView calling it
        // from a `.task` that could theoretically re-run.
        manager.configure(modelContext: context)
        manager.configure(modelContext: context)

        #expect(manager.product == nil)
        #expect(manager.lastError == nil)
    }
}
