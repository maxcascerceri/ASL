//
//  PracticeDailyTaskCard.swift
//  ASL
//

import SwiftUI

struct PracticeDailyTaskCard: View {
    let task: PracticeDailyTask
    var isHighlighted: Bool = false

    @Environment(\.raisedCardPressed) private var isPressed

    private static let starGold = Color(red: 1.0, green: 0.78, blue: 0.18)

    var body: some View {
        cardBody
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(PracticeTheme.accent, lineWidth: 2.5)
                        .padding(.bottom, RaisedCardMetrics.depth)
                }
            }
            .scaleEffect(isHighlighted ? 1.02 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isHighlighted)
            .opacity(task.isClaimed ? 0.72 : 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(task.title), \(task.progressLabel)")
    }

    private var cardBody: some View {
        PremiumWhiteCard(cornerRadius: 18, isPressed: isPressed) {
            cardContent
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var cardContent: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                Text(task.title)
                    .aslStyle(.cardTitle, surface: .light, variant: .compact)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                progressBar
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            rewardBadge
                .fixedSize()
                .layoutPriority(2)
        }
    }

    private let progressBarHeight: CGFloat = 24

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack {
                Capsule(style: .continuous)
                    .fill(Brand.divider.opacity(0.45))

                Capsule(style: .continuous)
                    .fill(task.isClaimed ? Color.lessonGreen : PracticeTheme.accent)
                    .frame(width: max(0, proxy.size.width * task.progressFraction))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(task.progressLabel)
                    .aslFont(.progressLabel, variant: .compact)
                    .foregroundStyle(progressLabelColor)
                    .monospacedDigit()
            }
        }
        .frame(height: progressBarHeight)
    }

    private var progressLabelColor: Color {
        if task.isClaimed || task.isComplete {
            return .white
        }
        return Brand.textPrimary.opacity(0.75)
    }

    @ViewBuilder
    private var rewardBadge: some View {
        if task.isClaimed {
            ASLIcon(
                source: .symbol("checkmark.circle.fill"),
                role: .feature,
                tint: Color.lessonGreen
            )
        } else if task.starReward > 0 {
            starPill
        }
    }

    private var starPill: some View {
        HStack(spacing: 4) {
            ASLIcon(
                source: .symbol("star.fill"),
                role: .utility,
                tint: Self.starGold
            )
            Text("\(task.starReward)")
                .aslFont(.progressLabel, variant: .prominent)
                .foregroundStyle(Brand.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}
