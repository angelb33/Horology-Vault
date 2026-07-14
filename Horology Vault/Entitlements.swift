//
//  Entitlements.swift
//  Horology Vault
//
//  Created by Angel Burgos on 7/14/26.
//

import Foundation
import SwiftData

enum SubscriptionStatus: String, Codable {
    case none
    case active
    case expired
    case gracePeriod
}

/// The single local source of truth for feature gating, per the monetization plan's Section 2.2.
/// The UI reads this table only — it never talks to StoreKit directly; `PurchaseManager` is the
/// only thing that writes to it, which is what keeps the app usable offline on the last known
/// entitlement state. Exactly one row is expected to exist at a time.
@Model
final class Entitlements {
    var isLifetimeUnlocked: Bool
    var subscriptionStatus: SubscriptionStatus
    var subscriptionExpiresAt: Date?
    var lastValidatedAt: Date?

    init(
        isLifetimeUnlocked: Bool = false,
        subscriptionStatus: SubscriptionStatus = .none,
        subscriptionExpiresAt: Date? = nil,
        lastValidatedAt: Date? = nil
    ) {
        self.isLifetimeUnlocked = isLifetimeUnlocked
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.lastValidatedAt = lastValidatedAt
    }
}
