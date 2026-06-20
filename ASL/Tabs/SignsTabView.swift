//
//  SignsTabView.swift
//  ASL
//

import AVFoundation
import AVKit
import SwiftUI
import UIKit

struct SignsTabView: View {
    @ObservedObject var store: ASLDataStore

    @State private var searchText = ""
    @State private var selectedSection: DictionarySection = .allSigns
    @State private var selectedSign: SignDetailSelection?
    @State private var navigationPath = NavigationPath()
    /// Holds category cards in the pressed look briefly after a real tap (finger-up clears `ButtonStyle` too fast to read).
    @State private var categoryTapPulseId: String?
    @State private var isSearchExpanded = false
    @FocusState private var isSearchFieldFocused: Bool
    /// Prevents the close button from immediately re-opening search after a simultaneous background tap.
    @State private var suppressSearchOpenUntil = Date.distantPast
    @AppStorage("asl.favoriteSigns.v1") private var favoriteWordIdsData = "[]"

    private let columns = [
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14),
        GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 14)
    ]

    private var dictionarySearchQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    private var isDictionarySearchActive: Bool {
        dictionarySearchQuery != nil
    }

    /// Prefix matches across the full dictionary (browse mode uses the category grid instead).
    private var visibleDictionaryWordIds: [String] {
        guard let query = dictionarySearchQuery else { return [] }

        return SignCategory.uniqueWordIds
            .filter { !SignEquivalence.isAlias($0) }
            .filter { SignEquivalence.matchesSearchQuery($0, query: query) }
            .sorted {
                SignEquivalence.dictionaryTitle(
                    for: $0,
                    fallback: ASLWordDisplay.title(for: $0)
                ).localizedCaseInsensitiveCompare(
                    SignEquivalence.dictionaryTitle(
                        for: $1,
                        fallback: ASLWordDisplay.title(for: $1)
                    )
                ) == .orderedAscending
            }
    }

    private var favoriteWordIds: Set<String> {
        Self.decodeFavoriteWordIds(from: favoriteWordIdsData)
    }

    private var visibleFavoriteWordIds: [String] {
        let favorites = SignCategory.allWords.filter { favoriteWordIds.contains($0) }
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return favorites
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return favorites.filter { ASLWordDisplay.title(for: $0).lowercased().hasPrefix(query) }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                SignsDictionaryHeader(
                    isSearchActive: isSearchExpanded || isDictionarySearchActive,
                    onOpenSearch: openDictionarySearch,
                    onCloseSearch: closeDictionarySearch
                )

                TabCurvedContentPanel {
                    VStack(spacing: 0) {
                        if isSearchExpanded || isDictionarySearchActive {
                            DictionarySearchField(text: $searchText, isFocused: $isSearchFieldFocused)
                                .padding(.horizontal, 18)
                                .padding(.top, 16)
                                .padding(.bottom, 12)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        SignsSectionPicker(selectedSection: $selectedSection)
                            .padding(.horizontal, 18)
                            .padding(.top, isSearchExpanded || isDictionarySearchActive ? 0 : 16)
                            .padding(.bottom, 14)

                        ScrollView(showsIndicators: false) {
                            Group {
                                switch selectedSection {
                                case .allSigns:
                                    if isDictionarySearchActive {
                                        if visibleDictionaryWordIds.isEmpty {
                                            DictionaryEmptyState(
                                                systemImage: "magnifyingglass",
                                                title: "No Signs Found",
                                                message: "Try another sign name."
                                            )
                                            .padding(.top, 56)
                                        } else {
                                            SignGridView(
                                                wordIds: visibleDictionaryWordIds,
                                                store: store,
                                                favoriteWordIds: favoriteWordIds,
                                                categoryTitleForWordId: SignCategory.primaryCategoryTitle(forWordId:),
                                                toggleFavorite: toggleFavorite,
                                                selectSign: openSignDetail
                                            )
                                            .task(id: visibleDictionaryWordIds) {
                                                await store.loadWordsAwait(wordIds: visibleDictionaryWordIds)
                                                store.prepareDictionarySearchResults(wordIds: visibleDictionaryWordIds)
                                            }
                                        }
                                    } else {
                                        LazyVGrid(columns: columns, spacing: 14) {
                                            ForEach(SignCategory.all) { category in
                                                Button {
                                                    Keyboard.dismiss()
                                                    Haptics.tap()
                                                    categoryTapPulseId = category.id
                                                    store.prepareDictionaryCategory(wordIds: category.words)
                                                    Task {
                                                        await store.loadWordsAwait(wordIds: category.words)
                                                    }
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                                        navigationPath.append(category.id)
                                                        categoryTapPulseId = nil
                                                    }
                                                } label: {
                                                    SignCategoryCard(
                                                        category: category,
                                                        pulsePressed: categoryTapPulseId == category.id
                                                    )
                                                }
                                                .buttonStyle(DictionaryCategoryPressStyle())
                                            }
                                        }
                                    }
                                case .favorites:
                                    if favoriteWordIds.isEmpty {
                                        DictionaryEmptyState(
                                            mascotImageName: "mine and yours",
                                            mascotSize: UnitMascot.favoritesEmptyStateSize,
                                            title: "No Favorites Yet",
                                            message: "Tap Save on a sign to add it here."
                                        )
                                        .padding(.top, 56)
                                    } else if visibleFavoriteWordIds.isEmpty {
                                        DictionaryEmptyState(
                                            systemImage: "magnifyingglass",
                                            title: "No Signs Found",
                                            message: "Try another sign name."
                                        )
                                        .padding(.top, 56)
                                    } else {
                                        SignGridView(
                                            wordIds: visibleFavoriteWordIds,
                                            store: store,
                                            favoriteWordIds: favoriteWordIds,
                                            toggleFavorite: toggleFavorite,
                                            selectSign: openSignDetail
                                        )
                                        .task(id: visibleFavoriteWordIds) {
                                            await store.loadWordsAwait(wordIds: visibleFavoriteWordIds)
                                            store.prepareDictionaryFavorites(wordIds: visibleFavoriteWordIds)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 28)
                        }
                    }
                }
                .padding(.top, -12)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                if isSearchExpanded || isDictionarySearchActive {
                    closeDictionarySearch()
                } else {
                    Keyboard.dismiss()
                }
            })
            .brandCanvasBackground()
            .onAppear { store.setSignsTabActive(true) }
            .onDisappear { store.setSignsTabActive(false) }
            .onChange(of: searchText) { _, newValue in
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                    isSearchExpanded = true
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { categoryId in
                if let category = SignCategory.category(withId: categoryId) {
                    SignCategoryDetailView(
                        category: category,
                        store: store,
                        favoriteWordIds: favoriteWordIds,
                        toggleFavorite: toggleFavorite,
                        selectSign: openSignDetail
                    )
                }
            }
            .sheet(item: $selectedSign) { selection in
                SignDetailSheet(
                    initialWordId: selection.wordId,
                    wordIds: selection.wordIds,
                    store: store,
                    favoriteWordIds: favoriteWordIds,
                    toggleFavorite: toggleFavorite
                )
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.hidden)
            }
            .onChange(of: store.practiceDailyEngine.navigation.consumeSignsCategoryId) { _, categoryId in
                guard let categoryId else { return }
                store.practiceDailyEngine.navigation.acknowledgeSignsCategoryConsumed()
                selectedSection = .allSigns
                closeDictionarySearch()
                navigationPath.append(categoryId)
            }
            .onChange(of: store.practiceDailyEngine.navigation.consumeSignsFavorites) { _, showFavorites in
                guard showFavorites else { return }
                store.practiceDailyEngine.navigation.acknowledgeSignsFavoritesConsumed()
                selectedSection = .favorites
                closeDictionarySearch()
            }
            .onChange(of: store.pendingSignWordId) { _, wordId in
                guard wordId != nil, let consumed = store.consumePendingSignWordId() else { return }
                openSignDetail(wordId: consumed, wordIds: [consumed])
            }
        }
    }

    private func openSignDetail(wordId: String, wordIds: [String]) {
        store.prepareDictionarySign(wordId: wordId, in: wordIds)
        selectedSign = SignDetailSelection(wordId: wordId, wordIds: wordIds)
    }

    private func openDictionarySearch() {
        guard Date() >= suppressSearchOpenUntil else { return }

        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isSearchExpanded = true
        }
        DispatchQueue.main.async {
            isSearchFieldFocused = true
        }
    }

    private func closeDictionarySearch() {
        suppressSearchOpenUntil = Date().addingTimeInterval(0.25)
        isSearchFieldFocused = false
        Keyboard.dismiss()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            isSearchExpanded = false
            searchText = ""
        }
    }

    private func toggleFavorite(_ wordId: String) {
        var favorites = favoriteWordIds
        if favorites.contains(wordId) {
            favorites.remove(wordId)
            Haptics.tap()
        } else {
            favorites.insert(wordId)
            Haptics.correct()
        }
        favoriteWordIdsData = Self.encodeFavoriteWordIds(favorites)
    }

    private static func decodeFavoriteWordIds(from raw: String) -> Set<String> {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(decoded)
    }

    private static func encodeFavoriteWordIds(_ ids: Set<String>) -> String {
        guard let data = try? JSONEncoder().encode(ids.sorted()),
              let raw = String(data: data, encoding: .utf8)
        else { return "[]" }
        return raw
    }
}

