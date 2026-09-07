//
//  VerticalScrollAxisLock.swift
//  Safesight
//

import SwiftUI
import UIKit

/// Disables horizontal rubber-banding on the nearest UIScrollView once.
/// Does not mutate contentSize (that previously froze Home).
struct VerticalScrollAxisLock: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            var node: UIView? = view.superview
            while let current = node {
                if let scroll = current as? UIScrollView {
                    scroll.alwaysBounceHorizontal = false
                    scroll.isDirectionalLockEnabled = true
                    scroll.showsHorizontalScrollIndicator = false
                    break
                }
                node = current.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
