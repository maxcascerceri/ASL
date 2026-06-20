//
//  OnboardingCopy.swift
//  ASL
//

import Foundation

enum OnboardingCopy {
    static let splashTagline = "Sign with confidence."
    static let welcomeHeadline = "Welcome to Ziggy ASL 👋"
    static let welcomeSub = "Unlock the world of sign language!"
    static let getStarted = "Get Started"
    static let continueCTA = "Continue"
    static let unlockPath = "Continue My Journey"
    static let startFreeTrial = "Start 7-Day Free Trial"
    static let paywallCTA = "Continue My Journey"
    static let paywallNoPaymentToday = "No payment due today"
    static let cancelAnytime = "Cancel anytime in Settings"

    // MARK: - Motivation

    static let motivationQuestion = "Why are you learning ASL?"
    static let motivationQuestionBold = ["ASL"]
    static let motivationMultiSelectBubble = "Great mix — we'll tailor your path!"
    static let motivationMultiSelectBubbleBold = ["tailor your path"]

    static func motivationReactiveBubbleBold(_ value: OnboardingMotivation) -> [String] {
        switch value {
        case .family: return ["ones you love"]
        case .work: return ["sign at work"]
        case .education: return ["ace those tests"]
        case .deaf: return ["more inclusive"]
        case .connecting: return ["chatting in no time"]
        case .fun: return ["love this"]
        }
    }

    static func motivationTitle(_ value: OnboardingMotivation) -> String {
        switch value {
        case .family: return "Signing with family"
        case .work: return "Signing at work"
        case .education: return "Supporting my education"
        case .deaf: return "I'm Deaf myself"
        case .connecting: return "Connecting with people"
        case .fun: return "For fun!"
        }
    }

    static func motivationSymbol(_ value: OnboardingMotivation) -> String {
        switch value {
        case .family: return "heart.fill"
        case .work: return "building.2.fill"
        case .education: return "book.fill"
        case .deaf: return "hand.wave.fill"
        case .connecting: return "person.2.fill"
        case .fun: return "sparkles"
        }
    }

    static func motivationReactiveBubble(_ value: OnboardingMotivation) -> String {
        switch value {
        case .family: return "Let's sign with the ones you love!"
        case .work: return "Great — we'll help you sign at work!"
        case .education: return "Let's ace those tests!"
        case .deaf: return "Let's make the world a bit more inclusive!"
        case .connecting: return "You'll be chatting in no time!"
        case .fun: return "You're going to love this!"
        }
    }

    // MARK: - Daily Goal

    static let dailyGoalQuestion = "How much time can you practice each day?"
    static let dailyGoalQuestionBold = ["practice each day"]

    static func dailyGoalReactiveBubble(signCount: Int) -> String {
        "At this pace, you'll know \(signCount)+ signs by next week."
    }

    static func dailyGoalReactiveBubbleBold(signCount: Int) -> [String] {
        ["\(signCount)+ signs"]
    }

    static func dailyGoalWeeklyProjection(for minutes: Int) -> Int {
        switch minutes {
        case 5: return 25
        case 10: return 50
        case 15: return 75
        case 20: return 100
        default: return max(10, minutes * 5)
        }
    }

    // MARK: - Personalizing lesson

    static let personalizingHeadline = "Personalizing your first lesson"
    static let personalizingReady = "Your lesson is ready!"
    static let personalizingStartCTA = "Start my lesson"

    static let personalizingSteps = [
        "Reviewing your goals",
        "Choosing your first signs",
        "Building your lesson",
        "Setting up your practice plan",
    ]

    struct PersonalizingSubline: Equatable {
        let primary: String
        let secondary: String?
    }

    static func personalizingSubline(profile: OnboardingProfile) -> PersonalizingSubline {
        let minutes = profile.dailyMinutes
        let motivation = profile.motivations.first

        switch (minutes, motivation) {
        case let (.some(m), .some(value)):
            return PersonalizingSubline(
                primary: "Optimized for \(m) min/day",
                secondary: motivationTitle(value)
            )
        case let (.some(m), .none):
            return PersonalizingSubline(
                primary: "Optimized for \(m) minutes a day",
                secondary: nil
            )
        case let (.none, .some(value)):
            return PersonalizingSubline(
                primary: "Tailored for \(motivationTitle(value))",
                secondary: nil
            )
        case (.none, .none):
            return PersonalizingSubline(
                primary: "Tailored to your goals",
                secondary: nil
            )
        }
    }

    // MARK: - Speech bubbles

