import SwiftUI

struct NotchView: View {
    @ObservedObject var model: AppModel
    let mediaService: MediaControlService
    let volumeService: SystemVolumeService
    let codexUsageService: CodexUsageService
    @Namespace private var contentSwitcherNamespace

    var body: some View {
        GeometryReader { _ in
            ZStack {
                NotchSurfaceShape(
                    bottomCornerRadius: 22,
                    topNotchWidth: model.physicalNotchWidth,
                    topNotchHeight: notchTopInset,
                    topNotchTransitionRadius: expandedNotchTransitionRadius,
                    expansionProgress: model.presentation == .expanded ? 1 : 0
                )
                .fill(model.notchBackgroundColor)
                .animation(
                    .timingCurve(0.22, 1.0, 0.36, 1.0, duration: 0.26),
                    value: model.presentation == .expanded
                )

                switch model.presentation {
                case .collapsed:
                    if model.notchContent == .media {
                        collapsedView
                    } else if model.notchContent == .codexUsage {
                        codexCollapsedView
                    } else {
                        noActiveContentCollapsedView
                    }
                case .expanded:
                    expandedContentView
                }
            }
        }
    }

    private var collapsedView: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: notchTopInset)

            if model.media.hasMedia {
                HStack(spacing: 8) {
                    artwork(size: 29)

                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(model.media.title, fontSize: 12)

                        if !model.media.album.isEmpty {
                            Text(model.media.album)
                                .font(.system(size: 10, weight: .light))
                                .foregroundStyle(.white.opacity(0.68))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                        // Der Lauftext bekommt ausschließlich den Platz links von
                        // der Equalizer-Animation. Das Clipping muss nach dem
                        // Layout erfolgen, damit der animierte Inhalt nicht in
                        // den reservierten Wave-Bereich gezeichnet wird.
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()

                    EqualizerView(
                        playing: model.media.isPlaying,
                        compact: true,
                        color: model.waveColor
                    )
                        .frame(width: 28)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Label("Keine Medienwiedergabe", systemImage: "music.note.slash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var expandedContentView: some View {
        VStack(spacing: 10) {
            Color.clear
                .frame(height: expandedContentTopInset)

            if model.enabledNotchContents.count > 1 {
                notchContentSwitcher
                    .frame(maxWidth: .infinity, minHeight: 28)
                    .overlay(alignment: .trailing) {
                        if model.notchContent == .codexUsage {
                            refreshCodexButton
                                .transition(.opacity)
                        }
                    }
            } else if model.notchContent == .codexUsage {
                HStack {
                    Spacer()
                    refreshCodexButton
                }
                .frame(maxWidth: .infinity, minHeight: 28)
            }

            ZStack(alignment: .top) {
                if model.notchContent == .media {
                    mediaExpandedContent
                } else if model.notchContent == .codexUsage {
                    codexExpandedContent
                } else {
                    noActiveContentExpandedView
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.22), value: model.notchContent)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var mediaExpandedContent: some View {
        Group {
            if model.media.hasMedia {
                mediaPlaybackContent
            } else {
                emptyMediaExpandedContent
            }
        }
    }

    private var mediaPlaybackContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 15) {
                artwork(size: 60)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.media.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    if !model.media.artist.isEmpty {
                        Text(model.media.artist)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.70))
                            .lineLimit(1)
                    }

                    if !model.media.album.isEmpty {
                        Text(model.media.album)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.42))
                            .lineLimit(1)
                    }
                }

                Spacer()
                EqualizerView(playing: model.media.isPlaying, color: model.waveColor)
            }

            HStack(spacing: 28) {
                controlButton("backward.fill") {
                    mediaService.previous()
                }

                Button {
                    mediaService.togglePlayPause()
                } label: {
                    Image(systemName: model.media.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(width: 38, height: 38)
                        .background(.white)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                controlButton("forward.fill") {
                    mediaService.next()
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))

                Slider(
                    value: Binding(
                        get: { model.systemVolume },
                        set: { newValue in
                            model.systemVolume = newValue
                            volumeService.setVolume(newValue)
                        }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var emptyMediaExpandedContent: some View {
        VStack(spacing: 9) {
            Image(systemName: "music.note.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))

            Text("Keine Medienwiedergabe")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text("Starte Musik, einen Podcast oder ein Video – dann erscheint es hier.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var codexCollapsedView: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: notchTopInset)

            Group {
                switch model.codexUsage.state {
                case .loading:
                    Label("Codex-Limits werden geladen …", systemImage: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))

                case .available:
                    HStack(spacing: 8) {
                        codexCompactWindow(label: "5 Std.", window: model.codexUsage.primaryWindow)

                        Rectangle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 1, height: 16)

                        codexCompactWindow(label: "Woche", window: model.codexUsage.weeklyWindow)
                    }

                case .unavailable:
                    Label("Codex-Limits nicht verfügbar", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.92))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noActiveContentCollapsedView: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: notchTopInset)

            Label("Kein Inhalt aktiv", systemImage: "rectangle.slash")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noActiveContentExpandedView: some View {
        VStack(spacing: 9) {
            Image(systemName: "rectangle.slash")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))

            Text("Kein Inhalt aktiv")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))

            Text("Aktiviere mindestens einen Inhalt in den Einstellungen.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.52))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var codexExpandedContent: some View {
        Group {
            switch model.codexUsage.state {
            case .loading:
                HStack(spacing: 9) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Aktuelle Codex-Limits werden geladen …")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .available:
                VStack(alignment: .leading, spacing: 10) {
                    codexUsageCard(
                        title: "5-Stunden-Limit",
                        window: model.codexUsage.primaryWindow
                    )

                    codexUsageCard(
                        title: "Wöchentliches Limit",
                        window: model.codexUsage.weeklyWindow
                    )
                }

            case .unavailable(let message):
                VStack(alignment: .leading, spacing: 6) {
                    Text("Keine Codex-Limits verfügbar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }

    private func codexCompactWindow(label: String, window: CodexUsageWindow?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(window?.percentageText ?? "—")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(usageColor(for: window))
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var notchContentSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(model.enabledNotchContents) { content in
                notchContentButton(content: content)
            }
        }
        .background(.white.opacity(0.10))
        .clipShape(Capsule())
        .contentShape(Capsule())
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: model.notchContent)
    }

    private var refreshCodexButton: some View {
        Button {
            codexUsageService.refresh()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.10))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Codex-Limits aktualisieren")
    }

    private func notchContentButton(content: NotchContent) -> some View {
        let isSelected = model.notchContent == content

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                model.selectNotchContent(content)
            }
            if content == .codexUsage {
                codexUsageService.refresh()
            }
        } label: {
            Image(systemName: content.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.72))
                .frame(width: 28, height: 26)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white)
                            .padding(2)
                            .matchedGeometryEffect(
                                id: "activeNotchContent",
                                in: contentSwitcherNamespace
                            )
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(content.title) in der Notch anzeigen")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func codexUsageCard(title: String, window: CodexUsageWindow?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))

                Spacer()

                Text(window.map { "\($0.percentageText) verwendet" } ?? "—")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(usageColor(for: window))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))

                    Capsule()
                        .fill(usageColor(for: window))
                        .frame(width: proxy.size.width * CGFloat((window?.usedPercent ?? 0) / 100))
                }
            }
            .frame(height: 7)

            TimelineView(.periodic(from: .now, by: 60)) { context in
                Text(
                    window.map {
                        "Reset \($0.resetText(relativeTo: context.date)) · \($0.resetDateTimeText(relativeTo: context.date))"
                    } ?? "Resetzeit nicht verfügbar"
                )
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
    }

    private func usageColor(for window: CodexUsageWindow?) -> Color {
        guard let percent = window?.usedPercent else { return .white.opacity(0.48) }

        switch percent {
        case 90...:
            return model.codexUsageCriticalColor
        case 75...:
            return model.codexUsageWarningColor
        default:
            return model.codexUsageNormalColor
        }
    }

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let artwork = model.media.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.white.opacity(0.09)
                    Image(systemName: "music.note")
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    private func controlButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
    }

    private var notchTopInset: CGFloat {
        max(model.physicalNotchHeight, 26)
    }

    private var expandedNotchTransitionRadius: CGFloat {
        min(notchTopInset * 0.45, model.physicalNotchWidth / 2)
    }

    private var expandedContentTopInset: CGFloat {
        notchTopInset + expandedNotchTransitionRadius
    }

}
