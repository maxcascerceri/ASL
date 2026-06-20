//
//  ProfileStatCard.swift
//  ASL
//

import SwiftUI

struct ProfileStatCard: View {
    let palette: PastelPalette
    let iconAnimation: ProfileIconAnimation
    let value: Int
    let label: String
    var animatesIcon: Bool = true
    var action: (() -> Void)?

    @Environment(\.raisedCardPressed) private var isPressed

    private var isVisuallyPressed: Bool {
        isPressed && action != nil
    }

    private var iconRowHeight: CGFloat {
        PastelCardMetrics.statIconSize
    }

    private var iconOutlineInset: CGFloat {
        PastelCardMetrics.iconOutlineWidth + 1
    }

    private var iconBlockHeight: CGFloat {
        iconRowHeight + iconOutlineInset
    }

    var body: some View {
        Group {
            if action != nil {
                Button {
                    Haptics.tap()
                    action?()
                } label: {
                    cardBody
                }
                .buttonStyle(RaisedCardPressStyle())
            } else {
                cardBody
            }
        }
    }

    private var cardBody: some View {
        PremiumColoredCard(
            fill: palette.fill,
            depthHint: palette.depth,
            depthMix: PastelCardMetrics.depthMix,
            slabDepth: PastelCardMetrics.slabDepth,
            cornerRadius: PastelCardMetrics.cornerRadius,
            isPressed: isVisuallyPressed
        ) {
            HStack(alignment: .top, spacing: PastelCardMetrics.profileStatColumnSpacing) {
                VStack(alignment: .leading, spacing: 0) {
                    statIcon
                        .frame(
                            width: iconBlockHeight,
                            height: iconBlockHeight,
                            alignment: .topLeading
                        )

                    Text(label)
                        .aslStyle(.cardTitle, variant: .compact)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.top, PastelCardMetrics.profileStatIconLabelSpacing)
                }

                Text("\(value)")
                    .aslStyle(.progressStat, variant: .compact)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.spring(response: 0.45, dampingFraction: 0.75), value: value)
                    .frame(height: iconBlockHeight, alignment: .center)
                    .offset(y: PastelCardMetrics.profileStatValueCenterOffset)

                Spacer(minLength: 0)
            }
            .padding(.leading, 15)
            .padding(.trailing, 12)
            .padding(.top, 15)
            .padding(.bottom, 12)
            .frame(height: PastelCardMetrics.profileStatCardHeight)
        }
        .contentShape(RoundedRectangle(cornerRadius: PastelCardMetrics.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var statIcon: some View {
        Group {
            if animatesIcon {
                ProfileAnimatedSymbol(
                    animation: iconAnimation,
                    tint: palette.iconTint,
                    role: .dictionaryCategory,
                    iconSize: PastelCardMetrics.statIconSize,
                    bounceValue: value
                )
            } else {
                ASLIcon(
                    source: .symbol(iconAnimation.systemImage),
                    role: .dictionaryCategory,
                    tint: palette.iconTint,
                    assetSize: PastelCardMetrics.statIconSize
                )
            }
        }
        .pastelIconWhiteOutline()
    }
}
