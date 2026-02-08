import AVFoundation
import Combine
import SwiftUI

// MARK: - Data Models

struct CountdownTimer: Identifiable {
    let id = UUID()
    let label: String
    var remainingSeconds: Int
    var timer: Timer?
}

struct UICard: Identifiable {
    let id = UUID()
    let cardType: CardType
    let title: String
    let items: [String]

    enum CardType: String {
        case checklist, banner, alert
    }
}

// MARK: - Tool Executor

/// Executes tool commands from the backend: metronome, timers, UI cards.
class ToolExecutor: ObservableObject {
    @Published var isMetronomeActive: Bool = false
    @Published var metronomeBPM: Int = 110
    @Published var metronomeBeat: Bool = false  // Toggles each beat for visual pulse
    @Published var activeTimers: [CountdownTimer] = []
    @Published var activeCards: [UICard] = []

    private var metronomeTimer: Timer?

    // Audio player for metronome — uses AVAudioPlayer which routes through AVAudioSession (HFP)
    private var clickPlayer: AVAudioPlayer?
    private var clickData: Data?

    init() {
        // Generate a short click tone as WAV data
        clickData = ToolExecutor.generateClickWAV(frequency: 880, durationMs: 40)
    }

    // MARK: - Dispatch

    @MainActor
    func execute(tool: String, params: [String: Any]) {
        switch tool {
        case "start_metronome":
            let bpm = params["bpm"] as? Int ?? 110
            startMetronome(bpm: bpm)
        case "stop_metronome":
            stopMetronome()
        case "start_timer":
            let label = params["label"] as? String ?? "Timer"
            let seconds = params["seconds"] as? Int ?? 120
            startTimer(label: label, seconds: seconds)
        case "stop_timer":
            let label = params["label"] as? String ?? ""
            stopTimer(label: label)
        case "show_ui":
            let typeStr = params["card_type"] as? String ?? "checklist"
            let title = params["title"] as? String ?? ""
            let items = params["items"] as? [String] ?? []
            let cardType = UICard.CardType(rawValue: typeStr) ?? .checklist
            showCard(type: cardType, title: title, items: items)
        default:
            NSLog("[ToolExecutor] Unknown tool: \(tool)")
        }
    }

    // MARK: - Metronome

    @MainActor
    private func startMetronome(bpm: Int) {
        stopMetronome()
        metronomeBPM = bpm
        isMetronomeActive = true

        let interval = 60.0 / Double(bpm)
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.playClick()
            DispatchQueue.main.async {
                self?.metronomeBeat.toggle()
            }
        }
        // Play first beat immediately
        playClick()
    }

    @MainActor
    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        isMetronomeActive = false
    }

    /// Play a click sound through AVAudioPlayer (routes via AVAudioSession → HFP → glasses speaker)
    private func playClick() {
        guard let data = clickData else { return }
        do {
            clickPlayer = try AVAudioPlayer(data: data)
            clickPlayer?.volume = 1.0
            clickPlayer?.play()
        } catch {
            NSLog("[Metronome] Play error: \(error)")
        }
    }

    /// Generate a short sine wave click as WAV data
    static func generateClickWAV(frequency: Double, durationMs: Int) -> Data {
        let sampleRate = 44100.0
        let numSamples = Int(sampleRate * Double(durationMs) / 1000.0)
        let amplitude: Int16 = 20000

        // WAV header (44 bytes) + PCM16 data
        let dataSize = numSamples * 2
        let fileSize = 36 + dataSize

        var wav = Data()

        // RIFF header
        wav.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Array($0) })
        wav.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // "WAVE"

        // fmt chunk
        wav.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // "fmt "
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) }) // chunk size
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // PCM
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) }) // mono
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(44100).littleEndian) { Array($0) }) // sample rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(88200).littleEndian) { Array($0) }) // byte rate
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) }) // block align
        wav.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) }) // bits per sample

        // data chunk
        wav.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // "data"
        wav.append(contentsOf: withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Array($0) })

        // Generate sine wave with quick fade-out
        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = max(0, 1.0 - (Double(i) / Double(numSamples))) // Linear fade-out
            let sample = Int16(Double(amplitude) * sin(2.0 * .pi * frequency * t) * envelope)
            wav.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Array($0) })
        }

        return wav
    }

    // MARK: - Timers

    @MainActor
    private func startTimer(label: String, seconds: Int) {
        stopTimer(label: label)

        var countdown = CountdownTimer(label: label, remainingSeconds: seconds)

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            DispatchQueue.main.async {
                guard let self else { t.invalidate(); return }
                if let idx = self.activeTimers.firstIndex(where: { $0.label == label }) {
                    self.activeTimers[idx].remainingSeconds -= 1
                    if self.activeTimers[idx].remainingSeconds <= 0 {
                        // Timer fired — play alert tone
                        self.playTimerAlert()
                        t.invalidate()
                        self.activeTimers.remove(at: idx)
                    }
                }
            }
        }

        countdown.timer = timer
        activeTimers.append(countdown)
    }

    @MainActor
    private func stopTimer(label: String) {
        if let idx = activeTimers.firstIndex(where: { $0.label == label }) {
            activeTimers[idx].timer?.invalidate()
            activeTimers.remove(at: idx)
        }
    }

    private func playTimerAlert() {
        // Three quick beeps
        let alertData = ToolExecutor.generateClickWAV(frequency: 1200, durationMs: 100)
        do {
            clickPlayer = try AVAudioPlayer(data: alertData)
            clickPlayer?.numberOfLoops = 2
            clickPlayer?.volume = 1.0
            clickPlayer?.play()
        } catch {
            NSLog("[Timer] Alert error: \(error)")
        }
    }

    // MARK: - UI Cards

    @MainActor
    private func showCard(type: UICard.CardType, title: String, items: [String]) {
        let card = UICard(cardType: type, title: title, items: items)
        activeCards.append(card)
    }

    @MainActor
    func dismissCard(_ card: UICard) {
        activeCards.removeAll { $0.id == card.id }
    }

    @MainActor
    func dismissAllCards() {
        activeCards.removeAll()
    }

    // MARK: - Cleanup

    @MainActor
    func stopAll() {
        stopMetronome()
        for t in activeTimers { t.timer?.invalidate() }
        activeTimers.removeAll()
        activeCards.removeAll()
    }
}

// MARK: - Helper: Format Timer

extension Int {
    var timerString: String {
        let m = self / 60
        let s = self % 60
        return String(format: "%d:%02d", m, s)
    }
}
