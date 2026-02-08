import Foundation
import AVFoundation
import UIKit
import PDFKit

/// Manages session logging: transcripts with timestamps, video recording, and report generation
@MainActor
class SessionLogger: ObservableObject {
    @Published var isRecording: Bool = false
    
    // Session metadata
    private var sessionId: String
    private var sessionStartTime: Date
    
    // Transcript storage
    private var transcriptEntries: [TranscriptEntry] = []
    
    // Video recording
    private var videoWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var frameCount: Int = 0
    private var videoStartTime: CMTime?
    private var lastFrameTime: CMTime?
    
    // Audio recording (for video)
    private var audioWriterInput: AVAssetWriterInput?
    
    struct TranscriptEntry: Codable {
        let timestamp: Date
        let role: String // "user" or "assistant"
        let text: String
        let isDelta: Bool // true if this is a partial update
    }
    
    struct SessionMetadata: Codable {
        let sessionId: String
        let startTime: Date
        let endTime: Date?
        let scenario: String
        let scenarioSeverity: String
        let scenarioSummary: String
        let bodyRegion: String
        let sceneObservations: [String]
    }
    
    init() {
        self.sessionId = UUID().uuidString
        self.sessionStartTime = Date()
    }
    
    // MARK: - Transcript Logging
    
    func logUserTranscript(_ text: String) {
        let entry = TranscriptEntry(
            timestamp: Date(),
            role: "user",
            text: text,
            isDelta: false
        )
        transcriptEntries.append(entry)
    }
    
    func logAgentTranscript(_ delta: String, isComplete: Bool = false) {
        if isComplete {
            // If complete, we might want to merge with last entry if it was a delta
            if let lastEntry = transcriptEntries.last,
               lastEntry.role == "assistant" && lastEntry.isDelta {
                // Replace the last delta entry with complete text
                transcriptEntries.removeLast()
                let completeText = lastEntry.text + delta
                let entry = TranscriptEntry(
                    timestamp: lastEntry.timestamp,
                    role: "assistant",
                    text: completeText,
                    isDelta: false
                )
                transcriptEntries.append(entry)
            } else {
                let entry = TranscriptEntry(
                    timestamp: Date(),
                    role: "assistant",
                    text: delta,
                    isDelta: false
                )
                transcriptEntries.append(entry)
            }
        } else {
            // Delta update - append to last entry or create new
            if let lastEntry = transcriptEntries.last,
               lastEntry.role == "assistant" && lastEntry.isDelta {
                // Update last delta entry
                transcriptEntries.removeLast()
                let updatedText = lastEntry.text + delta
                let entry = TranscriptEntry(
                    timestamp: lastEntry.timestamp,
                    role: "assistant",
                    text: updatedText,
                    isDelta: true
                )
                transcriptEntries.append(entry)
            } else {
                let entry = TranscriptEntry(
                    timestamp: Date(),
                    role: "assistant",
                    text: delta,
                    isDelta: true
                )
                transcriptEntries.append(entry)
            }
        }
    }
    
    func logSceneObservation(_ observation: String) {
        // Scene observations are logged separately but can be included in reports
    }
    
    // MARK: - Video Recording
    
    func startVideoRecording() throws {
        guard !isRecording else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videoURL = documentsPath.appendingPathComponent("\(sessionId).mp4")
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: videoURL)
        
        // Create video writer
        videoWriter = try AVAssetWriter(outputURL: videoURL, fileType: .mp4)
        
        // Video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 640,
            AVVideoHeightKey: 480,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2000000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
        
        guard let videoWriterInput = videoWriterInput,
              let videoWriter = videoWriter else {
            throw NSError(domain: "SessionLogger", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video writer"])
        }
        
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        
        // Pixel buffer adaptor for appending frames
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: 640,
            kCVPixelBufferHeightKey as String: 480
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )
        
        frameCount = 0
        videoStartTime = nil
        lastFrameTime = nil
        
        if videoWriter.startWriting() {
            isRecording = true
        } else {
            throw videoWriter.error ?? NSError(domain: "SessionLogger", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to start video writer"])
        }
    }
    
