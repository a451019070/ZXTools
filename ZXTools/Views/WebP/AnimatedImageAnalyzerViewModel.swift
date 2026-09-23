import SwiftUI
import Combine
import UniformTypeIdentifiers

@MainActor
final class AnimatedImageAnalyzerViewModel: ObservableObject {
    @Published var analysis: AnimatedImageAnalysis?
    @Published var currentFrameIndex = 0
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var samples: [ProcessMetricSample] = []

    private var playbackTask: Task<Void, Never>?
    private var samplingTask: Task<Void, Never>?

    var currentFrame: AnimatedImageFrame? {
        guard let frames = analysis?.frames, frames.indices.contains(currentFrameIndex) else { return nil }
        return frames[currentFrameIndex]
    }

    var latestSample: ProcessMetricSample? { samples.last }
    var peakCPU: Double { samples.map(\.cpuPercent).max() ?? 0 }
    var peakMemory: UInt64 { samples.map(\.residentBytes).max() ?? 0 }

    func load(url: URL) {
        stop()
        isLoading = true
        errorMessage = nil
        analysis = nil
        samples = []
        currentFrameIndex = 0

        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let decoded = try await Task.detached(priority: .userInitiated) {
                    try AnimatedImageDecoder.decode(url: url)
                }.value
                analysis = decoded
                isLoading = false
                start()
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func start() {
        guard analysis != nil, !isPlaying else { return }
        isPlaying = true
        startSampling()
        playbackTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let frame = self.currentFrame else { return }
                try? await Task.sleep(for: .seconds(frame.duration))
                guard !Task.isCancelled, let frames = self.analysis?.frames, !frames.isEmpty else { return }
                self.currentFrameIndex = (self.currentFrameIndex + 1) % frames.count
            }
        }
    }

    func stop() {
        isPlaying = false
        playbackTask?.cancel()
        samplingTask?.cancel()
        playbackTask = nil
        samplingTask = nil
    }

    func resetSamples() {
        samples = []
    }

    private func startSampling() {
        samplingTask?.cancel()
        samplingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.samples.append(ProcessMetricsReader.current())
                if self.samples.count > 120 {
                    self.samples.removeFirst(self.samples.count - 120)
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    deinit {
        playbackTask?.cancel()
        samplingTask?.cancel()
    }
}
