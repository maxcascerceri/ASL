import Foundation

enum ASLStoneDisplayTitles {
    private static let overrides: [String: [String]] = [
        "p1-u01": [
            "Getting Started",
            "Introduce Yourself",
            "Getting Started Challenge",
        ],
        "p1-u02": [
            "Everyday Replies",
            "Answer Naturally",
            "Response Challenge",
        ],
        "p1-u73": [
            "Ask for Help",
            "Fix Confusion",
            "Emergency Help",
        ],
    ]

    static func title(for lesson: ASLLesson, unit: ASLUnit) -> String {
        if let displayTitle = lesson.displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !displayTitle.isEmpty {
            return displayTitle
        }

        let stone = lesson.sortOrder
        if let unitOverrides = overrides[unit.id],
           stone >= 1,
           stone <= unitOverrides.count {
            return unitOverrides[stone - 1]
        }

        return templatedTitle(unitTitle: unit.title, stone: stone, fallback: lesson.title)
    }

    private static func templatedTitle(unitTitle: String, stone: Int, fallback: String) -> String {
        switch stone {
        case 1:
            return unitTitle
        case 2:
            return "\(unitTitle): Use It"
        case 3:
            return "\(unitTitle) Challenge"
        default:
            return fallback
        }
    }
}