    func appendVideoFrame(_ image: UIImage) {
        guard isRecording,
              let videoWriter = videoWriter,
              let videoWriterInput = videoWriterInput,
              let pixelBufferAdaptor = pixelBufferAdaptor,
              videoWriterInput.isReadyForMoreMediaData else {
            return
        }
        
        let frameTime = CMTime(value: Int64(frameCount), timescale: 30) // 30 fps
        
        if videoStartTime == nil {
            videoStartTime = frameTime
            videoWriter.startSession(atSourceTime: frameTime)
        }
        
        guard let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
            return
        }
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        // Convert UIImage to pixel buffer
        let context = CIContext()
        if let ciImage = CIImage(image: image) {
            context.render(ciImage, to: buffer)
        }
        
        if pixelBufferAdaptor.append(buffer, withPresentationTime: frameTime) {
            frameCount += 1
            lastFrameTime = frameTime
        }
    }
    
    func stopVideoRecording() async throws -> URL {
        guard isRecording else {
            throw NSError(domain: "SessionLogger", code: 3, userInfo: [NSLocalizedDescriptionKey: "Not recording"])
        }
        
        isRecording = false
        
        guard let videoWriter = videoWriter,
              let videoWriterInput = videoWriterInput else {
            throw NSError(domain: "SessionLogger", code: 4, userInfo: [NSLocalizedDescriptionKey: "Video writer not initialized"])
        }
        
        videoWriterInput.markAsFinished()
        
        return try await withCheckedThrowingContinuation { continuation in
            videoWriter.finishWriting {
                if let error = videoWriter.error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: videoWriter.outputURL)
                }
            }
        }
    }
    
    // MARK: - PDF Export
    
    func exportTranscriptPDF(scenario: String, severity: String, summary: String, bodyRegion: String, sceneObservations: [String]) throws -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "MedKit First-Aid Coach",
            kCGPDFContextTitle: "Session Transcript - \(sessionId)"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0 // US Letter width in points
        let pageHeight = 11.0 * 72.0 // US Letter height in points
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let pdfURL = documentsPath.appendingPathComponent("\(sessionId)_transcript.pdf")
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 72.0 // Start 1 inch from top
            let margin: CGFloat = 72.0
            let contentWidth = pageWidth - (2 * margin)
            
            // Title
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 24),
                .foregroundColor: UIColor.black
            ]
            let title = "Session Transcript"
            title.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 40
            
            // Session info
            let infoAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.gray
            ]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
            let sessionInfo = "Session ID: \(sessionId)\nStart Time: \(dateFormatter.string(from: sessionStartTime))"
            sessionInfo.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: infoAttributes)
            yPosition += 50
            
            // Scenario info
            if scenario != "none" {
                let scenarioAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: UIColor.black
                ]
                let scenarioText = "Scenario: \(scenario.uppercased())\nSeverity: \(severity)\nBody Region: \(bodyRegion)\nSummary: \(summary)"
                scenarioText.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: scenarioAttributes)
                yPosition += 60
            }
            
            // Scene observations
            if !sceneObservations.isEmpty {
                let obsTitle = "Scene Observations:"
                obsTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
                yPosition += 25
                
                for observation in sceneObservations {
                    let obsText = "• \(observation)"
                    let obsRect = CGRect(x: margin, y: yPosition, width: contentWidth, height: CGFloat.greatestFiniteMagnitude)
                    let obsAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11),
                        .foregroundColor: UIColor.darkGray
                    ]
                    let boundingRect = obsText.boundingRect(
                        with: CGSize(width: contentWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: obsAttributes,
                        context: nil
                    )
                    obsText.draw(in: obsRect, withAttributes: obsAttributes)
                    yPosition += boundingRect.height + 10
                    
                    if yPosition > pageHeight - 100 {
                        context.beginPage()
                        yPosition = 72.0
                    }
                }
                yPosition += 20
            }
            
            // Transcript entries
            let transcriptTitle = "Conversation Transcript:"
            transcriptTitle.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: titleAttributes)
            yPosition += 30
            
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .medium
            
            for entry in transcriptEntries {
                // Check if we need a new page
                if yPosition > pageHeight - 150 {
                    context.beginPage()
                    yPosition = 72.0
                }
                
                let timeString = timeFormatter.string(from: entry.timestamp)
                let roleString = entry.role == "user" ? "User" : "Assistant"
                
                // Timestamp and role
                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 10),
                    .foregroundColor: entry.role == "user" ? UIColor.blue : UIColor.green
                ]
                let header = "[\(timeString)] \(roleString):"
                header.draw(at: CGPoint(x: margin, y: yPosition), withAttributes: headerAttributes)
                yPosition += 18
                
                // Text content
                let textRect = CGRect(x: margin + 20, y: yPosition, width: contentWidth - 20, height: CGFloat.greatestFiniteMagnitude)
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.black
                ]
                let boundingRect = entry.text.boundingRect(
                    with: CGSize(width: contentWidth - 20, height: CGFloat.greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: textAttributes,
                    context: nil
                )
                entry.text.draw(in: textRect, withAttributes: textAttributes)
                yPosition += boundingRect.height + 20
            }
        }
        
        try data.write(to: pdfURL)
        return pdfURL
    }
    
    // MARK: - EMS Report Generation
    
    func generateEMSReport(scenario: String, severity: String, summary: String, bodyRegion: String, sceneObservations: [String]) throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .full
        
        var report = """
        ============================================
        EMS READY REPORT - FIRST AID SESSION
        ============================================
        
        SESSION INFORMATION
        --------------------
        Session ID: \(sessionId)
        Start Time: \(dateFormatter.string(from: sessionStartTime))
        End Time: \(dateFormatter.string(from: Date()))
        Duration: \(String(format: "%.1f", Date().timeIntervalSince(sessionStartTime))) seconds
        
        """
        
        if scenario != "none" {
            report += """
            SCENARIO DETAILS
            ----------------
            Type: \(scenario.uppercased())
            Severity: \(severity.uppercased())
            Body Region: \(bodyRegion)
            Summary: \(summary)
            
            """
        }
        
        if !sceneObservations.isEmpty {
            report += """
            SCENE OBSERVATIONS
            -----------------
            """
            for (index, observation) in sceneObservations.enumerated() {
                report += "\(index + 1). \(observation)\n"
            }
            report += "\n"
        }
        
        report += """
        CONVERSATION TRANSCRIPT
        -----------------------
        """
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        
        for entry in transcriptEntries {
            let timeString = timeFormatter.string(from: entry.timestamp)
            let roleString = entry.role == "user" ? "USER" : "ASSISTANT"
            report += "[\(timeString)] \(roleString): \(entry.text)\n\n"
        }
        
        report += """
        
        KEY INFORMATION SUMMARY
        ------------------------
        """
        
        // Extract key information
        var userStatements: [String] = []
        var assistantInstructions: [String] = []
        
        for entry in transcriptEntries {
            if entry.role == "user" {
                userStatements.append(entry.text)
            } else {
                assistantInstructions.append(entry.text)
            }
        }
        
        report += """
        User Statements (\(userStatements.count) total):
        """
        for statement in userStatements {
            report += "\n• \(statement)"
        }
        
        report += """
        
        
        Assistant Instructions (\(assistantInstructions.count) total):
        """
        for instruction in assistantInstructions {
            report += "\n• \(instruction)"
        }
        
        report += """
        
        
        ============================================
        END OF REPORT
        ============================================
        """
        
        // Save as text file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let reportURL = documentsPath.appendingPathComponent("\(sessionId)_EMS_Report.txt")
        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        
        return reportURL
    }
    
    // MARK: - Session Management
    
    func reset() {
        sessionId = UUID().uuidString
        sessionStartTime = Date()
        transcriptEntries.removeAll()
        frameCount = 0
        videoStartTime = nil
        lastFrameTime = nil
    }
    
    func getSessionId() -> String {
        return sessionId
    }
}
