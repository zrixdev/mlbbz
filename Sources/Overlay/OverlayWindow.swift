import UIKit
import Foundation
import AVFoundation

enum OverlayState {
    case waiting
    case connecting
    case active
    case lost
}

// MARK: - Pass-through window
class PassThroughWindow: UIWindow {
    weak var floatButton: ESPFloatButton?
    weak var menuView: ESPMenuView?

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let view = super.hitTest(point, with: event) else { return nil }

        if let floatButton = floatButton, view.isDescendant(of: floatButton) {
            return view
        }

        if let menuView = menuView, view.isDescendant(of: menuView) {
            return view
        }

        return nil
    }
}

// MARK: - Float button
class ESPFloatButton: UIButton {
    init() {
        super.init(frame: CGRect(x: 16, y: 250, width: 44, height: 44))
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        setTitle("E", for: .normal)
        titleLabel?.font = .systemFont(ofSize: 20, weight: .black)
        backgroundColor = UIColor(red: 0.8, green: 0.15, blue: 0.15, alpha: 0.85)
        layer.cornerRadius = 22
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.6).cgColor
        setTitleColor(.white, for: .normal)
        layer.shadowColor = UIColor.red.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 6
        layer.shadowOffset = .zero
        isUserInteractionEnabled = true
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: superview)
        let prev = touch.previousLocation(in: superview)
        center = CGPoint(x: center.x + loc.x - prev.x, y: center.y + loc.y - prev.y)
    }
}

// MARK: - In-game menu
class ESPMenuView: UIView {
    weak var hackState: HackState?

    private let espToggle = UIButton(type: .system)
    private let boxToggle = UIButton(type: .system)
    private let healthToggle = UIButton(type: .system)
    private let distanceToggle = UIButton(type: .system)
    private let levelToggle = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    private var lastTouchPoint: CGPoint = .zero

    init() {
        super.init(frame: CGRect(x: UIScreen.main.bounds.width - 190, y: 120, width: 170, height: 280))
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setup() {
        backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.02, alpha: 0.92)
        layer.cornerRadius = 12
        layer.borderWidth = 1.5
        layer.borderColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 0.6).cgColor
        isUserInteractionEnabled = true

        let title = UILabel()
        title.text = "ESP-BOX"
        title.font = .systemFont(ofSize: 14, weight: .black)
        title.textColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 1)
        title.translatesAutoresizingMaskIntoConstraints = false
        addSubview(title)

        closeButton.setTitle("✕", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        closeButton.backgroundColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.8)
        closeButton.layer.cornerRadius = 12
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        configureButton(espToggle, title: "ESP: ON", action: #selector(togESP))
        configureButton(boxToggle, title: "Box: ON", action: #selector(togBox))
        configureButton(healthToggle, title: "HP: ON", action: #selector(togHP))
        configureButton(distanceToggle, title: "Dist: ON", action: #selector(togDist))
        configureButton(levelToggle, title: "Lv: ON", action: #selector(togLv))

        let stack = UIStackView(arrangedSubviews: [espToggle, boxToggle, healthToggle, distanceToggle, levelToggle])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),

            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            closeButton.widthAnchor.constraint(equalToConstant: 24),
            closeButton.heightAnchor.constraint(equalToConstant: 24),

            stack.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
        ])

        for btn in [espToggle, boxToggle, healthToggle, distanceToggle, levelToggle] {
            btn.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }
    }

    private func configureButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        button.backgroundColor = UIColor(white: 0.1, alpha: 0.85)
        button.layer.cornerRadius = 6
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.4).cgColor
        button.setTitleColor(.white, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    func refreshToggles() {
        guard let state = hackState else { return }
        espToggle.setTitle(state.isConnected ? "ESP: ON" : "ESP: OFF", for: .normal)
        boxToggle.setTitle(state.showBoxESP ? "Box: ON" : "Box: OFF", for: .normal)
        healthToggle.setTitle(state.showHealthBar ? "HP: ON" : "HP: OFF", for: .normal)
        distanceToggle.setTitle(state.showDistance ? "Dist: ON" : "Dist: OFF", for: .normal)
        levelToggle.setTitle(state.showLevel ? "Lv: ON" : "Lv: OFF", for: .normal)
    }

    @objc private func togESP() { hackState?.isConnected.toggle(); refreshToggles() }
    @objc private func togBox() { hackState?.showBoxESP.toggle(); refreshToggles() }
    @objc private func togHP() { hackState?.showHealthBar.toggle(); refreshToggles() }
    @objc private func togDist() { hackState?.showDistance.toggle(); refreshToggles() }
    @objc private func togLv() { hackState?.showLevel.toggle(); refreshToggles() }
    @objc private func closeTapped() {
        isHidden = true
        (superview as? PassThroughWindow)?.floatButton?.isHidden = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        lastTouchPoint = touch.location(in: superview)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: superview)
        center = CGPoint(x: center.x + loc.x - lastTouchPoint.x, y: center.y + loc.y - lastTouchPoint.y)
        lastTouchPoint = loc
    }
}

