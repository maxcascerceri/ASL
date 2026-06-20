import SwiftUI

/// Word and phrase IDs awaiting new sign videos (curriculum v5 filming batch).
enum ASLPendingFilmCatalog {
    static let wordIds: Set<String> = [
        // Stone One / greetings awaiting film
        "hello", "sorry", "how", "are",
        // Deaf World culture (9)
        "deaf", "hearing", "hardofhearing", "asl", "signlanguage", "namesign",
        "deafculture", "fluent", "learnasl", "practice",
        // Pronouns & possessives (7)
        "she", "her", "him", "them", "their", "yours", "ours",
        // Disambiguation splits (3 + optional orange split)
        "letteri", "rightcorrect", "mexico", "orangefruit", "orangecolor",
        // v5 phrase batch (15)
        "imtired", "imhappy", "imsad", "imangry", "imscared",
        "iwant", "ilike", "imhungry", "iwanteat", "iwantdrink",
        "pleasehelpme", "howmany", "whereareyou",
        "whatisyournamesign", "imlearningasl",
        // TOP 25 words (18 new)
        "emergency", "police", "lost", "cool", "awesome", "funny", "try",
        "thirsty", "from", "little", "repeat", "nervous", "call", "doing",
        "much", "nineoneone", "that",
        // TOP 25 phrases (12 new)
        "isignalittle", "canyourepeatthat", "pleasesignslower", "thankyouverymuch",
        "whereareyoufrom", "imfrom", "whatareyoudoing", "imexcited", "imnervous",
        "imthirsty", "call911", "imlost",
    ]

    static func shouldShowPlaceholder(for wordId: String, store: ASLDataStore) -> Bool {
        guard wordIds.contains(wordId) else { return false }
        if (store.wordsById[wordId]?.videoCount ?? 0) > 0 { return false }
        return !store.hasPlayableVideo(for: wordId)
    }

    /// Filmed pilot signs always show media; “Soon” only when not in catalog and Firestore says no video.
    static func shouldShowMissingMedia(for wordId: String, store: ASLDataStore) -> Bool {
        if store.hasPlayableVideo(for: wordId) { return false }
        if FilmedSignCatalog.isFilmed(wordId: wordId) { return false }
        return true
    }

    static func title(for wordId: String, store: ASLDataStore) -> String {
        ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId)
    }
}

struct SignFilmPlaceholder: View {
    enum Style {
        case stage
        case thumbnail
        case choice
    }

    let title: String
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = LessonQuestionLayout.videoCornerRadius
    var style: Style = .stage

    var body: some View {
        Group {
            if let height {
                placeholderBody
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            } else {
                placeholderBody
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Brand.divider.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). Sign video coming soon.")
    }

    private var placeholderBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Brand.soft.opacity(0.95),
                            Brand.cream.opacity(0.92),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: innerCornerRadius, style: .continuous)
                .strokeBorder(
                    Brand.divider.opacity(0.95),
                    style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                )

            content
                .padding(contentPadding)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .thumbnail:
            VStack(spacing: 6) {
                Image(systemName: "video.badge.plus")
                    .font(.asl(22, weight: .semibold))
                    .foregroundStyle(Brand.primary.opacity(0.85))
                Text("Soon")
                    .font(.asl(11, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
            }
        case .choice:
            VStack(spacing: 8) {
                Image(systemName: "video.badge.plus")
                    .font(.asl(24, weight: .semibold))
                    .foregroundStyle(Brand.primary.opacity(0.9))
                Text(title)
                    .font(.asl(15, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text("Coming soon")
                    .font(.asl(12, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
            }
        case .stage:
            VStack(spacing: 10) {
                Image(systemName: "video.badge.plus")
                    .font(.asl(34, weight: .semibold))
                    .foregroundStyle(Brand.primary)
                Text(title)
                    .font(.asl(18, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("Sign video coming soon")
                    .font(.asl(13, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
            }
        }
    }

    private var innerCornerRadius: CGFloat {
        max(8, cornerRadius - (style == .stage ? 6 : 4))
    }

    private var contentPadding: CGFloat {
        switch style {
        case .thumbnail: return 8
        case .choice: return 12
        case .stage: return 16
        }
    }
}
