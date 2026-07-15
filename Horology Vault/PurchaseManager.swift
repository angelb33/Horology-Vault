//
//  PurchaseManager.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import Observation
import StoreKit
import SwiftData

/// V1's only in-app purchase: a single non-consumable lifetime unlock, per the monetization
/// plan's Section 8. Register this exact product ID in App Store Connect before shipping —
/// that dashboard step is the one piece of this feature that isn't code.
@Observable
final class PurchaseManager {
    static let lifetimeUnlockProductID = "com.angelburgos.HorologyVault.lifetime"

    private(set) var product: Product?
    private(set) var isLoadingProduct = false
    private(set) var lastError: String?

    private var modelContext: ModelContext?
    private var transactionListenerTask: Task<Void, Never>?

    /// Must be called once (e.g. from `ContentView`'s `.task`) before `purchase()`/
    /// `restorePurchases()` can write back to the `Entitlements` table.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        guard transactionListenerTask == nil else { return }
        // Catches purchases completed on another device, or interrupted mid-flow — this matters
        // more on macOS, where a purchase sheet can be dismissed unexpectedly.
        transactionListenerTask = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await reconcileEntitlements()
                }
            }
        }
    }

    func loadProduct() async {
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.lifetimeUnlockProductID]).first
        } catch {
            lastError = error.localizedDescription
        }
    }

    func purchase() async {
        guard let product else { return }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await reconcileEntitlements()
                case .unverified(_, let verificationError):
                    // A completed purchase that failed StoreKit's cryptographic verification —
                    // previously silently swallowed here (no error, no entitlement write), which
                    // looked identical to a successful-looking purchase sheet doing nothing
                    // afterward. Surfacing it so a real verification failure is visible instead
                    // of indistinguishable from every other silent-no-op path below.
                    lastError = "Purchase completed but couldn't be verified: \(verificationError.localizedDescription)"
                }
            case .userCancelled, .pending:
                // Neither is an error — the user backed out, or needs Ask to Buy/parental
                // approval, both of which resolve later via the Transaction.updates listener.
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await reconcileEntitlements()
    }

    /// Call once at launch to make sure the local `Entitlements` row matches what StoreKit
    /// actually has on record — this is what makes Restore Purchase mostly automatic.
    func reconcileEntitlementsOnLaunch() async {
        await reconcileEntitlements()
    }

    private func reconcileEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.lifetimeUnlockProductID {
                unlocked = true
            }
        }
        guard let modelContext else { return }
        Self.updateEntitlementsRecord(unlocked: unlocked, in: modelContext)
    }

    /// Inserts the singleton `Entitlements` row if none exists yet, otherwise updates it in
    /// place, rather than ever inserting a second row. Pulled out as a static, StoreKit-free
    /// function (rather than left inline in `reconcileEntitlements()`) so this gating logic —
    /// the part that actually decides whether the paid feature set is unlocked or locked — can
    /// be unit tested against an in-memory `ModelContext` without needing a live (or
    /// `StoreKitTest`) transaction feed.
    @discardableResult
    static func updateEntitlementsRecord(
        unlocked: Bool,
        in modelContext: ModelContext,
        now: Date = Date()
    ) -> Entitlements {
        if let existing = try? modelContext.fetch(FetchDescriptor<Entitlements>()).first {
            existing.isLifetimeUnlocked = unlocked
            existing.lastValidatedAt = now
            return existing
        } else {
            let entitlements = Entitlements(isLifetimeUnlocked: unlocked, lastValidatedAt: now)
            modelContext.insert(entitlements)
            return entitlements
        }
    }
}
