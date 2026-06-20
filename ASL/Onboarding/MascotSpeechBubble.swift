//
//  MascotSpeechBubble.swift
//  ASL
//

import SwiftUI

enum OnboardingMascotMetrics {
    static let headerMascotSize: CGFloat = 132
    static let standaloneMascotSize: CGFloat = 270
    static let headerSpacing: CGFloat = 9
}

enum MascotSpeechBubbleMetrics {
    static let fontSize: CGFloat = 19
    static let horizontalPadding: CGFloat = 30
    static let verticalPadding: CGFloat = 22
    static let cornerRadius: CGFloat = 22
    static let borderWidth: CGFloat = 3.5
    static let tailWidth: CGFloat = 24
    static let tailHeight: CGFloat = 14
    static let tailAnchor: CGFloat = 0.45
    static let tailSidePadding: CGFloat = 8
}

enum MascotSpeechBubbleTailDirection {
    case leading
    case bottom
    case top
}

struct MascotSpeechBubbleShape: Shape {
    var cornerRadius: CGFloat
    var tail: MascotSpeechBubbleTailDirection
    var tailWidth: CGFloat
    var tailHeight: CGFloat
    var tailAnchor: CGFloat

    func path(in rect: CGRect) -> Path {
        switch tail {
        case .leading:
            return leadingTailPath(in: rect)
        case .bottom:
            return bottomTailPath(in: rect)
        case .top:
            return topTailPath(in: rect)
        }
    }

