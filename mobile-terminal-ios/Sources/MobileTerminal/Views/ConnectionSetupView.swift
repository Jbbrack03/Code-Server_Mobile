import SwiftUI

enum ConnectionSetupMethod {
    case qrCode
    case manualEntry
    case networkDiscovery
    case demoMode
}

enum ConnectionType {
    case local
    case remote
    case advanced
}

struct ConnectionSetupView: View {
    @State private var selectedConnectionType: ConnectionType = .local
    let onMethodSelected: (ConnectionSetupMethod) -> Void
    
    init(onMethodSelected: @escaping (ConnectionSetupMethod) -> Void = { _ in }) {
        self.onMethodSelected = onMethodSelected
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 15) {
                Image(systemName: "wifi")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                
                Text("Connection Setup")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Choose how you want to connect to your Code-Server")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 40)
            
            // Connection Type Selection
            VStack(spacing: 20) {
                Text("Connection Type")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    ConnectionTypeCard(
                        type: .local,
                        title: "Local Network",
                        description: "Same WiFi, direct connection",
                        icon: "house.fill",
                        isSelected: selectedConnectionType == .local
                    ) {
                        selectedConnectionType = .local
                    }
                    
                    ConnectionTypeCard(
                        type: .remote,
                        title: "Remote Access",
                        description: "Internet access via port forwarding/proxy",
                        icon: "globe",
                        isSelected: selectedConnectionType == .remote
                    ) {
                        selectedConnectionType = .remote
                    }
                    
                    ConnectionTypeCard(
                        type: .advanced,
                        title: "Advanced Setup",
                        description: "VPN, tunnels, custom configurations",
                        icon: "gear",
                        isSelected: selectedConnectionType == .advanced
                    ) {
                        selectedConnectionType = .advanced
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Setup Methods
            VStack(spacing: 20) {
                Text("Setup Method")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                VStack(spacing: 12) {
                    SetupMethodCard(
                        method: .qrCode,
                        title: "QR Code Scan",
                        description: "Scan QR code from VS Code extension",
                        icon: "qrcode",
                        isRecommended: true
                    ) {
                        onMethodSelected(.qrCode)
                    }
                    
                    SetupMethodCard(
                        method: .manualEntry,
                        title: "Manual Entry",
                        description: "Enter server address and API key manually",
                        icon: "keyboard"
                    ) {
                        onMethodSelected(.manualEntry)
                    }
                    
                    SetupMethodCard(
                        method: .networkDiscovery,
                        title: "Network Discovery",
                        description: "Scan for Code-Server instances (local only)",
                        icon: "magnifyingglass.circle",
                        isEnabled: selectedConnectionType == .local
                    ) {
                        onMethodSelected(.networkDiscovery)
                    }
                    
                    SetupMethodCard(
                        method: .demoMode,
                        title: "Demo Mode",
                        description: "Try without setup - simulated experience",
                        icon: "play.circle"
                    ) {
                        onMethodSelected(.demoMode)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color.gray.opacity(0.1))
    }
}

struct ConnectionTypeCard: View {
    let type: ConnectionType
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .accentColor)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SetupMethodCard: View {
    let method: ConnectionSetupMethod
    let title: String
    let description: String
    let icon: String
    let isRecommended: Bool
    let isEnabled: Bool
    let onTap: () -> Void
    
    init(method: ConnectionSetupMethod, title: String, description: String, icon: String, isRecommended: Bool = false, isEnabled: Bool = true, onTap: @escaping () -> Void) {
        self.method = method
        self.title = title
        self.description = description
        self.icon = icon
        self.isRecommended = isRecommended
        self.isEnabled = isEnabled
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(isEnabled ? .primary : .secondary)
                        
                        if isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.5))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.6)
    }
}

#Preview {
    ConnectionSetupView()
}