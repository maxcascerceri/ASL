//
//  OnboardingScienceFactView.swift
//  ASL
//

import SwiftUI

private enum OnboardingScienceFactMetrics {
    static let heroMascotSize: CGFloat = 280
    static let mascotToHeadlineSpacing: CGFloat = -24
    static let headlineSize: CGFloat = 32
    static let heroStatSize: CGFloat = 40
    static let statSublineSize: CGFloat = 17
    static let bodySize: CGFloat = 17
    static let citationSize: CGFloat = 16
    static let citationCornerRadius: CGFloat = 14
    static let citationBorderWidth: CGFloat = 1
    static let mascotImageName = "sayings"
}

struct OnboardingScienceFactView: View {
    let profile: OnboardingProfile
    let progress: Double
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentIn = false
    @State private var showsSourceSheet = false

    private var minutes: Int { OnboardingCopy.scienceFactMinutes(for: profile) }
    private var projection: Int { OnboardingCopy.scienceFactWeeklyProjection(for: profile) }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingFlowProgressHeader(progress: progress)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(spacing: 0) {
                    Image(OnboardingScienceFactMetrics.mascotImageName)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(
                            (contentIn ? 1 : 0.9)
                                * UnitMascot.homePathContentScale(for: OnboardingScienceFactMetrics.mascotImageName)
                        )
                        .frame(
                            maxWidth: OnboardingScienceFactMetrics.heroMascotSize,
                            maxHeight: OnboardingScienceFactMetrics.heroMascotSize
                        )
                        .opacity(contentIn ? 1 : 0)

                    VStack(spacing: 10) {
                        Text(OnboardingCopy.scienceFactHeadline)
                            .font(.asl(OnboardingScienceFactMetrics.headlineSize, weight: .semibold))
                            .foregroundStyle(Brand.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(OnboardingCopy.scienceFactHeroStat(signCount: projection))
                            .font(.asl(OnboardingScienceFactMetrics.heroStatSize, weight: .bold, design: .display))
                            .foregroundStyle(Brand.primary)
                            .multilineTextAlignment(.center)

                        Text(OnboardingCopy.scienceFactStatSubline)
                            .font(.asl(OnboardingScienceFactMetrics.statSublineSize, weight: .regular))
                            .foregroundStyle(Brand.secondaryLabel)
                            .multilineTextAlignment(.center)

                        Text(bodyAttributedText)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)

                        citationCard
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, OnboardingScienceFactMetrics.mascotToHeadlineSpacing)
                    .opacity(contentIn ? 1 : 0)
                    .offset(y: contentIn ? 0 : 12)

                    Button {
                        showsSourceSheet = true
                    } label: {
                        Text(OnboardingCopy.scienceFactSourceLink)
                            .font(.asl(15, weight: .semibold))
                            .foregroundStyle(Brand.primary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                    .opacity(contentIn ? 1 : 0)
                }
                .padding(.bottom, 16)
            }

            OnboardingPrimaryButton(title: OnboardingCopy.continueCTA, action: onContinue)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showsSourceSheet) {
            OnboardingScienceFactSourceSheet()
        }
        .onAppear {
            if reduceMotion {
                contentIn = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.15)) {
                    contentIn = true
                }
            }
        }
    }

    private var bodyAttributedText: AttributedString {
        attributedString(
            OnboardingCopy.scienceFactBody(minutes: minutes),
            boldRanges: OnboardingCopy.scienceFactBodyBold(minutes: minutes),
            fontSize: OnboardingScienceFactMetrics.bodySize,
            color: Brand.secondaryLabel
        )
    }

    private var citationAttributedText: AttributedString {
        attributedString(
            OnboardingCopy.scienceFactCitationCard,
            boldRanges: OnboardingCopy.scienceFactCitationBold,
            fontSize: OnboardingScienceFactMetrics.citationSize,
            color: Brand.textPrimary
        )
    }

    private var citationCard: some View {
        Text(citationAttributedText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(
                    cornerRadius: OnboardingScienceFactMetrics.citationCornerRadius,
                    style: .continuous
                )
                .fill(Brand.primary.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: OnboardingScienceFactMetrics.citationCornerRadius,
                    style: .continuous
                )
                .strokeBorder(Brand.primary.opacity(0.18), lineWidth: OnboardingScienceFactMetrics.citationBorderWidth)
            }
    }

    private func attributedString(
        _ text: String,
        boldRanges: [String],
        fontSize: CGFloat,
        color: Color
    ) -> AttributedString {
        var result = AttributedString(text)
        result.font = .custom(ASLFontName.uiRegular, size: fontSize)
        result.foregroundColor = color

        for boldPart in boldRanges {
            if let range = result.range(of: boldPart) {
                result[range].font = .custom(ASLFontName.uiBold, size: fontSize)
                result[range].foregroundColor = color
            }
        }
        return result
    }
}

private struct OnboardingScienceFactSourceSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(OnboardingCopy.scienceFactSourceCepeda)
                        .font(.asl(16, weight: .regular))
                        .foregroundStyle(Brand.textPrimary)

                    Text(OnboardingCopy.scienceFactSourceVL2)
                        .font(.asl(16, weight: .regular))
                        .foregroundStyle(Brand.textPrimary)
                }
                .padding(24)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationTitle(OnboardingCopy.scienceFactSourceSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.asl(16, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
