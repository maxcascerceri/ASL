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
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
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
            .filter { ASLWordDisplay.title(for: $0).lowercased().hasPrefix(query) }
            .sorted {
                ASLWordDisplay.title(for: $0).localizedCaseInsensitiveCompare(
                    ASLWordDisplay.title(for: $1)
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
                                                selectSign: { wordId, wordIds in
                                                    selectedSign = SignDetailSelection(wordId: wordId, wordIds: wordIds)
                                                }
                                            )
                                            .task(id: visibleDictionaryWordIds) {
                                                store.loadWords(wordIds: visibleDictionaryWordIds)
                                            }
                                        }
                                    } else {
                                        LazyVGrid(columns: columns, spacing: 14) {
                                            ForEach(SignCategory.all) { category in
                                                Button {
                                                    Keyboard.dismiss()
                                                    Haptics.tap()
                                                    categoryTapPulseId = category.id
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
                                            mascotSize: 240,
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
                                            selectSign: { wordId, wordIds in
                                                selectedSign = SignDetailSelection(wordId: wordId, wordIds: wordIds)
                                            }
                                        )
                                        .task(id: visibleFavoriteWordIds) {
                                            store.loadWords(wordIds: visibleFavoriteWordIds)
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
                        selectSign: { wordId, wordIds in
                            selectedSign = SignDetailSelection(wordId: wordId, wordIds: wordIds)
                        }
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
        }
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
    let palette: CategoryPalette
    let words: [String]

    init(
        id: String,
        title: String,
        systemImage: String,
        iconAssetName: String? = nil,
        palette: CategoryPalette,
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

    /// Category label for search results (first category that lists this sign).
    static func primaryCategoryTitle(forWordId wordId: String) -> String? {
        category(containingWordId: wordId)?.title
    }

    static func category(containingWordId wordId: String) -> SignCategory? {
        all.first { $0.words.contains(wordId) }
    }

    static let all: [SignCategory] = [
        SignCategory(id: "greetings", title: "Getting Started", systemImage: "hand.wave.fill", palette: .brand, words: ["hello", "bye", "please", "thankyou", "sorry", "welcome", "name", "congratulations", "oops", "nice", "meet", "introduce", "sign", "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow", "imsorry", "yourewelcome"]),
        SignCategory(id: "responses", title: "Quick Responses", systemImage: "bubble.left.fill", palette: .mint, words: ["yes", "no", "sure", "wow", "really", "alright", "ok", "again", "wait", "nevermind", "maybe", "dontknow", "notyet", "signagain", "excuseme", "seeyoulater", "samehere", "havegoodday"]),
        SignCategory(id: "pronouns", title: "Pronouns", systemImage: "person.2.fill", palette: .lavender, words: ["i", "me", "you", "we", "us", "our", "my", "your", "his", "mine", "he", "they"]),
        SignCategory(id: "questions", title: "Ask & Answer", systemImage: "questionmark", palette: .peach, words: ["what", "where", "when", "who", "why", "how", "which", "whatisyourname", "whatsthat", "whatdoesthatmean"]),
        SignCategory(id: "people-words", title: "People Words", systemImage: "person.text.rectangle.fill", palette: .butter, words: ["person", "people", "myself", "yourself", "sign", "introduce"]),
        SignCategory(id: "mood-basics", title: "Check-ins", systemImage: "face.smiling.fill", palette: .aqua, words: ["good", "bad", "fine", "great", "happy", "sad", "tired", "angry", "scared", "excited", "worry", "imgood", "goodmorning", "goodnight"]),

        SignCategory(id: "deaf-culture", title: "Deaf Culture", systemImage: "hands.clap.fill", palette: .mint, words: ["deaf", "hearing", "hardofhearing", "community", "culture", "identity", "pride", "history", "iamdeaf", "iamhearing", "imlearningasl", "signlanguage"]),
        SignCategory(id: "accessibility", title: "Accessibility", systemImage: "captions.bubble.fill", palette: .sky, words: ["interpreter", "caption", "hearingaid", "lipread", "gesture", "translate"]),
        SignCategory(id: "alphabet", title: "Alphabet", systemImage: "a.circle.fill", palette: .lavender, words: ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]),
        SignCategory(id: "fingerspelling", title: "Fingerspelling", systemImage: "hand.point.up.left.fill", palette: .peach, words: ["alphabet", "fingerspell", "letter", "language", "word", "name"]),
        SignCategory(id: "numbers", title: "Numbers", systemImage: "number", palette: .aqua, words: ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]),
        SignCategory(id: "money", title: "Money", systemImage: "dollarsign.circle.fill", palette: .butter, words: ["money", "pay", "cost", "price", "1dollar", "5dollars"]),
        SignCategory(id: "amounts-math", title: "Amounts & Math", systemImage: "percent", palette: .mint, words: ["half", "quarter", "percent", "double", "triple", "hundred", "many", "few", "enough", "more", "less", "very", "almost", "really"]),
        SignCategory(id: "sentence-helpers", title: "Sentence Helpers", systemImage: "link", palette: .sky, words: ["and", "but", "or", "so", "then", "with", "without", "also", "because", "same", "different", "if"]),

        SignCategory(id: "family", title: "Family", systemImage: "figure.2.and.child.holdinghands", palette: .peach, words: ["mother", "father", "sister", "brother", "baby", "child", "family", "parents", "grandmother", "grandfather", "aunt", "uncle", "cousin", "niece", "nephew", "twins"]),
        SignCategory(id: "people", title: "People", systemImage: "person.fill", palette: .lavender, words: ["man", "woman", "boy", "girl", "adult", "teenager"]),
        SignCategory(id: "movement", title: "Movement", systemImage: "figure.walk", palette: .aqua, words: ["go", "come", "walk", "run", "stop", "turn", "move", "leave"]),
        SignCategory(id: "body-actions", title: "Body Actions", systemImage: "figure.arms.open", palette: .mint, words: ["eat", "drink", "sleep", "see", "hear", "feel", "breathe", "smell"]),
        SignCategory(id: "communication", title: "Communication", systemImage: "message.fill", palette: .sky, words: ["tell", "ask", "talk", "think", "know", "understand", "believe", "need", "help", "idontunderstand", "ineedhelp", "canyouhelpme"]),
        SignCategory(id: "doing-helping", title: "Doing & Helping", systemImage: "bolt.fill", palette: .butter, words: ["make", "get", "give", "take", "use", "find", "want", "help"]),

        SignCategory(id: "colors", title: "Colors", systemImage: "paintbrush.fill", palette: .mint, words: ["red", "blue", "green", "yellow", "orange", "purple", "pink", "brown", "black", "white", "gray", "gold", "silver", "bright"]),
        SignCategory(id: "descriptions", title: "Descriptions", systemImage: "slider.horizontal.3", palette: .peach, words: ["dark", "light", "bright", "big", "small", "tall", "fast", "slow", "hard", "hot"]),
        SignCategory(id: "temperature", title: "Temperature", systemImage: "thermometer.medium", palette: .lavender, words: ["hot", "cold"]),
        SignCategory(id: "home", title: "Home", systemImage: "house.fill", palette: .sky, words: ["home", "house", "kitchen", "bathroom", "bedroom", "livingroom", "basement", "backyard", "wherebathroom", "garage"]),
        SignCategory(id: "furniture", title: "Furniture", systemImage: "chair.fill", palette: .butter, words: ["table", "chair", "bed", "couch", "door", "window", "lamp", "clock"]),
        SignCategory(id: "hygiene", title: "Hygiene", systemImage: "shower.fill", palette: .aqua, words: ["shower", "toilet", "sink", "soap", "toothbrush", "brush", "comb", "mirror"]),
        SignCategory(id: "chores", title: "Chores", systemImage: "sparkles", palette: .mint, words: ["clean", "wash", "cook", "sweep", "vacuum", "washdishes"]),

        SignCategory(id: "mealtime", title: "Mealtime", systemImage: "fork.knife", palette: .peach, words: ["breakfast", "lunch", "dinner", "hungry", "full", "delicious"]),
        SignCategory(id: "fruit", title: "Fruit", systemImage: "apple.logo", palette: .sky, words: ["apple", "banana", "grapes", "strawberry", "cherry", "pineapple", "lemon", "orange"]),
        SignCategory(id: "vegetables", title: "Vegetables", systemImage: "carrot.fill", palette: .mint, words: ["tomato", "carrot", "corn", "onion", "potato", "lettuce"]),
        SignCategory(id: "protein-dairy", title: "Protein & Dairy", systemImage: "takeoutbag.and.cup.and.straw.fill", palette: .butter, words: ["meat", "fish", "egg", "cheese", "milk", "butter", "bacon", "chicken"]),
        SignCategory(id: "snacks", title: "Snacks", systemImage: "birthday.cake.fill", palette: .lavender, words: ["bread", "pizza", "cake", "chocolate"]),
        SignCategory(id: "drinks", title: "Drinks", systemImage: "cup.and.saucer.fill", palette: .aqua, words: ["water", "coffee", "tea", "juice"]),

        SignCategory(id: "weekdays", title: "Weekdays", systemImage: "calendar", palette: .mint, words: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "weekend"]),
        SignCategory(id: "time-of-day", title: "Time of Day", systemImage: "sun.max.fill", palette: .sky, words: ["morning", "afternoon", "night", "today", "yesterday", "tomorrow", "now", "noon", "later", "early"]),
        SignCategory(id: "time-units", title: "Time Units", systemImage: "clock.fill", palette: .peach, words: ["day", "week", "month", "year", "hour", "minute", "weekend", "holiday"]),
        SignCategory(id: "head-face", title: "Head & Face", systemImage: "face.smiling", palette: .lavender, words: ["head", "face", "eyes", "ear", "nose", "mouth", "teeth", "tongue"]),
        SignCategory(id: "body", title: "Body", systemImage: "figure.arms.open", palette: .aqua, words: ["body", "arm", "hands", "finger", "shoulder", "neck", "back", "stomach"]),
        SignCategory(id: "symptoms", title: "Symptoms", systemImage: "bandage.fill", palette: .butter, words: ["sick", "hurt", "pain", "headache", "cough", "sneeze", "tired", "dizzy"]),
        SignCategory(id: "health", title: "Health", systemImage: "cross.case.fill", palette: .mint, words: ["health", "exercise", "doctor", "nurse", "hospital", "medicine"]),

        SignCategory(id: "personality", title: "Personality", systemImage: "person.crop.circle.fill", palette: .sky, words: ["confident", "humble", "lazy", "stubborn", "curious", "serious", "remember", "forget"]),
        SignCategory(id: "big-feelings", title: "Big Feelings", systemImage: "heart.fill", palette: .peach, words: ["bored", "lonely", "jealous", "embarrass", "frustrate", "surprise"]),
        SignCategory(id: "relationships", title: "Relationships", systemImage: "heart.circle.fill", palette: .lavender, words: ["love", "like", "hate", "friend", "hug", "kiss"]),
        SignCategory(id: "clothing", title: "Clothing", systemImage: "tshirt.fill", palette: .mint, words: ["shirt", "pants", "dress", "shoes", "socks", "jacket", "hat", "clothes", "shorts", "skirt", "sweater", "boots", "gloves", "scarf", "belt", "suit"]),
        SignCategory(id: "accessories", title: "Accessories", systemImage: "backpack.fill", palette: .butter, words: ["glasses", "earring", "necklace", "bracelet", "ring", "backpack", "wallet", "watch"]),

        SignCategory(id: "transportation", title: "Transportation", systemImage: "car.fill", palette: .sky, words: ["car", "bus", "train", "airplane", "bike", "truck", "motorcycle", "boat"]),
        SignCategory(id: "directions", title: "Directions", systemImage: "location.north.line.fill", palette: .aqua, words: ["here", "there", "left", "right", "up", "down", "near", "far"]),
        SignCategory(id: "places", title: "Places", systemImage: "mappin.and.ellipse", palette: .peach, words: ["shop", "park", "restaurant", "hotel", "library", "church"]),
        SignCategory(id: "commute", title: "Commute", systemImage: "road.lanes", palette: .lavender, words: ["drive", "ride", "arrive", "travel", "road", "street", "traffic", "commute"]),
        SignCategory(id: "school", title: "School", systemImage: "book.fill", palette: .mint, words: ["school", "class", "student", "teacher", "learn", "study", "read", "write", "math", "science", "history", "art", "book", "pen", "paper", "music"]),
        SignCategory(id: "work", title: "Work", systemImage: "briefcase.fill", palette: .butter, words: ["work", "job", "boss", "lawyer", "engineer", "scientist", "meeting", "retire"]),

        SignCategory(id: "pets-farm", title: "Pets & Farm", systemImage: "pawprint.fill", palette: .peach, words: ["dog", "cat", "horse", "cow", "pig", "sheep", "rabbit", "duck"]),
        SignCategory(id: "wild-animals", title: "Wild Animals", systemImage: "hare.fill", palette: .sky, words: ["lion", "tiger", "elephant", "bear", "wolf", "fox", "eagle", "monkey"]),
        SignCategory(id: "nature", title: "Nature", systemImage: "leaf.fill", palette: .mint, words: ["tree", "flower", "mountain", "river", "ocean", "beach", "sun", "moon"]),
        SignCategory(id: "weather", title: "Weather", systemImage: "cloud.sun.fill", palette: .aqua, words: ["rain", "snow", "wind", "cloud", "lightning", "thunder"]),
        SignCategory(id: "seasons", title: "Seasons", systemImage: "tree.fill", palette: .butter, words: ["spring", "summer", "fall", "winter"]),
        SignCategory(id: "sports", title: "Sports", systemImage: "sportscourt.fill", palette: .lavender, words: ["football", "basketball", "baseball", "soccer", "volleyball", "hockey", "tennis", "golf"]),
        SignCategory(id: "arts-hobbies", title: "Arts & Hobbies", systemImage: "music.note", palette: .peach, words: ["draw", "paint", "sing", "dance", "music", "guitar", "piano", "nicetoseeyou"]),

        SignCategory(id: "holidays", title: "Holidays", systemImage: "party.popper.fill", palette: .mint, words: ["party", "birthday", "christmas", "halloween", "thanksgiving", "easter"]),
        SignCategory(id: "countries", title: "Countries", systemImage: "globe.americas.fill", palette: .sky, words: ["america", "canada", "mexican", "france", "germany", "china", "japan", "italy"]),
        SignCategory(id: "tech", title: "Tech", systemImage: "desktopcomputer", palette: .lavender, words: ["computer", "phone", "tablet", "laptop", "camera", "tv", "keyboard", "mouse"]),
        SignCategory(id: "online-media", title: "Online & Media", systemImage: "wifi", palette: .aqua, words: ["internet", "email", "text", "download", "upload", "share", "send", "video"]),
        SignCategory(id: "big-ideas", title: "Big Ideas", systemImage: "lightbulb.fill", palette: .butter, words: ["can", "cannot", "maybe", "important", "right", "wrong", "future", "always"]),
        SignCategory(id: "asl-phrases", title: "ASL Phrases", systemImage: "quote.bubble.fill", palette: .peach, words: [
            "mynameis", "nicetomeetyou", "howareyou", "imfine", "signslow", "imsorry", "yourewelcome",
            "dontknow", "notyet", "signagain", "excuseme", "seeyoulater", "samehere", "havegoodday",
            "whatisyourname", "whatsthat", "whatdoesthatmean", "imgood", "goodmorning", "goodnight",
            "idontunderstand", "ineedhelp", "canyouhelpme", "iamdeaf", "iamhearing", "imlearningasl",
            "wherebathroom", "nicetoseeyou", "letmesee", "howyousignthat", "onemoretime", "talktoyoulater",
            "blowmind", "allofsudden", "wrapup", "letgo"
        ])
    ]
}

