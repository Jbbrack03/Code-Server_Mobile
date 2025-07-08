import SwiftUI

struct OnboardingView: View {
    @State private var currentSlide = 0
    let onCompletion: () -> Void
    
    init(onCompletion: @escaping () -> Void = {}) {
        self.onCompletion = onCompletion
    }
    
    var body: some View {
        VStack {
            // Page indicator
            HStack {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(currentSlide == index ? Color.accentColor : Color.secondary)
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentSlide)
                }
            }
            .padding(.top, 20)
            
            // Slide content
            TabView(selection: $currentSlide) {
                WelcomeSlideView()
                    .tag(0)
                
                FeaturesSlideView()
                    .tag(1)
                
                IntegrationSlideView()
                    .tag(2)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
            .animation(.easeInOut(duration: 0.3), value: currentSlide)
            
            // Navigation buttons
            HStack {
                if currentSlide > 0 {
                    Button("Previous") {
                        withAnimation {
                            currentSlide -= 1
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Skip") {
                    onCompletion()
                }
                .foregroundColor(.secondary)
                .opacity(currentSlide < 2 ? 1 : 0)
                
                Spacer()
                
                if currentSlide < 2 {
                    Button("Next") {
                        withAnimation {
                            currentSlide += 1
                        }
                    }
                    .foregroundColor(.accentColor)
                } else {
                    Button("Get Started") {
                        onCompletion()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    // Support swipe gestures
                    let threshold: CGFloat = 50
                    if value.translation.width > threshold && currentSlide > 0 {
                        withAnimation {
                            currentSlide -= 1
                        }
                    } else if value.translation.width < -threshold && currentSlide < 2 {
                        withAnimation {
                            currentSlide += 1
                        }
                    }
                }
        )
    }
}

struct WelcomeSlideView: View {
    var body: some View {
        VStack(spacing: 30) {
            // App logo/icon placeholder
            Image(systemName: "terminal")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 15) {
                Text("Welcome to Mobile Terminal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Access your terminals anywhere")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("Connect to your Code-Server and control your development environment from your mobile device.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .padding()
    }
}

struct FeaturesSlideView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "command")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 15) {
                Text("Create Custom Shortcuts")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Streamline your workflow")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 15) {
                FeatureRow(icon: "bolt", title: "Quick Commands", description: "Create shortcuts for frequently used commands")
                FeatureRow(icon: "rectangle.stack", title: "Multiple Terminals", description: "Switch between terminals with gestures")
                FeatureRow(icon: "keyboard", title: "Mobile-Optimized", description: "Special keyboard with common symbols")
            }
            .padding(.horizontal, 30)
        }
        .padding()
    }
}

struct IntegrationSlideView: View {
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "network")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)
            
            VStack(spacing: 15) {
                Text("Seamless Integration")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Works with Code-Server")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 15) {
                FeatureRow(icon: "wifi", title: "Local & Remote", description: "Connect via local network or internet")
                FeatureRow(icon: "lock.shield", title: "Secure Connection", description: "Encrypted communication with API keys")
                FeatureRow(icon: "qrcode", title: "Easy Setup", description: "Scan QR code for instant connection")
            }
            .padding(.horizontal, 30)
        }
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}