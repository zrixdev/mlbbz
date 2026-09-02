import Foundation
import UIKit
import Vision

class DetectionEngine: ObservableObject {
    static let shared = DetectionEngine()
    weak var overlayView: ESPOverlayUIView?
    
    @Published var isESPEnabled = false
    @Published var detectionThreshold: Double = 0.65
    @Published var showEnemies = true
    @Published var showAllies = false
    @Published var showHealthBars = true
    
    private let detectionQueue = DispatchQueue(label: "com.kakuforge.mlbb-esp.detection", qos: .userInitiated)
    private var lastFrameProcessed = Date()
    
    struct Target {
        let boundingBox: CGRect
        let confidence: Float
        let isEnemy: Bool
    }
    
    func toggleESP(_ enabled: Bool) {
        isESPEnabled = enabled
    }
    
    func start() {
        ScreenCaptureService.shared.start()
    }
    
    func stop() {
        ScreenCaptureService.shared.stop()
    }
    
    func processScreenImage(_ image: UIImage) {
        guard isESPEnabled else { return }
        
        let frameInterval: TimeInterval = 0.2
        let now = Date()
        guard now.timeIntervalSince(lastFrameProcessed) >= frameInterval else { return }
        lastFrameProcessed = now
        
        detectionQueue.async { [weak self] in
            self?.analyzeImage(image)
        }
    }
    
    private func analyzeImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        let request = VNDetectHumanRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNHumanObservation] else { return }
            
            let targets = observations.compactMap { observation -> Target? in
                let confidence = observation.confidence
                guard confidence > Float(self?.detectionThreshold ?? 0.65) else { return nil }
                
                let boundingBox = self?.convertVisionRectToScreen(observation.boundingBox, imageSize: image.size) ?? .zero
                
                // Heuristic: enemies are typically on the right side in MLBB
                let isEnemy = boundingBox.midX > (self?.screenCenterX() ?? 0)
                
                return Target(
                    boundingBox: boundingBox,
                    confidence: confidence,
                    isEnemy: isEnemy
                )
            }
            
            DispatchQueue.main.async {
                self?.overlayView?.drawTargets(targets)
            }
        }
        
        request.usesCPUOnly = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }
    
    private func convertVisionRectToScreen(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        // Vision uses normalized coordinates with origin at bottom-left
        let screenRect = CGRect(
            x: visionRect.origin.x * UIScreen.main.bounds.width,
            y: (1 - visionRect.origin.y - visionRect.height) * UIScreen.main.bounds.height,
            width: visionRect.width * UIScreen.main.bounds.width,
            height: visionRect.height * UIScreen.main.bounds.height
        )
        return screenRect
    }
    
    private func screenCenterX() -> CGFloat {
        return UIScreen.main.bounds.width / 2
    }
}
