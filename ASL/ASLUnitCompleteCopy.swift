import Foundation

/// Copy for unit completion celebration footers.
enum ASLUnitCompleteCopy {
    static let continueCTA = "Continue"

    static func headline(unit: ASLUnit) -> String {
        if unit.isReview {
            return ASLPhaseReviewCopy.completionHeadline(phaseTitle: unit.phaseTitle ?? unit.title)
        }
        return "You finished \(unit.title)!"
    }

    static func startCTA(nextUnit: ASLUnit) -> String {
        if nextUnit.isReview {
            let label = ASLPhaseReviewCopy.checkpointLabel(for: nextUnit.phaseKey)
            let title = nextUnit.phaseTitle ?? nextUnit.title
            return "Start \(label) - \(title)"
        }
        return "Start Unit \(nextUnit.sortOrder) - \(nextUnit.title)"
    }
}
