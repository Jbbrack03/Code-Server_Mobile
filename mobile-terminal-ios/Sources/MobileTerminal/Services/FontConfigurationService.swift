#if os(iOS)
import SwiftUI
import UIKit

/// Service for managing terminal font configuration and dynamic sizing
public class FontConfigurationService: ObservableObject {
    
    // MARK: - Types
    
    /// Font configuration options
    public struct FontConfiguration {
        public let size: CGFloat
        public let weight: UIFont.Weight
        public let name: String
        public let lineSpacing: CGFloat
        public let letterSpacing: CGFloat
        
        public init(
            size: CGFloat,
            weight: UIFont.Weight = .regular,
            name: String = "Menlo",
            lineSpacing: CGFloat = 1.2,
            letterSpacing: CGFloat = 0.0
        ) {
            self.size = size
            self.weight = weight
            self.name = name
            self.lineSpacing = lineSpacing
            self.letterSpacing = letterSpacing
        }
    }
    
    /// Font preset for different use cases
    public enum FontPreset: CaseIterable {
        case small
        case medium
        case large
        case extraLarge
        case accessibility
        
        public var displayName: String {
            switch self {
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            case .extraLarge: return "Extra Large"
            case .accessibility: return "Accessibility"
            }
        }
        
        public var configuration: FontConfiguration {
            switch self {
            case .small:
                return FontConfiguration(size: 10, weight: .regular, name: "Menlo")
            case .medium:
                return FontConfiguration(size: 14, weight: .regular, name: "Menlo")
            case .large:
                return FontConfiguration(size: 18, weight: .regular, name: "Menlo")
            case .extraLarge:
                return FontConfiguration(size: 22, weight: .regular, name: "Menlo")
            case .accessibility:
                return FontConfiguration(size: 20, weight: .medium, name: "Menlo", lineSpacing: 1.4)
            }
        }
    }
    
    // MARK: - Properties
    
    @Published public private(set) var currentConfiguration: FontConfiguration
    @Published public private(set) var availableFonts: [String]
    @Published public private(set) var terminalSize: CGSize = .zero
    
    // Font sizing constraints
    public let minFontSize: CGFloat = 8
    public let maxFontSize: CGFloat = 32
    
    // MARK: - Initialization
    
    public init() {
        self.currentConfiguration = FontPreset.medium.configuration
        self.availableFonts = Self.getAvailableMonospaceFonts()
    }
    
    // MARK: - Public Methods
    
    /// Apply a font preset
    public func applyPreset(_ preset: FontPreset) {
        currentConfiguration = preset.configuration
        calculateTerminalSize()
    }
    
    /// Set custom font size
    public func setFontSize(_ size: CGFloat) {
        let clampedSize = max(minFontSize, min(maxFontSize, size))
        currentConfiguration = FontConfiguration(
            size: clampedSize,
            weight: currentConfiguration.weight,
            name: currentConfiguration.name,
            lineSpacing: currentConfiguration.lineSpacing,
            letterSpacing: currentConfiguration.letterSpacing
        )
        calculateTerminalSize()
    }
    
    /// Set font weight
    public func setFontWeight(_ weight: UIFont.Weight) {
        currentConfiguration = FontConfiguration(
            size: currentConfiguration.size,
            weight: weight,
            name: currentConfiguration.name,
            lineSpacing: currentConfiguration.lineSpacing,
            letterSpacing: currentConfiguration.letterSpacing
        )
    }
    
    /// Set font family
    public func setFontFamily(_ fontName: String) {
        guard availableFonts.contains(fontName) else { return }
        
        currentConfiguration = FontConfiguration(
            size: currentConfiguration.size,
            weight: currentConfiguration.weight,
            name: fontName,
            lineSpacing: currentConfiguration.lineSpacing,
            letterSpacing: currentConfiguration.letterSpacing
        )
    }
    
    /// Apply custom font configuration
    public func applyConfiguration(_ configuration: FontConfiguration) {
        currentConfiguration = configuration
        calculateTerminalSize()
    }
    
    /// Get UIFont for current configuration
    public func getUIFont() -> UIFont {
        let font = UIFont(name: currentConfiguration.name, size: currentConfiguration.size) ??
                   UIFont.monospacedSystemFont(ofSize: currentConfiguration.size, weight: currentConfiguration.weight)
        return font
    }
    
    /// Get SwiftUI Font for current configuration
    public func getSwiftUIFont() -> Font {
        if let customFont = UIFont(name: currentConfiguration.name, size: currentConfiguration.size) {
            return Font(customFont)
        } else {
            return Font.system(size: currentConfiguration.size, weight: mapUIFontWeight(currentConfiguration.weight), design: .monospaced)
        }
    }
    
