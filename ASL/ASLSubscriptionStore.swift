//
//  ASLSubscriptionStore.swift
//  ASL
//

import Combine
import Foundation
import RevenueCat
import SwiftUI

struct PaywallPricingSnapshot: Equatable {
    let weeklyDisplayPrice: String
    let yearlyDisplayPrice: String
    let yearlyWeeklyBreakdown: String
    let savingsPercent: Int
    let trialDays: Int?

    static let fallback = PaywallPricingSnapshot(
        weeklyDisplayPrice: OnboardingPaywallPricing.formattedWeeklyPrice,
        yearlyDisplayPrice: OnboardingPaywallPricing.formattedYearlyPrice,
        yearlyWeeklyBreakdown: OnboardingPaywallPricing.yearlyWeeklyBreakdown,
        savingsPercent: OnboardingPaywallPricing.savingsPercent,
        trialDays: OnboardingPaywallPricing.trialDays
    )

    static func from(annual: Package?, weekly: Package?) -> PaywallPricingSnapshot {
        let weeklyProduct = weekly?.storeProduct
        let annualProduct = annual?.storeProduct

        let weeklyDisplay = weeklyProduct?.localizedPriceString ?? fallback.weeklyDisplayPrice
        let yearlyDisplay = annualProduct?.localizedPriceString ?? fallback.yearlyDisplayPrice

        let weeklyDecimal = weeklyProduct?.price as Decimal?
        let annualDecimal = annualProduct?.price as Decimal?

        let yearlyWeeklyBreakdown: String = {
            guard let annualDecimal, annualDecimal > 0 else { return fallback.yearlyWeeklyBreakdown }
            let perWeek = annualDecimal / 52
            return Self.currencyString(for: perWeek)
        }()

        let savingsPercent: Int = {
            guard
                let weeklyDecimal, weeklyDecimal > 0,
                let annualDecimal
            else { return fallback.savingsPercent }
            let weeklyAnnual = weeklyDecimal * 52
            guard weeklyAnnual > 0 else { return fallback.savingsPercent }
            let savings = ((weeklyAnnual - annualDecimal) / weeklyAnnual) * 100
            return max(0, Int(NSDecimalNumber(decimal: savings).doubleValue.rounded()))
        }()

        let trialDays = Self.trialDays(from: annualProduct) ?? Self.trialDays(from: weeklyProduct) ?? fallback.trialDays

        return PaywallPricingSnapshot(
            weeklyDisplayPrice: weeklyDisplay,
            yearlyDisplayPrice: yearlyDisplay,
            yearlyWeeklyBreakdown: yearlyWeeklyBreakdown,
            savingsPercent: savingsPercent,
            trialDays: trialDays
        )
    }

    private static func trialDays(from product: StoreProduct?) -> Int? {
        guard
            let discount = product?.introductoryDiscount,
            discount.paymentMode == .freeTrial
        else { return nil }

        switch discount.subscriptionPeriod.unit {
        case .day:
            return discount.subscriptionPeriod.value
        case .week:
            return discount.subscriptionPeriod.value * 7
        case .month:
            return discount.subscriptionPeriod.value * 30
        case .year:
            return discount.subscriptionPeriod.value * 365
        @unknown default:
            return nil
        }
    }

    private static func currencyString(for amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: amount as NSDecimalNumber) ?? String(format: "$%.2f", (amount as NSDecimalNumber).doubleValue)
    }
}

@MainActor
final class ASLSubscriptionStore: NSObject, ObservableObject {
    static let shared = ASLSubscriptionStore()

    static let apiKey = "appl_VXWMbYGLciaftSkAIctaZTAqZEz"
    static let entitlementID = "premium"

    @Published private(set) var hasPremium = false
    @Published private(set) var pricing = PaywallPricingSnapshot.fallback
    @Published private(set) var isLoadingOfferings = false
    @Published private(set) var isPurchasing = false
    @Published private(set) var isRestoring = false
    @Published var purchaseError: String?

    private var annualPackage: Package?
    private var weeklyPackage: Package?
    private var isConfigured = false

    func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        Purchases.configure(withAPIKey: Self.apiKey)
        Purchases.shared.delegate = self

        Task {
            await refreshCustomerInfo()
            await loadOfferings()
        }
    }

    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            applyCustomerInfo(info)
        } catch {
            // Keep the last known access state if RevenueCat is temporarily unavailable.
        }
    }

    func loadOfferings() async {
        isLoadingOfferings = true
        defer { isLoadingOfferings = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            annualPackage = current?.annual ?? current?.package(identifier: "$rc_annual")
            weeklyPackage = current?.weekly ?? current?.package(identifier: "$rc_weekly")
            pricing = PaywallPricingSnapshot.from(annual: annualPackage, weekly: weeklyPackage)
        } catch {
            purchaseError = "Could not load subscription options. Please try again."
        }
    }

    func package(for plan: OnboardingPaywallPlan) -> Package? {
        switch plan {
        case .yearly:
            return annualPackage
        case .weekly:
            return weeklyPackage
        }
    }

    @discardableResult
    func purchase(plan: OnboardingPaywallPlan) async -> Bool {
        guard let package = package(for: plan) else {
            purchaseError = "That plan is not available right now."
            return false
        }

        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            applyCustomerInfo(result.customerInfo)
            return hasPremium
        } catch {
            let nsError = error as NSError
            if nsError.domain == ErrorCode.errorDomain,
               nsError.code == ErrorCode.purchaseCancelledError.rawValue {
                return false
            }
            purchaseError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        isRestoring = true
        purchaseError = nil
        defer { isRestoring = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            applyCustomerInfo(info)
            if !hasPremium {
                purchaseError = "No active subscription was found for this Apple ID."
            }
            return hasPremium
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    private func applyCustomerInfo(_ info: CustomerInfo) {
        hasPremium = info.entitlements[Self.entitlementID]?.isActive == true
    }
}

extension ASLSubscriptionStore: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            applyCustomerInfo(customerInfo)
        }
    }
}
