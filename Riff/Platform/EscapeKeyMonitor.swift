//
//  EscapeKeyMonitor.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import AppKit

// MARK: - Tecla esc

/// Escucha esc en la app. Se usa un monitor local porque la ventana de un MenuBarExtra
/// no reacciona a esc por sí sola, y `onExitCommand` solo funciona si algo tiene el foco.
@MainActor
final class EscapeKeyMonitor {

    private var monitor: Any?

    /// El handler devuelve true si usó la tecla; en ese caso el evento se consume.
    func start(_ handler: @escaping @MainActor (NSEvent) -> Bool) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else { return event } // 53 = esc
            let handled = MainActor.assumeIsolated { handler(event) }
            return handled ? nil : event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
