import AVFoundation
import Combine
import Speech

/// Handles raw PCM16 24kHz audio capture from glasses mic (via HFP Bluetooth),
/// playback of AI response audio, and wake word detection.
class AudioManager: ObservableObject {
    @Published var isCapturing: Bool = false
    @Published var isActivated: Bool = false  // True when wake word detected or emergency active
    @Published var wakeWordStatus: String = "Say \"Medkit\" to start"

    /// Called when activation state changes
    var onActivationChanged: ((Bool) -> Void)?

    private var audioEngine = AVAudioEngine()
    private var playerNode = AVAudioPlayerNode()
    private var inputConverter: AVAudioConverter?
    private var onAudioChunk: ((Data) -> Void)?
    private var isPlayerAttached = false

    // Wake word detection
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var deactivationTimer: Timer?
    // All variations SFSpeechRecognizer might hear when user says "medkit"
    private let wakePhrases = ["medkit", "med kit", "medic", "med cat", "metric", "meg kit", "med get"]
    private let deactivationDelay: TimeInterval = 15.0  // Seconds of silence before deactivating

    // If true, skip wake word (active emergency)
    var alwaysActive: Bool = false {
        didSet {
            if alwaysActive && !isActivated {
                activate(reason: "Emergency active")
            }
        }
    }

    // PCM16, 24kHz, mono — what OpenAI Realtime sends/expects
    private let pcm16Format = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 24000,
        channels: 1,
        interleaved: true
    )!

    // Float32, 24kHz, mono — what AVAudioPlayerNode needs
    private let playerFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24000,
        channels: 1,
        interleaved: false
    )!

    // MARK: - Audio Session

    func setupAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func requestPermissions() async -> Bool {
        // Mic permission
        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            micStatus = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }

        // Speech recognition permission (for wake word)
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }

        return micStatus && speechStatus
    }

    // MARK: - Audio Capture

    func startCapture(onChunk: @escaping (Data) -> Void) {
        guard !isCapturing else { return }
        self.onAudioChunk = onChunk

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        if !isPlayerAttached {
            audioEngine.attach(playerNode)
            audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playerFormat)
            isPlayerAttached = true
        }

        inputConverter = AVAudioConverter(from: inputFormat, to: pcm16Format)

        // Single tap: feeds both wake word detector and PCM16 conversion
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Always feed to wake word detector
            self.recognitionRequest?.append(buffer)

            // Only convert and send audio when activated
            if self.isActivated, let converter = self.inputConverter {
                self.convertAndDeliver(buffer: buffer, converter: converter)
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            DispatchQueue.main.async { self.isCapturing = true }
            startWakeWordDetection()
        } catch {
            NSLog("[AudioManager] Engine start failed: \(error)")
        }
    }

    func stopCapture() {
        guard isCapturing else { return }
        stopWakeWordDetection()
        audioEngine.inputNode.removeTap(onBus: 0)
        playerNode.stop()
        audioEngine.stop()
        onAudioChunk = nil
        deactivationTimer?.invalidate()
        DispatchQueue.main.async {
            self.isCapturing = false
            self.isActivated = false
        }
    }

    // MARK: - Wake Word Detection

    private func startWakeWordDetection() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            NSLog("[WakeWord] Speech recognizer unavailable — activating permanently")
            activate(reason: "No speech recognizer")
            return
        }

        stopWakeWordDetection()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString.lowercased()
                NSLog("[WakeWord] Heard: \"\(text)\"")

                // Check for any wake phrase variation
                if !self.isActivated {
                    let matched = self.wakePhrases.contains(where: { text.contains($0) })
                    if matched {
                        NSLog("[WakeWord] MATCH found in: \"\(text)\"")
                        DispatchQueue.main.async {
                            self.activate(reason: "Wake word detected: \(text)")
                        }
                    }
                }

                // If activated, reset the deactivation timer on any speech
                if self.isActivated {
                    DispatchQueue.main.async {
                        self.resetDeactivationTimer()
                    }
                }
            }

            if let error {
                NSLog("[WakeWord] Error: \(error.localizedDescription)")
            }

            // Restart on timeout/error (SFSpeechRecognizer has ~1min limit)
            if error != nil || (result?.isFinal ?? false) {
                DispatchQueue.main.async {
                    self.restartWakeWordDetection()
                }
            }
        }
    }

    private func stopWakeWordDetection() {
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
    }

    private func restartWakeWordDetection() {
        stopWakeWordDetection()
        // Small delay to avoid rapid restart loops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.isCapturing else { return }
            self.startWakeWordDetection()
        }
    }

    // MARK: - Activation

    private func activate(reason: String) {
        guard !isActivated else { return }
        isActivated = true
        wakeWordStatus = "Listening..."
        onActivationChanged?(true)
        resetDeactivationTimer()
        NSLog("[WakeWord] Activated: \(reason)")
    }

    /// Called when the user speaks or the model responds — keeps the session alive
    func keepActive() {
        if isActivated {
            resetDeactivationTimer()
        }
    }

    func deactivate() {
        guard isActivated, !alwaysActive else { return }
        isActivated = false
        wakeWordStatus = "Say \"Medkit\" to start"
        deactivationTimer?.invalidate()
        onActivationChanged?(false)
        NSLog("[WakeWord] Deactivated")
    }

    private func resetDeactivationTimer() {
        deactivationTimer?.invalidate()
        guard !alwaysActive else { return }
        deactivationTimer = Timer.scheduledTimer(withTimeInterval: deactivationDelay, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.deactivate()
            }
        }
    }

    // MARK: - PCM16 Conversion

    private func convertAndDeliver(buffer: AVAudioPCMBuffer, converter: AVAudioConverter) {
        let ratio = pcm16Format.sampleRate / buffer.format.sampleRate
        let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
        guard frameCount > 0 else { return }

        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: pcm16Format,
            frameCapacity: frameCount
        ) else { return }

        var error: NSError?
        var hasData = true

        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        if let error {
            NSLog("[AudioManager] Conversion error: \(error)")
            return
        }

        guard convertedBuffer.frameLength > 0 else { return }

        let byteCount = Int(convertedBuffer.frameLength) * 2
        let data = Data(bytes: convertedBuffer.int16ChannelData![0], count: byteCount)
        onAudioChunk?(data)
    }

    // MARK: - Audio Playback

    func playAudioChunk(_ data: Data) {
        guard data.count >= 2 else { return }

        let sampleCount = data.count / 2

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playerFormat,
            frameCapacity: UInt32(sampleCount)
        ) else { return }

        buffer.frameLength = UInt32(sampleCount)

        // Convert Int16 samples to Float32 manually — no converter needed
        let floatPtr = buffer.floatChannelData![0]
        data.withUnsafeBytes { raw in
            let int16Ptr = raw.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                floatPtr[i] = Float(int16Ptr[i]) / 32768.0
            }
        }

        playerNode.scheduleBuffer(buffer)
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    func stopPlayback() {
        playerNode.stop()
    }
}
