import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @ObservedObject var viewModel: StreamViewModel
    @Binding var isPresented: Bool
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(MedkitTheme.accent)
                    Text("Export Session Data")
                        .font(.title2.bold())
                    Text("Save video, transcripts, and reports")
                        .font(.subheadline)
                        .foregroundColor(MedkitTheme.textSecondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Export buttons
                if viewModel.hasSessionData {
                    VStack(spacing: 16) {
                        ExportButton(
                            icon: "video.fill",
                            title: "Export Video",
                            subtitle: "Save as MP4",
                            color: .blue
                        ) {
                            await exportVideo()
                        }
                        
                        ExportButton(
                            icon: "doc.text.fill",
                            title: "Export Transcript PDF",
                            subtitle: "Save with timestamps",
                            color: .red
                        ) {
                            await exportTranscriptPDF()
                        }
                        
                        ExportButton(
                            icon: "doc.richtext.fill",
                            title: "Export EMS Report",
                            subtitle: "Complete session report",
                            color: .green
                        ) {
                            await exportEMSReport()
                        }
                    }
                    .padding(.horizontal, 24)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 48))
                            .foregroundColor(MedkitTheme.textSecondary.opacity(0.5))
                        Text("No session data available")
                            .font(.headline)
                            .foregroundColor(MedkitTheme.textSecondary)
                        Text("Start a session to record data")
                            .font(.caption)
                            .foregroundColor(MedkitTheme.textSecondary.opacity(0.7))
                    }
                    .padding(.horizontal, 24)
                }
                
                Spacer()
                
                // Error message
                if let error = exportError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 24)
                }
                
                // Close button
                Button("Close") {
                    isPresented = false
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MedkitTheme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }
    
    private func exportVideo() async {
        isExporting = true
        exportError = nil
        
        do {
            let videoURL = try await viewModel.exportVideo()
            shareItems = [videoURL]
            showShareSheet = true
        } catch {
            exportError = "Failed to export video: \(error.localizedDescription)"
        }
        
        isExporting = false
    }
    
    private func exportTranscriptPDF() async {
        isExporting = true
        exportError = nil
        
        do {
            let pdfURL = try viewModel.exportTranscriptPDF()
            shareItems = [pdfURL]
            showShareSheet = true
        } catch {
            exportError = "Failed to export PDF: \(error.localizedDescription)"
        }
        
        isExporting = false
    }
    
    private func exportEMSReport() async {
        isExporting = true
        exportError = nil
        
        do {
            let reportURL = try viewModel.exportEMSReport()
            shareItems = [reportURL]
            showShareSheet = true
        } catch {
            exportError = "Failed to export report: \(error.localizedDescription)"
        }
        
        isExporting = false
    }
}

struct ExportButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () async -> Void
    
    @State private var isExporting = false
    
    var body: some View {
        Button(action: {
            Task {
                isExporting = true
                await action()
                isExporting = false
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(MedkitTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(MedkitTheme.textSecondary)
                }
                
                Spacer()
                
                if isExporting {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(MedkitTheme.textSecondary)
                }
            }
            .padding(16)
            .background(MedkitTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .disabled(isExporting)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