private struct SignDetailSelection: Identifiable {
    let wordId: String
    let wordIds: [String]

    var id: String {
        "\(wordId)-\(wordIds.joined(separator: ","))"
    }
}

private enum DictionarySection: String, CaseIterable, Identifiable {
    case allSigns = "All Signs"
    case favorites = "Favorites"

    var id: String { rawValue }
}

private struct SignCategory: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    /// When set, shown in the card center instead of the SF Symbol placeholder.
    let iconAssetName: String?
    let palette: PastelPalette
    let words: [String]

    init(
        id: String,
        title: String,
        systemImage: String,
        iconAssetName: String? = nil,
        palette: PastelPalette,
        words: [String]
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.iconAssetName = iconAssetName
        self.palette = palette
        self.words = words
    }

    static var allWords: [String] {
        all.flatMap(\.words)
    }

    /// First-seen order across categories; duplicates (e.g. shared lesson ids) appear once.
    static var uniqueWordIds: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for category in all {
            for wordId in category.words where seen.insert(wordId).inserted {
                ordered.append(wordId)
            }
        }
        return ordered
    }

    static func category(withId id: String) -> SignCategory? {
        all.first { $0.id == id }
    }

    /// Grid cells for dictionary browsing (pronouns use grouped canonical ids).
    var dictionaryGridWordIds: [String] {
        if id == "pronouns" {
            return SignEquivalence.pronounGridWordIds
        }
        return words
    }

    /// Category label for search results (first category that lists this sign).
    static func primaryCategoryTitle(forWordId wordId: String) -> String? {
        category(containingWordId: wordId)?.title
    }

    static func category(containingWordId wordId: String) -> SignCategory? {
        all.first { $0.words.contains(wordId) }
    }

    static let all: [SignCategory] = {
        let entries: [(String, String, String, String?, [String])] = [
            ("greetings", "First Signs", "hand.wave.fill", nil, ["hello", "bye", "please", "thankyou", "sorry", "welcome", "name", "congratulations", "oops", "nice", "meet", "introduce", "sign", "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow", "yourewelcome", "thankyouverymuch"]),
            ("responses", "Everyday Replies", "bubble.left.fill", nil, ["yes", "no", "sure", "wow", "really", "alright", "ok", "again", "wait", "nevermind", "maybe", "dontknow", "notyet", "signagain", "excuseme", "seeyoulater", "samehere", "havegoodday", "nicetoseeyou", "cool", "awesome", "funny"]),
            ("pronouns", "Pronouns", "person.2.fill", nil, ["i", "me", "you", "we", "us", "our", "my", "your", "his", "mine", "he", "they", "she", "her", "him", "them", "their", "yours", "ours"]),
            ("questions", "Question Words", "questionmark", nil, ["what", "where", "when", "who", "why", "how", "which", "whatisyourname", "whatsthat", "whatdoesthatmean", "howmany", "whereareyou", "whatisyournamesign", "whereareyoufrom", "whatareyoudoing", "imfrom"]),
            ("people-words", "People Words", "person.text.rectangle.fill", nil, ["person", "people", "myself", "yourself", "sign", "introduce"]),
            ("mood-basics", "Check-ins", "face.smiling.fill", nil, ["good", "bad", "fine", "great", "happy", "sad", "tired", "angry", "scared", "excited", "worry", "nervous", "imgood", "goodmorning", "goodnight", "imtired", "imhappy", "imsad", "imangry", "imscared", "imexcited", "imnervous"]),
            ("deaf-world", "Deaf World Basics", "ear.fill", nil, ["deaf", "hearing", "hardofhearing", "asl", "signlanguage", "namesign", "deafculture", "fluent", "learnasl", "practice", "whatisyournamesign", "imlearningasl", "isignalittle", "interpreter", "caption", "hearingaid", "lipread", "gesture", "translate"]),
            ("alphabet", "Alphabet", "a.circle.fill", nil, ["a", "b", "c", "d", "e", "f", "g", "h", "letteri", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]),
            ("fingerspelling", "Fingerspelling", "hand.point.up.left.fill", nil, ["alphabet", "fingerspell", "letter", "language", "word", "name"]),
            ("numbers", "Numbers", "number", nil, ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]),
            ("money", "Money", "dollarsign.circle.fill", nil, ["money", "pay", "cost", "price", "1dollar", "5dollars"]),
            ("amounts-math", "Amounts & Math", "percent", nil, ["half", "quarter", "percent", "double", "triple", "hundred", "many", "few", "enough", "more", "less", "very", "almost", "really"]),
            ("sentence-helpers", "Sentence Helpers", "link", nil, ["and", "but", "or", "so", "with", "without", "also", "because", "same", "different", "if"]),
            ("family", "Family", "figure.2.and.child.holdinghands", nil, ["mother", "father", "sister", "brother", "baby", "child", "family", "parents", "grandmother", "grandfather", "aunt", "uncle", "cousin", "niece", "nephew", "twins"]),
            ("people", "People", "person.fill", nil, ["man", "woman", "boy", "girl", "adult", "teenager"]),
            ("movement", "Movement", "figure.walk", nil, ["go", "come", "walk", "run", "stop", "turn", "move", "lost", "imlost"]),
            ("body-actions", "Body Actions", "figure.arms.open", nil, ["eat", "drink", "sleep", "see", "hear", "feel", "breathe", "smell"]),
            ("communication", "Communication", "message.fill", nil, ["tell", "ask", "talk", "think", "know", "understand", "believe", "need", "help", "idontunderstand", "ineedhelp", "canyouhelpme", "pleasehelpme", "canyourepeatthat", "pleasesignslower", "howyousignthat", "isignalittle", "call911"]),
            ("doing-helping", "Doing & Helping", "bolt.fill", nil, ["make", "get", "give", "take", "use", "find", "want", "help", "iwant", "try", "doing", "whatareyoudoing"]),
            ("colors", "Colors", "paintbrush.fill", nil, ["red", "blue", "green", "yellow", "orangecolor", "purple", "pink", "brown", "black", "white", "gray", "gold", "silver", "bright"]),
            ("descriptions", "Descriptions", "slider.horizontal.3", nil, ["dark", "light", "bright", "big", "small", "tall", "fast", "slow", "hard"]),
            ("home", "Home", "house.fill", nil, ["home", "house", "kitchen", "bathroom", "bedroom", "livingroom", "basement", "backyard", "wherebathroom", "garage"]),
            ("furniture", "Furniture", "chair.fill", nil, ["table", "chair", "bed", "couch", "door", "window", "lamp", "clock"]),
            ("hygiene", "Hygiene", "shower.fill", nil, ["shower", "toilet", "sink", "soap", "toothbrush", "brush", "comb", "mirror"]),
            ("chores", "Chores", "sparkles", nil, ["clean", "wash", "cook", "sweep", "vacuum", "washdishes"]),
            ("mealtime", "Mealtime", "fork.knife", nil, ["breakfast", "lunch", "dinner", "hungry", "full", "delicious", "imhungry"]),
            ("fruit", "Fruit", "apple.logo", nil, ["apple", "banana", "grapes", "strawberry", "cherry", "pineapple", "lemon", "orangefruit"]),
            ("vegetables", "Vegetables", "carrot.fill", nil, ["tomato", "carrot", "corn", "onion", "potato", "lettuce"]),
            ("protein-dairy", "Protein & Dairy", "takeoutbag.and.cup.and.straw.fill", nil, ["meat", "fish", "egg", "cheese", "milk", "butter", "bacon", "chicken"]),
            ("snacks-drinks", "Snacks & Drinks", "mug.fill", nil, ["bread", "pizza", "cake", "chocolate", "water", "coffee", "tea", "juice"]),
            ("weekdays", "Weekdays", "calendar", nil, ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "weekend"]),
            ("time-of-day", "Time of Day", "sun.max.fill", nil, ["morning", "afternoon", "night", "today", "yesterday", "tomorrow", "now", "noon", "later", "early"]),
            ("time-units", "Time Units", "clock.fill", nil, ["day", "week", "month", "year", "hour", "minute", "weekend", "holiday"]),
            ("head-face", "Head & Face", "face.smiling", nil, ["head", "face", "eyes", "ear", "nose", "mouth", "teeth", "tongue"]),
            ("body", "Body", "figure.arms.open", nil, ["body", "arm", "hands", "finger", "shoulder", "neck", "back", "stomach"]),
            ("symptoms", "Symptoms", "bandage.fill", nil, ["sick", "hurt", "pain", "headache", "cough", "sneeze", "tired", "dizzy"]),
            ("health", "Health", "cross.case.fill", nil, ["health", "exercise", "doctor", "nurse", "hospital", "medicine"]),
            ("personality", "Personality", "person.crop.circle.fill", nil, ["confident", "humble", "lazy", "stubborn", "curious", "serious", "remember", "forget"]),
            ("big-feelings", "Big Feelings", "heart.fill", nil, ["bored", "lonely", "jealous", "embarrass", "frustrate", "surprise"]),
            ("relationships", "Relationships", "heart.circle.fill", nil, ["love", "like", "hate", "friend", "hug", "kiss", "ilike"]),
            ("clothing", "Clothing", "tshirt.fill", nil, ["shirt", "pants", "dress", "shoes", "socks", "jacket", "hat", "clothes", "shorts", "skirt", "sweater", "boots", "gloves", "scarf", "belt", "suit"]),
            ("accessories", "Accessories", "backpack.fill", nil, ["glasses", "earring", "necklace", "bracelet", "ring", "backpack", "wallet", "watch"]),
            ("transportation", "Transportation", "car.fill", nil, ["car", "bus", "train", "airplane", "bike", "truck", "motorcycle", "boat"]),
            ("directions", "Directions", "location.north.line.fill", nil, ["here", "there", "left", "right", "up", "down", "near", "far"]),
            ("places", "Places", "mappin.and.ellipse", nil, ["shop", "park", "restaurant", "hotel", "library", "church"]),
            ("commute", "Commute", "road.lanes", nil, ["drive", "ride", "arrive", "travel", "road", "street", "traffic", "commute"]),
            ("school", "School", "book.fill", nil, ["school", "class", "student", "teacher", "learn", "study", "read", "write", "math", "science", "history", "art", "book", "pen", "paper", "music"]),
            ("work", "Work", "briefcase.fill", nil, ["work", "job", "boss", "lawyer", "engineer", "scientist", "meeting", "retire"]),
            ("pets-farm", "Pets & Farm", "pawprint.fill", nil, ["dog", "cat", "horse", "cow", "pig", "sheep", "rabbit", "duck"]),
            ("wild-animals", "Wild Animals", "hare.fill", nil, ["lion", "tiger", "elephant", "bear", "wolf", "fox", "eagle", "monkey"]),
            ("nature-seasons", "Nature & Seasons", "leaf.fill", nil, ["tree", "flower", "mountain", "river", "ocean", "beach", "sun", "moon", "spring", "summer", "fall", "winter"]),
            ("weather", "Weather", "cloud.sun.fill", nil, ["rain", "snow", "wind", "cloud", "lightning", "thunder", "hot", "cold"]),
            ("sports", "Sports", "sportscourt.fill", nil, ["football", "basketball", "baseball", "soccer", "volleyball", "hockey", "tennis", "golf"]),
            ("arts-hobbies", "Arts & Hobbies", "music.note", nil, ["draw", "paint", "sing", "dance", "music", "guitar", "piano"]),
            ("holidays", "Holidays", "party.popper.fill", nil, ["party", "birthday", "christmas", "halloween", "thanksgiving", "easter"]),
            ("countries", "Countries", "globe.americas.fill", nil, ["america", "canada", "mexico", "france", "germany", "china", "japan", "italy"]),
            ("tech", "Tech", "desktopcomputer", nil, ["computer", "phone", "tablet", "laptop", "camera", "tv", "keyboard", "mouse"]),
            ("online-media", "Online & Media", "wifi", nil, ["internet", "email", "text", "download", "upload", "share", "send", "video"]),
            ("big-ideas", "Big Ideas", "lightbulb.fill", nil, ["can", "cannot", "maybe", "important", "rightcorrect", "wrong", "future", "always"]),
            ("asl-phrases", "ASL Phrases", "quote.bubble.fill", nil, ["mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow", "yourewelcome", "dontknow", "notyet", "signagain", "excuseme", "seeyoulater", "samehere", "havegoodday", "whatisyourname", "whatsthat", "whatdoesthatmean", "imgood", "goodmorning", "goodnight", "idontunderstand", "ineedhelp", "canyouhelpme", "pleasehelpme", "wherebathroom", "nicetoseeyou", "letmesee", "howyousignthat", "onemoretime", "talktoyoulater", "blowmind", "allofsudden", "wrapup", "letgo", "imtired", "imhappy", "imsad", "imangry", "imscared", "iwant", "ilike", "imhungry", "iwanteat", "iwantdrink", "howmany", "whereareyou", "whatisyournamesign", "imlearningasl"]),
        ]
        return entries.enumerated().map { index, entry in
            SignCategory(
                id: entry.0,
                title: entry.1,
                systemImage: entry.2,
                iconAssetName: entry.3,
                palette: PastelPalette.dictionaryBrowse(at: index),
                words: entry.4
            )
        }
    }()
}