    /// Calculate terminal dimensions based on screen size and font
    public func calculateTerminalDimensions(for screenSize: CGSize) -> (cols: Int, rows: Int) {
        let font = getUIFont()
        let fontAttributes = [NSAttributedString.Key.font: font]
        let charSize = ("M" as NSString).size(withAttributes: fontAttributes)
        
        let availableWidth = screenSize.width - 40 // Account for padding
        let availableHeight = screenSize.height - 200 // Account for UI elements
        
        let cols = Int(availableWidth / charSize.width)
        let rows = Int(availableHeight / (charSize.height * currentConfiguration.lineSpacing))
        
        return (cols: max(cols, 80), rows: max(rows, 24))
    }
    
    /// Adjust font size based on zoom level
    public func adjustFontSize(by zoomFactor: CGFloat) {
        let newSize = currentConfiguration.size * zoomFactor
        setFontSize(newSize)
    }
    
    /// Reset to default configuration
    public func resetToDefault() {
        applyPreset(.medium)
    }
    
    /// Support for iOS Dynamic Type
    public func adjustForDynamicType() {
        let preferredSize = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body).pointSize
        let scaledSize = currentConfiguration.size * (preferredSize / 17.0) // 17 is default body size
        setFontSize(scaledSize)
    }
    
    // MARK: - Private Methods
    
    private func calculateTerminalSize() {
        let font = getUIFont()
        let fontAttributes = [NSAttributedString.Key.font: font]
        let charSize = ("M" as NSString).size(withAttributes: fontAttributes)
        terminalSize = CGSize(
            width: charSize.width,
            height: charSize.height * currentConfiguration.lineSpacing
        )
    }
    
    private func mapUIFontWeight(_ weight: UIFont.Weight) -> Font.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        default: return .regular
        }
    }
    
    private static func getAvailableMonospaceFonts() -> [String] {
        let monospaceFonts = ["Menlo", "Monaco", "Courier", "Courier New", "Source Code Pro", "Fira Code"]
        return monospaceFonts.filter { fontName in
            UIFont(name: fontName, size: 12) != nil
        }
    }
}

/// SwiftUI View for font configuration
public struct FontConfigurationView: View {
    @ObservedObject var fontService: FontConfigurationService
    @State private var selectedPreset: FontConfigurationService.FontPreset = .medium
    @State private var customFontSize: Double = 14
    @State private var showingAdvancedOptions = false
    
    public init(fontService: FontConfigurationService) {
        self.fontService = fontService
    }
    
    public var body: some View {
        NavigationView {
            List {
                Section("Font Presets") {
                    ForEach(FontConfigurationService.FontPreset.allCases, id: \.self) { preset in
                        Button(action: {
                            selectedPreset = preset
                            fontService.applyPreset(preset)
                        }) {
                            HStack {
                                Text(preset.displayName)
                                Spacer()
                                if selectedPreset == preset {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section("Custom Size") {
                    VStack(alignment: .leading) {
                        Text("Font Size: \(Int(customFontSize))pt")
                            .font(.caption)
                        
                        Slider(
                            value: $customFontSize,
                            in: Double(fontService.minFontSize)...Double(fontService.maxFontSize),
                            step: 1
                        ) {
                            Text("Font Size")
                        } onEditingChanged: { _ in
                            fontService.setFontSize(CGFloat(customFontSize))
                        }
                    }
                }
                
                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terminal Preview")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("$ ls -la\ndrwxr-xr-x  5 user  staff   160 Jan  8 16:54 .\ndrwxr-xr-x  3 user  staff    96 Jan  8 16:54 ..\n-rw-r--r--  1 user  staff  1024 Jan  8 16:54 README.md")
                            .font(fontService.getSwiftUIFont())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                }
                
                if showingAdvancedOptions {
                    Section("Advanced Options") {
                        Picker("Font Family", selection: Binding(
                            get: { fontService.currentConfiguration.name },
                            set: { fontService.setFontFamily($0) }
                        )) {
                            ForEach(fontService.availableFonts, id: \.self) { fontName in
                                Text(fontName).tag(fontName)
                            }
                        }
                        
                        Button("Reset to Default") {
                            fontService.resetToDefault()
                            selectedPreset = .medium
                            customFontSize = 14
                        }
                        .foregroundColor(.red)
                        
                        Button("Adjust for Dynamic Type") {
                            fontService.adjustForDynamicType()
                            customFontSize = Double(fontService.currentConfiguration.size)
                        }
                    }
                }
            }
            .navigationTitle("Font Configuration")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(showingAdvancedOptions ? "Hide Advanced" : "Show Advanced") {
                        showingAdvancedOptions.toggle()
                    }
                }
            }
        }
        .onAppear {
            customFontSize = Double(fontService.currentConfiguration.size)
        }
    }
}

// MARK: - Preview

#Preview {
    FontConfigurationView(fontService: FontConfigurationService())
}

#endif