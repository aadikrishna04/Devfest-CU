import SwiftUI

struct SessionsView: View {
    @ObservedObject var store: SessionStore
    @State private var shareItem: URL?
    @State private var showShare = false
    @State private var selectedSession: SavedSession?
    @State private var sessionToDelete: SavedSession?

    var body: some View {
        VStack(spacing: 0) {
            if store.sessions.isEmpty {
                emptyState
            } else {
                sessionsList
            }
        }
        .fullScreenCover(item: $selectedSession) { session in
            SessionReportView(session: session)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(MedkitTheme.textSecondary.opacity(0.3))
            Text("No sessions yet")
                .font(.headline)
                .foregroundColor(MedkitTheme.textSecondary)
            Text("Your session reports will appear here")
                .font(.subheadline)
                .foregroundColor(MedkitTheme.textSecondary.opacity(0.7))
            Spacer()
        }
    }

    private var sessionsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(store.sessions) { session in
                    SessionRow(session: session) {
                        selectedSession = session
                    }
                    .contextMenu {
                        if session.reportURL != nil {
                            Button {
                                if let url = session.reportURL {
                                    shareItem = url
                                    showShare = true
                                }
                            } label: {
                                Label("Share Report", systemImage: "square.and.arrow.up")
                            }
                        }
                        if session.videoURL != nil {
                            Button {
                                if let url = session.videoURL {
                                    shareItem = url
                                    showShare = true
                                }
                            } label: {
                                Label("Share Video", systemImage: "video")
                            }
                        }
                        Button(role: .destructive) {
                            store.delete(session)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showShare) {
            if let url = shareItem {
                ShareSheet(items: [url])
            }
        }
    }
}

struct SessionRow: View {
    let session: SavedSession
    let onTap: () -> Void

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }

    private var severityColor: Color {
        switch session.severity {
        case "critical": return .red
        case "moderate": return .orange
        default: return MedkitTheme.accent
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(session.hasScenario ? severityColor.opacity(0.12) : MedkitTheme.accentVeryLight)
                        .frame(width: 44, height: 44)

                    Image(systemName: session.hasScenario ? "cross.case.fill" : "waveform")
                        .font(.system(size: 18))
                        .foregroundColor(session.hasScenario ? severityColor : MedkitTheme.accent)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        if session.hasScenario {
                            Text(session.scenario.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(MedkitTheme.textPrimary)
                        } else {
                            Text("Session")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(MedkitTheme.textPrimary)
                        }

                        if session.hasScenario {
                            Text(session.severity.uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(severityColor)
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 4) {
                        Text(dateString)
                        Text("•")
                        Text(session.durationString)
                    }
                    .font(.caption)
                    .foregroundColor(MedkitTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(MedkitTheme.textSecondary.opacity(0.4))
            }
            .padding(14)
            .background(MedkitTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// ShareSheet is already defined in ExportView.swift
