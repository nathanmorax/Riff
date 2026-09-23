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
/// transición, en vez de abrir una ventana aparte.
struct PopoverRootView: View {

    let radio: RadioPlayer

    @State private var isSearching = false

    var body: some View {
        Group {
            if isSearching {
                SearchView(radio: radio) {
                    close()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            } else {
                PlayerView(radio: radio) {
                    open()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .frame(width: 300)
        .clipped()
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
