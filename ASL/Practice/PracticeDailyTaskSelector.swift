//
//  PracticeDailyTaskSelector.swift
//  ASL
//

import Foundation

enum PracticeDailyTaskSelector {
    static func selectTasks(for periodKey: String, store: ASLDataStore) -> [PracticeDailyTaskSpec] {
        let rotationIndex = abs(hash(periodKey))
        let slotA = selectSlotA(rotationIndex: rotationIndex, store: store)
        let slotB = selectSlotB(store: store)
        let slotC = selectSlotC(periodKey: periodKey, store: store, excluding: slotA.kind)
        return [slotA, slotB, slotC]
    }

    private static func selectSlotA(rotationIndex: Int, store: ASLDataStore) -> PracticeDailyTaskSpec {
        let rotation: [PracticeDailyTaskKind] = [
            .quizSession,
            .flashcardsSession,
        ]
        let kind = rotation[rotationIndex % rotation.count]
        return PracticeDailyTaskSpec(slot: 0, kind: kind, params: [:])
    }

    private static func selectSlotB(store: ASLDataStore) -> PracticeDailyTaskSpec {
        let unit = PracticePathContext.currentLearningUnit(from: store)
            ?? PracticePathContext.primaryUnits(from: store).last
        if let unit {
            return PracticeDailyTaskSpec(
                slot: 1,
                kind: .finishUnit,
                params: ["unitId": unit.id, "unitTitle": unit.title]
            )
        }
        return PracticeDailyTaskSpec(slot: 1, kind: .quizSession, params: [:])
    }

    private static func selectSlotC(
        periodKey: String,
        store: ASLDataStore,
        excluding excludedKind: PracticeDailyTaskKind
    ) -> PracticeDailyTaskSpec {
        var candidates: [PracticeDailyTaskSpec] = []

        if excludedKind != .spellYourNameSession,
           PracticeSpellYourNameAvailability.isUnlocked(from: store) {
            candidates.append(PracticeDailyTaskSpec(slot: 2, kind: .spellYourNameSession, params: [:]))
        }

        if excludedKind != .dictionaryCategory {
            let category = SignCategoryCatalog.categoryForDaySeed(periodKey)
            candidates.append(PracticeDailyTaskSpec(
                slot: 2,
                kind: .dictionaryCategory,
                params: ["categoryId": category.id, "categoryTitle": category.title]
            ))
        }

        if excludedKind != .dictionaryFavorites, FavoriteSignsStore.count >= 1 {
            candidates.append(PracticeDailyTaskSpec(slot: 2, kind: .dictionaryFavorites, params: [:]))
        }

        if excludedKind != .quizCorrectCount {
            candidates.append(PracticeDailyTaskSpec(slot: 2, kind: .quizCorrectCount, params: [:]))
        }

        if excludedKind != .weakSignsQuiz {
            let weakIds = store.weakSignWordIdsForPractice(maxCount: 3)
            if weakIds.count >= 3,
               let unit = PracticePathContext.currentLearningUnit(from: store) {
                candidates.append(PracticeDailyTaskSpec(
                    slot: 2,
                    kind: .weakSignsQuiz,
                    params: [
                        "wordIds": weakIds.joined(separator: ","),
                        "unitId": unit.id,
                    ]
                ))
            }
        }

        if candidates.isEmpty {
            return PracticeDailyTaskSpec(slot: 2, kind: .quizSession, params: [:])
        }

        let seed = hash(periodKey)
        let index = abs(seed) % candidates.count
        return candidates[index]
    }

    private static func hash(_ value: String) -> Int {
        value.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) }
    }
}