// MARK: - Overlay controller
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

    private var overlayWindow: PassThroughWindow?
    private var espView: ESPOverlayView?
    private var floatButton: ESPFloatButton?
    private var menuView: ESPMenuView?

    init(memoryManager: MemoryManager, baseAddress: UInt64, settings: HackState) {
        self.memory = memoryManager
        self.baseAddress = baseAddress
        self.hackState = settings
        super.init()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appDidEnterBackground() {
        // Keep window visible
        overlayWindow?.isHidden = false
        overlayWindow?.makeKeyAndVisible()
        startBackgroundKeepAlive()
    }

    @objc private func appWillEnterForeground() {
        overlayWindow?.isHidden = false
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        currentState = .waiting

        startBackgroundKeepAlive()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setupOverlayWindow()
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
            self.overlayWindow?.isHidden = true
            self.overlayWindow = nil
            self.espView = nil
            self.floatButton = nil
            self.menuView = nil
        }
    }

    private func setupOverlayWindow() {
        guard overlayWindow == nil else { return }

        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        let window = PassThroughWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.statusBar + 100
        window.backgroundColor = .clear
        window.isOpaque = false
        window.isUserInteractionEnabled = true

        let espView = ESPOverlayView(frame: windowScene.coordinateSpace.bounds)
        espView.backgroundColor = .clear
        espView.isUserInteractionEnabled = false

        let floatButton = ESPFloatButton()
        floatButton.addTarget(self, action: #selector(floatTapped), for: .touchUpInside)
        floatButton.isHidden = false

        let menuView = ESPMenuView()
        menuView.hackState = hackState
        menuView.isHidden = true

        let rootVC = UIViewController()
        rootVC.view.backgroundColor = .clear
        rootVC.view.isUserInteractionEnabled = true

        rootVC.view.addSubview(espView)
        rootVC.view.addSubview(floatButton)
        rootVC.view.addSubview(menuView)

        espView.frame = rootVC.view.bounds
        espView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        window.rootViewController = rootVC
        window.floatButton = floatButton
        window.menuView = menuView
        window.isHidden = false
        window.makeKeyAndVisible()

        overlayWindow = window
        self.espView = espView
        self.floatButton = floatButton
        self.menuView = menuView
    }

    @objc private func floatTapped() {
        menuView?.isHidden = false
        menuView?.refreshToggles()
        floatButton?.isHidden = true
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
                DispatchQueue.main.async { self.currentState = .waiting }
                return
            }

            guard let base = self.memory.findModuleBase(named: "legends") else {
                self.memory.detach()
                DispatchQueue.main.async { self.currentState = .waiting }
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
                self.menuView?.refreshToggles()
            }
        }
    }

    @objc private func renderFrame() {
        guard isRunning else { return }

        if let view = espView {
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

            // Generate 1 second low-volume sine wave
            let sampleRate = 44100
            let duration = 1.0
            let numSamples = Int(Double(sampleRate) * duration)
            let dataSize = numSamples * 2

            var wavData = Data()
            func appendLE32(_ val: UInt32) { withUnsafeBytes(of: val.littleEndian) { wavData.append(contentsOf: $0) } }
            func appendLE16(_ val: UInt16) { withUnsafeBytes(of: val.littleEndian) { wavData.append(contentsOf: $0) } }

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

            for i in 0..<numSamples {
                let value = sin(2.0 * .pi * 440.0 * Double(i) / Double(sampleRate)) * 0.01
                let sample = Int16(value * 32767.0)
                appendLE16(UInt16(bitPattern: sample))
            }

            let tempFile = URL(fileURLWithPath: NSTemporaryDirectory() + "keepalive.wav")
            try wavData.write(to: tempFile)

            audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.volume = 0.01
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
    override var prefersStatusBarHidden: Bool { return true }
    override var prefersHomeIndicatorAutoHidden: Bool { return true }
}
