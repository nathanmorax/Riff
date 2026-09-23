//
//  RiffApp.swift
//  Riff
//
//  Created by Satori Tech 341 on 19/09/26.
//
import SwiftUI

@main
struct RiffApp: App {

    @State private var radio = RadioPlayer()

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(radio: radio)
        } label: {
            MenuBarLabel(radio: radio)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Lo que se ve en la barra de menú.
struct MenuBarLabel: View {

    let radio: RadioPlayer

    var body: some View {
        if radio.isActive {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text(radio.menuBarText)
            }
        } else {
            Image(systemName: "dot.radiowaves.left.and.right")
        }
    }
}

//
//  PopoverRootView.swift
//  Riff
//
//  Created by Satori Tech 341 on 21/09/26.
//
import SwiftUI

/// Contenido del popover. Alterna entre el reproductor y la búsqueda con una
/// transición, y el popover cambia de tamaño según la vista visible.
struct PopoverRootView: View {

    let radio: RadioPlayer

    @State private var isSearching = false
    @State private var size = CGSize(width: 300, height: 260) // tamaño inicial, antes de medir

    var body: some View {
        content
            // Mide el tamaño natural de lo que está visible, sin restringirlo.
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SizeKey.self, value: proxy.size)
                }
            )
            .onPreferenceChange(SizeKey.self) { newSize in
                guard newSize.width > 0, newSize.height > 0, newSize != size else { return }
                withAnimation(.snappy(duration: 0.28)) {
                    size = newSize
                }
            }
            // El contenedor real que ve el popover: aquí sí se fija el tamaño, y es lo que anima.
            .frame(width: size.width, height: size.height)
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if isSearching {
            SearchView(radio: radio) {
                close()
            }
            .frame(width: 340) // la búsqueda puede ser más ancha que el reproductor
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
        } else {
            PlayerView(radio: radio) {
                open()
            }
            .frame(width: 300)
            .transition(.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
    }

    private func open() {
        withAnimation(.snappy(duration: 0.28)) {
            isSearching = true
        }
    }

    private func close() {
        withAnimation(.snappy(duration: 0.28)) {
            isSearching = false
        }
    }
}

/// Reporta el tamaño más grande visible en un momento dado (útil durante la
/// transición, cuando la vista saliente y la entrante coexisten brevemente).
private struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}
