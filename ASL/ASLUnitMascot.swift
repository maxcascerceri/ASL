import Foundation
import UIKit

/// Maps curriculum units to mascot artwork in `Assets.xcassets`.
/// Resolution is by stable `unit.id` so curriculum title edits do not affect mascots.
enum UnitMascot {
    static let defaultDisplaySize: CGFloat = 189
    static let headerMascotSize: CGFloat = 166
    static let profileHeaderMascotSize: CGFloat = 154
    static let emptyStateMascotSize: CGFloat = 189
    static let favoritesEmptyStateSize: CGFloat = 239
    static let celebrationMascotHeight: CGFloat = 119
    static let streakCelebrationMascotMaxWidth: CGFloat = 380
    static let streakCelebrationMascotMaxHeight: CGFloat = 360
    static let streakCelebrationImageNames = ["5streak", "10streak", "20streak"]
    static let reviewIntroMascotMaxWidth: CGFloat = 320
    static let reviewIntroMascotMaxHeight: CGFloat = 340

    static let reviewIntroMascotImageNames = ["redrill-review-thinking", "redrill-review-teaching"]
    static let stoneCompleteCelebrationImageName = "stone-complete-celebration"
    static let stoneCompleteMascotMaxWidth: CGFloat = 320
    static let stoneCompleteMascotMaxHeight: CGFloat = 340
    static let unitCompleteMascotMaxWidth: CGFloat = 320
    static let unitCompleteMascotMaxHeight: CGFloat = 340
    private static let reviewIntroMascotIndexKey = "asl.reviewIntroMascotIndex.v1"

    static let headAndFaceImageName = "headface"

    enum MascotIntroSlot: Hashable {
        case homeFirstSigns
    }

    private static var playedIntroVideoSlots: Set<MascotIntroSlot> = []

    static func shouldPlayIntroVideo(for slot: MascotIntroSlot) -> Bool {
        !playedIntroVideoSlots.contains(slot)
    }

    static func markIntroVideoPlayed(for slot: MascotIntroSlot) {
        playedIntroVideoSlots.insert(slot)
    }

    /// Clears the home intro slot so the mascot clip can play after onboarding paywall exit.
    static func prepareHomeIntroAfterOnboarding() {
        playedIntroVideoSlots.remove(.homeFirstSigns)
    }

    static func isMineAndYours(_ imageName: String) -> Bool {
        imageName == "mine and yours"
    }

    static func isWeather(_ imageName: String) -> Bool {
        imageName == "weather"
    }

    static func isAndBut(_ imageName: String) -> Bool {
        imageName == "andbut"
    }

    static func isSports(_ imageName: String) -> Bool {
        imageName == "sports"
    }

    static func isMusicArt(_ imageName: String) -> Bool {
        imageName == "musicart"
    }

    static func isWildAnimals(_ imageName: String) -> Bool {
        imageName == "wildanimals"
    }

    static func displaySize(for _: String) -> CGFloat {
        defaultDisplaySize
    }

    /// Scales mascot artwork so visible character size matches `commute` (Getting There),
    /// compensating for differing transparent padding in source PNGs.
    static func homePathContentScale(for imageName: String) -> CGFloat {
        homePathContentScaleByAsset[imageName] ?? 1
    }

    /// Extra vertical inset on the home path (positive = lower on screen).
    static func homeVerticalNudge(for imageName: String) -> CGFloat {
        if isMineAndYours(imageName) { return 0 }
        var nudge: CGFloat = 9
        if isAndBut(imageName) { nudge += 1 }
        return nudge
    }

    /// Extra horizontal offset on the home path (negative = left, positive = right).
    static func homeHorizontalNudge(for imageName: String) -> CGFloat {
        switch imageName {
        case "andbut": return -1
        case "wildanimals": return 2
        case "sports": return 1
        default: return 0
        }
    }

    /// Asset for in-lesson streak milestone pop-ups (5 / 10 / 20; 40 reuses 20).
    static func streakCelebrationImageName(for streak: Int) -> String {
        switch streak {
        case 5: return "5streak"
        case 10: return "10streak"
        case 20, 40: return "20streak"
        default: return "5streak"
        }
    }

    /// Every mascot asset used on the home path, tab headers, and empty states.
    static var allImageAssetNames: [String] {
        Array(Set(byUnitId.values).union(byTitle.values).union([
            headAndFaceImageName,
            "SignMascot",
            stoneCompleteCelebrationImageName,
        ] + reviewIntroMascotImageNames + streakCelebrationImageNames))
    }

    /// Loads and decodes mascot PNGs so fast home scrolling does not flash placeholders.
    static func preloadAllImages() {
        let names = allImageAssetNames
        DispatchQueue.global(qos: .userInitiated).async {
            for name in names {
                warmImageCache(named: name)
            }
        }
    }