    private func leadingTailPath(in rect: CGRect) -> Path {
        let bodyLeft = rect.minX + tailHeight
        let bodyRight = rect.maxX
        let bodyTop = rect.minY
        let bodyBottom = rect.maxY
        let bodyWidth = bodyRight - bodyLeft
        let bodyHeight = bodyBottom - bodyTop
        let radius = min(cornerRadius, bodyWidth / 2, bodyHeight / 2)

        let tailCenterY = bodyTop + bodyHeight * tailAnchor
        let halfTail = tailWidth / 2
        let notchTop = min(max(tailCenterY - halfTail, bodyTop + radius + 2), bodyBottom - radius - 2)
        let notchBottom = min(max(tailCenterY + halfTail, bodyTop + radius + 2), bodyBottom - radius - 2)

        var path = Path()
        path.move(to: CGPoint(x: bodyLeft + radius, y: bodyTop))
        path.addLine(to: CGPoint(x: bodyRight - radius, y: bodyTop))
        path.addArc(
            center: CGPoint(x: bodyRight - radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyRight, y: bodyBottom - radius))
        path.addArc(
            center: CGPoint(x: bodyRight - radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft + radius, y: bodyBottom))
        path.addArc(
            center: CGPoint(x: bodyLeft + radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft, y: notchBottom))
        path.addLine(to: CGPoint(x: rect.minX, y: tailCenterY))
        path.addLine(to: CGPoint(x: bodyLeft, y: notchTop))
        path.addLine(to: CGPoint(x: bodyLeft, y: bodyTop + radius))
        path.addArc(
            center: CGPoint(x: bodyLeft + radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    private func bottomTailPath(in rect: CGRect) -> Path {
        let bodyLeft = rect.minX
        let bodyRight = rect.maxX
        let bodyTop = rect.minY
        let bodyBottom = rect.maxY - tailHeight
        let bodyWidth = bodyRight - bodyLeft
        let bodyHeight = bodyBottom - bodyTop
        let radius = min(cornerRadius, bodyWidth / 2, bodyHeight / 2)

        let tailCenterX = rect.midX
        let halfTail = tailWidth / 2
        let notchLeft = min(max(tailCenterX - halfTail, bodyLeft + radius + 2), bodyRight - radius - 2)
        let notchRight = min(max(tailCenterX + halfTail, bodyLeft + radius + 2), bodyRight - radius - 2)

        var path = Path()
        path.move(to: CGPoint(x: bodyLeft + radius, y: bodyTop))
        path.addLine(to: CGPoint(x: bodyRight - radius, y: bodyTop))
        path.addArc(
            center: CGPoint(x: bodyRight - radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyRight, y: bodyBottom - radius))
        path.addArc(
            center: CGPoint(x: bodyRight - radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: notchRight, y: bodyBottom))
        path.addLine(to: CGPoint(x: tailCenterX, y: rect.maxY))
        path.addLine(to: CGPoint(x: notchLeft, y: bodyBottom))
        path.addLine(to: CGPoint(x: bodyLeft + radius, y: bodyBottom))
        path.addArc(
            center: CGPoint(x: bodyLeft + radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft, y: bodyTop + radius))
        path.addArc(
            center: CGPoint(x: bodyLeft + radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }

    private func topTailPath(in rect: CGRect) -> Path {
        let bodyLeft = rect.minX
        let bodyRight = rect.maxX
        let bodyTop = rect.minY + tailHeight
        let bodyBottom = rect.maxY
        let bodyWidth = bodyRight - bodyLeft
        let bodyHeight = bodyBottom - bodyTop
        let radius = min(cornerRadius, bodyWidth / 2, bodyHeight / 2)

        let tailCenterX = rect.midX
        let halfTail = tailWidth / 2
        let notchLeft = min(max(tailCenterX - halfTail, bodyLeft + radius + 2), bodyRight - radius - 2)
        let notchRight = min(max(tailCenterX + halfTail, bodyLeft + radius + 2), bodyRight - radius - 2)

        var path = Path()
        path.move(to: CGPoint(x: notchLeft, y: bodyTop))
        path.addLine(to: CGPoint(x: tailCenterX, y: rect.minY))
        path.addLine(to: CGPoint(x: notchRight, y: bodyTop))
        path.addLine(to: CGPoint(x: bodyRight - radius, y: bodyTop))
        path.addArc(
            center: CGPoint(x: bodyRight - radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyRight, y: bodyBottom - radius))
        path.addArc(
            center: CGPoint(x: bodyRight - radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft + radius, y: bodyBottom))
        path.addArc(
            center: CGPoint(x: bodyLeft + radius, y: bodyBottom - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: bodyLeft, y: bodyTop + radius))
        path.addArc(
            center: CGPoint(x: bodyLeft + radius, y: bodyTop + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

struct MascotSpeechBubble: View {
    let text: String
    var boldRanges: [String] = []
    var tailDirection: MascotSpeechBubbleTailDirection = .leading
    var fontSize: CGFloat = MascotSpeechBubbleMetrics.fontSize

    private var bubbleShape: MascotSpeechBubbleShape {
        MascotSpeechBubbleShape(
            cornerRadius: MascotSpeechBubbleMetrics.cornerRadius,
            tail: tailDirection,
            tailWidth: MascotSpeechBubbleMetrics.tailWidth,
            tailHeight: MascotSpeechBubbleMetrics.tailHeight,
            tailAnchor: MascotSpeechBubbleMetrics.tailAnchor
        )
    }

    var body: some View {
        bubbleContent
            .padding(contentPadding)
            .background {
                bubbleShape
                    .fill(Color.white)
            }
            .overlay {
                bubbleShape
                    .stroke(
                        Brand.primary,
                        style: StrokeStyle(
                            lineWidth: MascotSpeechBubbleMetrics.borderWidth,
                            lineJoin: .round
                        )
                    )
            }
    }

    private var contentPadding: EdgeInsets {
        let horizontal = MascotSpeechBubbleMetrics.horizontalPadding
        let vertical = MascotSpeechBubbleMetrics.verticalPadding
        let tailInset = MascotSpeechBubbleMetrics.tailHeight + MascotSpeechBubbleMetrics.tailSidePadding

        switch tailDirection {
        case .leading:
            return EdgeInsets(
                top: vertical,
                leading: horizontal + tailInset,
                bottom: vertical,
                trailing: horizontal
            )
        case .bottom:
            return EdgeInsets(
                top: vertical,
                leading: horizontal,
                bottom: vertical + tailInset,
                trailing: horizontal
            )
        case .top:
            return EdgeInsets(
                top: vertical + tailInset,
                leading: horizontal,
                bottom: vertical,
                trailing: horizontal
            )
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if boldRanges.isEmpty {
            Text(text)
                .font(.asl(fontSize, weight: .regular, design: .ui))
                .foregroundStyle(Brand.textPrimary)
                .multilineTextAlignment(.center)
                .animation(nil, value: text)
        } else {
            Text(attributedText)
                .multilineTextAlignment(.center)
                .animation(nil, value: text)
        }
    }

    private var attributedText: AttributedString {
        var result = AttributedString(text)
        result.font = .custom(ASLFontName.uiRegular, size: fontSize)
        result.foregroundColor = Brand.textPrimary

        for boldPart in boldRanges {
            if let range = result.range(of: boldPart) {
                result[range].font = .custom(ASLFontName.uiBold, size: fontSize)
                result[range].foregroundColor = Brand.textPrimary
            }
        }
        return result
    }
}