private struct DictionarySearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .aslIconStyle(role: .navigation, tint: Brand.primary)

            TextField("Search signs", text: $text)
                .aslFont(.cardDescription, variant: .prominent)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused(isFocused)
                .submitLabel(.search)
                .onSubmit {
                    isFocused.wrappedValue = false
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isFocused.wrappedValue = false
                            Keyboard.dismiss()
                        }
                        .aslFont(.button, variant: .compact)
                    }
                }

            if !text.isEmpty {
                Button {
                    text = ""
                    isFocused.wrappedValue = false
                    Keyboard.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .aslIconStyle(role: .utility, tint: Brand.secondaryLabel, isEmphasis: false)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Brand.chrome)
        )
        .elevation(.insetField)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Brand.divider, lineWidth: 1.5)
        }
    }
}

private enum Keyboard {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Signs page chrome (reference layout)

private struct SignsDictionaryHeader: View {
    let isSearchActive: Bool
    let onOpenSearch: () -> Void
    let onCloseSearch: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    if isSearchActive {
                        onCloseSearch()
                    }
                }

            TabScreenHeaderTitleBlock(
                title: "Signs",
                subtitle: "Your ASL dictionary. Explore, learn, and add signs to your favorites.",
                mascotWidth: UnitMascot.headerMascotSize
            )

