//
//  RiffUITestsLaunchTests.swift
//  RiffUITests
//
//  Created by Nathan Mora on 16/09/26.
//

import XCTest

final class RiffUITestsLaunchTests: XCTestCase {

    /// Una sola corrida: la app es siempre oscura y no tiene ventana, así que repetirla por cada
    /// apariencia solo alarga los tests.
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Sin ventana propia: se guarda la pantalla completa, donde se ven las perillas en la barra de menú.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Barra de menú al arrancar"
        attachment.lifetime = .keepAlways
        add(attachment)

        app.terminate()
    }
}
