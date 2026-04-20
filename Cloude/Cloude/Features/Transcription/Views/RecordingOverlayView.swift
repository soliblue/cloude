import SwiftUI

struct RecordingOverlayView: View {
    @ObservedObject var audioRecorder: AudioRecorder
    var isTranscribing: Bool = false
    let onStop: () -> Void

    @State private var pulse = false
    @State private var currentLevel: Float = 0

    var body: some View {
        HStack(spacing: DS.Spacing.l) {
            if isTranscribing {
                ProgressView()
                    .tint(.accentColor)

                Spacer()

                Image(systemName: "waveform")
                    .font(.system(size: DS.Icon.l))
                    .foregroundColor(.accentColor.opacity(DS.Opacity.m))
            } else {
                Circle()
                    .fill(Color.accentColor.opacity(DS.Opacity.l))
                    .frame(width: DS.Icon.s, height: DS.Icon.s)
                    .scaleEffect(pulse ? DS.Scale.l : DS.Scale.m)
                    .opacity(pulse ? DS.Opacity.l : DS.Opacity.m)

                Spacer()

                AudioWaveformView(
                    audioLevel: currentLevel,
                    barCount: 7,
                    color: .accentColor.opacity(DS.Opacity.l),
                    barWidth: DS.Spacing.xs,
                    maxHeight: DS.Size.m
                )

                Spacer()

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: DS.Icon.l))
                        .foregroundColor(.accentColor.opacity(DS.Opacity.l))
                }
            }
        }
        .padding(.horizontal, DS.Spacing.l)
        .padding(.vertical, DS.Spacing.m)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: DS.Radius.l))
        .padding(.horizontal, DS.Spacing.s)
        .onAppear {
            withAnimation(.easeInOut(duration: DS.Duration.l).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
                currentLevel = audioRecorder.audioLevel
            }
        }
    }
}