private struct CategoryPalette {
    let unitPalette: UnitPalette

    var fill: Color { unitPalette.color }
    var depth: Color { unitPalette.shadow }

    static let brand = CategoryPalette(unitPalette: UnitPalette.palette(for: 0))
    static let mint = CategoryPalette(unitPalette: UnitPalette.palette(for: 1))
    static let sky = CategoryPalette(unitPalette: UnitPalette.palette(for: 2))
    static let aqua = CategoryPalette(unitPalette: UnitPalette.palette(for: 2))
    static let peach = CategoryPalette(unitPalette: UnitPalette.palette(for: 3))
    static let lavender = CategoryPalette(unitPalette: UnitPalette.palette(for: 4))
    static let butter = CategoryPalette(unitPalette: UnitPalette.palette(for: 5))
}

private struct DictionarySearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .aslIconStyle(role: .navigation, tint: Brand.primary)

            TextField("Search signs", text: $text)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                        .font(.system(size: 16, weight: .bold))
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

    private let depth: CGFloat = 5

    var body: some View {
        ZStack(alignment: .top) {
            Capsule(style: .continuous)
                .fill(Brand.primaryShadow.opacity(0.35))
                .frame(height: 52)
                .offset(y: depth)

            Capsule(style: .continuous)
                .fill(Brand.cream)
                .frame(height: 52)
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
                            isSelected: selectedSection == section
                        )
                    }
                    .buttonStyle(SignsRaisedPressStyle())
                }
            }
            .padding(4)
        }
        .frame(height: 52 + depth, alignment: .top)
    }
}

