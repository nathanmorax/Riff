////
////  RadioViews.swift
////  Riff — componentes de la vista retro (System 7) y el view model.
////  Sin @main aquí: el punto de entrada vive en RiffApp.swift.
////
//
//import SwiftUI
//import Combine
//
//// MARK: - Model
//
//struct Station: Identifiable, Equatable, Hashable {
//    // El id es el propio nombre, no un UUID aleatorio. Con UUID, dos
//    // `Station(name: "Fresh FM", ...)` construidos por separado (uno en la
//    // lista, otro como valor por defecto de `selected`) nunca serían ==
//    // entre sí, y ningún renglón se vería marcado con ✓ al abrir la app.
//    var id: String { name }
//    let name: String
//    let bitrateLabel: String
//}
//
//// MARK: - View model
//
///// Holds playback + selection state. Kept separate from the views so it can
///// later be swapped for a real AVPlayer-backed implementation without
///// touching any SwiftUI code below.
//@MainActor
//final class RadioPlayerModel: ObservableObject {
//    @Published var stations: [Station] = [
//        Station(name: "Fresh FM", bitrateLabel: "128k"),
//        Station(name: "Hangover Club", bitrateLabel: "96k"),
//        Station(name: "Tokyo Disco", bitrateLabel: "128k"),
//        Station(name: "Friday Nite Heat", bitrateLabel: "112k"),
//        Station(name: "Indie Summer", bitrateLabel: "128k"),
//        Station(name: "Tokyo Disco", bitrateLabel: "128k")
//        
//    ]
//    // Mismo valor que el primer elemento de `stations` arriba, pero como
//    // literal propio — así no hace falta un init() que lea `self.stations`
//    // antes de que `selected` tenga valor (esa lectura es justo lo que
//    // producía el error de inicialización en dos fases).
//    @Published var selected: Station = Station(name: "Fresh FM", bitrateLabel: "128k")
//    @Published var isPlaying: Bool = true
//    
//    func select(_ station: Station) {
//        selected = station
//        isPlaying = true
//    }
//    
//    func togglePlayback() {
//        isPlaying.toggle()
//    }
//}
//
//// MARK: - Dithered pattern (the classic 1-on/1-off title-bar stripe)
//
///// Recreates the diagonal/horizontal dither you see in real System 7 chrome.
///// Drawn with Canvas rather than an image asset so it scales losslessly
///// and needs zero bundled resources.
//private struct DitherStripe: View {
//    var spacing: CGFloat = 2
//    
//    var body: some View {
//        Canvas { context, size in
//            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
//            var y: CGFloat = 0
//            while y < size.height {
//                let stripe = CGRect(x: 0, y: y, width: size.width, height: 1)
//                context.fill(Path(stripe), with: .color(.black))
//                y += spacing
//            }
//        }
//    }
//}
//
//// MARK: - Title bar
//
//private struct RetroTitleBar: View {
//    let title: String
//    /// Wired to the real close action from `RadioMenuBarView` below —
//    /// this is the piece your draft already had right.
//    let onClose: () -> Void
//    
//    var body: some View {
//        ZStack {
//            DitherStripe()
//            HStack(spacing: 6) {
//                RetroChromeIcon(systemName: "doc.plaintext")
//                Spacer()
//                Text(title)
//                    .font(.system(size: 13, weight: .black, design: .monospaced))
//                    .tracking(1.5)
//                    .padding(.horizontal, 10)
//                    .background(Color.white)
//                Spacer()
//                RetroChromeIcon(systemName: "xmark", action: onClose)
//            }
//            .padding(.horizontal, 6)
//        }
//        .frame(height: 22)
//        .overlay(alignment: .bottom) {
//            Rectangle().frame(height: 2).foregroundColor(.black)
//        }
//    }
//}
//
///// The little bordered glyphs on either end of the title bar.
///// Pass `action` to make one of them tappable (the close box); omit it
///// for a purely decorative icon like the doc glyph on the left.
//private struct RetroChromeIcon: View {
//    let systemName: String
//    var action: (() -> Void)? = nil
//    
//    var body: some View {
//        Group {
//            if let action {
//                Button(action: action) { glyph }
//                    .buttonStyle(.plain)
//            } else {
//                glyph
//            }
//        }
//    }
//    
//    private var glyph: some View {
//        Image(systemName: systemName)
//            .font(.system(size: 9, weight: .bold))
//            .foregroundColor(.black)
//            .padding(3)
//            .background(Color.white)
//            .overlay(Rectangle().stroke(Color.black, lineWidth: 1.5))
//    }
//}
//
//// MARK: - Menu row ("Canal  Volumen  Ayuda")
//
//private struct RetroMenuRow: View {
//    let items: [String]
//    let activeIndex: Int
//    
//    var body: some View {
//        HStack(spacing: 0) {
//            ForEach(items.indices, id: \.self) { i in
//                Text(items[i])
//                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
//                    .foregroundColor(i == activeIndex ? .white : .black)
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 6)
//                    .background(i == activeIndex ? Color.black : Color.white)
//            }
//            Spacer(minLength: 0)
//        }
//        .overlay(alignment: .bottom) {
//            Rectangle().frame(height: 2).foregroundColor(.black)
//        }
//    }
//}
//
//// MARK: - Station list (the dropdown content, always-visible in this mock)
//
//private struct RetroStationList: View {
//    
//    let stations: [Station]
//    let selected: Station
//    let onSelect: (Station) -> Void
//    
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 0) {
//                ForEach(stations) { station in
//                    RetroStationRow(
//                        station: station,
//                        isSelected: station == selected,
//                        onSelect: {
//                            onSelect(station)
//                        }
//                    )
//                }
//            }
//        }
//        .frame(maxHeight: 300)
//    }
//}
//
//private struct RetroStationRow: View {
//    
//    let station: Station
//    let isSelected: Bool
//    let onSelect: () -> Void
//    
//    @State private var isHovering = false
//    
//    var body: some View {
//        
//        Button(action: onSelect) {
//            
//            HStack(spacing: 8) {
//                ZStack {
//                    if isSelected {
//                        Image(systemName: "circle.fill")
//                            .symbolEffect(.pulse, isActive: isSelected)
//                            .foregroundStyle(.white)
//                    }
//                }
//                .frame(width: 13)
//                
//                Text(station.name)
//                    .font(.system(size: 15, weight: .bold, design: .monospaced))
//                
//                Spacer(minLength: 0)
//            }
//            .padding(.horizontal, 14)
//            .padding(.vertical, 10)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(rowBackground)
//            .foregroundColor(isSelected ? .white : .black)
//        }
//        .buttonStyle(.plain)
//        .onHover { isHovering = $0 }
//    }
//    
//    
//    private var rowBackground: Color {
//        if isSelected { return .black }
//        if isHovering { return Color.black.opacity(0.08) }
//        return .white
//    }
//}
//
//// MARK: - Status bar ("▶ Reproduciendo   128k")
//
//private struct RetroStatusBar: View {
//    let isPlaying: Bool
//    let bitrateLabel: String
//    
//    var body: some View {
//        HStack {
//            Text(isPlaying ? "▶ Reproduciendo" : "❙❙ Pausado")
//                .font(.system(size: 12, weight: .bold, design: .monospaced))
//                .foregroundStyle(.black)
//            
//            
//            Spacer()
//            Text(bitrateLabel)
//                .font(.system(size: 12, weight: .bold, design: .monospaced))
//                .foregroundStyle(.black)
//        }
//        .padding(.horizontal, 10)
//        .padding(.vertical, 7)
//        .overlay(alignment: .top) {
//            Rectangle().frame(height: 2).foregroundColor(.black)
//        }
//    }
//}
//
//// MARK: - Root popover view
//
//struct RadioMenuBarView: View {
//    @ObservedObject var model: RadioPlayerModel
//    /// Ahora viene de fuera (AppDelegate.closeWindow) en vez de llamar
//    /// NSApp.keyWindow?.orderOut(nil) directamente — así también se limpia
//    /// el monitor de "clic afuera" cada vez que se cierra.
//    let onClose: () -> Void
//    
//    var body: some View {
//        VStack(spacing: 0) {
//            RetroTitleBar(title: "RADIO", onClose: onClose)
//            RetroMenuRow(items: ["Radio", "Favorites", "Help"], activeIndex: 0)
//            RetroStationList(
//                stations: model.stations,
//                selected: model.selected,
//                onSelect: model.select
//            )
//            RetroStatusBar(isPlaying: model.isPlaying, bitrateLabel: model.selected.bitrateLabel)
//        }
//        .frame(width: 320)
//        .background(Color.white)
//        .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
//        .fixedSize()
//    }
//}
//
//// MARK: - Preview
//
////#Preview {
////    RadioMenuBarView(model: RadioPlayerModel(), onClose: {})
////        .padding(40)
////        .background(Color(white: 0.9))
////}
//
//#Preview {
//    RadioView()
//        .frame(width: 420)
//    
//}
//
//
//
//struct RadioView: View {
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            
//            // Encabezado
//            VStack(alignment: .leading, spacing: 4) {
//                Text("NTS Radio 1")
//                    .font(.title)
//                    .bold()
//                Text("104.2 FM")
//                    .font(.headline)
//                Text("Global music for global people")
//                    .font(.subheadline)
//                    .foregroundColor(.gray)
//                
//                Button("FOLLOW STATION") {
//                    // acción
//                }
//                .padding(.vertical, 6)
//                .padding(.horizontal, 12)
//                .background(Color.white)
//                .foregroundColor(.black)
//                .cornerRadius(6)
//            }
//            
//            // Lista con scroll
//            Text("TODAY'S SCHEDULE")
//                .font(.headline)
//            
//            ScrollView {
//                VStack(alignment: .leading, spacing: 12) {
//                    ForEach(scheduleData, id: \.id) { show in
//                        HStack {
//                            Text(show.time)
//                                .frame(width: 50, alignment: .leading)
//                            VStack(alignment: .leading) {
//                                Text(show.title).bold()
//                                Text(show.subtitle).foregroundColor(.gray)
//                            }
//                        }
//                    }
//                }
//            }
//            
//            // On Air
//            VStack(alignment: .leading, spacing: 4) {
//                Text("ON AIR").font(.headline)
//                Text("Live from London").font(.subheadline)
//            }
//            
//            Spacer()
//        }
//        .padding() // padding general
//        .background(Color.secondary) // fondo oscuro
//        .foregroundColor(.white) // texto claro
//
//    }
//}
//
//
//// Datos de ejemplo
//struct Show: Identifiable {
//    let id = UUID()
//    let time: String
//    let title: String
//    let subtitle: String
//}
//
//let scheduleData = [
//    Show(time: "14:00", title: "Solomon Paradox", subtitle: "Quiet Reflection Live"),
//    Show(time: "16:00", title: "Moxie", subtitle: "NTS On Air"),
//    Show(time: "18:00", title: "Otro Show", subtitle: "Descripción breve")
//]
//
//struct RadioView_Previews: PreviewProvider {
//    static var previews: some View {
//        RadioView()
//    }
//}
//
//
