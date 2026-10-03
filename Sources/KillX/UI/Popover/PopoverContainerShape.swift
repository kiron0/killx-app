import SwiftUI

struct PopoverContainerShape: Shape {
    var arrowX: CGFloat = 135
    var arrowWidth: CGFloat = 32
    var arrowHeight: CGFloat = 12
    var cornerRadius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.minY + arrowHeight
        let bottom = rect.maxY
        let left = rect.minX
        let right = rect.maxX
        let halfW = arrowWidth / 2
        let clampedArrowX = max(left + cornerRadius + halfW, min(arrowX, right - cornerRadius - halfW))

        path.move(to: CGPoint(x: left + cornerRadius, y: top))
        path.addLine(to: CGPoint(x: clampedArrowX - halfW, y: top))
        path.addCurve(
            to: CGPoint(x: clampedArrowX - 10.4, y: top - 2.4),
            control1: CGPoint(x: clampedArrowX - 14.0, y: top),
            control2: CGPoint(x: clampedArrowX - 12.0, y: top - 0.9)
        )
        path.addLine(to: CGPoint(x: clampedArrowX - 4.0, y: top - 9.2))
        path.addCurve(
            to: CGPoint(x: clampedArrowX + 4.0, y: top - 9.2),
            control1: CGPoint(x: clampedArrowX - 1.8, y: top - 11.8),
            control2: CGPoint(x: clampedArrowX + 1.8, y: top - 11.8)
        )
        path.addLine(to: CGPoint(x: clampedArrowX + 10.4, y: top - 2.4))
        path.addCurve(
            to: CGPoint(x: clampedArrowX + halfW, y: top),
            control1: CGPoint(x: clampedArrowX + 12.0, y: top - 0.9),
            control2: CGPoint(x: clampedArrowX + 14.0, y: top)
        )
        path.addLine(to: CGPoint(x: right - cornerRadius, y: top))

        path.addArc(
            center: CGPoint(x: right - cornerRadius, y: top + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: right, y: bottom - cornerRadius))
        path.addArc(
            center: CGPoint(x: right - cornerRadius, y: bottom - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: left + cornerRadius, y: bottom))
        path.addArc(
            center: CGPoint(x: left + cornerRadius, y: bottom - cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: left, y: top + cornerRadius))
        path.addArc(
            center: CGPoint(x: left + cornerRadius, y: top + cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        path.closeSubpath()
        return path
    }
}
