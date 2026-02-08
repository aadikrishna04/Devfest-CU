import Combine
import Foundation

/// WebSocket client to the Modal backend.
/// Sends audio chunks + video frames up, receives audio + transcripts + tool commands back.
class WebSocketManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var userTranscript: String = ""
    @Published var agentTranscript: String = ""
    @Published var latestSceneObservation: String = ""

    /// Callbacks set by StreamViewModel
    var onAudioReceived: ((Data) -> Void)?
    var onToolCommand: ((String, [String: Any]) -> Void)?
    var onInterrupt: (() -> Void)?
    var onScenarioUpdate: ((String, String, String, String) -> Void)?  // scenario, severity, summary, bodyRegion

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?

    // MARK: - Connection

    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            NSLog("[WS] Invalid URL: \(urlString)")
            return
        }

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)

        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()

        DispatchQueue.main.async { self.isConnected = true }
        NSLog("[WS] Connecting to \(urlString)")

        // Start receive loop
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }

        // Start ping loop for keep-alive
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15 * NSEC_PER_SEC)
                self?.webSocketTask?.sendPing { error in
                    if let error {
                        NSLog("[WS] Ping failed: \(error)")
                    }
                }
            }
        }
    }

    func disconnect() {
        pingTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        DispatchQueue.main.async { self.isConnected = false }
        NSLog("[WS] Disconnected")
    }

    // MARK: - Sending

    /// Send a raw audio chunk (PCM16 24kHz) as base64.
    func sendAudio(_ data: Data) {
        let b64 = data.base64EncodedString()
        let msg: [String: Any] = ["type": "audio", "data": b64]
        sendJSON(msg)
    }

    /// Send a video frame (JPEG) as base64.
    func sendFrame(_ jpegData: Data) {
        let b64 = jpegData.base64EncodedString()
        let msg: [String: Any] = ["type": "frame", "data": b64]
        sendJSON(msg)
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8)
        else { return }

        webSocketTask?.send(.string(text)) { error in
            if let error {
                NSLog("[WS] Send error: \(error)")
            }
        }
    }

    // MARK: - Receiving

    private func receiveLoop() async {
        while !Task.isCancelled {
            guard let ws = webSocketTask else { break }

            do {
                let message = try await ws.receive()

                switch message {
                case .string(let text):
                    handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleMessage(text)
                    }
                @unknown default:
                    break
                }

            } catch {
                NSLog("[WS] Receive error: \(error)")
                await MainActor.run { self.isConnected = false }
                break
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        switch type {
        case "audio":
            // Base64 PCM16 audio from AI → decode and play
            if let b64 = json["data"] as? String,
               let audioData = Data(base64Encoded: b64) {
                onAudioReceived?(audioData)
            }

        case "transcript":
            let role = json["role"] as? String ?? ""
            if role == "user" {
                let text = json["text"] as? String ?? ""
                DispatchQueue.main.async { self.userTranscript = text }
            } else if role == "assistant" {
                let delta = json["delta"] as? String ?? ""
                DispatchQueue.main.async { self.agentTranscript += delta }
            }

        case "interrupt":
            // User started speaking — stop AI audio playback
            onInterrupt?()
            DispatchQueue.main.async { self.agentTranscript = "" }

        case "tool":
            let name = json["name"] as? String ?? ""
            let params = json["params"] as? [String: Any] ?? [:]
            onToolCommand?(name, params)

        case "scene_update":
            let obs = json["observation"] as? String ?? ""
            DispatchQueue.main.async { self.latestSceneObservation = obs }

        case "scenario_update":
            let scenario = json["scenario"] as? String ?? "none"
            let severity = json["severity"] as? String ?? "minor"
            let summary = json["summary"] as? String ?? ""
            let bodyRegion = json["body_region"] as? String ?? ""
            onScenarioUpdate?(scenario, severity, summary, bodyRegion)

        case "transcript_done":
            break  // Agent finished speaking — no action needed

        default:
            NSLog("[WS] Unknown message type: \(type)")
        }
    }
}
