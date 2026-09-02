import SwiftUI
import UIKit

struct ESPOverlayView: UIViewRepresentable {
    func makeUIView(context: Context) -> ESPOverlayUIView {
        let view = ESPOverlayUIView()
        DetectionEngine.shared.overlayView = view
        return view
    }
    
    func updateUIView(_ uiView: ESPOverlayUIView, context: Context) {}
}

class ESPOverlayUIView: UIView {
    private var overlayLayers: [CAShapeLayer] = []
    
    func drawTargets(_ targets: [DetectionEngine.Target]) {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        overlayLayers.removeAll()
        
        for target in targets {
            let boxLayer = CAShapeLayer()
            let path = UIBezierPath(roundedRect: target.boundingBox, cornerRadius: 4)
            boxLayer.path = path.cgPath
            boxLayer.strokeColor = target.isEnemy ? UIColor.red.cgColor : UIColor.blue.cgColor
            boxLayer.fillColor = (target.isEnemy ? UIColor.red : UIColor.blue).withAlphaComponent(0.15).cgColor
            boxLayer.lineWidth = 2.0
            
            let labelLayer = CATextLayer()
            labelLayer.string = "\(target.isEnemy ? "ENEMY" : "ALLY") \(Int(target.confidence * 100))%"
            labelLayer.fontSize = 11
            labelLayer.foregroundColor = target.isEnemy ? UIColor.red.cgColor : UIColor.blue.cgColor
            labelLayer.frame = CGRect(
                x: target.boundingBox.origin.x,
                y: target.boundingBox.origin.y - 16,
                width: 120,
                height: 14
            )
            
            layer.addSublayer(boxLayer)
            layer.addSublayer(labelLayer)
            
            if DetectionEngine.shared.showHealthBars {
                let healthBar = CAShapeLayer()
                let healthPath = UIBezierPath(
                    roundedRect: CGRect(
                        x: target.boundingBox.origin.x,
                        y: target.boundingBox.origin.y - 4,
                        width: target.boundingBox.width,
                        height: 4
                    ),
                    cornerRadius: 2
                )
                healthBar.path = healthPath.cgPath
                healthBar.fillColor = UIColor.green.cgColor
                layer.addSublayer(healthBar)
            }
        }
    }
}
