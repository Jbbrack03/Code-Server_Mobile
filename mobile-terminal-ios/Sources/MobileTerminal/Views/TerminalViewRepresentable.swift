import SwiftUI
import SwiftTerm
import Foundation

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if os(iOS)
/// SwiftUI wrapper for SwiftTerm's TerminalView
struct TerminalViewRepresentable: UIViewRepresentable {
    let viewModel: TerminalViewModel
    let font: UIFont?
    let cols: Int?
    let rows: Int?
    
    // Reference to the underlying terminal view for data streaming
    @State private var terminalViewRef: TerminalView?
    
    init(viewModel: TerminalViewModel, font: UIFont? = nil, cols: Int? = nil, rows: Int? = nil) {
        self.viewModel = viewModel
        self.font = font
        self.cols = cols
        self.rows = rows
    }
    
    func makeUIView(context: Context) -> TerminalView {
        let terminalView = TerminalView()
        terminalView.terminalDelegate = context.coordinator
        
        // Configure font
        if let font = font {
            terminalView.font = font
        } else {
            terminalView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        }
        
        // Configure size if specified
        if let cols = cols, let rows = rows {
            terminalView.getTerminal().resize(cols: cols, rows: rows)
        }
        
        // Store reference for data streaming
        DispatchQueue.main.async {
            context.coordinator.terminalViewRef = terminalView
        }
        
        return terminalView
    }
    
    func updateUIView(_ uiView: TerminalView, context: Context) {
        // Update font if changed
        if let font = font {
            uiView.font = font
        }
        
        // Update size if changed
        if let cols = cols, let rows = rows {
            let terminal = uiView.getTerminal()
            if terminal.cols != cols || terminal.rows != rows {
                terminal.resize(cols: cols, rows: rows)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, TerminalViewDelegate {
        var parent: TerminalViewRepresentable
        var terminalViewRef: TerminalView?
        
        init(_ parent: TerminalViewRepresentable) {
            self.parent = parent
        }
        
        /// Feed data to the terminal for display
        func feedData(_ data: Data) {
            guard let terminalView = terminalViewRef else { return }
            let bytes = Array(data)
            terminalView.getTerminal().feed(byteArray: bytes)
        }
        
        /// Get the underlying terminal instance
        func getTerminal() -> Terminal? {
            return terminalViewRef?.getTerminal()
        }
        
        // MARK: - TerminalViewDelegate Methods
        
        func setTerminalTitle(source: TerminalView, title: String) {
            // Handle terminal title changes
            // This could be used to update the UI with the terminal title
        }
        
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            // Handle terminal size changes
            Task {
                await parent.viewModel.resizeTerminal(cols: newCols, rows: newRows)
            }
        }
        
        func clipboardCopy(source: TerminalView, content: Data) {
            // Handle clipboard copy operations
            UIPasteboard.general.setData(content, forPasteboardType: "public.utf8-plain-text")
        }
        
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
            // Handle current directory updates
            // This could be used to update the UI with the current directory
        }
        
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            // Handle data that needs to be sent to the terminal process
            guard let string = String(bytes: data, encoding: .utf8) else {
                print("Warning: Could not decode terminal input data to UTF-8")
                return
            }
            
            Task {
                await parent.viewModel.sendInput(string)
            }
        }
        
        func scrolled(source: TerminalView, position: Double) {
            // Handle scroll position changes
            // This could be used for scroll-based UI updates
        }
        
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
            // Handle range changes in the terminal display
            // This could be used for performance optimizations
        }
        
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
            // Handle link opening requests
            guard let encodedLink = link.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: encodedLink) else {
                return
            }
            
            UIApplication.shared.open(url) { success in
                if !success {
                    print("Failed to open URL: \(link)")
                }
            }
        }
        
        func bell(source: TerminalView) {
            // Handle terminal bell with haptic feedback
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
        }
        
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
            // Handle iTerm2-specific content
            // This is typically used for special terminal features
            // Default implementation can be empty for basic usage
        }
    }
}

// MARK: - Default Initializers

extension TerminalViewRepresentable {
    init(viewModel: TerminalViewModel) {
        self.viewModel = viewModel
        self.font = nil
        self.cols = nil
        self.rows = nil
    }
    
    init(viewModel: TerminalViewModel, font: UIFont) {
        self.viewModel = viewModel
        self.font = font
        self.cols = nil
        self.rows = nil
    }
    
    init(viewModel: TerminalViewModel, cols: Int, rows: Int) {
        self.viewModel = viewModel
        self.font = nil
        self.cols = cols
        self.rows = rows
    }
}
#endif