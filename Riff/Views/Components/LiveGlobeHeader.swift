//
//  LiveGlobeHeader.swift
//  Riff
//
//  Created by Satori Tech 341 on 23/09/26.
//
import SwiftUI

// MARK: - Encabezado con globo en vivo

/// Globo de puntos que gira despacio y enciende una ciudad cada pocos segundos,
/// con su nombre al lado ("En vivo ahora en Tokio").
struct LiveGlobeHeader: View {

    var globeSize: CGFloat = 52

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let state = GlobeModel.state(at: t)

            HStack(spacing: 12) {
                Canvas { ctx, size in
                    GlobeModel.draw(in: &ctx, size: size, state: state)
                }
                .frame(width: globeSize, height: globeSize)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("En vivo ahora en")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(state.city.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .id(state.city.name)
                        .transition(.opacity)
                }
                .animation(.easeInOut(duration: 0.35), value: state.city.name)
                .accessibilityElement(children: .combine)

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Modelo y dibujo

private enum GlobeModel {

    struct City {
        let name: String
        let lat: Double
        let lon: Double
    }

    struct State {
        let rotation: Double   // grados
        let city: City
        let pulse: Double      // 0…1, progreso del anillo
    }

    // Ajustes
    static let secondsPerCity = 3.2
    static let degreesPerSecond = 12.0
    static let tilt = -18.0
    static let pulseDuration = 1.6

    /// Capitales de radio de los países con más estaciones y más escucha, repartidas por todo el globo
    /// (norte y sur, este y oeste) para que la ciudad encendida cambie de lugar en cada vuelta.
    static let cities: [City] = [
        City(name: String(localized: "Nueva York"), lat: 40.7, lon: -74.0),
        City(name: String(localized: "Los Ángeles"), lat: 34.1, lon: -118.2),
        City(name: String(localized: "Ciudad de México"), lat: 19.4, lon: -99.1),
        City(name: String(localized: "São Paulo"), lat: -23.6, lon: -46.6),
        City(name: String(localized: "Buenos Aires"), lat: -34.6, lon: -58.4),
        City(name: String(localized: "Londres"), lat: 51.5, lon: -0.1),
        City(name: String(localized: "París"), lat: 48.9, lon: 2.4),
        City(name: String(localized: "Berlín"), lat: 52.5, lon: 13.4),
        City(name: String(localized: "Atenas"), lat: 38.0, lon: 23.7),
        City(name: String(localized: "Moscú"), lat: 55.8, lon: 37.6),
        City(name: String(localized: "Johannesburgo"), lat: -26.2, lon: 28.0),
        City(name: String(localized: "Bombay"), lat: 19.1, lon: 72.9),
        City(name: String(localized: "Yakarta"), lat: -6.2, lon: 106.8),
        City(name: String(localized: "Manila"), lat: 14.6, lon: 121.0),
        City(name: String(localized: "Tokio"), lat: 35.7, lon: 139.7),
        City(name: String(localized: "Sídney"), lat: -33.9, lon: 151.2)
    ]

    /// Retícula de puntos: menos puntos cerca de los polos para que se vea pareja.
    static let dots: [(lat: Double, lon: Double)] = {
        var result: [(Double, Double)] = []
        var lat = -80.0
        while lat <= 80 {
            let count = max(6, Int((36 * cos(lat * .pi / 180)).rounded()))
            for i in 0..<count {
                result.append((lat, -180 + Double(i) * 360 / Double(count)))
            }
            lat += 10
        }
        return result
    }()

    // MARK: Estado en el tiempo t

    static func rotation(at t: Double) -> Double {
        20 - (t * degreesPerSecond).truncatingRemainder(dividingBy: 360)
    }

    static func state(at t: Double) -> State {
        let start = floor(t / secondsPerCity) * secondsPerCity
        let previous = frontmostCity(at: start - secondsPerCity, excluding: nil)
        let city = frontmostCity(at: start, excluding: previous)
        let pulse = (t - start).truncatingRemainder(dividingBy: pulseDuration) / pulseDuration
        return State(rotation: rotation(at: t), city: city, pulse: pulse)
    }

    /// La ciudad más cercana al frente del globo en ese momento, sin repetir la anterior.
    static func frontmostCity(at t: Double, excluding: City?) -> City {
        let rot = rotation(at: t)
        return cities
            .filter { $0.name != excluding?.name }
            .max { project(lat: $0.lat, lon: $0.lon, rotation: rot).z < project(lat: $1.lat, lon: $1.lon, rotation: rot).z }
            ?? cities[0]
    }

    // MARK: Proyección ortográfica (resultado entre -1 y 1)

    static func project(lat: Double, lon: Double, rotation: Double) -> (x: Double, y: Double, z: Double) {
        let l = (lon + rotation) * .pi / 180
        let p = lat * .pi / 180
        let k = tilt * .pi / 180

        let x = cos(p) * sin(l)
        let y = sin(p)
        let z = cos(p) * cos(l)

        let y2 = y * cos(k) - z * sin(k)
        let z2 = y * sin(k) + z * cos(k)
        return (x, y2, z2)
    }

    // MARK: Dibujo

    static func draw(in ctx: inout GraphicsContext, size: CGSize, state: State) {
        let radius = min(size.width, size.height) / 2 - 2
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        func point(_ p: (x: Double, y: Double, z: Double)) -> CGPoint {
            CGPoint(x: center.x + p.x * radius, y: center.y - p.y * radius)
        }

        // Puntos del globo (solo la cara visible)
        for dot in dots {
            let p = project(lat: dot.lat, lon: dot.lon, rotation: state.rotation)
            guard p.z > 0 else { continue }
            let c = point(p)
            let r: CGFloat = 0.65
            ctx.fill(
                Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.12 + p.z * 0.35))
            )
        }

        // Ciudad encendida con anillo
        let p = project(lat: state.city.lat, lon: state.city.lon, rotation: state.rotation)
        guard p.z > 0 else { return }
        let c = point(p)

        let ring = 1.5 + state.pulse * 6
        ctx.stroke(
            Path(ellipseIn: CGRect(x: c.x - ring, y: c.y - ring, width: ring * 2, height: ring * 2)),
            with: .color(.white.opacity((1 - state.pulse) * p.z)),
            lineWidth: 0.75
        )

        let r: CGFloat = 1.6
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
            with: .color(.white)
        )
    }
}

#Preview {
    LiveGlobeHeader()
        .padding(20)
        .frame(width: 300)
        .background(Color.black)
}
