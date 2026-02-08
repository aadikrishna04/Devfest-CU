import Combine
import Foundation

struct SavedSession: Codable, Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let scenario: String
    let severity: String
    let summary: String
    let bodyRegion: String
    let reportFileName: String  // PDF filename in documents dir
    let videoFileName: String?  // MP4 filename in documents dir, nil if no video

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var durationString: String {
        let mins = Int(duration) / 60
        let secs = Int(duration) % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }

    var hasScenario: Bool {
        !scenario.isEmpty && scenario != "none"
    }

    var reportURL: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(reportFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    var videoURL: URL? {
        guard let videoFileName else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = docs.appendingPathComponent(videoFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

@MainActor
class SessionStore: ObservableObject {
    @Published var sessions: [SavedSession] = []

    private let fileName = "saved_sessions.json"

    init() {
        load()
    }

    func save(_ session: SavedSession) {
        sessions.insert(session, at: 0) // newest first
        persist()
    }

    func delete(_ session: SavedSession) {
        sessions.removeAll { $0.id == session.id }

        // Delete files
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: docs.appendingPathComponent(session.reportFileName))
        if let videoName = session.videoFileName {
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(videoName))
        }

        persist()
    }

    private func load() {
        let url = fileURL()
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            sessions = try JSONDecoder().decode([SavedSession].self, from: data)
        } catch {
            NSLog("[SessionStore] Failed to load sessions: \(error)")
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(sessions)
            try data.write(to: fileURL(), options: .atomic)
        } catch {
            NSLog("[SessionStore] Failed to save sessions: \(error)")
        }
    }

    private func fileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}