            HStack(spacing: 0) {
                Spacer(minLength: 0)

                Image("SignMascot")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: UnitMascot.headerMascotSize, height: UnitMascot.headerMascotSize)
                    .padding(.trailing, TabScreenHeaderLayout.mascotTrailingPadding)
                    .padding(.top, TabScreenHeaderLayout.mascotTopPadding)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .padding(.trailing, TabScreenHeaderLayout.toolbarTrailingReserve)

            Button {
                Haptics.tap()
                if isSearchActive {
                    onCloseSearch()
                } else {
                    onOpenSearch()
                }
            } label: {
                SignsHeaderSearchButtonIcon(isSearchActive: isSearchActive)
                    .contentShape(Circle())
            }
            .buttonStyle(SignsSearchHeaderButtonStyle())
            .padding(.top, TabScreenHeaderLayout.toolbarTopPadding)
            .padding(.trailing, TabScreenHeaderLayout.toolbarTrailingPadding)
            .zIndex(10)
        }
        .frame(height: TabScreenHeaderLayout.height)
    }
}

private struct SignsSectionPicker: View {
    @Binding var selectedSection: DictionarySection

    private let depth: CGFloat = 4
    private let trackHeight: CGFloat = 46

    var body: some View {
        ZStack(alignment: .top) {
            Capsule(style: .continuous)
                .fill(Brand.primaryShadow.opacity(0.35))
                .frame(height: trackHeight)
                .offset(y: depth)

            Capsule(style: .continuous)
                .fill(Brand.cream)
                .frame(height: trackHeight)
                .overlay {
                    Capsule(style: .continuous)
                        .stroke(Brand.divider, lineWidth: 1.5)
                }

            HStack(spacing: 4) {
                ForEach(DictionarySection.allCases) { section in
                    Button {
                        Haptics.tap()
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedSection = section
                        }
                    } label: {
                        SignsSectionTabLabel(
                            title: section.rawValue,
                            isSelected: selectedSection == section,
                            isCompact: section == .allSigns
                        )
                    }
                    .buttonStyle(SignsRaisedPressStyle())
                }
            }
            .padding(4)
        }
        .frame(height: trackHeight + depth, alignment: .top)
    }
}

private struct SignsSectionTabLabel: View {
    let title: String
    let isSelected: Bool
    var isCompact: Bool = false
    @Environment(\.signsRaisedPressed) private var isPressed

    private var tabHeight: CGFloat { isCompact ? 36 : 40 }
    private var depth: CGFloat { isCompact ? 2.5 : 3 }

    var body: some View {
        ZStack(alignment: .top) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(Brand.primaryShadow)
                    .frame(height: tabHeight)
                    .offset(y: isPressed ? 1.5 : depth)

                Capsule(style: .continuous)
                    .fill(Brand.primary)
                    .frame(height: tabHeight)
                    .offset(y: isPressed ? depth - 1.5 : 0)
            }

            Text(title)
                .font(.asl(isCompact ? 15 : 17, weight: .semibold, design: .ui))
                .foregroundStyle(isSelected ? Color.white : Brand.primary)
                .frame(maxWidth: .infinity)
                .frame(height: tabHeight)
                .offset(y: isSelected ? (isPressed ? depth - 1.5 : 0) : 0)
        }
        .frame(height: isSelected ? tabHeight + depth : tabHeight, alignment: .top)
        .scaleEffect(isPressed ? (isSelected ? 0.985 : 0.98) : 1)
        .opacity(isPressed && !isSelected ? 0.82 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.68), value: isPressed)
        .contentShape(Capsule())
    }
}

private struct SignCategoryCard: View {
    let category: SignCategory
    /// True for a moment after a successful tap, before navigation pushes.
    var pulsePressed: Bool = false

    @Environment(\.dictionaryCategoryPressed) private var isPressed

    private var isVisuallyPressed: Bool {
        isPressed || pulsePressed
    }