private struct SignsSectionTabLabel: View {
    let title: String
    let isSelected: Bool
    @Environment(\.signsRaisedPressed) private var isPressed

    private let depth: CGFloat = 4

    var body: some View {
        ZStack(alignment: .top) {
            if isSelected {
                Capsule(style: .continuous)
                    .fill(Brand.primaryShadow)
                    .frame(height: 44)
                    .offset(y: isPressed ? 1.5 : depth)

                Capsule(style: .continuous)
                    .fill(Brand.primary)
                    .frame(height: 44)
                    .offset(y: isPressed ? depth - 1.5 : 0)
            }

            Text(title)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(isSelected ? Color.white : Brand.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .offset(y: isSelected ? (isPressed ? depth - 1.5 : 0) : 0)
        }
        .frame(height: isSelected ? 44 + depth : 44, alignment: .top)
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
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(category.palette.depth)
                .offset(y: isVisuallyPressed ? 2 : 7)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(category.palette.fill)
                .offset(y: isVisuallyPressed ? 5 : 0)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)

                        Text("\(category.words.count) signs")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }

            categoryIcon
                .frame(width: 38, height: 38)
                .padding(.top, 10)
                .padding(.trailing, 10)
                .offset(y: isVisuallyPressed ? 5 : 0)
        }
        .frame(height: 104)
        .elevation(.chapterCard(tint: category.palette.depth))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .scaleEffect(isVisuallyPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.68), value: isVisuallyPressed)
    }

    @ViewBuilder
    private var categoryIcon: some View {
        if let asset = category.iconAssetName {
            ZStack {
                Circle()
                    .fill(Color.white)

                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 30, height: 30)
            }
            .frame(width: 38, height: 38)
        } else {
            ZStack {
                Circle()
                    .fill(Color.white)

                ASLIcon(
                    source: .symbol(category.systemImage),
                    role: .badgeDisc,
                    tint: category.palette.fill
                )
                .scaleEffect(1.28)
            }
            .frame(width: 38, height: 38)
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
                .font(.system(size: 18, weight: .bold))
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
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool

    private var visibleWordIds: [String] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return category.words
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return category.words.filter { ASLWordDisplay.title(for: $0).lowercased().hasPrefix(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                SignCategoryHeroCard(category: category) {
                    Haptics.tap()
                    dismiss()
                }

                DictionarySearchField(text: $searchText, isFocused: $isSearchFieldFocused)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(Brand.canvas)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if visibleWordIds.isEmpty {
                        DictionaryEmptyState(
                            systemImage: "magnifyingglass",
                            title: "No Signs Found",
                            message: "Try searching this category for another sign."
                        )
                        .padding(.top, 40)
                    } else {
                        SignGridView(
                            wordIds: visibleWordIds,
                            store: store,
                            favoriteWordIds: favoriteWordIds,
                            compact: true,
                            toggleFavorite: toggleFavorite,
                            selectSign: selectSign
                        )
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .brandCanvasBackground()
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            Keyboard.dismiss()
        })
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: category.id) {
            store.loadWords(wordIds: category.words)
        }
    }
}

