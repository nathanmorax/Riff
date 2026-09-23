//
//  WindowReader.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI
import AppKit

// MARK: - Acceso a la ventana del MenuBarExtra

/// Guarda la ventana sin provocar redibujos (una @State con NSWindow sí los provocaría).
final class WindowBox {
    weak var window: NSWindow?
}

/// Reporta la NSWindow que contiene a la vista.
struct WindowReader: NSViewRepresentable {

    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { onWindow(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onWindow(nsView.window) }
    }
}
