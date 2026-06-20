//
//  OnboardingScaffold.swift
//  ASL
//

import SwiftUI

struct OnboardingScaffold<Content: View, Footer: View>: View {
    var progress: Double? = nil
    var showsBack: Bool = true
    var onBack: (() -> Void)? = nil
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.asl(.pageTitle, variant: .compact))
                            .foregroundStyle(Brand.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle)
                                .font(.asl(.subtitle))
                                .foregroundStyle(Brand.secondaryLabel)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    content()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            footer()
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .background(Brand.canvas)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            HomeWorldBackground()
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            if showsBack, let onBack {
                Button(action: {
                    Haptics.tap()
                    onBack()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.asl(16, weight: .semibold))
                        .foregroundStyle(Brand.secondaryLabel)
                        .frame(width: 36, height: 36)
                        .background {
                            Circle()
                                .fill(Brand.chrome.opacity(0.92))
                        }
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            if let progress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        PremiumProgressBarTrack(height: 12)
                        PremiumProgressBarFill(
                            color: Brand.primary,
                            shadowColor: Brand.primaryShadow,
                            height: 12
                        )
                        .frame(width: max(14, geo.size.width * progress))
                    }
                }
                .frame(height: 12)
            } else {
                Spacer(minLength: 0)
            }

            Color.clear.frame(width: 36, height: 36)
        }
    }
}

extension OnboardingScaffold where Footer == EmptyView {
    init(
        progress: Double? = nil,
        showsBack: Bool = true,
        onBack: (() -> Void)? = nil,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.progress = progress
        self.showsBack = showsBack
        self.onBack = onBack
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.footer = { EmptyView() }
    }
}
