//
//  SearchPanelController.swift
//  Riff
//
//  Created by Nathan Mora on 23/09/26.
//
import SwiftUI
import AppKit
import Observation

// MARK: - Controlador del panel flotante

/// Muestra una ventana flotante justo debajo del popover del MenuBarExtra.
/// El panel nunca se vuelve key: así el popover no pierde el foco (y no se cierra)
/// mientras el usuario escribe arriba o hace clic en un resultado.
@MainActor
final class SearchPanelController {

    /// Alto del contenido visible del panel.
    var contentHeight: CGFloat = 360

    private let gap: CGFloat = 8          // separación entre el popover y el panel
    private let sideInset: CGFloat = 20   // espacio para la sombra a los lados
    private let bottomInset: CGFloat = 28 // espacio para la sombra abajo

    private var panel: FloatingPanel?
    private weak var parent: NSWindow?
    private let appearance = PanelAppearance()
    private var observers: [NSObjectProtocol] = []
    private var hideWork: DispatchWorkItem?
    /// Estado propio: `panel.isVisible` no sirve porque macOS oculta al hijo junto con el popover.
    private var isShown = false
    /// Monitor de clics fuera de la app (escritorio, otras apps).
    private var globalClickMonitor: Any?
    /// Avisa al modelo que la búsqueda se cerró por salir del popover.
    private var onParentResign: (@MainActor () -> Void)?
    /// Observadores que viven mientras exista el popover (no solo mientras el panel está abierto).
    private var parentObservers: [NSObjectProtocol] = []

    func show<Content: View>(below parent: NSWindow,
                             onParentResign: @escaping @MainActor () -> Void,
                             @ViewBuilder content: () -> Content) {
        hideWork?.cancel()
        self.parent = parent
        isShown = true

        let panel = self.panel ?? makePanel()
        let root = FloatingPanelContainer(
            appearance: appearance,
            height: contentHeight,
            sideInset: sideInset,
            bottomInset: bottomInset,
            content: content()
        )
        .environment(\.colorScheme, .dark)

        let host = FirstMouseHostingView(rootView: AnyView(root))
        host.sizingOptions = [] // el panel define su tamaño, no el contenido
        panel.contentView = host
        panel.level = parent.level
        panel.appearance = parent.appearance

        reposition()

        if panel.parent !== parent {
            panel.parent?.removeChildWindow(panel)
            parent.addChildWindow(panel, ordered: .above)
        }
        panel.orderFront(nil)

        self.onParentResign = onParentResign
        observe(parent)
        observeParentLifetime(parent)

        // Aparece en el siguiente ciclo para que la animación tenga un estado inicial.
        DispatchQueue.main.async { [appearance] in
            withAnimation(.snappy(duration: 0.28)) {
                appearance.isVisible = true
            }
        }
    }

    /// Cierre normal (esc, ×, clic en el popover): con animación de salida.
    func hide() {
        guard isShown else { return }
        isShown = false
        removeObservers()

        withAnimation(.easeIn(duration: 0.16)) {
            appearance.isVisible = false
        }

        // Se retira la ventana cuando termina la animación de salida.
        let work = DispatchWorkItem { [weak self] in
            self?.detach()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    /// Cierre inmediato, sin animación: se usa cuando el popover se oculta (clic fuera).
    /// Separa el panel del popover para que no reaparezca con él la próxima vez que se abra.
    func closeImmediately(reason: String = "") {
        guard isShown else { return }
        #if DEBUG
        print("[Knob] Panel de búsqueda cerrado por: \(reason)")
        #endif
        isShown = false
        hideWork?.cancel()
        removeObservers()

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            appearance.isVisible = false
        }
        detach()
    }

    private func detach() {
        guard let panel else { return }
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
    }

    // MARK: Ventana

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false          
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        self.panel = panel
        return panel
    }

    /// Alinea el panel con el popover: mismo ancho, pegado a su borde inferior.
    private func reposition() {
        guard let panel, let parent else { return }
        let f = parent.frame
        let frame = NSRect(
            x: f.minX - sideInset,
            y: f.minY - gap - contentHeight - bottomInset,
            width: f.width + sideInset * 2,
            height: contentHeight + bottomInset
        )
        panel.setFrame(frame, display: true)
    }

    // MARK: Observadores del popover

    /// Señales mientras el panel está abierto. Cualquiera que llegue primero lo cierra.
    private func observe(_ parent: NSWindow) {
        removeObservers()
        let center = NotificationCenter.default

        // El popover cambia de alto (por ejemplo, al aparecer los recientes): seguirlo.
        observers.append(center.addObserver(forName: NSWindow.didResizeNotification, object: parent, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        })

        // 1. El popover pierde el foco.
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: parent, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.parentDidHide(reason: "el popover perdió el foco") }
        })

        // 2. La app deja de estar activa.
        observers.append(center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.parentDidHide(reason: "la app dejó de estar activa") }
        })

        // 3. El popover deja de verse en pantalla.
        observers.append(center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: parent, queue: .main) { [weak self, weak parent] _ in
            MainActor.assumeIsolated {
                guard let parent, !parent.occlusionState.contains(.visible) else { return }
                self?.parentDidHide(reason: "el popover se ocultó")
            }
        })

        // 4. Clic fuera de la app (escritorio, otras apps). Los monitores globales se ejecutan en el hilo principal.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.parentDidHide(reason: "clic fuera de la app") }
        }
    }

    /// Red de seguridad: si el popover vuelve a aparecer y el panel quedó unido sin estar abierto, separarlo.
    private func observeParentLifetime(_ parent: NSWindow) {
        guard parentObservers.isEmpty else { return }
        let center = NotificationCenter.default

        parentObservers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: parent, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isShown else { return }
                self.detach()
            }
        })
    }

    private func parentDidHide(reason: String) {
        guard isShown else { return }
        closeImmediately(reason: reason)
        onParentResign?()
    }

    private func removeObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }
}

// MARK: - Piezas de AppKit

/// Panel que nunca toma el foco.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Acepta el primer clic aunque la ventana no sea key, para que los botones respondan de inmediato.
///
/// No es genérica a propósito: con `FirstMouseHostingView<Content>` (subclase genérica de
/// `NSHostingView`) el optimizador de Swift 6.2 truena al compilar en Release (EarlyPerfInliner
/// en el `deinit`). Con `AnyView` fijo la clase deja de ser genérica y compila igual en Debug y Release.
private final class FirstMouseHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
@Observable
private final class PanelAppearance {
    var isVisible = false
}

// MARK: - Contenedor con animación de entrada/salida

private struct FloatingPanelContainer<Content: View>: View {

    let appearance: PanelAppearance
    let height: CGFloat
    let sideInset: CGFloat
    let bottomInset: CGFloat
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
                // Entra deslizándose desde debajo del popover; sale igual, más rápido.
                .opacity(appearance.isVisible ? 1 : 0)
                .offset(y: appearance.isVisible || reduceMotion ? 0 : -10)
                .scaleEffect(appearance.isVisible || reduceMotion ? 1 : 0.98, anchor: .top)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, sideInset)
        .padding(.bottom, bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