    private static func warmImageCache(named name: String) {
        guard let image = UIImage(named: name) else { return }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        _ = renderer.image { _ in
            image.draw(at: .zero)
        }
    }

    static func imageName(for unit: ASLUnit) -> String? {
        guard !unit.isReview else { return nil }
        if let name = byUnitId[unit.id] { return name }
        return byTitle[unit.title]
    }

    static func imageName(for unitId: String) -> String? {
        byUnitId[unitId]
    }

    /// Bundled `.mp4` resource name (no extension) when a unit uses an animated mascot.
    static func animatedVideoResource(for unit: ASLUnit) -> String? {
        guard !unit.isReview else { return nil }
        if unit.id == "p1-u01" || unit.title == "First Signs" || unit.title == "Getting Started" {
            return "greetings-mascot"
        }
        return nil
    }

    /// Playback URL for mascot intro clips (bundle root → cache copy for AVPlayer).
    static func bundleVideoURL(for resourceName: String) -> URL? {
        guard !resourceName.isEmpty else { return nil }
        guard let source = mascotBundleSourceURL(for: resourceName) else { return nil }
        return cachedMascotPlaybackURL(copying: source, resourceName: resourceName)
    }

    private static func mascotBundleSourceURL(for resourceName: String) -> URL? {
        let subdirectories = [nil as String?, "Mascots"]
        for subdirectory in subdirectories {
            if let url = Bundle.main.url(
                forResource: resourceName,
                withExtension: "mp4",
                subdirectory: subdirectory
            ) {
                return url
            }
        }
        return nil
    }

