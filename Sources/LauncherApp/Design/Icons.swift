import SwiftUI

public struct CubeIcon: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let r = min(rect.width, rect.height) / 2
        let cos30: CGFloat = 0.86602540378
        let sin30: CGFloat = 0.5

        let pTop = CGPoint(x: cx, y: cy - r)
        let pTopRight = CGPoint(x: cx + r * cos30, y: cy - r * sin30)
        let pBottomRight = CGPoint(x: cx + r * cos30, y: cy + r * sin30)
        let pBottom = CGPoint(x: cx, y: cy + r)
        let pBottomLeft = CGPoint(x: cx - r * cos30, y: cy + r * sin30)
        let pTopLeft = CGPoint(x: cx - r * cos30, y: cy - r * sin30)
        let center = CGPoint(x: cx, y: cy)

        // Hexagon outline
        path.move(to: pTop)
        path.addLine(to: pTopRight)
        path.addLine(to: pBottomRight)
        path.addLine(to: pBottom)
        path.addLine(to: pBottomLeft)
        path.addLine(to: pTopLeft)
        path.closeSubpath()

        // 3 inner edges meeting at center
        path.move(to: center)
        path.addLine(to: pTopLeft)
        path.move(to: center)
        path.addLine(to: pTopRight)
        path.move(to: center)
        path.addLine(to: pBottom)

        return path
    }
}

public struct PlayTriangle: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerRadius = min(w, h) * 0.15

        let p1 = CGPoint(x: rect.minX + w * 0.15, y: rect.minY + h * 0.1)
        let p2 = CGPoint(x: rect.maxX - w * 0.1, y: rect.midY)
        let p3 = CGPoint(x: rect.minX + w * 0.15, y: rect.maxY - h * 0.1)

        path.move(to: CGPoint(x: p1.x, y: p1.y + cornerRadius))
        path.addArc(tangent1End: p1, tangent2End: p2, radius: cornerRadius)
        path.addArc(tangent1End: p2, tangent2End: p3, radius: cornerRadius)
        path.addArc(tangent1End: p3, tangent2End: p1, radius: cornerRadius)
        path.closeSubpath()
        return path
    }
}

public struct SearchIcon: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let size = min(rect.width, rect.height)
        let originX = rect.midX - size / 2
        let originY = rect.midY - size / 2

        let center = CGPoint(x: originX + size * 0.4, y: originY + size * 0.4)
        let radius = size * 0.28

        path.addEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        let cos45: CGFloat = 0.70710678
        let handleStart = CGPoint(x: center.x + radius * cos45, y: center.y + radius * cos45)
        let handleEnd = CGPoint(x: originX + size * 0.85, y: originY + size * 0.85)

        path.move(to: handleStart)
        path.addLine(to: handleEnd)

        return path
    }
}
