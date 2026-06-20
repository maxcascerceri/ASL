//
//  ProfileStarsInfoSheet.swift
//  ASL
//

import SwiftUI

struct ProfileStarsInfoSheet: View {
    @ObservedObject var store: ASLDataStore

    @Environment(\.dismiss) private var dismiss

    private static let accent = Color(red: 0.86, green: 0.71, blue: 0.33)
    private static let sheetHeight: CGFloat = 300

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Brand.divider)
                .frame(width: 42, height: 5)
                .padding(.top, 10)

            ProfileRaisedIconBadge(
                animation: .starTwinkle,
                tint: .yellow,
                size: 108,
                iconSize: 42,
                bounceValue: store.totalStars
            )

            VStack(spacing: 8) {
                Text("Total Stars")
                    .font(.asl(24, weight: .semibold))
                    .foregroundStyle(Brand.textPrimary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.asl(14, weight: .medium))
                    Text("\(store.totalStars) earned")
                        .font(.asl(15, weight: .medium))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Capsule().fill(Self.accent.opacity(0.18)))
                .foregroundStyle(Self.accent)

                Text("Earn stars by completing stones and units on your path, studying signs in the dictionary, and finishing daily practice goals.")
                    .font(.asl(15, weight: .semibold))
                    .foregroundStyle(Brand.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text("Done")
                    .font(.asl(17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Self.accent)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.canvas)
        .presentationDetents([.height(Self.sheetHeight)])
        .presentationDragIndicator(.hidden)
    }
}
