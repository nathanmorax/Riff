//
//  RiffUITests.swift
//  RiffUITests
//
//  Created by Nathan Mora on 16/09/26.
//

import XCTest

/// Knob vive en la barra de menú (LSUIElement): no tiene ventana ni ícono en el Dock al arrancar.
/// Por eso aquí solo se comprueba que arranca y se mantiene viva. El comportamiento se prueba
/// en los tests unitarios (RiffTests), que son rápidos y estables.
///
/// Se quitó `testLaunchPerformance` de la plantilla: `XCTApplicationLaunchMetric` no siempre
/// registra el arranque de una app sin ventana y falla con "Received unexpected number of metrics".
final class RiffUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesAndKeepsRunning() throws {
        let app = XCUIApplication()
        app.launch()

        // Una app de barra de menú puede quedar en primer o segundo plano; lo importante es que siga viva.
        let running = app.wait(for: .runningForeground, timeout: 5) || app.state == .runningBackground
        XCTAssertTrue(running, "La app se cerró al arrancar (estado: \(app.state.rawValue))")

        app.terminate()
    }
}
