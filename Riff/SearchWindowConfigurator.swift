//
//  SearchWindowConfigurator.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

// MARK: - Ventana de búsqueda sin marco

/// Oculta los botones de colores de la ventana y la cierra cuando deja de ser la
/// ventana activa: clic afuera, cambio de app o abrir el popover.
struct SearchWindowConfigurator: NSViewRepresentable {

    let onResignKey: @MainActor () -> Void

    func makeNSView(context: Context) -> ConfiguratorView {
        let view = ConfiguratorView()
        view.onResignKey = onResignKey
        return view
    }

    func updateNSView(_ nsView: ConfiguratorView, context: Context) {
        nsView.onResignKey = onResignKey
    }

    final class ConfiguratorView: NSView {

        var onResignKey: @MainActor () -> Void = {}

        // `nonisolated(unsafe)` para poder cancelarlo desde deinit. Solo se escribe en el MainActor.
        nonisolated(unsafe) private var task: Task<Void, Never>?

        deinit {
            task?.cancel()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            task?.cancel()

            guard let window else { return }

            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = true

            task = Task { @MainActor [weak self, weak window] in
                guard let window else { return }
                let center = NotificationCenter.default

                // Esperamos a que sea la ventana activa antes de vigilar cuándo deja de serlo;
                // así no se cierra sola mientras el popover termina de cerrarse.
                if !window.isKeyWindow {
                    for await _ in center.notifications(named: NSWindow.didBecomeKeyNotification, object: window) {
                        break
                    }
                }

                for await _ in center.notifications(named: NSWindow.didResignKeyNotification, object: window) {
                    self?.onResignKey()
                    break
                }
            }
        }
    }
}
