import SwiftUI
import AVFoundation

struct ContentView: View {
    @StateObject private var detectionEngine = DetectionEngine.shared
    @State private var isRunning = false
    @State private var sensitivity: Double = 0.65
    @State private var showEnemies = true
    @State private var showAllies = false
    @State private var showHealthBars = true
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isRunning {
                runningGUI
            } else {
                idleGUI
            }
        }
    }
    
    var idleGUI: some View {
        VStack(spacing: 30) {
            Text("MLBB ESP OVERLAY")
                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                .foregroundColor(.green)
            
            Button(action: {
                isRunning = true
                detectionEngine.toggleESP(true)
                detectionEngine.start()
            }) {
                Text("START")
                    .frame(width: 200, height: 60)
                    .background(Color.green.opacity(0.9))
                    .foregroundColor(.black)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .cornerRadius(8)
            }
        }
    }
    
    var runningGUI: some View {
        VStack(spacing: 15) {
            Text("MLBB ESP OVERLAY")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundColor(.green)
            
            HStack(spacing: 20) {
                Toggle("Enemies", isOn: $showEnemies)
                    .onChange(of: showEnemies) { newValue in
                        detectionEngine.showEnemies = newValue
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .red))
                    .foregroundColor(.white)
                
                Toggle("Allies", isOn: $showAllies)
                    .onChange(of: showAllies) { newValue in
                        detectionEngine.showAllies = newValue
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .foregroundColor(.white)
                
                Toggle("Health", isOn: $showHealthBars)
                    .onChange(of: showHealthBars) { newValue in
                        detectionEngine.showHealthBars = newValue
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .foregroundColor(.white)
            }
            
            HStack {
                Text("Threshold:")
                    .foregroundColor(.white)
                    .font(.system(size: 14, design: .monospaced))
                Slider(value: $sensitivity, in: 0.3...0.95)
                    .onChange(of: sensitivity) { newValue in
                        detectionEngine.detectionThreshold = newValue
                    }
                Text(String(format: "%.2f", sensitivity))
                    .foregroundColor(.yellow)
                    .monospacedDigit()
            }
            
            ESPOverlayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.green, width: 1)
            
            Button(action: {
                detectionEngine.stop()
                detectionEngine.toggleESP(false)
                isRunning = false
            }) {
                Text("STOP")
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.red.opacity(0.9))
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
