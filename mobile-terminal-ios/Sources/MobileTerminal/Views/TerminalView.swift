#if os(iOS)
import SwiftUI
import SwiftTerm
import UIKit

/// Main terminal view that integrates SwiftTerm with ViewModel
struct TerminalView: View {
    @ObservedObject var terminalViewModel: TerminalViewModel
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @State private var isConnected = false
    @State private var showingError = false
    @State private var terminalSize = CGSize(width: 80, height: 24)
    
    var body: some View {
        ZStack {
            if isConnected {
                TerminalViewRepresentable(
                    viewModel: terminalViewModel,
                    cols: Int(terminalSize.width),
                    rows: Int(terminalSize.height)
                )
                .background(Color.black)
                .onAppear {
                    setupTerminal()
                }
                .onDisappear {
                    Task {
                        await terminalViewModel.disconnect()
                    }
                }
            } else {
                ConnectionView(
                    viewModel: connectionViewModel,
                    onConnect: { profile in
                        Task {
                            await connectToTerminal(profile: profile)
                        }
                    }
                )
            }
        }
        .onReceive(terminalViewModel.$connectionState) { state in
            withAnimation {
                isConnected = state.isConnected
            }
        }
        .onReceive(terminalViewModel.$error) { error in
            showingError = error != nil
        }
        .alert("Terminal Error", isPresented: $showingError) {
            Button("OK") {
                terminalViewModel.error = nil
            }
        } message: {
            Text(terminalViewModel.error?.localizedDescription ?? "Unknown error")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                await terminalViewModel.reconnect()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupTerminal() {
        Task {
            await terminalViewModel.loadTerminals()
        }
    }
    
    private func connectToTerminal(profile: ConnectionProfile) async {
        await terminalViewModel.connect(profile: profile)
    }
    
    private func calculateTerminalSize(from geometry: GeometryProxy) -> CGSize {
        let fontWidth: CGFloat = 8  // Approximate monospace font width
        let fontHeight: CGFloat = 16 // Approximate monospace font height
        
        let cols = Int(geometry.size.width / fontWidth)
        let rows = Int(geometry.size.height / fontHeight)
        
        return CGSize(width: max(cols, 80), height: max(rows, 24))
    }
}

/// Connection view for selecting connection profile
struct ConnectionView: View {
    @ObservedObject var viewModel: ConnectionViewModel
    let onConnect: (ConnectionProfile) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Connect to Terminal")
                    .font(.title)
                    .padding()
                
                if viewModel.profiles.isEmpty {
                    Text("No connection profiles found")
                        .foregroundColor(.secondary)
                        .padding()
                    
                    Button("Add Connection") {
                        // TODO: Navigate to connection setup
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    List(viewModel.profiles) { profile in
                        ConnectionProfileRow(profile: profile) {
                            onConnect(profile)
                        }
                    }
                }
            }
            .navigationTitle("Mobile Terminal")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Row view for connection profile selection
struct ConnectionProfileRow: View {
    let profile: ConnectionProfile
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(profile.urls.first ?? "No URL")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: profile.hasSecureConnection ? "lock.fill" : "lock.open")
                        .foregroundColor(profile.hasSecureConnection ? .green : .orange)
                    
                    Text("Last used: \(profile.lastUsed.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    TerminalView(
        terminalViewModel: TerminalViewModel(
            apiClient: APIClient(
                baseURL: URL(string: "http://localhost:8092")!,
                apiKey: "preview-key"
            ),
            webSocketManager: MobileTerminalWebSocketClient()
        ),
        connectionViewModel: ConnectionViewModel(
            keychainService: KeychainService()
        )
    )
}

#endif