    var body: some View {
        PremiumColoredCard(
            fill: category.palette.fill,
            depthHint: category.palette.depth,
            depthMix: PastelCardMetrics.depthMix,
            slabDepth: PastelCardMetrics.slabDepth,
            cornerRadius: PastelCardMetrics.cornerRadius,
            isPressed: isVisuallyPressed
        ) {
            categoryCardContent
        }
        .contentShape(RoundedRectangle(cornerRadius: PastelCardMetrics.cornerRadius, style: .continuous))
    }

    private var categoryCardContent: some View {
        ZStack(alignment: .bottomLeading) {
            categoryIcon
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, PastelCardMetrics.iconPadding)
                .padding(.trailing, PastelCardMetrics.iconPadding)

            PastelPillLabel(title: category.title)
                .padding(PastelCardMetrics.contentPadding)
        }
        .frame(height: PastelCardMetrics.cardHeight)
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let asset = category.iconAssetName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PastelCardMetrics.browseIconSize,
                    height: PastelCardMetrics.browseIconSize
                )
                .pastelIconWhiteOutline()
        } else {
            ASLIcon(
                source: .symbol(category.systemImage),
                role: .dictionaryCategory,
                tint: category.palette.iconTint,
                assetSize: PastelCardMetrics.browseIconSize
            )
            .pastelIconWhiteOutline()
        }
    }
}

// MARK: - Shared 3D raised controls

private struct SignsRaisedCircleButton<Label: View>: View {
    let isPressed: Bool
    let size: CGFloat
    let depth: CGFloat
    let face: Color
    let shadow: Color
    @ViewBuilder let label: () -> Label

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(shadow)
                .frame(width: size, height: size)
                .offset(y: isPressed ? 1 : depth)

            Circle()
                .fill(face)
                .frame(width: size, height: size)
                .overlay { label() }
                .offset(y: isPressed ? depth - 1 : 0)
        }
        .frame(width: size, height: size + depth, alignment: .top)
    }
}

private struct SignsRaisedPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.signsRaisedPressed, configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

/// Plain button style so the header search/close control always receives taps and fires its action.
private struct SignsSearchHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.signsRaisedPressed, configuration.isPressed)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct SignsRaisedPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var signsRaisedPressed: Bool {
        get { self[SignsRaisedPressedKey.self] }
        set { self[SignsRaisedPressedKey.self] = newValue }
    }
}

private struct SignsHeaderSearchButtonIcon: View {
    let isSearchActive: Bool
    @Environment(\.signsRaisedPressed) private var isPressed

    var body: some View {
        SignsRaisedCircleButton(
            isPressed: isPressed,
            size: 44,
            depth: 5,
            face: Brand.chrome,
            shadow: Brand.divider
        ) {
            Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                .font(.asl(18, weight: .semibold))
                .foregroundStyle(Brand.primary)
        }
    }
}

/// Standard `ButtonStyle` so `ScrollView` can own vertical drags; avoid `DragGesture(minimumDistance: 0)` here,
/// which competes with scrolling and often blocks it entirely.
private struct DictionaryCategoryPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.dictionaryCategoryPressed, configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

private struct DictionaryCategoryPressedKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var dictionaryCategoryPressed: Bool {
        get { self[DictionaryCategoryPressedKey.self] }
        set { self[DictionaryCategoryPressedKey.self] = newValue }
    }
}

private struct SignCategoryDetailView: View {
    let category: SignCategory
    @ObservedObject var store: ASLDataStore
    let favoriteWordIds: Set<String>
    let toggleFavorite: (String) -> Void
    let selectSign: (String, [String]) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            SignCategoryHeroCard(category: category) {
                Haptics.tap()
                dismiss()
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity)
            .background(Brand.canvas)

            ScrollView(showsIndicators: false) {
                SignGridView(
                    wordIds: category.dictionaryGridWordIds,
                    store: store,
                    favoriteWordIds: favoriteWordIds,
                    compact: true,
                    toggleFavorite: toggleFavorite,
                    selectSign: { wordId, _ in
                        let detailIds = SignEquivalence.dictionaryDetailWordIds(primaryWordId: wordId)
                        selectSign(wordId, detailIds)
                    }
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)

                if category.id == "fingerspelling" || category.id == "alphabet" {
                    spellYourNameFooter
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                }

                Spacer(minLength: 28)
            }
        }
        .brandCanvasBackground()
        .simultaneousGesture(categorySwipeBackGesture)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .background(NavigationSwipeBackEnabler())
        .task(id: category.id) {
            await store.loadWordsAwait(wordIds: category.words)
            store.prepareDictionaryCategory(wordIds: category.words)
        }
    }

    private var categorySwipeBackGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                guard abs(dx) > abs(dy), abs(dx) > 70 else { return }
                Haptics.tap()
                dismiss()
            }
    }

    private var spellYourNameFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(category.id == "alphabet" ? "Ready to spell your name?" : "Spell a name")
                .font(LessonQuestionLayout.microcopyFont)
                .foregroundStyle(Brand.secondaryLabel)
            Button {
                Haptics.tap()
                store.queueSpellYourNamePractice(intent: .personalName)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "person.text.rectangle.fill")
                    Text("Open Spell Your Name")
                        .font(LessonQuestionLayout.choiceFont)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.aslReading(13, weight: .semibold))
                }
                .foregroundStyle(Brand.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Brand.homeBackground)
                )
            }
            .buttonStyle(.plain)
            .disabled(!PracticeSpellYourNameAvailability.isUnlocked(from: store))
            .opacity(PracticeSpellYourNameAvailability.isUnlocked(from: store) ? 1 : 0.55)
        }
    }
}

private struct SignCategoryHeroCard: View {
    let category: SignCategory
    let onBack: () -> Void

    private var palette: PastelPalette { category.palette }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(
                    PremiumCardStyle.softDepth(
                        for: palette.fill,
                        hint: palette.depth,
                        mix: PastelCardMetrics.depthMix
                    )
                )
                .offset(y: PastelCardMetrics.slabDepth)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(palette.fill)
                .overlay(alignment: .bottomLeading) {
                    PastelPillLabel(
                        title: category.title,
                        fontSize: PastelCardMetrics.heroTitleFontSize,
                        horizontalPadding: 12,
                        verticalPadding: 6
                    )
                    .padding(PastelCardMetrics.heroContentPadding)
                }

            heroIcon
                .padding(PastelCardMetrics.heroIconPadding)
        }
        .elevation(.chapterCard(tint: palette.fill))
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.asl(20, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary.opacity(0.62))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Brand.chrome.opacity(0.92))
                    )
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .frame(height: 156)
    }

    @ViewBuilder
    private var heroIcon: some View {
        if let asset = category.iconAssetName {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(
                    width: PastelCardMetrics.heroIconSize,
                    height: PastelCardMetrics.heroIconSize
                )
                .pastelIconWhiteOutline(strokeWidth: 2.25)
        } else {
            ASLIcon(
                source: .symbol(category.systemImage),
                role: .dictionaryCategory,
                tint: palette.iconTint,
                assetSize: PastelCardMetrics.heroIconSize
            )
            .pastelIconWhiteOutline(strokeWidth: 2.25)
        }
    }
}

