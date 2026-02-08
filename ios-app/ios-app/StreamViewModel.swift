import Combine
import MWDATCamera
import MWDATCore
import SwiftUI

// MARK: - Configuration

enum BackendConfig {
    static let webSocketURL = "wss://aaditkrishna04--first-aid-coach-create-app-dev.modal.run/ws"
}

@MainActor
class StreamViewModel: ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var streamingStatus: StreamingStatus = .stopped
    @Published var hasActiveDevice: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    // Transcripts from backend
    @Published var userTranscript: String = ""
    @Published var agentTranscript: String = ""
    @Published var sceneObservation: String = ""
    @Published var isConnected: Bool = false

    // Wake word / activation
    @Published var isActivated: Bool = false
    @Published var wakeWordStatus: String = "Say \"Hey Coach\" to start"

    // Scenario from backend
    @Published var currentScenario: String = "none"
    @Published var scenarioSeverity: String = "minor"
    @Published var scenarioSummary: String = ""
    @Published var bodyRegion: String = ""

    var isStreaming: Bool { streamingStatus != .stopped }

    let audioManager = AudioManager()
    let wsManager = WebSocketManager()
    let toolExecutor = ToolExecutor()
    let sessionLogger = SessionLogger()

    private var streamSession: StreamSession
    private var sceneObservations: [String] = []
    private var stateToken: AnyListenerToken?
    private var frameToken: AnyListenerToken?
    private var errorToken: AnyListenerToken?
    private var deviceMonitorTask: Task<Void, Never>?
    private var frameSamplingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private let wearables: WearablesInterface

    enum StreamingStatus {
        case streaming, waiting, stopped
    }

    init(wearables: WearablesInterface) {
        self.wearables = wearables

        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .low,
            frameRate: 24
        )
        self.streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)

        // Monitor device availability
        deviceMonitorTask = Task { @MainActor in
            for await device in deviceSelector.activeDeviceStream() {
                self.hasActiveDevice = device != nil
            }
        }

        // Listen for state changes
        stateToken = streamSession.statePublisher.listen { [weak self] state in
            Task { @MainActor [weak self] in
                self?.updateStatus(from: state)
            }
        }

        // Listen for video frames
        frameToken = streamSession.videoFramePublisher.listen { [weak self] frame in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let image = frame.makeUIImage() {
                    self.currentFrame = image
                    // Record frame for video
                    if self.sessionLogger.isRecording {
                        self.sessionLogger.appendVideoFrame(image)
                    }
                }
            }
        }

        // Listen for errors
        errorToken = streamSession.errorPublisher.listen { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.showError(self.describe(error))
            }
        }

        updateStatus(from: streamSession.state)

        // Forward WebSocketManager changes for SwiftUI
        wsManager.$userTranscript.receive(on: DispatchQueue.main).assign(to: &$userTranscript)
        wsManager.$agentTranscript.receive(on: DispatchQueue.main).assign(to: &$agentTranscript)
        wsManager.$latestSceneObservation.receive(on: DispatchQueue.main).sink { [weak self] observation in
            self?.sceneObservation = observation
            if !observation.isEmpty && !(self?.sceneObservations.contains(observation) ?? false) {
                self?.sceneObservations.append(observation)
                self?.sessionLogger.logSceneObservation(observation)
            }
        }.store(in: &cancellables)
        wsManager.$isConnected.receive(on: DispatchQueue.main).assign(to: &$isConnected)
        
        // Set up transcript logging callbacks
        wsManager.onUserTranscript = { [weak self] text in
            guard let self = self, !text.isEmpty else { return }
            self.sessionLogger.logUserTranscript(text)
        }
        
        wsManager.onAgentTranscriptDelta = { [weak self] delta in
            guard let self = self, !delta.isEmpty else { return }
            self.sessionLogger.logAgentTranscript(delta, isComplete: false)
        }
        
        wsManager.onAgentTranscriptComplete = { [weak self] completeText in
            guard let self = self, !completeText.isEmpty else { return }
            self.sessionLogger.logAgentTranscript(completeText, isComplete: true)
        }

        // Forward AudioManager activation state
        audioManager.$isActivated.receive(on: DispatchQueue.main).assign(to: &$isActivated)
        audioManager.$wakeWordStatus.receive(on: DispatchQueue.main).assign(to: &$wakeWordStatus)

        // Wire WebSocket callbacks
        wsManager.onAudioReceived = { [weak self] data in
            self?.audioManager.keepActive()  // AI is responding — keep session alive
            self?.audioManager.playAudioChunk(data)
        }

        wsManager.onToolCommand = { [weak self] name, params in
            Task { @MainActor in
                self?.toolExecutor.execute(tool: name, params: params)
            }
        }

        wsManager.onInterrupt = { [weak self] in
            self?.audioManager.stopPlayback()
        }

        // Handle scenario updates from backend
        wsManager.onScenarioUpdate = { [weak self] scenario, severity, summary, bodyRegion in
            Task { @MainActor in
                guard let self else { return }
                self.currentScenario = scenario
                self.scenarioSeverity = severity
                self.scenarioSummary = summary
                self.bodyRegion = bodyRegion

                // During critical/moderate emergencies, disable wake word requirement
                let isEmergency = severity == "critical" || severity == "moderate"
                self.audioManager.alwaysActive = isEmergency

                // When scenario resolves, re-enable wake word
                if scenario == "resolved" || scenario == "none" {
                    self.audioManager.alwaysActive = false
                }
            }
        }
    }

    // MARK: - Streaming Lifecycle

    func startStreaming() async {
        // 1. Set up HFP audio session BEFORE starting stream
        do {
            try audioManager.setupAudioSession()
        } catch {
            showError("Audio setup failed: \(error.localizedDescription)")
            return
        }

        // 2. Request mic + speech permission
        let hasPerms = await audioManager.requestPermissions()
        if !hasPerms {
            showError("Microphone or speech recognition permission denied.")
        }

        // 3. Check camera permission
        do {
            let status = try await wearables.checkPermissionStatus(.camera)
            if status != .granted {
                let requested = try await wearables.requestPermission(.camera)
                guard requested == .granted else {
                    showError("Camera permission denied.")
                    return
                }
            }
        } catch {
            showError("Permission error: \(error.localizedDescription)")
            return
        }

        // 4. Wait for HFP to be ready
        try? await Task.sleep(nanoseconds: 2 * NSEC_PER_SEC)

        // 5. Start the stream session (video from glasses)
        await streamSession.start()

        // 6. Connect WebSocket to Modal backend
        wsManager.connect(to: BackendConfig.webSocketURL)

        // 7. Start audio capture with wake word gating
        // Audio only flows to backend when isActivated == true
        audioManager.startCapture { [weak self] audioData in
            self?.wsManager.sendAudio(audioData)
        }

        // 8. Start frame sampling → send JPEG to backend every 3s
        startFrameSampling()
        
        // 9. Start video recording
        do {
            try sessionLogger.startVideoRecording()
        } catch {
            NSLog("[StreamViewModel] Failed to start video recording: \(error)")
        }
    }

    func stopStreaming() async {
        frameSamplingTask?.cancel()
        frameSamplingTask = nil
        audioManager.stopCapture()
        toolExecutor.stopAll()
        wsManager.disconnect()
        await streamSession.stop()
        
        // Stop video recording
        if sessionLogger.isRecording {
            do {
                _ = try await sessionLogger.stopVideoRecording()
            } catch {
                NSLog("[StreamViewModel] Failed to stop video recording: \(error)")
            }
        }
    }

    func dismissError() {
        showError = false
        errorMessage = ""
    }

    // MARK: - Frame Sampling

    private func startFrameSampling() {
        frameSamplingTask?.cancel()
        frameSamplingTask = Task { @MainActor in
            while !Task.isCancelled {
                if let image = currentFrame,
                   let jpegData = image.jpegData(compressionQuality: 0.5) {
                    wsManager.sendFrame(jpegData)
                }
                try? await Task.sleep(nanoseconds: 3 * NSEC_PER_SEC)
            }
        }
    }

    // MARK: - Private

    private func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    private func updateStatus(from state: StreamSessionState) {
        switch state {
        case .stopped:
            currentFrame = nil
            streamingStatus = .stopped
        case .waitingForDevice, .starting, .stopping, .paused:
            streamingStatus = .waiting
        case .streaming:
            streamingStatus = .streaming
        }
    }

    private func describe(_ error: StreamSessionError) -> String {
        switch error {
        case .deviceNotFound: return "Device not found."
        case .deviceNotConnected: return "Device not connected."
        case .timeout: return "Connection timed out."
        case .videoStreamingError: return "Video streaming failed."
        case .permissionDenied: return "Camera permission denied."
        case .hingesClosed: return "Glasses hinges are closed. Open them to stream."
        case .internalError: return "Internal error occurred."
        case .audioStreamingError: return "Audio streaming error."
        @unknown default: return "Unknown streaming error."
        }
    }
    
    // MARK: - Session Logging & Export
    
    func exportVideo() async throws -> URL {
        // If recording, stop it first
        if sessionLogger.isRecording {
            return try await sessionLogger.stopVideoRecording()
        }
        
        // Otherwise, try to find the last recorded video
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoURL = documentsPath.appendingPathComponent("\(sessionLogger.getSessionId()).mp4")
        
        if FileManager.default.fileExists(atPath: videoURL.path) {
            return videoURL
        } else {
            throw NSError(domain: "StreamViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video recording available"])
        }
    }
    
    func exportTranscriptPDF() throws -> URL {
        return try sessionLogger.exportTranscriptPDF(
            scenario: currentScenario,
            severity: scenarioSeverity,
            summary: scenarioSummary,
            bodyRegion: bodyRegion,
            sceneObservations: sceneObservations
        )
    }
    
    func exportEMSReport() throws -> URL {
        return try sessionLogger.generateEMSReport(
            scenario: currentScenario,
            severity: scenarioSeverity,
            summary: scenarioSummary,
            bodyRegion: bodyRegion,
            sceneObservations: sceneObservations
        )
    }
    
    var hasSessionData: Bool {
        // Check if there's any data to export
        return !sessionLogger.getSessionId().isEmpty
    }
}