    static let ziggyIntroBubble = "Hi! I'm Ziggy — your ASL coach. Let's build your first lesson together!"
    static let ziggyIntroBubbleBold = ["Ziggy", "first lesson"]

    static let streakGoalBubble = "Let's set a learning goal."
    static let streakGoalBubbleBold = ["learning goal"]

    // MARK: - First sign celebration

    static func firstSignCelebrationBubble(word: String) -> String {
        "You just signed \(word)!"
    }

    static let firstSignCelebrationSublinePrimary = "That's how fluency starts."
    static let firstSignCelebrationSublineSecondary = "Every signer began right here."

    // MARK: - Lesson complete

    static func lessonCompleteHeadline(profile: OnboardingProfile) -> String {
        guard let first = profile.motivations.first else {
            return "You're amazing!"
        }
        switch first {
        case .family: return "You're signing for your family"
        case .work: return "You're building real work skills"
        case .education: return "You're ready for class"
        case .deaf: return "You're joining the conversation"
        case .connecting: return "You're connecting with people"
        case .fun: return "You're off to a great start"
        }
    }

    // MARK: - Science Fact

    static let scienceFactHeadline = "A little practice each day helps you learn ASL"
    static let scienceFactStatSubline = "by next week"
    static let scienceFactCitationCard =
        "Research shows spreading practice over days helps you remember more — up to 34% compared to cramming in one sitting."
    static let scienceFactSourceLink = "Source of research"
    static let scienceFactSourceSheetTitle = "Research sources"
    static let scienceFactSourceCepeda =
        "Cepeda, N. J., et al. (2009). Distributed practice in verbal recall tasks: A review and quantitative synthesis. Psychological Bulletin — spacing practice across days can improve recall by up to about 34% compared to cramming."
    static let scienceFactSourceVL2 =
        "Gallaudet University VL2 — research on visual language, literacy, and ASL learning."

    static let scienceFactDefaultMinutes = 10

    static func scienceFactMinutes(for profile: OnboardingProfile) -> Int {
        profile.dailyMinutes ?? scienceFactDefaultMinutes
    }

    static func scienceFactWeeklyProjection(for profile: OnboardingProfile) -> Int {
        dailyGoalWeeklyProjection(for: scienceFactMinutes(for: profile))
    }

    static func scienceFactHeroStat(signCount: Int) -> String {
        "\(signCount)+ signs"
    }

    static func scienceFactBody(minutes: Int) -> String {
        "Just \(minutes) minutes a day beats one long study session. It's not a trend — it's backed by science."
    }

    static func scienceFactBodyBold(minutes: Int) -> [String] {
        ["\(minutes) minutes"]
    }

    static let scienceFactCitationBold = ["34%"]

    // MARK: - App Store review

    static let appStoreReviewHeadline = "Support us"
    static let appStoreReviewSublinePrefix = "by giving "
    static let appStoreReviewSublineBold = "your rating"
    static let appStoreReviewAccessibilityLabel =
        "Support us by giving your rating. Continue to leave a review in the App Store."

    // MARK: - Paywall

    static func paywallProgressChip(profile: OnboardingProfile) -> String {
        let signs = profile.miniModuleSignsLearned ?? OnboardingMiniModuleSteps.signsLearnedCount
        let stars = ASLStarEconomy.onboardingLessonStarReward
        return "\(signs) signs learned · Day 1 streak · \(stars) stars"
    }

    static func paywallSubheadline(profile: OnboardingProfile) -> String {
        let minutesSuffix = profile.dailyMinutes.map { " · \($0) min/day" } ?? ""
        return "500+ signs\(minutesSuffix)"
    }

    static func paywallHeadline(profile: OnboardingProfile) -> String {
        guard let first = profile.motivations.first else {
            return "You're ready for the full path"
        }
        switch first {
        case .family: return "Keep signing with the ones you love"
        case .work: return "You're ready to sign at work"
        case .education: return "You're ready to ace your classes"
        case .deaf: return "You're ready to join the conversation"
        case .connecting: return "You're ready to connect with people"
        case .fun: return "You're going to love this"
        }
    }