private struct SignCategoryHeroCard: View {
    let category: SignCategory
    let onBack: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(category.palette.depth)
                .offset(y: 8)

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(category.palette.fill)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.title)
                            .font(.system(size: 31, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(category.words.count) signs")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(20)
                }

            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 64, height: 64)

                ASLIcon(
                    source: .symbol(category.systemImage),
                    role: .badgeDisc,
                    tint: category.palette.fill
                )
                .scaleEffect(1.55)
            }
            .frame(width: 64, height: 64)
            .padding(24)
        }
        .elevation(.chapterCard(tint: category.palette.depth))
        .overlay(alignment: .topLeading) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .heavy))
                    .foregroundStyle(Color.primary.opacity(0.62))
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
}

private struct SignGridView: View {
    let wordIds: [String]
    @ObservedObject var store: ASLDataStore
    let favoriteWordIds: Set<String>
    var categoryTitleForWordId: ((String) -> String?)? = nil
    var compact: Bool = false
    let toggleFavorite: (String) -> Void
    let selectSign: (String, [String]) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(wordIds, id: \.self) { wordId in
                SignWordCard(
                    wordId: wordId,
                    store: store,
                    categorySubtitle: categoryTitleForWordId?(wordId),
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
            }
        }
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

    private var thumbnailHeight: CGFloat { compact ? 112 : 128 }
    private var labelMinHeight: CGFloat {
        if compact { return categorySubtitle == nil ? 56 : 62 }
        return categorySubtitle == nil ? 66 : 72
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                SignThumbnailSurface(wordId: wordId, store: store)
                    .frame(height: thumbnailHeight)
                    .clipped()

                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(isFavorite ? SignsTheme.accent : Color.white.opacity(0.72))
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.plain)
                .padding(3)
            }

            VStack(alignment: .leading, spacing: compact ? 6 : 2) {
                if compact {
                    Text(ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId))
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Brand.cream.opacity(0.95))
                        )
                } else {
                    Text(ASLWordDisplay.title(for: store.wordsById[wordId]?.text ?? wordId))
                        .font(.system(size: 21, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if let categorySubtitle {
                    Text(categorySubtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(.leading, compact ? 4 : 0)
                }
            }
            .frame(maxWidth: .infinity, minHeight: labelMinHeight, alignment: .leading)
            .padding(.horizontal, compact ? 10 : 0)
            .padding(.vertical, compact ? 8 : 0)
            .background(Brand.chrome)
        }
        .background(Brand.chrome)
        .clipShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .elevation(.insetField)
        .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        .onTapGesture(perform: openSign)
        .task(id: wordId) {
            store.loadWords(wordIds: [wordId])
        }
    }
}

