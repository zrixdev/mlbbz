import Foundation
import UIKit

class HackState: ObservableObject {
    static let shared = HackState()

    let version = "0.1"

    @Published var isConnected = false
    @Published var isTransitioning = false
    @Published var statusText = "Not Connected"
    @Published var mlbbPID: Int32 = 0
    @Published var baseAddress: UInt64 = 0
    @Published var currentFPS: Int = 0
    @Published var entityCount: Int = 0

    @Published var showBoxESP = true
    @Published var showHealthBar = true
    @Published var showDistance = true
    @Published var showNames = false
    @Published var showLevel = true
    @Published var showHealthText = false

    @Published var enemyColor = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 0.9)
    @Published var allyColor = UIColor(red: 0.25, green: 1.0, blue: 0.25, alpha: 0.9)
    @Published var boxThickness: Double = 1.5
    @Published var boxGlow: Double = 4.0

    let memoryManager = MemoryManager()
    private var overlayController: OverlayController?

    func spawnOverlay() {
        overlayController = OverlayController(
            memoryManager: memoryManager,
            baseAddress: 0,
            settings: self
        )
        overlayController?.start()
        statusText = "Waiting for MLBB..."
    }

    func stopHack() {
        guard !isTransitioning else { return }
        isTransitioning = true

        overlayController?.stop()
        overlayController = nil
        memoryManager.detach()

        withAnimation(.easeInOut(duration: 0.3)) {
            isConnected = false
            isTransitioning = false
            statusText = "Not Connected"
            mlbbPID = 0
            baseAddress = 0
            entityCount = 0
            currentFPS = 0
        }
    }

    func resetState() {
        overlayController?.stop()
        overlayController = nil
        memoryManager.detach()
        isConnected = false
        isTransitioning = false
        mlbbPID = 0
        baseAddress = 0
        entityCount = 0
        currentFPS = 0
        statusText = "Not Connected"
    }
}
