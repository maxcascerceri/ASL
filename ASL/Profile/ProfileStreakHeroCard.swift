//
//  ProfileStreakHeroCard.swift
//  ASL
//

import SwiftUI

struct ProfileStreakHeroCard: View {
    @ObservedObject var store: ASLDataStore

    private static let palette = PastelPalette.dailyStreak
    private static let cardCornerRadius: CGFloat = PastelCardMetrics.cornerRadius
    private static let heroFlameTopInset: CGFloat = 40
    private static let heroFlameIconSize: CGFloat = 56
    private static let heroStreakValueSize: CGFloat = 36

    var body: some View {
        let streak = store.dailyActivityStreak
        let bestStreak = store.bestDailyActivityStreak
        let weekDays = store.streakWeekdayStates()

        ZStack(alignment: .top) {
            streakCardBody(
                streak: streak,
                bestStreak: bestStreak,
                weekDays: weekDays
            )

            heroFlame(streak: streak)
                .offset(y: -Self.heroFlameTopInset)
        }
        .padding(.top, Self.heroFlameTopInset)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Daily streak \(streak) days. Current streak \(streak). Best streak \(bestStreak).")
    }

    private func streakCardBody(
        streak: Int,
        bestStreak: Int,
        weekDays: [ASLDataStore.StreakDayState]
    ) -> some View {
        PremiumColoredCard(
            fill: Self.palette.fill,
            depthHint: Self.palette.depth,
            depthMix: PastelCardMetrics.depthMix,
            slabDepth: PastelCardMetrics.slabDepth,
            cornerRadius: Self.cardCornerRadius,
            isPressed: false
        ) {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Spacer(minLength: 10)

                    HStack(alignment: .center, spacing: 10) {
                        Text("\(streak)")
                            .aslStyle(.progressStat, variant: .prominent, color: Self.palette.iconTint)
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(streak)))
                            .animation(.spring(response: 0.45, dampingFraction: 0.75), value: streak)

                        Text("Daily Streak")
                            .aslStyle(.cardTitle, variant: .compact)
                            .fontWeight(.bold)

                        Spacer(minLength: 0)
                    }

                    StreakWeekRow(weekDays: weekDays)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

                Rectangle()
                    .fill(Brand.divider.opacity(0.55))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    StreakFooterStat(
                        value: streak,
                        label: "Current streak",
                        accent: Self.palette.iconTint
                    )

                    Rectangle()
                        .fill(Brand.divider.opacity(0.55))
                        .frame(width: 1)
                        .padding(.vertical, 10)

                    StreakFooterStat(
                        value: bestStreak,
                        label: "Best streak",
                        accent: Self.palette.iconTint
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
        }
    }

    private func heroFlame(streak: Int) -> some View {
        Image(systemName: "flame.fill")
            .font(.system(size: Self.heroFlameIconSize, weight: .semibold))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(Self.palette.iconTint)
            .pastelIconWhiteOutline()
    }
}

// MARK: - Week row

private struct StreakWeekRow: View {
    let weekDays: [ASLDataStore.StreakDayState]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays) { day in
                StreakWeekDot(day: day)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("This week")
    }
}

private struct StreakWeekDot: View {
    let day: ASLDataStore.StreakDayState

    private static let weekDotSize: CGFloat = 36
    private static let checkmarkSize: CGFloat = 14
    private static let depthOffset: CGFloat = 2.5
    private static let completePalette = PastelPalette.dictionaryMint

    private var faceColor: Color {
        Self.completePalette.fill
    }

    private var rimColor: Color {
        PremiumCardStyle.softDepth(
            for: Self.completePalette.fill,
            hint: Self.completePalette.depth,
            mix: PastelCardMetrics.depthMix
        )
    }

    private var activeDot: some View {
        ZStack(alignment: .top) {
            Circle()
                .fill(rimColor)
                .frame(width: Self.weekDotSize, height: Self.weekDotSize)
                .offset(y: Self.depthOffset)

            Circle()
                .fill(faceColor)
                .frame(width: Self.weekDotSize, height: Self.weekDotSize)

            Image(systemName: "checkmark")
                .font(.asl(Self.checkmarkSize, weight: .semibold, design: .ui))
                .foregroundStyle(Self.completePalette.iconTint)
                .frame(width: Self.weekDotSize, height: Self.weekDotSize)
        }
    }

    private var inactiveDot: some View {
        Circle()
            .fill(Color.white.opacity(0.92))
            .overlay {
                Circle()
                    .strokeBorder(Self.completePalette.fill.opacity(0.55), lineWidth: 1.5)
            }
            .frame(width: Self.weekDotSize, height: Self.weekDotSize)
    }

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if day.isActive {
                    activeDot
                } else {
                    inactiveDot
                }
            }
            .frame(
                width: Self.weekDotSize,
                height: day.isActive ? Self.weekDotSize + Self.depthOffset : Self.weekDotSize,
                alignment: .top
            )

            Text(day.weekdaySymbol)
                .aslFont(.tabBar, variant: .compact)
                .foregroundStyle(Brand.secondaryLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [day.weekdaySymbol]
        if day.isToday { parts.append("today") }
        parts.append(day.isActive ? "completed" : "not completed")
        return parts.joined(separator: ", ")
    }
}

// MARK: - Footer stats

private struct StreakFooterStat: View {
    let value: Int
    let label: String
    let accent: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.asl(14, weight: .medium))
                    .foregroundStyle(accent)

                Text("\(value)")
                    .aslStyle(.progressStat, surface: .light, variant: .compact)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
            }

            Text(label)
                .aslStyle(.progressLabel, surface: .light, variant: .standard)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}
