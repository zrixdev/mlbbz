import UIKit
import Foundation
import AVFoundation

enum OverlayState {
    case waiting
    case connecting
    case active
    case lost
}

class OverlayController: NSObject {
    
    private var memory: MemoryManager
    private var baseAddress: UInt64 = 0
    private var displayLink: CADisplayLink?
    private var entityParser: EntityParser?
    
    private weak var hackState: HackState?
    
    private var frameCount = 0
    private var lastFpsUpdate = Date()
    
    private var isRunning = false
    
    private var pollTimer: Timer?
    private var pollCounter = 0
    
    private var currentState: OverlayState = .waiting
    
    private var audioPlayer: AVAudioPlayer?
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    
    private var fallbackWindow: UIWindow?
    private var fallbackView: ESPOverlayView?
    
    init(memoryManager: MemoryManager, baseAddress: UInt64, settings: HackState) {
        self.memory = memoryManager
        self.baseAddress = baseAddress
        self.hackState = settings
        super.init()
    }
    
    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentState = .waiting
        
        startBackgroundKeepAlive()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.setupFallbackWindow()
            self.startDisplayLink()
            self.startPolling()
        }
    }
    
    func stop() {
        isRunning = false
        currentState = .waiting
        
        stopPolling()
        stopDisplayLink()
        stopBackgroundKeepAlive()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.fallbackWindow?.isHidden = true
            self.fallbackWindow = nil
            self.fallbackView = nil
        }
    }
    
    private func setupFallbackWindow() {
        guard fallbackWindow == nil else { return }
        
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        
        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.alert + 100
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isUserInteractionEnabled = false
        
        let view = ESPOverlayView(frame: windowScene.coordinateSpace.bounds)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        
        window.rootViewController = OverlayViewController(overlayView: view)
        window.isHidden = false
        
        fallbackWindow = window
        fallbackView = view
    }
    
    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(renderFrame))
        displayLink?.preferredFramesPerSecond = 20
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func startPolling() {
        stopPolling()
        
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForMLBB()
        }
    }
    
    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func checkForMLBB() {
        guard isRunning else { return }
        
        switch currentState {
        case .waiting, .lost:
            if let pid = ProcessFinder.findPID(byName: "legends")
                    ?? ProcessFinder.findPID(byName: "MLBB") {
                connectToMLBB(pid: pid)
            }
            
        case .active:
            if ProcessFinder.findPID(byName: "legends") == nil
                && ProcessFinder.findPID(byName: "MLBB") == nil {
                memory.detach()
                entityParser = nil
                currentState = .lost
                
                DispatchQueue.main.async {
                    self.hackState?.isConnected = false
                    self.hackState?.statusText = "Game Closed — Waiting..."
                    self.hackState?.mlbbPID = 0
                    self.hackState?.entityCount = 0
                    self.hackState?.currentFPS = 0
                }
            }
            
        case .connecting:
            break
        }
    }
    
    private func connectToMLBB(pid: Int32) {
        currentState = .connecting
        
        DispatchQueue.main.async {
            self.hackState?.statusText = "Connecting to MLBB..."
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard self.memory.attach(to: pid) else {
                DispatchQueue.main.async {
                    self.currentState = .waiting
                }
                return
            }
            
            guard let base = self.memory.findModuleBase(named: "legends") else {
                self.memory.detach()
                DispatchQueue.main.async {
                    self.currentState = .waiting
                }
                return
            }
            
            self.baseAddress = base
            let parser = EntityParser(memory: self.memory, baseAddress: base)
            
            DispatchQueue.main.async {
                self.entityParser = parser
                self.currentState = .active
                
                self.hackState?.isConnected = true
                self.hackState?.statusText = "Connected"
                self.hackState?.mlbbPID = pid
                self.hackState?.baseAddress = base
            }
        }
    }
    
    @objc private func renderFrame() {
        guard isRunning else { return }
        
        if let view = fallbackView {
            renderToView(view)
        }
    }
    
    private func renderToView(_ view: ESPOverlayView) {
        switch currentState {
        case .waiting, .lost:
            pollCounter += 1
            view.updateWaitingTick(pollCounter)
            view.setOverlayState(currentState)
            
        case .connecting:
            view.updateConnectingTick()
            view.setOverlayState(currentState)
            
        case .active:
            view.setOverlayState(.active)
            
            if let parser = entityParser {
                let entities = parser.parseEntities()
                
                if let state = hackState {
                    view.settings = ESPSettings(
                        showBoxESP: state.showBoxESP,
                        showHealthBar: state.showHealthBar,
                        showHealthText: state.showHealthText,
                        showDistance: state.showDistance,
                        showLevel: state.showLevel,
                        showNames: state.showNames,
                        showSelf: false,
                        showDeadPlayers: false,
                        enemyColor: state.enemyColor,
                        allyColor: state.allyColor,
                        boxThickness: CGFloat(state.boxThickness),
                        boxGlow: CGFloat(state.boxGlow)
                    )
                }
                
                view.updateEntities(entities)
                updateFPS(entities.count)
            }
        }
    }
    
    private func updateFPS(_ count: Int) {
        frameCount += 1
        let now = Date()
        if now.timeIntervalSince(lastFpsUpdate) >= 1.0 {
            let fps = frameCount
            frameCount = 0
            lastFpsUpdate = now
            
            DispatchQueue.main.async {
                self.hackState?.currentFPS = fps
                self.hackState?.entityCount = count
            }
        }
    }
    
    private func startBackgroundKeepAlive() {
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ESP-BOX-KeepAlive") { [weak self] in
            self?.stopBackgroundKeepAlive()
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            let sampleRate = 44100
            let dataSize = 44100 * 2
            
            var wavData = Data()
            
            func appendLE32(_ val: UInt32) {
                withUnsafeBytes(of: val.littleEndian) { wavData.append(contentsOf: $0) }
            }
            func appendLE16(_ val: UInt16) {
                withUnsafeBytes(of: val.littleEndian) { wavData.append(contentsOf: $0) }
            }
            
            wavData.append("RIFF".data(using: .utf8)!)
            appendLE32(UInt32(36 + dataSize))
            wavData.append("WAVE".data(using: .utf8)!)
            wavData.append("fmt ".data(using: .utf8)!)
            appendLE32(16)
            appendLE16(1)
            appendLE16(1)
            appendLE32(UInt32(sampleRate))
            appendLE32(UInt32(sampleRate * 2))
            appendLE16(2)
            appendLE16(16)
            wavData.append("data".data(using: .utf8)!)
            appendLE32(UInt32(dataSize))
            
            wavData.append(Data(repeating: 0, count: min(dataSize, 44100 * 2)))
            
            let tempFile = URL(fileURLWithPath: NSTemporaryDirectory() + "silence.wav")
            try wavData.write(to: tempFile)
            
            audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.0
            audioPlayer?.play()
        } catch {
            print("[VEX] Audio keep-alive failed: \(error)")
        }
    }
    
    private func stopBackgroundKeepAlive() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        if bgTask != .invalid {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

class OverlayViewController: UIViewController {
    
    private let overlayView: ESPOverlayView
    
    init(overlayView: ESPOverlayView) {
        self.overlayView = overlayView
        super.init(nibName: nil, bundle: nil)
        self.view = overlayView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }
    
    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
}