    private static func cachedMascotPlaybackURL(copying source: URL, resourceName: String) -> URL? {
        let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MascotIntroVideos", isDirectory: true)
        let cachedURL = cacheDirectory.appendingPathComponent("\(resourceName).mp4")

        if FileManager.default.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        do {
            try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: cachedURL.path) {
                try FileManager.default.removeItem(at: cachedURL)
            }
            try FileManager.default.copyItem(at: source, to: cachedURL)
            return cachedURL
        } catch {
            return source
        }
    }

    /// Returns the next review-intro mascot asset and advances the rotation.
    static func nextReviewIntroMascotImageName() -> String {
        let names = reviewIntroMascotImageNames
        guard !names.isEmpty else { return "redrill-review-thinking" }
        let index = UserDefaults.standard.integer(forKey: reviewIntroMascotIndexKey) % names.count
        UserDefaults.standard.set(index + 1, forKey: reviewIntroMascotIndexKey)
        return names[index]
    }

    // MARK: - Stable unit id → asset (curriculum v5 home path)

    /// Relative to `commute` opaque content height (936px @ 1024 canvas).
    private static let homePathContentScaleByAsset: [String: CGFloat] = [
        "abcs1": 1.059,
        "andbut": 1.03,
        "aroundtown": 0.914,
        "body": 1.013,
        "colors": 1.018,
        "commute": 1.0,
        "countries": 0.98,
        "doingthings": 1.09,
        "family": 0.974,
        "fruits": 1.078,
        "furniture": 1.03,
        "gettingaround": 1.054,
        "greetings": 1.143,
        "home": 1.05,
        "howmuch": 1.065,
        "introductions": 1.062,
        "languages": 1.08,
        "me&you": 1.005,
        "mealtime": 1.022,
        "money": 1.109,
        "mood": 1.059,
        "musicart": 1.16,
        "nature": 1.001,
        "numbers": 1.083,
        "outfits": 0.941,
        "party": 0.984,
        "questions": 1.132,
        "routine": 1.137,
        "sayings": 1.056,
        "school": 0.972,
        "smalltalk": 1.039,
        "sports": 1.132,
        "talking": 1.106,
        "tech": 1.029,
        "time": 0.987,
        "weather": 1.056,
        "wildanimals": 0.974,
        "work": 1.039,
    ]

    private static let byUnitId: [String: String] = [
        // First Conversations
        "p1-u01": "greetings",
        "p1-u02": "smalltalk",
        "p1-u03": "me&you",
        "p1-u73": "talking",
        "p1-u06": "mood",
        // About You
        "p1-u05": "questions",
        "p1-u22": "languages",
        // Daily Life
        "p1-u24": "doingthings",
        "p1-u23": "gettingaround",
        "p1-u56": "commute",
        "p1-u40": "time",
        "p1-u18": "family",
        // Social
        "p1-u49": "party",
        // Everyday Essentials
        "p1-u30": "home",
        "p1-u31": "furniture",
        "p1-u17": "money",
        "p1-u57": "school",
        "p1-u45": "aroundtown",
        // Foundations
        "p1-u15": "numbers",
        "p1-u10": "abcs1",
        // Describe & Connect
        "p1-u32": "routine",
        "p1-u27": "colors",
        "p1-u29": "howmuch",
        "p1-u08": "andbut",
        // Body & Health
        "p1-u42": "body",
        // Work & Style
        "p1-u50": "outfits",
        "p1-u59": "work",
        // Tech & World
        "p1-u69": "tech",
        "p1-u68": "countries",
        // Outdoors & Fun
        "p1-u60": "wildanimals",
        "p1-u63": "weather",
        "p1-u62": "nature",
        "p1-u65": "sports",
        "p1-u66": "musicart",
        // Food
        "p1-u35": "fruits",
        "p1-u37": "mealtime",
        // Everyday Wisdom
        "p1-u71": "sayings",
    ]

    /// Legacy title lookup for units not yet keyed by id (e.g. old Firestore snapshots).
    private static let byTitle: [String: String] = [
        "Getting Started": "greetings",
        "First Signs": "greetings",
        "First Conversation": "introductions",
        "Quick Responses": "smalltalk",
        "Quick Replies": "smalltalk",
        "Everyday Replies": "smalltalk",
        "Me & You": "me&you",
        "You & Me": "me&you",
        "Introduce Yourself": "introductions",
        "Getting Help": "talking",
        "Feelings": "mood",
        "Feelings & Emotions": "mood",
        "Meet People": "questions",
        "Deaf Culture": "languages",
        "Daily Verbs": "doingthings",
        "Everyday Actions": "doingthings",
        "Action Words": "doingthings",
        "On the Move": "gettingaround",
        "Getting There": "commute",
        "Time Words": "time",
        "Time & Calendar": "time",
        "Days & Weeks": "daysofweek",
        "Family & People": "family",
        "Friends & Holidays": "party",
        "My Home": "home",
        "Money & Counting": "money",
        "School & Classroom": "school",
        "Health & Town": "aroundtown",
        "Fingerspell A–N": "abcs1",
        "Fingerspell O–Z": "abcs2",
        "The Alphabet": "abcs1",
        "At Home": "routine",
        "Size & Amount": "howmuch",
        "Feelings & Personality": "personality",
        "Connect Ideas": "andbut",
        "Body & Wellness": "body",
        "Clothes": "outfits",
        "Clothes & Accessories": "outfits",
        "Work Life": "work",
        "Devices & Apps": "tech",
        "Animals": "wildanimals",
        "Fruits & Veggies": "fruits",
        "Food & Drinks": "mealtime",
        "Everyday Sayings": "sayings",
        "Mine & Yours": "mine and yours",
        "Pronouns & Possessives": "mine and yours",
        "Introductions": "introductions",
        "Ask & Answer": "questions",
        "Question Words": "questions",
        "Useful Questions": "questions",
        "Deaf World Basics": "languages",
        "Check-ins": "mood",
        "Getting Unstuck": "talking",
        "Languages": "languages",
        "ABCs Part 1": "abcs1",
        "ABCs Part 2": "abcs2",
        "ABCs Part 3": "abcs2",
        "ABCs Part 4": "abcs4",
        "Spelling": "spelling",
        "Numbers": "numbers",
        "Counting": "counting",
        "Money": "money",
        "And, But, Or": "andbut",
        "How Much": "howmuch",
        "Family": "family",
        "Family Part 2": "family2",
        "People": "people",
        "Getting Around": "gettingaround",
        "Daily Life": "dailylife",
        "Talking": "talking",
        "Doing Things": "doingthings",
        "Colors": "colors",
        "More Colors": "morecolors",
        "Describing Things": "describingthings",
        "Home": "home",
        "Furniture": "furniture",
        "Routine": "routine",
        "Chores": "chores",
        "Mealtime": "mealtime",
        "Fruits": "fruits",
        "Vegetables": "vegetables",
        "Meat & Dairy": "meatdairy",
        "Snacks & Drinks": "snacks",
        "Days of the Week": "daysofweek",
        "When": "when",
        "Time": "time",
        "Head & Face": headAndFaceImageName,
        "Your Body": "body",
        "Feeling Sick": "feelingsick",
        "Health": "health",
        "Big Feelings": "bigfeelings",
        "Personality": "personality",
        "Love": "love",
        "Outfits": "outfits",
        "Layers": "layers",
        "Accessories": "accessories",
        "Travel": "travel",
        "Directions": "directions",
        "Around Town": "aroundtown",
        "Commute": "commute",
        "School": "school",
        "Classroom": "classroom",
        "Work": "work",
        "Pets": "pets",
        "Wild Animals": "wildanimals",
        "Nature & Seasons": "nature",
        "Weather": "weather",
        "Sports": "sports",
        "Music & Art": "musicart",
        "Party": "party",
        "Countries": "countries",
        "Tech": "tech",
        "Online": "online",
        "Big Ideas": "bigideas",
        "Useful Expressions": "sayings",
    ]
}
