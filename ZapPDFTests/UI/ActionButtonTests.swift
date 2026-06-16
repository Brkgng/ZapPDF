//
//  ActionButtonTests.swift
//  ZapPDFTests
//
//  Unit tests for ActionButton component.
//

import XCTest
import SwiftUI
@testable import ZapPDF

final class ActionButtonTests: XCTestCase {

    func testInitializerStoresDefaultsAndOverrides() {
        let defaultButton = ActionButton(action: .merge, isEnabled: true, onTap: {})
        XCTAssertEqual(defaultButton.action, .merge)
        XCTAssertTrue(defaultButton.isEnabled)
        XCTAssertEqual(defaultButton.style, .tinted)
        XCTAssertTrue(defaultButton.showLabel)

        let customButton = ActionButton(
            action: .split,
            isEnabled: false,
            style: .secondary,
            showLabel: false,
            onTap: {}
        )
        XCTAssertEqual(customButton.action, .split)
        XCTAssertFalse(customButton.isEnabled)
        XCTAssertEqual(customButton.style, .secondary)
        XCTAssertFalse(customButton.showLabel)
    }

    func testAllActionsHaveValidProperties() {
        for action in UserAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty, "\(action) should have a display name")
            XCTAssertFalse(action.iconName.isEmpty, "\(action) should have an icon name")
            XCTAssertFalse(action.description.isEmpty, "\(action) should have a description")
        }
    }
}