    static func paywallBenefits(profile: OnboardingProfile) -> [PaywallBenefit] {
        guard let motivation = profile.motivations.first else {
            return paywallDefaultBenefits
        }
        switch motivation {
        case .family:
            return [
                PaywallBenefit(
                    text: "Sign with family in real conversations",
                    systemImage: "bubble.left.and.bubble.right.fill"
                ),
                PaywallBenefit(
                    text: "Daily practice built around your people",
                    systemImage: "flame.fill"
                ),
                PaywallBenefit(
                    text: "Short lessons you can finish in minutes",
                    systemImage: "clock.fill"
                ),
            ]
        case .work:
            return [
                PaywallBenefit(
                    text: "Sign confidently at work",
                    systemImage: "briefcase.fill"
                ),
                PaywallBenefit(
                    text: "Daily practice that fits your schedule",
                    systemImage: "calendar"
                ),
                PaywallBenefit(
                    text: "Bite-sized units for busy days",
                    systemImage: "bolt.fill"
                ),
            ]
        case .education:
            return [
                PaywallBenefit(
                    text: "Sign for class and study with confidence",
                    systemImage: "book.fill"
                ),
                PaywallBenefit(
                    text: "Daily practice that supports your education",
                    systemImage: "flame.fill"
                ),
                PaywallBenefit(
                    text: "Structured path from basics to fluency",
                    systemImage: "map.fill"
                ),
            ]
        case .deaf:
            return [
                PaywallBenefit(
                    text: "Connect with the Deaf community",
                    systemImage: "person.3.fill"
                ),
                PaywallBenefit(
                    text: "Daily practice on your terms",
                    systemImage: "flame.fill"
                ),
                PaywallBenefit(
                    text: "Culture tips woven into every unit",
                    systemImage: "heart.fill"
                ),
            ]
        case .connecting:
            return [
                PaywallBenefit(
                    text: "Sign in real conversations",
                    systemImage: "bubble.left.and.bubble.right.fill"
                ),
                PaywallBenefit(
                    text: "Daily practice built to help you connect",
                    systemImage: "flame.fill"
                ),
                PaywallBenefit(
                    text: "Build confidence one sign at a time",
                    systemImage: "hand.wave.fill"
                ),
            ]
        case .fun:
            return [
                PaywallBenefit(
                    text: "Learn signs you'll actually use",
                    systemImage: "sparkles"
                ),
                PaywallBenefit(
                    text: "Daily practice that's fun to stick with",
                    systemImage: "flame.fill"
                ),
                PaywallBenefit(
                    text: "Earn stars and keep your streak alive",
                    systemImage: "star.fill"
                ),
            ]
        }
    }

    private static let paywallDefaultBenefits: [PaywallBenefit] = [
        PaywallBenefit(
            text: "Sign in real conversations",
            systemImage: "bubble.left.and.bubble.right.fill"
        ),
        PaywallBenefit(
            text: "Daily practice built for your goals",
            systemImage: "flame.fill"
        ),
        PaywallBenefit(
            text: "500+ signs taught with real video",
            systemImage: "play.rectangle.fill"
        ),
    ]

    static var paywallYearlyComparePrefix: String {
        "\(OnboardingPaywallPricing.formattedYearlyPrice)/year · was "
    }

    static var paywallYearlyCompareStrikethrough: String {
        "\(OnboardingPaywallPricing.formattedWeeklyPrice)/week"
    }

    static func paywallBillingMicrocopy(plan: OnboardingPaywallPlan) -> String {
        switch plan {
        case .yearly:
            return "7 days free, then \(OnboardingPaywallPricing.formattedYearlyPrice)/year. Cancel anytime."
        case .weekly:
            return "7 days free, then \(OnboardingPaywallPricing.formattedWeeklyPrice)/week. Cancel anytime."
        }
    }

    /// Legacy alias — prefer `paywallBenefits(profile:)`.
    static var paywallFeatures: [String] {
        paywallDefaultBenefits.map(\.text)
    }

    // MARK: - Preview units

    static func previewUnitIds(for motivation: OnboardingMotivation?) -> [String] {
        switch motivation {
        case .family:
            return ["p1-u01", "p1-u18", "p1-u06"]
        case .work:
            return ["p1-u01", "p1-u73", "p1-u05"]
        case .education:
            return ["p1-u01", "p1-u57", "p1-u05"]
        case .connecting, .deaf:
            return ["p1-u01", "p1-u22", "p1-u02"]
        case .fun, .none:
            return ["p1-u01", "p1-u02", "p1-u03"]
        }
    }

    static func previewUnitTitle(for unitId: String) -> String {
        switch unitId {
        case "p1-u01": return "Getting Started"
        case "p1-u02": return "Everyday Replies"
        case "p1-u03": return "You & Me"
        case "p1-u05": return "Meet People"
        case "p1-u06": return "Feelings & Emotions"
        case "p1-u18": return "Family & People"
        case "p1-u22": return "Deaf Culture"
        case "p1-u57": return "School"
        case "p1-u73": return "Getting Help"
        default: return "Learn ASL"
        }
    }
}
