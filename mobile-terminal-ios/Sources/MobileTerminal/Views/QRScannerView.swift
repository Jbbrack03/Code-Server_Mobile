import SwiftUI
import AVFoundation

enum CameraPermissionStatus {
    case notDetermined
    case denied
    case authorized
}

struct QRScannerView: View {
    @State private var permissionStatus: CameraPermissionStatus = .notDetermined
    @State private var isFlashlightOn = false
    @State private var scannedCode: String?
    @State private var showingManualEntry = false
    @State private var errorMessage: String?
    
    let onCodeScanned: (String) -> Void
    let onCancel: () -> Void
    let onManualEntry: () -> Void
    
    init(
        onCodeScanned: @escaping (String) -> Void = { _ in },
        onCancel: @escaping () -> Void = {},
        onManualEntry: @escaping () -> Void = {}
    ) {
        self.onCodeScanned = onCodeScanned
        self.onCancel = onCancel
        self.onManualEntry = onManualEntry
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            VStack {
                // Top bar with cancel button
                HStack {
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    // Flashlight toggle (only show if camera is available)
                    if permissionStatus == .authorized {
                        Button(action: toggleFlashlight) {
                            Image(systemName: isFlashlightOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .foregroundColor(.white)
                                .font(.title2)
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                // Main content based on permission status
                switch permissionStatus {
                case .notDetermined:
                    requestPermissionView
                case .denied:
                    permissionDeniedView
                case .authorized:
                    cameraView
                }
                
                Spacer()
                
                // Bottom instructions and manual entry
                VStack(spacing: 20) {
                    if permissionStatus == .authorized {
                        Text("Point your camera at the QR code from VS Code")
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    
                    Button("Enter Connection Details Manually") {
                        onManualEntry()
                    }
                    .foregroundColor(.accentColor)
                    .padding()
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .alert("QR Code Detected", isPresented: .constant(scannedCode != nil)) {
            Button("Use This Code") {
                if let code = scannedCode {
                    onCodeScanned(code)
                }
            }
            Button("Cancel", role: .cancel) {
                scannedCode = nil
            }
        } message: {
            if let code = scannedCode {
                Text("Connection details found: \(code)")
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let message = errorMessage {
                Text(message)
            }
        }
    }
    
    // MARK: - Permission Views
    
    private var requestPermissionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera")
                .font(.system(size: 80))
                .foregroundColor(.white)
            
            VStack(spacing: 15) {
                Text("Camera Access Required")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Mobile Terminal needs camera access to scan QR codes for quick connection setup.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Grant Camera Access") {
                requestCameraPermission()
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 30) {
            Image(systemName: "camera.fill.badge.xmark")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            VStack(spacing: 15) {
                Text("Camera Access Denied")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("To scan QR codes, please enable camera access in Settings > Mobile Terminal > Camera")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button("Open Settings") {
                openSettings()
            }
            .foregroundColor(.black)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
        }
    }
    
    private var cameraView: some View {
        VStack {
            // Camera preview placeholder
            ZStack {
                // Simulated camera preview
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 400)
                    .cornerRadius(20)
                    .overlay(
                        VStack {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 100))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Text("Camera Preview")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    )
                
                // Scanning indicator
                ScanningIndicator()
            }
            .padding(.horizontal, 40)
            
            // Simulate QR code detection for testing
            Button("Simulate QR Code Detection") {
                simulateQRCodeDetection()
            }
            .foregroundColor(.accentColor)
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(10)
        }
    }
    
    // MARK: - Helper Functions
    
    private func checkCameraPermission() {
        #if os(iOS)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .denied, .restricted:
            permissionStatus = .denied
        case .authorized:
            permissionStatus = .authorized
        @unknown default:
            permissionStatus = .notDetermined
        }
        #else
        // For macOS testing, simulate authorized status
        permissionStatus = .authorized
        #endif
    }
    
    private func requestCameraPermission() {
        #if os(iOS)
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.permissionStatus = granted ? .authorized : .denied
            }
        }
        #else
        // For macOS testing, simulate permission granted
        permissionStatus = .authorized
        #endif
    }
    
    private func toggleFlashlight() {
        #if os(iOS)
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            errorMessage = "Flashlight not available on this device"
            return
        }
        
        do {
            try device.lockForConfiguration()
            device.torchMode = isFlashlightOn ? .off : .on
            device.unlockForConfiguration()
            isFlashlightOn.toggle()
        } catch {
            errorMessage = "Failed to toggle flashlight"
        }
        #else
        // For macOS testing, just toggle the state
        isFlashlightOn.toggle()
        #endif
    }
    
    private func openSettings() {
        #if os(iOS)
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
        #endif
    }
    
    private func simulateQRCodeDetection() {
        // Simulate a QR code detection for testing
        let mockQRCode = """
        {
            "urls": ["192.168.1.100:8092", "https://terminal.example.com"],
            "apiKey": "mock-api-key-12345",
            "version": "1.0.0"
        }
        """
        scannedCode = mockQRCode
    }
}

struct ScanningIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 200, height: 200)
            .overlay(
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 2)
                    .frame(width: 200, height: 200)
            )
            .overlay(
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 200, height: 2)
                    .offset(y: isAnimating ? 100 : -100)
                    .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: isAnimating)
            )
            .onAppear {
                isAnimating = true
            }
    }
}

#Preview {
    QRScannerView()
}