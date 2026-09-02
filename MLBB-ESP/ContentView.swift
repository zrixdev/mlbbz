import SwiftUI

struct ContentView: View {
    @StateObject private var detectionEngine = DetectionEngine.shared
    @State private var isRunning = false
    
    var body: some View {
        ZStack {
            Color.red.edgesIgnoringSafeArea(.all)
            
            if isRunning {
                runningGUI
            } else {
                idleGUI
            }
        }
    }
    
    var idleGUI: some View {
        VStack(spacing: 40) {
            Text("MLBB ESP")
                .font(.system(size: 36, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            
            Button(action: {
                isRunning = true
                detectionEngine.toggleESP(true)
                detectionEngine.start()
            }) {
                Text("START")
                    .frame(width: 250, height: 70)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .cornerRadius(12)
            }
        }
    }
    
    var runningGUI: some View {
        VStack(spacing: 20) {
            Text("MLBB ESP")
                .font(.system(size: 24, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
            
            ESPOverlayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .border(Color.white, width: 1)
            
            Button(action: {
                detectionEngine.stop()
                detectionEngine.toggleESP(false)
                isRunning = false
            }) {
                Text("STOP")
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .font(.system(size: 24, weight: .heavy, design: .monospaced))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
    }
}
