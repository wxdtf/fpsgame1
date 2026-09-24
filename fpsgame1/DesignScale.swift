//
//  DesignScale.swift
//  fpsgame1
//
//  The screens are laid out for the 960×600 window the Mac opens with. Smaller
//  hosts (an iPhone in landscape, a Mac window shrunk below that) show the same
//  layout scaled down to fit, letterboxed on black, so nothing clips or wraps.
//  Larger hosts are untouched: the layouts fill them as before.
//

import SwiftUI

extension View {
    /// Shrink the view to fit hosts smaller than the 960×600 design size
    func fitDesignSize() -> some View {
        modifier(FitDesignSize())
    }
}

struct FitDesignSize: ViewModifier {
    static let designWidth: CGFloat = CGFloat(GameConstants.windowWidth)
    static let designHeight: CGFloat = CGFloat(GameConstants.windowHeight)

    /// The factor a host of this size scales the design by (never above 1)
    static func scale(for size: CGSize) -> CGFloat {
        guard size.width > 0, size.height > 0 else { return 1 }
        return min(1, min(size.width / designWidth, size.height / designHeight))
    }

    func body(content: Content) -> some View {
        GeometryReader { geo in
            let scale = Self.scale(for: geo.size)
            if scale < 1 {
                content
                    .frame(width: Self.designWidth, height: Self.designHeight)
                    .scaleEffect(scale)
                    .frame(width: geo.size.width, height: geo.size.height)
            } else {
                content
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}
