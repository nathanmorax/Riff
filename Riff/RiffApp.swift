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
            ContentView1(radio: radio)
        } label: {
            HStack(spacing: 6) {
                // Símbolo SF
                //                Image(systemName: "wave.3.up")
                //                    .foregroundStyle(.primary)
                //
                //                // Título dinámico (estación o canción)
                //                Text(radio.menuBarText)
                
                MenuBarLabel(radio: radio)
                
                
            }
            .background(.black)
        }
        
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    
    let radio: RadioPlayer
    
    var body: some View {
        if radio.isPlaying {
            Text(radio.menuBarText)
                .font(.system(size: 12, design: .monospaced))
            
            // Punto que cambia de color
            Image(systemName: "circle.fill")
                .foregroundColor(radio.isPlaying ? .green : .white)
            
        } else {
            Image(systemName: "dot.radiowaves.left.and.right")
        }
    }
}
