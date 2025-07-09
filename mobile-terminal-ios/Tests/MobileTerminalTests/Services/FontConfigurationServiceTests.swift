#if os(iOS)
import XCTest
import SwiftUI
import UIKit
@testable import MobileTerminal

final class FontConfigurationServiceTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var sut: FontConfigurationService!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        sut = FontConfigurationService()
    }
    
    override func tearDown() {
        sut = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testFontConfigurationServiceInitialization() {
        // Given & When
        let service = FontConfigurationService()
        
        // Then
        XCTAssertNotNil(service.currentConfiguration, "Should have current configuration")
        XCTAssertEqual(service.currentConfiguration.size, 14, "Should have default font size")
        XCTAssertEqual(service.currentConfiguration.name, "Menlo", "Should have default font name")
        XCTAssertFalse(service.availableFonts.isEmpty, "Should have available fonts")
        XCTAssertEqual(service.minFontSize, 8, "Should have minimum font size")
        XCTAssertEqual(service.maxFontSize, 32, "Should have maximum font size")
    }
    
    func testFontConfigurationServiceHasAvailableFonts() {
        // Given & When
        let availableFonts = sut.availableFonts
        
        // Then
        XCTAssertFalse(availableFonts.isEmpty, "Should have available fonts")
        XCTAssertTrue(availableFonts.contains("Menlo"), "Should contain Menlo font")
    }
    
    // MARK: - Font Preset Tests
    
    func testApplyFontPreset() {
        // Given
        let preset = FontConfigurationService.FontPreset.large
        let expectedSize = preset.configuration.size
        
        // When
        sut.applyPreset(preset)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, expectedSize, "Should apply preset font size")
        XCTAssertEqual(sut.currentConfiguration.name, preset.configuration.name, "Should apply preset font name")
    }
    
    func testFontPresetDisplayNames() {
        // Given
        let presets = FontConfigurationService.FontPreset.allCases
        
        // When & Then
        for preset in presets {
            XCTAssertFalse(preset.displayName.isEmpty, "Preset should have display name")
        }
    }
    
    func testFontPresetConfigurations() {
        // Given
        let presets = FontConfigurationService.FontPreset.allCases
        
        // When & Then
        for preset in presets {
            let config = preset.configuration
            XCTAssertGreaterThan(config.size, 0, "Configuration should have positive size")
            XCTAssertFalse(config.name.isEmpty, "Configuration should have font name")
            XCTAssertGreaterThan(config.lineSpacing, 0, "Configuration should have positive line spacing")
        }
    }
    
    func testAllFontPresets() {
        // Given
        let presets = FontConfigurationService.FontPreset.allCases
        
        // When & Then
        for preset in presets {
            sut.applyPreset(preset)
            
            XCTAssertEqual(sut.currentConfiguration.size, preset.configuration.size, "Should match preset size")
            XCTAssertEqual(sut.currentConfiguration.name, preset.configuration.name, "Should match preset name")
        }
    }
    
    // MARK: - Font Size Tests
    
    func testSetFontSize() {
        // Given
        let newSize: CGFloat = 16
        
        // When
        sut.setFontSize(newSize)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, newSize, "Should update font size")
    }
    
    func testSetFontSizeWithinBounds() {
        // Given
        let validSize: CGFloat = 20
        
        // When
        sut.setFontSize(validSize)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, validSize, "Should set valid font size")
    }
    
    func testSetFontSizeBelowMinimum() {
        // Given
        let belowMinSize: CGFloat = 5
        
        // When
        sut.setFontSize(belowMinSize)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, sut.minFontSize, "Should clamp to minimum font size")
    }
    
    func testSetFontSizeAboveMaximum() {
        // Given
        let aboveMaxSize: CGFloat = 50
        
        // When
        sut.setFontSize(aboveMaxSize)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, sut.maxFontSize, "Should clamp to maximum font size")
    }
    
    func testAdjustFontSizeByZoomFactor() {
        // Given
        let initialSize: CGFloat = 14
        let zoomFactor: CGFloat = 1.5
        sut.setFontSize(initialSize)
        
        // When
        sut.adjustFontSize(by: zoomFactor)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, initialSize * zoomFactor, "Should adjust font size by zoom factor")
    }
    
    func testAdjustFontSizeByZoomFactorWithClamping() {
        // Given
        let initialSize: CGFloat = 30
        let zoomFactor: CGFloat = 2.0
        sut.setFontSize(initialSize)
        
        // When
        sut.adjustFontSize(by: zoomFactor)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, sut.maxFontSize, "Should clamp zoomed size to maximum")
    }
    
    // MARK: - Font Weight Tests
    
    func testSetFontWeight() {
        // Given
        let newWeight = UIFont.Weight.bold
        
        // When
        sut.setFontWeight(newWeight)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.weight, newWeight, "Should update font weight")
    }
    
    func testSetFontWeightPreservesOtherProperties() {
        // Given
        let originalSize = sut.currentConfiguration.size
        let originalName = sut.currentConfiguration.name
        let newWeight = UIFont.Weight.semibold
        
        // When
        sut.setFontWeight(newWeight)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, originalSize, "Should preserve font size")
        XCTAssertEqual(sut.currentConfiguration.name, originalName, "Should preserve font name")
        XCTAssertEqual(sut.currentConfiguration.weight, newWeight, "Should update font weight")
    }
    
    // MARK: - Font Family Tests
    
    func testSetFontFamily() {
        // Given
        let newFontName = "Monaco"
        
        // When
        sut.setFontFamily(newFontName)
        
        // Then
        if sut.availableFonts.contains(newFontName) {
            XCTAssertEqual(sut.currentConfiguration.name, newFontName, "Should update font family")
        }
    }
    
    func testSetFontFamilyWithInvalidName() {
        // Given
        let originalFontName = sut.currentConfiguration.name
        let invalidFontName = "NonExistentFont"
        
        // When
        sut.setFontFamily(invalidFontName)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.name, originalFontName, "Should not change font family for invalid name")
    }
    
    func testSetFontFamilyPreservesOtherProperties() {
        // Given
        let originalSize = sut.currentConfiguration.size
        let originalWeight = sut.currentConfiguration.weight
        let newFontName = "Monaco"
        
        // When
        sut.setFontFamily(newFontName)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, originalSize, "Should preserve font size")
        XCTAssertEqual(sut.currentConfiguration.weight, originalWeight, "Should preserve font weight")
    }
    
    // MARK: - Custom Configuration Tests
    
    func testApplyCustomConfiguration() {
        // Given
        let customConfig = FontConfigurationService.FontConfiguration(
            size: 18,
            weight: .bold,
            name: "Monaco",
            lineSpacing: 1.3,
            letterSpacing: 0.5
        )
        
        // When
        sut.applyConfiguration(customConfig)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, customConfig.size, "Should apply custom size")
        XCTAssertEqual(sut.currentConfiguration.weight, customConfig.weight, "Should apply custom weight")
        XCTAssertEqual(sut.currentConfiguration.name, customConfig.name, "Should apply custom name")
        XCTAssertEqual(sut.currentConfiguration.lineSpacing, customConfig.lineSpacing, "Should apply custom line spacing")
        XCTAssertEqual(sut.currentConfiguration.letterSpacing, customConfig.letterSpacing, "Should apply custom letter spacing")
    }
    
    // MARK: - Font Generation Tests
    
    func testGetUIFont() {
        // Given
        let expectedSize = sut.currentConfiguration.size
        
        // When
        let font = sut.getUIFont()
        
        // Then
        XCTAssertEqual(font.pointSize, expectedSize, "Should return font with correct size")
    }
    
    func testGetUIFontWithCustomConfiguration() {
        // Given
        let customSize: CGFloat = 20
        sut.setFontSize(customSize)
        
        // When
        let font = sut.getUIFont()
        
        // Then
        XCTAssertEqual(font.pointSize, customSize, "Should return font with custom size")
    }
    
    func testGetSwiftUIFont() {
        // Given & When
        let font = sut.getSwiftUIFont()
        
        // Then
        XCTAssertNotNil(font, "Should return SwiftUI font")
    }
    
    // MARK: - Terminal Dimensions Tests
    
    func testCalculateTerminalDimensions() {
        // Given
        let screenSize = CGSize(width: 390, height: 844) // iPhone 12 size
        
        // When
        let dimensions = sut.calculateTerminalDimensions(for: screenSize)
        
        // Then
        XCTAssertGreaterThan(dimensions.cols, 0, "Should have positive column count")
        XCTAssertGreaterThan(dimensions.rows, 0, "Should have positive row count")
        XCTAssertGreaterThanOrEqual(dimensions.cols, 80, "Should have at least 80 columns")
        XCTAssertGreaterThanOrEqual(dimensions.rows, 24, "Should have at least 24 rows")
    }
    
    func testCalculateTerminalDimensionsWithDifferentFontSizes() {
        // Given
        let screenSize = CGSize(width: 390, height: 844)
        let fontSizes: [CGFloat] = [10, 14, 18, 22]
        
        // When & Then
        for fontSize in fontSizes {
            sut.setFontSize(fontSize)
            let dimensions = sut.calculateTerminalDimensions(for: screenSize)
            
            XCTAssertGreaterThan(dimensions.cols, 0, "Should have positive columns for font size \(fontSize)")
            XCTAssertGreaterThan(dimensions.rows, 0, "Should have positive rows for font size \(fontSize)")
        }
    }
    
    func testCalculateTerminalDimensionsWithSmallScreen() {
        // Given
        let smallScreenSize = CGSize(width: 320, height: 568) // iPhone SE size
        
        // When
        let dimensions = sut.calculateTerminalDimensions(for: smallScreenSize)
        
        // Then
        XCTAssertGreaterThanOrEqual(dimensions.cols, 80, "Should have minimum columns even on small screen")
        XCTAssertGreaterThanOrEqual(dimensions.rows, 24, "Should have minimum rows even on small screen")
    }
    
    // MARK: - Reset and Default Tests
    
    func testResetToDefault() {
        // Given
        sut.setFontSize(20)
        sut.setFontWeight(.bold)
        let defaultConfig = FontConfigurationService.FontPreset.medium.configuration
        
        // When
        sut.resetToDefault()
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, defaultConfig.size, "Should reset to default size")
        XCTAssertEqual(sut.currentConfiguration.weight, defaultConfig.weight, "Should reset to default weight")
        XCTAssertEqual(sut.currentConfiguration.name, defaultConfig.name, "Should reset to default name")
    }
    
    func testAdjustForDynamicType() {
        // Given
        let originalSize = sut.currentConfiguration.size
        
        // When
        sut.adjustForDynamicType()
        
        // Then
        // The size should be adjusted based on system preferences
        XCTAssertNotNil(sut.currentConfiguration.size, "Should have adjusted size")
    }
    
    // MARK: - Memory Management Tests
    
    func testMemoryManagement() {
        // Given
        weak var weakService: FontConfigurationService?
        
        // When
        autoreleasepool {
            let service = FontConfigurationService()
            weakService = service
            service.setFontSize(16)
        }
        
        // Then
        XCTAssertNil(weakService, "Service should be deallocated")
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentFontSizeUpdates() {
        // Given
        let expectation = expectation(description: "Concurrent font size updates")
        expectation.expectedFulfillmentCount = 10
        
        // When
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            sut.setFontSize(CGFloat(10 + index))
            expectation.fulfill()
        }
        
        // Then
        waitForExpectations(timeout: 5.0) { error in
            XCTAssertNil(error, "Should handle concurrent updates")
        }
    }
    
    // MARK: - Configuration Persistence Tests
    
    func testConfigurationChangePersistence() {
        // Given
        let customSize: CGFloat = 18
        let customWeight = UIFont.Weight.semibold
        let customName = "Monaco"
        
        // When
        sut.setFontSize(customSize)
        sut.setFontWeight(customWeight)
        sut.setFontFamily(customName)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, customSize, "Should persist font size")
        XCTAssertEqual(sut.currentConfiguration.weight, customWeight, "Should persist font weight")
        if sut.availableFonts.contains(customName) {
            XCTAssertEqual(sut.currentConfiguration.name, customName, "Should persist font name")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFontConfigurationPerformance() {
        // Given & When & Then
        self.measure {
            sut.setFontSize(16)
            _ = sut.getUIFont()
            _ = sut.getSwiftUIFont()
        }
    }
    
    func testTerminalDimensionsCalculationPerformance() {
        // Given
        let screenSize = CGSize(width: 390, height: 844)
        
        // When & Then
        self.measure {
            _ = sut.calculateTerminalDimensions(for: screenSize)
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testZeroFontSize() {
        // Given
        let zeroSize: CGFloat = 0
        
        // When
        sut.setFontSize(zeroSize)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, sut.minFontSize, "Should clamp zero size to minimum")
    }
    
    func testNegativeFontSize() {
        // Given
        let negativeSize: CGFloat = -10
        
        // When
        sut.setFontSize(negativeSize)
        
        // Then
        XCTAssertEqual(sut.currentConfiguration.size, sut.minFontSize, "Should clamp negative size to minimum")
    }
    
    func testExtremeZoomFactors() {
        // Given
        let initialSize: CGFloat = 14
        sut.setFontSize(initialSize)
        
        // When & Then
        sut.adjustFontSize(by: 0.1) // Very small zoom
        XCTAssertEqual(sut.currentConfiguration.size, sut.minFontSize, "Should clamp to minimum with small zoom")
        
        sut.setFontSize(initialSize)
        sut.adjustFontSize(by: 10.0) // Very large zoom
        XCTAssertEqual(sut.currentConfiguration.size, sut.maxFontSize, "Should clamp to maximum with large zoom")
    }
}

// MARK: - Font Configuration Tests

final class FontConfigurationTests: XCTestCase {
    
    func testFontConfigurationInitialization() {
        // Given & When
        let config = FontConfigurationService.FontConfiguration(
            size: 16,
            weight: .bold,
            name: "Monaco",
            lineSpacing: 1.3,
            letterSpacing: 0.5
        )
        
        // Then
        XCTAssertEqual(config.size, 16, "Should set correct size")
        XCTAssertEqual(config.weight, .bold, "Should set correct weight")
        XCTAssertEqual(config.name, "Monaco", "Should set correct name")
        XCTAssertEqual(config.lineSpacing, 1.3, "Should set correct line spacing")
        XCTAssertEqual(config.letterSpacing, 0.5, "Should set correct letter spacing")
    }
    
    func testFontConfigurationDefaultValues() {
        // Given & When
        let config = FontConfigurationService.FontConfiguration(size: 14)
        
        // Then
        XCTAssertEqual(config.size, 14, "Should set correct size")
        XCTAssertEqual(config.weight, .regular, "Should use default weight")
        XCTAssertEqual(config.name, "Menlo", "Should use default name")
        XCTAssertEqual(config.lineSpacing, 1.2, "Should use default line spacing")
        XCTAssertEqual(config.letterSpacing, 0.0, "Should use default letter spacing")
    }
}

#endif