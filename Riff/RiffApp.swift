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
            PlayerView(radio: radio)
        } label: {
            MenuBarLabel(radio: radio)
        }
        .menuBarExtraStyle(.window)

        Window("Buscar estación", id: "search") {
            SearchView(radio: radio)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.suppressed)
        .windowLevel(.floating)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

/// Lo que se ve en la barra de menú
struct MenuBarLabel: View {

    let radio: RadioPlayer

    var body: some View {
        if radio.isActive {
            HStack(spacing: 6) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("\(radio.menuBarText)")
            }
        } else {
            Image(systemName: "dot.radiowaves.left.and.right")
        }
    }
}