private struct SignThumbnailSurface: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore

    @State private var thumbnail: UIImage?
    @State private var thumbnailURL: URL?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.93, green: 0.92, blue: 0.96),
                                Color(red: 0.86, green: 0.94, blue: 0.96)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        ProgressView()
                            .tint(SignsTheme.accent)
                    }
            }
        }
        .onAppear { loadThumbnailIfReady() }
        .onChange(of: store.wordsById[wordId]?.id) { _, _ in loadThumbnailIfReady() }
        .onChange(of: store.videosByWordId[wordId]?.first?.playbackURL) { _, _ in loadThumbnailIfReady() }
    }

    private var playbackURL: URL? {
        store.videosByWordId[wordId]?.first?.playbackURL
    }

    private func loadThumbnailIfReady() {
        if let url = playbackURL {
            generateThumbnail(for: url)
            return
        }

        if let word = store.wordsById[wordId] {
            store.loadVideos(for: word)
        } else {
            store.loadWords(wordIds: [wordId])
        }
    }

    private func generateThumbnail(for url: URL) {
        guard thumbnailURL != url else { return }
        thumbnailURL = url
        thumbnail = nil

        Task {
            let image = await Self.thumbnailImage(for: url)
            guard thumbnailURL == url else { return }
            thumbnail = image
        }
    }

    private static func thumbnailImage(for url: URL) async -> UIImage? {
        await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 420, height: 420)

            do {
                let image = try generator.copyCGImage(at: CMTime(seconds: 0.15, preferredTimescale: 600), actualTime: nil)
                return UIImage(cgImage: image)
            } catch {
                return nil
            }
        }.value
    }
}

