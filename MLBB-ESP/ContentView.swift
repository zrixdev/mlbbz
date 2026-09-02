import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var detectionEngine = DetectionEngine.shared
    @State private var espEnabled = false
    @State private var sensitivity: Double = 0.65
    @State private var showEnemies = true
    @State private var showAllies = false
    @State private var showHealthBars = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                Text("MLBB ESP OVERLAY")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)
                
                HStack(spacing: 30) {
                    Toggle("ESP Master", isOn: $espEnabled)
                        .onChange(of: espEnabled) { newValue in
                            detectionEngine.toggleESP(newValue)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .green))
                    
                    Toggle("Enemies", isOn: $showEnemies)
                        .onChange(of: showEnemies) { newValue in
                            detectionEngine.showEnemies = newValue
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .red))
                    
                    Toggle("Allies", isOn: $showAllies)
                        .onChange(of: showAllies) { newValue in
                            detectionEngine.showAllies = newValue
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                
                HStack {
                    Text("Detection Threshold:")
                        .foregroundColor(.white)
                    Slider(value: $sensitivity, in: 0.3...0.95)
                        .onChange(of: sensitivity) { newValue in
                            detectionEngine.detectionThreshold = newValue
                        }
                    Text(String(format: "%.2f", sensitivity))
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                }
                
                Toggle("Health Bars", isOn: $showHealthBars)
                    .onChange(of: showHealthBars) { newValue in
                        detectionEngine.showHealthBars = newValue
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                
                ESPOverlayView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Button(action: {
                    UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exit(0)
                    }
                }) {
                    Text("CLOSE OVERLAY")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onAppear {
            detectionEngine.start()
        }
        .onDisappear {
            detectionEngine.stop()
        }
    }
}