private enum SignsGridLayout {
    static let columnCount = 2
    static let columnSpacing: CGFloat = 14
    static let rowSpacing: CGFloat = 14
}

private struct SignGridView: View {
    let wordIds: [String]
    @ObservedObject var store: ASLDataStore
    let favoriteWordIds: Set<String>
    var categoryTitleForWordId: ((String) -> String?)? = nil
    var compact: Bool = false
    let toggleFavorite: (String) -> Void
    let selectSign: (String, [String]) -> Void

    private var rows: [[String]] {
        stride(from: 0, to: wordIds.count, by: SignsGridLayout.columnCount).map { start in
            Array(wordIds[start..<min(start + SignsGridLayout.columnCount, wordIds.count)])
        }
    }

    var body: some View {
        VStack(spacing: SignsGridLayout.rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: SignsGridLayout.columnSpacing) {
                    ForEach(row, id: \.self) { wordId in
                        signCard(wordId: wordId)
                            .frame(maxWidth: .infinity)
                    }

                    if row.count < SignsGridLayout.columnCount {
                        ForEach(0..<(SignsGridLayout.columnCount - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func signCard(wordId: String) -> some View {
        let categorySubtitle = categoryTitleForWordId?(wordId)

        SignWordCard(
            wordId: wordId,
            store: store,
            categorySubtitle: categorySubtitle,
            compact: compact,
            isFavorite: favoriteWordIds.contains(wordId),
            toggleFavorite: {
                toggleFavorite(wordId)
            },
            openSign: {
                Haptics.tap()
                selectSign(wordId, wordIds)
            }
        )
        .frame(
            height: SignsWordCardLayout.cardHeight(
                compact: compact,
                hasSubtitle: categorySubtitle != nil
            )
        )
    }
}

private enum SignsWordCardLayout {
    static let compactThumbnailHeight: CGFloat = 122
    static let standardThumbnailHeight: CGFloat = 134

    static let compactLabelContentHeight: CGFloat = 52
    static let standardLabelContentHeight: CGFloat = 62
    static let compactLabelContentHeightWithSubtitle: CGFloat = 58
    static let standardLabelContentHeightWithSubtitle: CGFloat = 68

    static let compactTitleLineHeight: CGFloat = 20
    static let standardTitleLineHeight: CGFloat = 24
    static let subtitleLineHeight: CGFloat = 16

    static let compactHorizontalPadding: CGFloat = 10
    static let standardHorizontalPadding: CGFloat = 8
    static let compactVerticalPadding: CGFloat = 6
    static let standardVerticalPadding: CGFloat = 5

    static let cornerRadius: CGFloat = 21

    static func thumbnailHeight(compact: Bool) -> CGFloat {
        compact ? compactThumbnailHeight : standardThumbnailHeight
    }

    static func labelContentHeight(compact: Bool, hasSubtitle: Bool) -> CGFloat {
        if compact {
            return hasSubtitle ? compactLabelContentHeightWithSubtitle : compactLabelContentHeight
        }
        return hasSubtitle ? standardLabelContentHeightWithSubtitle : standardLabelContentHeight
    }

    static func labelSectionHeight(compact: Bool, hasSubtitle: Bool) -> CGFloat {
        let verticalPadding = compact ? compactVerticalPadding : standardVerticalPadding
        return labelContentHeight(compact: compact, hasSubtitle: hasSubtitle) + (verticalPadding * 2)
    }

    static func cardHeight(compact: Bool, hasSubtitle: Bool) -> CGFloat {
        thumbnailHeight(compact: compact) + labelSectionHeight(compact: compact, hasSubtitle: hasSubtitle)
    }
}

private struct SignWordCard: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore
    var categorySubtitle: String? = nil
    var compact: Bool = false
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    let openSign: () -> Void

    private var thumbnailHeight: CGFloat {
        SignsWordCardLayout.thumbnailHeight(compact: compact)
    }

    private var hasSubtitle: Bool { categorySubtitle != nil }

    private var labelContentHeight: CGFloat {
        SignsWordCardLayout.labelContentHeight(compact: compact, hasSubtitle: hasSubtitle)
    }

    private var labelSectionHeight: CGFloat {
        SignsWordCardLayout.labelSectionHeight(compact: compact, hasSubtitle: hasSubtitle)
    }

    private var cardHeight: CGFloat {
        SignsWordCardLayout.cardHeight(compact: compact, hasSubtitle: hasSubtitle)
    }

    private var horizontalPadding: CGFloat {
        compact ? SignsWordCardLayout.compactHorizontalPadding : SignsWordCardLayout.standardHorizontalPadding
    }

    private var verticalPadding: CGFloat {
        compact ? SignsWordCardLayout.compactVerticalPadding : SignsWordCardLayout.standardVerticalPadding
    }

    var body: some View {
        VStack(spacing: 0) {
            thumbnailStage

            labelSection
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
        .background(Brand.chrome)
        .clipShape(RoundedRectangle(cornerRadius: SignsWordCardLayout.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SignsWordCardLayout.cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .elevation(.insetField)
        .contentShape(RoundedRectangle(cornerRadius: SignsWordCardLayout.cornerRadius, style: .continuous))
        .onAppear { store.mergeDictionaryVisiblePriority(wordId: wordId) }
        .onTapGesture(perform: openSign)
    }

    private var thumbnailStage: some View {
        ZStack(alignment: .topTrailing) {
            SignPosterSurface(wordId: wordId, store: store)

            Button {
                toggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.asl(24, weight: .semibold))
                    .foregroundStyle(isFavorite ? SignsTheme.accent : Color.white.opacity(0.72))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.plain)
            .padding(3)
        }
        .frame(maxWidth: .infinity, minHeight: thumbnailHeight, maxHeight: thumbnailHeight)
        .clipped()
    }

    private var labelSection: some View {
        VStack(spacing: compact ? 6 : 2) {
            Text(SignEquivalence.dictionaryTitle(
                for: wordId,
                fallback: ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId)
            ))
                .aslStyle(.cardTitle, variant: compact ? .compact : .standard)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: compact ? SignsWordCardLayout.compactTitleLineHeight : SignsWordCardLayout.standardTitleLineHeight, maxHeight: compact ? SignsWordCardLayout.compactTitleLineHeight : SignsWordCardLayout.standardTitleLineHeight)

            if let categorySubtitle {
                Text(categorySubtitle)
                    .aslStyle(.progressLabel, variant: .standard)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: SignsWordCardLayout.subtitleLineHeight, maxHeight: SignsWordCardLayout.subtitleLineHeight)
                    .padding(.leading, compact ? 4 : 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: labelContentHeight, maxHeight: labelContentHeight, alignment: hasSubtitle ? .top : .center)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: labelSectionHeight, maxHeight: labelSectionHeight)
        .background(Brand.chrome)
    }
}

private struct SignPosterSurface: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore

    var body: some View {
        PosterImageView(wordId: wordId, store: store)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SignVideoSurface: View {
    let wordId: String
    let neighborWordIds: [String]
    @ObservedObject var store: ASLDataStore
    var cornerRadius: CGFloat
    var videoGravity: AVLayerVideoGravity
    /// Fixed height for dictionary detail sheet stage cards.
    var stageHeight: CGFloat = 340
    /// Shows the shared replay + green turtle controls (primary "sign area"
    /// surfaces only, e.g. the detail sheet — not dense grid thumbnails).
    var showsControls: Bool = false

    @State private var controller: LessonPlayerController?
    @State private var showLoadError = false
    @State private var retryToken = 0

    var body: some View {
        Group {
            if ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store) {
                SignFilmPlaceholder(
                    title: ASLPendingFilmCatalog.title(for: wordId, store: store),
                    height: showsControls ? stageHeight : nil,
                    cornerRadius: cornerRadius,
                    style: .stage
                )
                .elevation(showsControls ? .insetField : .none)
            } else if missingBundledVideo {
                dictionaryLoadFailure
            } else if showsControls, let controller {
                dictionaryDetailStage(controller: controller)
            } else if let controller {
                SignVideoSurfaceBody(
                    wordId: wordId,
                    store: store,
                    controller: controller,
                    cornerRadius: cornerRadius,
                    videoGravity: videoGravity,
                    showsControls: showsControls,
                    showLoadError: $showLoadError,
                    onRetry: retryDictionaryVideo
                )
            } else {
                dictionaryDetailLoadingPoster
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: showsControls ? stageHeight : nil)
        .task(id: "\(wordId)-\(retryToken)") {
            await borrowController()
        }
    }

    @ViewBuilder
    private func dictionaryDetailStage(controller: LessonPlayerController) -> some View {
        LessonVideoStage(
            controller: controller,
            wordId: wordId,
            store: store,
            height: stageHeight,
            cornerRadius: cornerRadius,
            showsControls: true
        )
        .overlay {
            if !controller.isPlaybackReady {
                SignDetailPosterSurface(
                    wordId: wordId,
                    store: store,
                    cornerRadius: SignVideoCardMetrics.innerCornerRadius
                )
                .padding(SignVideoCardMetrics.innerPadding)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                        style: .continuous
                    )
                )
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .overlay {
            if showLoadError && !controller.isPlaybackReady {
                SignVideoLoadFailureView(cornerRadius: cornerRadius, onRetry: retryDictionaryVideo)
            }
        }
        .animation(.easeOut(duration: 0.15), value: controller.isPlaybackReady)
        .onChange(of: controller.isPlaybackReady) { _, ready in
            if ready { showLoadError = false }
        }
        .onChange(of: controller.playbackFailed) { _, failed in
            if failed { showLoadError = true }
        }
    }

    private var dictionaryDetailLoadingPoster: some View {
        SignDetailPosterSurface(
            wordId: wordId,
            store: store,
            cornerRadius: SignVideoCardMetrics.innerCornerRadius
        )
        .padding(SignVideoCardMetrics.innerPadding)
        .frame(maxWidth: .infinity)
        .frame(height: stageHeight)
        .background(Brand.homeBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Brand.divider.opacity(0.95), lineWidth: SignVideoCardMetrics.borderWidth)
        }
        .elevation(.insetField)
    }

    private func retryDictionaryVideo() {
        Haptics.tap()
        showLoadError = false
        retryToken += 1
    }

    private var missingBundledVideo: Bool {
        FilmedSignCatalog.isFilmed(wordId: wordId) && !BundledSignMedia.hasBundledVideo(for: wordId)
    }

    private var dictionaryLoadFailure: some View {
        SignVideoLoadFailureView(cornerRadius: cornerRadius, onRetry: retryDictionaryVideo)
    }

    private func borrowController() async {
        guard !ASLPendingFilmCatalog.shouldShowMissingMedia(for: wordId, store: store) else { return }
        showLoadError = false

        let borrowed = await store.borrowDictionaryController(
            for: wordId,
            neighborWordIds: neighborWordIds
        )
        controller = borrowed

        if borrowed.isPlaybackReady {
            return
        }

        await borrowed.awaitPlaybackReady(timeout: 2)
        if borrowed.playbackFailed || !borrowed.isPlaybackReady {
            showLoadError = true
        }
    }
}

private struct SignVideoSurfaceBody: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore
    @ObservedObject var controller: LessonPlayerController
    var cornerRadius: CGFloat
    var videoGravity: AVLayerVideoGravity
    var showsControls: Bool
    @Binding var showLoadError: Bool
    var onRetry: () -> Void

    var body: some View {
        Group {
            if showsControls {
                detailPlaybackStack
            } else {
                gridPlaybackStack
            }
        }
        .onChange(of: controller.isPlaybackReady) { _, ready in
            if ready { showLoadError = false }
        }
        .onChange(of: controller.playbackFailed) { _, failed in
            if failed { showLoadError = true }
        }
    }

    private var detailPlaybackStack: some View {
        ZStack {
            SignDetailPosterSurface(
                wordId: wordId,
                store: store,
                cornerRadius: SignVideoCardMetrics.innerCornerRadius
            )
            .opacity(controller.isPlaybackReady ? 0 : 1)
            .animation(.easeOut(duration: 0.15), value: controller.isPlaybackReady)

            LessonVideoPlayer(
                controller: controller,
                cornerRadius: SignVideoCardMetrics.innerCornerRadius,
                videoGravity: videoGravity
            )

            if showLoadError && !controller.isPlaybackReady {
                SignVideoLoadFailureView(cornerRadius: cornerRadius, onRetry: onRetry)
            }
        }
        .padding(SignVideoCardMetrics.innerPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.homeBackground)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Brand.divider.opacity(0.95), lineWidth: SignVideoCardMetrics.borderWidth)
        }
        .elevation(.insetField)
        .overlay { SignVideoControlsOverlay(controller: controller) }
    }

    private var gridPlaybackStack: some View {
        ZStack {
            LessonVideoPlayer(
                controller: controller,
                cornerRadius: cornerRadius,
                videoGravity: videoGravity
            )
            if !controller.isPlaybackReady {
                ProgressView()
                    .tint(SignsTheme.accent)
            }
        }
    }
}

private struct SignVideoLoadFailureView: View {
    var cornerRadius: CGFloat
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.asl(32, weight: .semibold))
                .foregroundStyle(Brand.secondaryLabel)
            Text("Couldn't load sign video")
                .font(.asl(15, weight: .semibold))
                .foregroundStyle(Brand.textPrimary)
            Button(action: onRetry) {
                Text("Retry")
                    .font(.asl(14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(SignsTheme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Brand.homeBackground.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct SignDetailPosterSurface: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore
    var cornerRadius: CGFloat

    @ObservedObject private var loader = PosterImageLoader.shared

    var body: some View {
        let _ = store.mediaCacheRevision
        let _ = loader.revision
        let detailURL = store.detailPosterDisplayURL(for: wordId)

        ZStack {
            if let bundledURL = BundledSignMedia.posterURL(for: wordId),
               let image = UIImage(contentsOfFile: bundledURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let localURL = store.localPosterURL(for: wordId),
               let image = UIImage(contentsOfFile: localURL.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let detailURL,
                      let image = loader.image(for: wordId, url: detailURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let gridURL = store.posterDisplayURL(for: wordId),
                      let image = loader.image(for: wordId, url: gridURL) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(Brand.homeBackground)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            store.prepareDictionaryDetailPoster(wordId: wordId)
            guard let detailURL else { return }
            guard store.localPosterURL(for: wordId) != nil else {
                guard loader.image(for: wordId, url: detailURL) == nil else { return }
                guard !loader.isLoading(wordId: wordId, url: detailURL) else { return }
                loader.load(wordId: wordId, url: detailURL)
                return
            }
        }
    }
}

private struct SignDetailSheet: View {
    let initialWordId: String
    let wordIds: [String]
    @ObservedObject var store: ASLDataStore
    let favoriteWordIds: Set<String>
    let toggleFavorite: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("asl.favoriteSigns.v1") private var favoriteWordIdsData = "[]"
    @State private var currentIndex: Int
    @State private var showYourTurnPractice = false

    init(initialWordId: String,
         wordIds: [String],
         store: ASLDataStore,
         favoriteWordIds: Set<String>,
         toggleFavorite: @escaping (String) -> Void) {
        self.initialWordId = initialWordId
        self.wordIds = wordIds
        self.store = store
        self.favoriteWordIds = favoriteWordIds
        self.toggleFavorite = toggleFavorite
        _currentIndex = State(initialValue: wordIds.firstIndex(of: initialWordId) ?? 0)
    }

    private var currentWordId: String {
        guard wordIds.indices.contains(currentIndex) else { return initialWordId }
        return wordIds[currentIndex]
    }

    private var currentTitle: String {
        SignEquivalence.dictionaryTitle(
            for: currentWordId,
            fallback: ASLWordDisplay.title(for: store.wordsById[currentWordId]?.text ?? currentWordId)
        )
    }

    private var groupedSignNote: String? {
        guard SignEquivalence.groupedDisplayTitle(for: currentWordId) != nil else { return nil }
        return "These English words share one ASL sign."
    }

    private var isFavorite: Bool {
        decodeFavoriteWordIds().contains(currentWordId)
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Text(currentTitle)
                    .aslStyle(.cardTitle, variant: .prominent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
            .overlay(alignment: .trailing) {
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.asl(18, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel.opacity(0.55))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)

            SignVideoSurface(
                wordId: currentWordId,
                neighborWordIds: wordIds,
                store: store,
                cornerRadius: SignVideoCardMetrics.cornerRadius,
                videoGravity: .resizeAspectFill,
                stageHeight: 340,
                showsControls: true
            )

            if let groupedSignNote {
                Text(groupedSignNote)
                    .font(LessonQuestionLayout.microcopyFont)
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 40) {
                Button {
                    move(by: -1)
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.asl(28, weight: .semibold))
                        .foregroundStyle(wordIds.count > 1 ? Brand.textPrimary.opacity(0.85) : Brand.secondaryLabel.opacity(0.18))
                        .frame(width: 58, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(wordIds.count <= 1)

                Button {
                    move(by: 1)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.asl(28, weight: .semibold))
                        .foregroundStyle(wordIds.count > 1 ? Brand.textPrimary.opacity(0.85) : Brand.secondaryLabel.opacity(0.18))
                        .frame(width: 58, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(wordIds.count <= 1)
            }

            HStack {
                Button {
                    Haptics.tap()
                    showYourTurnPractice = true
                } label: {
                    SheetActionLabel(
                        systemImage: "rectangle.2.swap",
                        title: "Practice",
                        isActive: true
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    toggleFavorite(currentWordId)
                } label: {
                    SheetActionLabel(
                        systemImage: isFavorite ? "heart.fill" : "heart",
                        title: isFavorite ? "Saved" : "Save",
                        isActive: isFavorite
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 38)
            .padding(.bottom, 20)
        }
        .padding(.horizontal, 24)
        .brandCanvasBackground()
        .fullScreenCover(isPresented: $showYourTurnPractice) {
            SignYourTurnPracticeView(
                store: store,
                wordId: currentWordId,
                onDismiss: { showYourTurnPractice = false }
            )
        }
        .task(id: currentWordId) {
            await store.loadWordsAwait(wordIds: wordIds)
            store.recordSignStudied(wordId: currentWordId)
            store.warmDictionaryVideo(wordId: currentWordId, neighborWordIds: wordIds)
        }
        .onDisappear {
            store.clearDictionaryVideoProtection()
        }
    }

    private func move(by offset: Int) {
        guard wordIds.count > 1 else { return }
        Haptics.tap()
        let next = (currentIndex + offset + wordIds.count) % wordIds.count
        let nextWordId = wordIds[next]
        store.warmDictionaryVideo(wordId: nextWordId, neighborWordIds: wordIds)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            currentIndex = next
        }
    }

    private func decodeFavoriteWordIds() -> Set<String> {
        guard let data = favoriteWordIdsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return Set(decoded)
    }
}

private struct SheetActionLabel: View {
    let systemImage: String
    let title: String
    let isActive: Bool

    var body: some View {
        VStack(spacing: 7) {
            ASLIcon(
                source: .symbol(systemImage),
                role: .feature,
                tint: isActive ? SignsTheme.accent : Brand.secondaryLabel.opacity(0.45),
                isEmphasis: isActive
            )

            Text(title)
                .aslFont(.tabBar, variant: .prominent)
                .foregroundStyle(isActive ? SignsTheme.accent : Brand.secondaryLabel.opacity(0.55))
        }
        .frame(width: 76)
    }
}

private struct DictionaryEmptyState: View {
    var systemImage: String? = nil
    var mascotImageName: String? = nil
    var mascotSize: CGFloat = UnitMascot.emptyStateMascotSize
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            if let mascotImageName {
                Image(mascotImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: mascotSize, height: mascotSize)
                    .offset(y: 2)
                    .accessibilityHidden(true)
            } else if let systemImage {
                ASLIcon(
                    source: .symbol(systemImage),
                    role: .feature,
                    tint: SignsTheme.accent.opacity(0.82)
                )
            }

            Text(title)
                .aslStyle(.cardTitle, variant: .standard)

            Text(message)
                .aslStyle(.cardDescription, variant: .compact)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum SignsTheme {
    static let accent = Brand.primary
}

/// Re-enables the system edge-swipe back gesture when the default back button is hidden.
private struct NavigationSwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            guard let navigationController = uiViewController.navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController = gestureRecognizer.view?.nearestNavigationController else {
                return false
            }
            return navigationController.viewControllers.count > 1
        }
    }
}

private extension UIView {
    var nearestNavigationController: UINavigationController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let navigationController = current as? UINavigationController {
                return navigationController
            }
            responder = current.next
        }
        return nil
    }
}
