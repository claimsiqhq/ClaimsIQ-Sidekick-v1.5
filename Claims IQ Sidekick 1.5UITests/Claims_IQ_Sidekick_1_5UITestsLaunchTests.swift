//
//  Claims_IQ_Sidekick_1_5UITestsLaunchTests.swift
//  Claims IQ Sidekick 1.5UITests
//
//  Created by John Shoust on 2025-11-07.
//

import XCTest

final class Claims_IQ_Sidekick_1_5UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
