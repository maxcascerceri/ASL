//
//  ProfileMedalDetailSheet.swift
//  ASL
//

import SwiftUI

struct ProfileMedalDetailSheet: View {
    let item: ProfileMedalItem
    @ObservedObject var store: ASLDataStore

    @Environment(\.dismiss) private var dismiss

    private var definition: ASLMedalDefinition { item.definition }

    private var accent: Color { item.accentColor }

    private var progressFraction: Double {
        if item.isUnlocked { return 1 }
        return store.medalEngine.progressFraction(for: definition, store: store)
    }

    private var showsProgressBar: Bool {
        !item.isUnlocked && store.medalEngine.progress(for: definition, store: store) != nil
    }

    private var hidesLockedDescription: Bool {
        definition.category == .signsLearned
    }

    private var sheetHeight: CGFloat {
        if item.isUnlocked { return 300 }
        if showsProgressBar && hidesLockedDescription { return 318 }
        return showsProgressBar ? 348 : 318
    }

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Brand.divider)
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            ProfileMedalDisc(
                state: item.state,
                palette: item.palette,
                symbolName: definition.symbolName,
                progressFraction: progressFraction,
                discSize: 108,
                iconSize: 42
            )

            VStack(spacing: 8) {
                Text(definition.title)
                    .font(.asl(24, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)

                if !definition.subtitle.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: item.isUnlocked ? "rosette" : "target")
                            .font(.asl(14, weight: .medium))
                        Text(definition.subtitle)
                            .font(.asl(15, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(accent.opacity(item.isUnlocked ? 0.18 : 0.10)))
                    .foregroundStyle(item.isUnlocked ? accent : Brand.secondaryLabel)
                }

                if item.isUnlocked {
                    Text(definition.description)
                        .font(.asl(15, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                } else {
                    lockedProgressContent
                }
            }

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text(item.isUnlocked ? "Done" : "Keep Going")
                    .font(.asl(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(item.isUnlocked ? accent : Brand.primary)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.canvas)
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.hidden)
    }

    private func progressLabel(current: Int, target: Int) -> String {
        let value = min(current, target)
        if case .unitsComplete = definition.criterion {
            return "\(value) of \(target) units"
        }
        return "\(value) / \(target)"
    }

    @ViewBuilder
    private var lockedProgressContent: some View {
        VStack(spacing: 12) {
            if !hidesLockedDescription {
                Text(definition.description)
                    .font(.asl(15, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            if let progress = store.medalEngine.progress(for: definition, store: store) {
                MedalProgressBar(
                    current: progress.current,
                    target: progress.target,
                    label: progressLabel(current: progress.current, target: progress.target),
                    accent: accent
                )
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Progress bar

private struct MedalProgressBar: View {
    let current: Int
    let target: Int
    let label: String
    let accent: Color

    private var fillFraction: CGFloat {
        guard target > 0 else { return 0 }
        return CGFloat(min(current, target)) / CGFloat(target)
    }

    private func progressFillWidth(in totalWidth: CGFloat) -> CGFloat {
        guard totalWidth.isFinite, totalWidth > 0, fillFraction.isFinite, fillFraction > 0 else {
            return 0
        }
        return max(14, min(totalWidth, totalWidth * fillFraction))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Brand.divider.opacity(0.55))

                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent)
                        .frame(width: progressFillWidth(in: geometry.size.width))
                    Spacer(minLength: 0)
                }

                Text(label)
                    .font(.asl(15, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(height: 40)
    }
}
