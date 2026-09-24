//
//  Theme.swift
//  Riff
//
//  Created by Nathan Mora on 24/09/26.
//
import SwiftUI

// MARK: - Colores que se adaptan a modo claro / oscuro

/// Fondo de Knob: negro en modo oscuro, crema muy claro en modo claro.
/// Es un `ShapeStyle` que se resuelve con el `colorScheme` del entorno, así respeta tanto
/// la apariencia del sistema como un `.environment(\.colorScheme, …)` forzado (por ejemplo al exportar capturas).
///
/// El resto de la interfaz usa `Color.primary` con opacidad para rellenos y bordes:
/// blanco translúcido en oscuro, negro translúcido en claro.
struct ThemeBackground: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark
            ? .black
            : Color(red: 0.965, green: 0.957, blue: 0.937) // #F6F4EF
    }
}

extension ShapeStyle where Self == ThemeBackground {
    /// Fondo del popover y del panel de búsqueda.
    static var themeBackground: ThemeBackground { ThemeBackground() }
}
