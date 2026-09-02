import Foundation
import AVFoundation
import UIKit

class ScreenCaptureService {
    static let shared = ScreenCaptureService()
    private var timer: Timer?
    private var screenshotService: UIScreen?
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.captureScreen()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func captureScreen() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        
        DetectionEngine.shared.processScreenImage(image)
    }
}
