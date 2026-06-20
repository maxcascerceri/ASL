//
//  PracticeDailyPracticeSection.swift
//  ASL
//

import SwiftUI

struct PracticeDailyPracticeSection: View {
    @ObservedObject var store: ASLDataStore
    var highlightedTaskKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(alignment: .center, spacing: 12) {
                    Text("Daily Practice")
                        .aslStyle(.cardTitle, surface: .light, variant: .compact)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .aslIconStyle(role: .utility, tint: Brand.secondaryLabel, isEmphasis: false)
                        Text(resetsLabel(at: context.date))
                            .aslFont(.tabBar, variant: .compact)
                    }
                    .foregroundStyle(Brand.secondaryLabel)
                }
                .onChange(of: context.date) { _, date in
                    tickPeriodRefresh(at: date)
                }
            }

            if store.practiceDailyEngine.allTasksClaimed {
                RaisedCardShell(
                    fill: Brand.soft.opacity(0.55),
                    depthColor: Brand.divider.opacity(0.45),
                    cornerRadius: 14,
                    isPressed: false
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .aslIconStyle(
                                role: .decorative,
                                tint: Color(red: 1.00, green: 0.76, blue: 0.34)
                            )
                        Text("All daily practice complete!")
                            .aslStyle(.cardDescription, surface: .light, variant: .compact)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
            }

            VStack(spacing: 10) {
                ForEach(store.practiceDailyEngine.tasks) { task in
                    PracticeDailyTaskCard(
                        task: task,
                        isHighlighted: highlightedTaskKey == task.instanceKey
                    )
                    .id(task.instanceKey)
                }
            }
        }
        .padding(.top, 6)
        .onAppear {
            store.practiceDailyEngine.refreshPeriodIfNeeded(store: store)
        }
    }

    private func resetsLabel(at date: Date) -> String {
        let remaining = max(0, store.practiceDailyEngine.resetsAt.timeIntervalSince(date))
        let hours = Int(remaining) / 3600
        if hours > 0 {
            return "Resets in \(hours)h"
        }
        return remaining > 0 ? "Resets in 1h" : "Resets soon"
    }

    private func tickPeriodRefresh(at date: Date) {
        guard date >= store.practiceDailyEngine.resetsAt else { return }
        store.practiceDailyEngine.refreshPeriodIfNeeded(store: store)
    }
}