private struct SignVideoSurface: View {
    let wordId: String
    @ObservedObject var store: ASLDataStore
    var cornerRadius: CGFloat
    var videoGravity: AVLayerVideoGravity

    @StateObject private var controller = LessonPlayerController()

    var body: some View {
        ZStack {
            if playbackURL != nil {
                LessonVideoPlayer(
                    controller: controller,
                    cornerRadius: cornerRadius,
                    videoGravity: videoGravity
                )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(red: 0.93, green: 0.92, blue: 0.96))
                    .overlay {
                        ProgressView()
                            .tint(SignsTheme.accent)
                    }
            }
        }
        .onAppear { loadIfReady() }
        .onChange(of: store.wordsById[wordId]?.id) { _, _ in loadIfReady() }
        .onChange(of: playbackURL) { _, _ in loadIfReady() }
    }

    private var playbackURL: URL? {
        store.videosByWordId[wordId]?.first?.playbackURL
    }

    private func loadIfReady() {
        if let url = playbackURL {
            controller.load(url)
            controller.playAtNormalSpeed()
            controller.replay()
            return
        }

        if let word = store.wordsById[wordId] {
            store.loadVideos(for: word)
        } else {
            store.loadWords(wordIds: [wordId])
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
        ASLWordDisplay.title(for: store.wordsById[currentWordId]?.text ?? currentWordId)
    }

    private var isFavorite: Bool {
        decodeFavoriteWordIds().contains(currentWordId)
    }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Spacer()
                Text(currentTitle.uppercased())
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
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
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.secondary.opacity(0.55))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)

            SignVideoSurface(
                wordId: currentWordId,
                store: store,
                cornerRadius: 22,
                videoGravity: .resizeAspectFill
            )
            .frame(height: 340)

            HStack(spacing: 40) {
                Button {
                    move(by: -1)
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(wordIds.count > 1 ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.18))
                        .frame(width: 58, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(wordIds.count <= 1)

                Button {
                    move(by: 1)
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(wordIds.count > 1 ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.18))
                        .frame(width: 58, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(wordIds.count <= 1)
            }

            HStack {
                Button {
                    Haptics.tap()
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
        .task(id: currentWordId) {
            store.loadWords(wordIds: [currentWordId])
            store.recordSignStudied(wordId: currentWordId)
        }
    }

    private func move(by offset: Int) {
        guard wordIds.count > 1 else { return }
        Haptics.tap()
        let next = (currentIndex + offset + wordIds.count) % wordIds.count
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
                tint: isActive ? SignsTheme.accent : Color.secondary.opacity(0.45),
                isEmphasis: isActive
            )

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(isActive ? SignsTheme.accent : Color.secondary.opacity(0.55))
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
                    .accessibilityHidden(true)
            } else if let systemImage {
                ASLIcon(
                    source: .symbol(systemImage),
                    role: .feature,
                    tint: SignsTheme.accent.opacity(0.82)
                )
            }

            Text(title)
                .font(.system(size: 22, weight: .heavy, design: .rounded))

            Text(message)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum SignsTheme {
    static let accent = Brand.primary
}
