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
    
    // MARK: - Initialization Tests
    
    func testDefaultProperties() {
        // Given
        var wasTapped = false
        
        // When
        let button = ActionButton(
            action: .merge,
            isEnabled: true,
            onTap: { wasTapped = true }
        )
        
        // Then
        XCTAssertEqual(button.action, .merge)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.style, .primary)
        XCTAssertTrue(button.showLabel)
    }
    
    func testCustomProperties() {
        // When
        let button = ActionButton(
            action: .split,
            isEnabled: false,
            style: .secondary,
            showLabel: false,
            onTap: {}
        )
        
        // Then
        XCTAssertEqual(button.action, .split)
        XCTAssertFalse(button.isEnabled)
        XCTAssertEqual(button.style, .secondary)
        XCTAssertFalse(button.showLabel)
    }
    
    // MARK: - Action Type Tests
    
    func testMergeAction() {
        let button = ActionButton(action: .merge, isEnabled: true, onTap: {})
        XCTAssertEqual(button.action.displayName, "Merge PDFs")
        XCTAssertEqual(button.action.iconName, "doc.on.doc")
        XCTAssertEqual(button.action.accentColor, .blue)
    }
    
    func testSplitAction() {
        let button = ActionButton(action: .split, isEnabled: true, onTap: {})
        XCTAssertEqual(button.action.displayName, "Split PDF")
        XCTAssertEqual(button.action.iconName, "scissors")
        XCTAssertEqual(button.action.accentColor, .orange)
    }
    
    func testCompressAction() {
        let button = ActionButton(action: .compress, isEnabled: true, onTap: {})
        XCTAssertEqual(button.action.displayName, "Compress PDF")
        XCTAssertEqual(button.action.iconName, "arrow.down.doc")
        XCTAssertEqual(button.action.accentColor, .green)
    }
    
    func testConvertAction() {
        let button = ActionButton(action: .convert, isEnabled: true, onTap: {})
        XCTAssertEqual(button.action.displayName, "Convert PDF")
        XCTAssertEqual(button.action.iconName, "arrow.triangle.2.circlepath")
        XCTAssertEqual(button.action.accentColor, .purple)
    }
    
    // MARK: - Style Tests
    
    func testPrimaryStyle() {
        let button = ActionButton(action: .merge, isEnabled: true, style: .primary, onTap: {})
        XCTAssertEqual(button.style, .primary)
    }
    
    func testSecondaryStyle() {
        let button = ActionButton(action: .merge, isEnabled: true, style: .secondary, onTap: {})
        XCTAssertEqual(button.style, .secondary)
    }
    
    func testCompactStyle() {
        let button = ActionButton(action: .merge, isEnabled: true, style: .compact, onTap: {})
        XCTAssertEqual(button.style, .compact)
    }
    
    // MARK: - Enabled/Disabled State Tests
    
    func testEnabledState() {
        let button = ActionButton(action: .merge, isEnabled: true, onTap: {})
        XCTAssertTrue(button.isEnabled)
    }
    
    func testDisabledState() {
        let button = ActionButton(action: .merge, isEnabled: false, onTap: {})
        XCTAssertFalse(button.isEnabled)
    }
    
    // MARK: - Pro Badge Tests
    
    func testFreeTierActionsDoNotShowProBadge() {
        // Given
        let freeActions: [UserAction] = [.merge, .split, .compress]
        
        for action in freeActions {
            // Then
            XCTAssertTrue(action.isFreeTierAction, "\(action) should be a free tier action")
        }
    }
    
    func testProActionsShowProBadge() {
        // Given
        let proActions: [UserAction] = [.convert]
        
        for action in proActions {
            // Then
            XCTAssertFalse(action.isFreeTierAction, "\(action) should be a pro action")
        }
    }
    
    // MARK: - All Actions Tests
    
    func testAllActionsHaveValidProperties() {
        for action in UserAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty, "\(action) should have a display name")
            XCTAssertFalse(action.iconName.isEmpty, "\(action) should have an icon name")
            XCTAssertFalse(action.description.isEmpty, "\(action) should have a description")
        }
    }
}

// MARK: - StyledActionButton Tests

final class StyledActionButtonTests: XCTestCase {
    
    func testDefaultProperties() {
        var wasTapped = false
        
        let button = StyledActionButton(
            action: .merge,
            isEnabled: true,
            onTap: { wasTapped = true }
        )
        
        XCTAssertEqual(button.action, .merge)
        XCTAssertTrue(button.isEnabled)
        XCTAssertEqual(button.style, .primary)
        XCTAssertTrue(button.showLabel)
        XCTAssertTrue(button.showProBadge)
    }
    
    func testProBadgeCanBeHidden() {
        let button = StyledActionButton(
            action: .convert,
            isEnabled: true,
            showProBadge: false,
            onTap: {}
        )
        
        XCTAssertFalse(button.showProBadge)
    }
}

// MARK: - ActionButtonStyle Tests

final class ActionButtonStyleTests: XCTestCase {
    
    func testAllStyleCases() {
        let styles: [ActionButtonStyle] = [.primary, .secondary, .compact]
        XCTAssertEqual(styles.count, 3)
    }
}
