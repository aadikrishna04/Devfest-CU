import MWDATCore
import SwiftUI

struct MetaCameraView: View {
    let wearables: WearablesInterface
    @ObservedObject var viewModel: WearablesViewModel
    @StateObject private var streamVM: StreamViewModel
    @State private var selectedPage = 0

    init(wearables: WearablesInterface, viewModel: WearablesViewModel) {
        self.wearables = wearables
        self.viewModel = viewModel
        self._streamVM = StateObject(wrappedValue: StreamViewModel(wearables: wearables))
    }

    var body: some View {
        ZStack {
            if streamVM.isStreaming {
                activeSessionView
                    .transition(.opacity)
            } else {
                homeView
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: streamVM.isStreaming)
        .alert("Error", isPresented: $streamVM.showError) {
            Button("OK") { streamVM.dismissError() }
        } message: {
            Text(streamVM.errorMessage)
        }
        .onDisappear {
            Task { await streamVM.stopStreaming() }
        }
    }

    private var isReadyToStream: Bool {
        viewModel.registrationState == .registered && streamVM.hasActiveDevice
    }

    private var hasActiveScenario: Bool {
        let s = streamVM.currentScenario
        return !s.isEmpty && s != "none" && s != "resolved"
    }

    // =========================================================================
    // MARK: - Home Screen
    // =========================================================================

    private var homeView: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [MedkitTheme.gradientTop, .white, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Soft radial glow behind orb area
            VStack {
                RadialGradient(
                    colors: [
                        MedkitTheme.accentSoft.opacity(0.25),
                        MedkitTheme.accentVeryLight.opacity(0.15),
                        Color.clear,
                    ],
                    center: .topLeading,
                    startRadius: 10,
                    endRadius: 250
                )
                .frame(height: 280)
                .ignoresSafeArea()
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    homeHeader
                        .padding(.top, 16)

                    greetingSection
                        .padding(.horizontal, 28)
                        .padding(.top, 12)

                    quickActionsSection
                        .padding(.horizontal, 28)
                        .padding(.top, 36)

                    Spacer(minLength: 60)

                    connectionSection
                        .padding(.horizontal, 28)
                        .padding(.bottom, 50)
                }
                .frame(minHeight: UIScreen.main.bounds.height - 100)
            }
        }
    }

    // MARK: Home Header

    private var homeHeader: some View {
        HStack {
            // Decorative orb
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [MedkitTheme.accentSoft.opacity(0.8), MedkitTheme.accent],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 32
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: MedkitTheme.accent.opacity(0.3), radius: 14, y: 6)
            }

            Spacer()

            // Glasses status pill
            if viewModel.registrationState == .registered {
                HStack(spacing: 6) {
                    Image(systemName: "eyeglasses")
                        .font(.caption)
                    Circle()
                        .fill(streamVM.hasActiveDevice ? .green : .orange)
                        .frame(width: 6, height: 6)
                }
                .foregroundColor(MedkitTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(MedkitTheme.cardBackground)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Medkit")
                .font(.system(size: 34, weight: .regular, design: .default))
                .foregroundColor(MedkitTheme.textPrimary)

            HStack(spacing: 0) {
                Text("How can I ")
                    .foregroundColor(MedkitTheme.textPrimary)
                Text("help you?")
                    .foregroundColor(MedkitTheme.accent)
            }
            .font(.system(size: 34, weight: .bold, design: .default))
        }
    }

    // MARK: Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("[ Quick actions ]")
                .font(.subheadline)
                .foregroundColor(MedkitTheme.textSecondary)
                .padding(.bottom, 2)

            quickActionCard(
                icon: "cross.fill",
                title: "Emergency care",
                subtitle: "Immediate organization of the necessary help",
                action: { startSession(emergency: true) }
            )

            quickActionCard(
                icon: "stethoscope",
                title: "Symptom identification",
                subtitle: "Gathering information, planning further actions",
                action: { startSession(emergency: false) }
            )

            quickActionCard(
                icon: "list.bullet.clipboard",
                title: "Providing instructions",
                subtitle: "Help with preparing for specific procedures",
                action: { startSession(emergency: false) }
            )
        }
    }

    private func quickActionCard(
        icon: String, title: String, subtitle: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(MedkitTheme.accentVeryLight)
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(MedkitTheme.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(MedkitTheme.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(MedkitTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundColor(MedkitTheme.textSecondary.opacity(0.4))
            }
            .padding(14)
            .background(MedkitTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .disabled(!isReadyToStream)
        .opacity(isReadyToStream ? 1.0 : 0.5)
    }

    // MARK: Connection Section

    private var connectionSection: some View {
        VStack(spacing: 14) {
            if viewModel.registrationState != .registered {
                Button(action: { viewModel.connectGlasses() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "eyeglasses")
                        Text("Connect Glasses")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(MedkitTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(viewModel.registrationState == .registering)
                .opacity(viewModel.registrationState == .registering ? 0.6 : 1.0)

                if viewModel.registrationState == .registering {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Connecting...")
                            .font(.caption)
                            .foregroundColor(MedkitTheme.textSecondary)
                    }
                }
            } else if !streamVM.hasActiveDevice {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Waiting for glasses...")
                        .font(.subheadline)
                        .foregroundColor(MedkitTheme.textSecondary)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundColor(MedkitTheme.accent)
                        .font(.caption)
                    Text("Tap an action or say \"Medkit\" to start")
                        .font(.subheadline)
                        .foregroundColor(MedkitTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // =========================================================================
    // MARK: - Active Session Screen
    // =========================================================================

    private var activeSessionView: some View {
        ZStack {
            // Base background
            MedkitTheme.sessionBackground.ignoresSafeArea()

            // Warm gradient glow behind top area
            VStack {
                RadialGradient(
                    colors: [
                        MedkitTheme.accentVeryLight.opacity(0.8),
                        MedkitTheme.accentSoft.opacity(0.15),
                        MedkitTheme.sessionBackground.opacity(0),
                    ],
                    center: .top,
                    startRadius: 20,
                    endRadius: 350
                )
                .frame(height: 420)
                .ignoresSafeArea()
                Spacer()
            }

            VStack(spacing: 0) {
                // Top status bar
                sessionStatusBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // ---- Top half: Swipeable viz/video + tool overlays ----
                VStack(spacing: 0) {
                    Spacer(minLength: 8)

                    // Paged view: (Audio Viz or Wireframe) | Video Feed
                    TabView(selection: $selectedPage) {
                        // Page 0: Audio viz normally, wireframe when scenario active
                        Group {
                            if hasActiveScenario {
                                WireframeSceneView(
                                    scenario: streamVM.currentScenario,
                                    bpm: streamVM.toolExecutor.metronomeBPM,
                                    isMetronomeActive: streamVM.toolExecutor.isMetronomeActive,
                                    bodyRegion: streamVM.bodyRegion
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding(.horizontal, 16)
                            } else {
                                AudioVisualizerView(isActive: streamVM.isActivated)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 220)
                        .tag(0)

                        // Page 1: Video Feed
                        videoFeedPage
                            .tag(1)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 240)

                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { i in
                            Circle()
                                .fill(selectedPage == i ? MedkitTheme.accent : MedkitTheme.textSecondary.opacity(0.25))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut(duration: 0.2), value: selectedPage)
                        }
                    }
                    .padding(.top, 6)

                    // Tool overlays
                    if hasToolOverlays {
                        ScrollView(showsIndicators: false) {
                            toolOverlays
                        }
                        .frame(maxHeight: 160)
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }

                    Spacer(minLength: 8)
                }
                .frame(maxHeight: .infinity)

                // ---- Bottom half: Flowing transcript ----
                ZStack(alignment: .bottom) {
                    transcriptFlow
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

                    // Fade-out gradient at top of transcript area
                    VStack {
                        LinearGradient(
                            colors: [MedkitTheme.sessionBackground, MedkitTheme.sessionBackground.opacity(0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 50)
                        Spacer()
                    }
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 24)

                // Safety text
                Text("Decision support only - Not a substitute for professional medical help")
                    .font(.caption2)
                    .foregroundColor(MedkitTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)

                // Bottom controls
                sessionBottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
            }
        }
    }

    // MARK: Video Feed Page

    private var videoFeedPage: some View {
        Group {
            if let frame = streamVM.currentFrame {
                Image(uiImage: frame)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 36))
                        .foregroundColor(MedkitTheme.textSecondary.opacity(0.3))
                    Text("No video feed")
                        .font(.caption)
                        .foregroundColor(MedkitTheme.textSecondary)
                }
            }
        }
        .frame(height: 220)
    }

    // MARK: Session Status Bar

    private var sessionStatusBar: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(streamVM.isActivated ? Color.green : MedkitTheme.accent)
                    .frame(width: 8, height: 8)
                Text(streamVM.isActivated ? "Listening" : streamVM.wakeWordStatus)
                    .font(.caption)
                    .foregroundColor(MedkitTheme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())

            Spacer()

            if streamVM.currentScenario != "none" {
                Text(streamVM.currentScenario.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        streamVM.scenarioSeverity == "critical" ? Color.red :
                        streamVM.scenarioSeverity == "moderate" ? Color.orange :
                        MedkitTheme.accent
                    )
                    .clipShape(Capsule())
            }

            if streamVM.isConnected {
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("LIVE").font(.caption2.bold()).foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
    }

    // MARK: Flowing Transcript

    private var transcriptFlow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer(minLength: 0)

            // User transcript (dimmer, smaller)
            if !streamVM.userTranscript.isEmpty {
                Text(streamVM.userTranscript)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(MedkitTheme.textSecondary.opacity(0.6))
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Agent transcript (large, prominent, recent words bold)
            if !streamVM.agentTranscript.isEmpty {
                Text(styledTranscript(streamVM.agentTranscript))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Styles the transcript so older words are lighter and recent words are bold+dark
    private func styledTranscript(_ text: String) -> AttributedString {
        let words = text.components(separatedBy: " ")
        let total = words.count
        var result = AttributedString()

        for (i, word) in words.enumerated() {
            if i > 0 {
                result.append(AttributedString(" "))
            }

            var attr = AttributedString(word)
            let progress = total <= 1 ? 1.0 : Double(i) / Double(total - 1)

            // Recent words (last ~40%) are bold and dark, older words are lighter
            if progress > 0.6 {
                attr.font = .system(size: 22, weight: .bold)
                attr.foregroundColor = MedkitTheme.textPrimary
            } else if progress > 0.3 {
                attr.font = .system(size: 22, weight: .medium)
                attr.foregroundColor = MedkitTheme.textPrimary.opacity(0.7)
            } else {
                attr.font = .system(size: 22, weight: .regular)
                attr.foregroundColor = MedkitTheme.textSecondary.opacity(0.5)
            }

            result.append(attr)
        }

        return result
    }

    // MARK: Session Bottom Bar

    private var sessionBottomBar: some View {
        HStack {
            // Stop button
            Button(action: { Task { await streamVM.stopStreaming() } }) {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(MedkitTheme.darkSurface)
                    .clipShape(Circle())
            }

            Spacer()

            // Waveform (decorative)
            HStack(spacing: 2.5) {
                ForEach(0..<15, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MedkitTheme.textSecondary.opacity(streamVM.isActivated ? 0.5 : 0.2))
                        .frame(width: 2.5, height: waveformHeight(for: i))
                }
            }

            Spacer()

            // Disconnect button
            Button(action: {
                Task { await streamVM.stopStreaming() }
                viewModel.disconnectGlasses()
            }) {
                Image(systemName: "eyeglasses")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 52, height: 52)
                    .background(MedkitTheme.accent)
                    .clipShape(Circle())
            }
        }
    }

    private func waveformHeight(for index: Int) -> CGFloat {
        let heights: [CGFloat] = [8, 14, 10, 22, 16, 28, 20, 26, 18, 24, 12, 20, 14, 10, 8]
        return heights[index % heights.count]
    }

    // =========================================================================
    // MARK: - Tool Overlays
    // =========================================================================

    private var hasToolOverlays: Bool {
        streamVM.toolExecutor.isMetronomeActive ||
        !streamVM.toolExecutor.activeTimers.isEmpty ||
        !streamVM.toolExecutor.activeCards.isEmpty
    }

    private var toolOverlays: some View {
        VStack(spacing: 8) {
            if streamVM.toolExecutor.isMetronomeActive {
                metronomeOverlay
            }

            ForEach(streamVM.toolExecutor.activeTimers) { timer in
                timerOverlay(timer)
            }

            ForEach(streamVM.toolExecutor.activeCards) { card in
                cardOverlay(card)
            }
        }
    }

    private var metronomeOverlay: some View {
        HStack(spacing: 10) {
            Image(systemName: "metronome.fill")
                .foregroundColor(MedkitTheme.accent)
                .font(.title3)
            Text("\(streamVM.toolExecutor.metronomeBPM) BPM")
                .font(.headline.monospacedDigit())
                .foregroundColor(MedkitTheme.textPrimary)
            Spacer()
            Button(action: {
                streamVM.toolExecutor.execute(tool: "stop_metronome", params: [:])
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(MedkitTheme.textSecondary)
                    .font(.title3)
            }
        }
        .padding(14)
        .background(MedkitTheme.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func timerOverlay(_ timer: CountdownTimer) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "timer")
                .foregroundColor(.orange)
                .font(.title3)
            Text(timer.label.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(.subheadline)
                .foregroundColor(MedkitTheme.textPrimary)
            Spacer()
            Text(timer.remainingSeconds.timerString)
                .font(.title2.monospacedDigit().bold())
                .foregroundColor(.orange)
        }
        .padding(14)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func cardOverlay(_ card: UICard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: card.cardType == .alert ? "exclamationmark.triangle.fill" :
                        card.cardType == .banner ? "megaphone.fill" : "checklist")
                    .foregroundColor(card.cardType == .alert ? .red : MedkitTheme.accent)
                Text(card.title)
                    .font(.headline)
                    .foregroundColor(MedkitTheme.textPrimary)
                Spacer()
                Button(action: { streamVM.toolExecutor.dismissCard(card) }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(MedkitTheme.textSecondary)
                }
            }

            ForEach(Array(card.items.enumerated()), id: \.offset) { idx, item in
                HStack(alignment: .top, spacing: 8) {
                    if card.cardType == .checklist {
                        Text("\(idx + 1).")
                            .font(.subheadline.bold())
                            .foregroundColor(MedkitTheme.accent)
                            .frame(width: 20)
                    }
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(MedkitTheme.textPrimary)
                }
            }
        }
        .padding(14)
        .background(MedkitTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
    }

    // =========================================================================
    // MARK: - Actions
    // =========================================================================

    private func startSession(emergency: Bool) {
        if emergency {
            streamVM.audioManager.alwaysActive = true
        }
        Task { await streamVM.startStreaming() }
    }
}
