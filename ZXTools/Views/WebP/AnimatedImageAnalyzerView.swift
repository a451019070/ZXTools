import SwiftUI
import UniformTypeIdentifiers
import Charts

struct AnimatedImageAnalyzerView: View {
    @StateObject private var viewModel = AnimatedImageAnalyzerViewModel()
    @State private var showImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            Divider().background(Color.slate200)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    importCard
                    if let analysis = viewModel.analysis {
                        analysisContent(analysis)
                    }
                }
                .padding(24)
            }
            .background(Color.canvasBackground)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first { viewModel.load(url: url) }
            case .failure(let error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .alert("加载失败", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("好") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onDisappear { viewModel.stop() }
    }

    private var allowedTypes: [UTType] {
        var types: [UTType] = [.gif]
        if let webP = UTType(filenameExtension: "webp") { types.append(webP) }
        return types
    }

    private var heroHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.path.ecg.rectangle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.orange, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("动图性能分析")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text("加载 WebP / GIF，分析解码内存与当前进程 CPU 占用")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    private var importCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.analysis?.fileURL.lastPathComponent ?? "选择一个本地动图")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text("采样值为 Tools 当前进程数据，适合对比同一环境下不同动图的开销。")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
            }
            Spacer()
            if viewModel.isLoading { ProgressView().controlSize(.small) }
            Button("选择 GIF / WebP") { showImporter = true }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(viewModel.isLoading)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slate200, lineWidth: 1))
    }

    @ViewBuilder
    private func analysisContent(_ analysis: AnimatedImageAnalysis) -> some View {
        HStack(alignment: .top, spacing: 20) {
            previewCard(analysis)
                .frame(maxWidth: .infinity)
            metricsCard(analysis)
                .frame(width: 330)
        }
        chartCard
        frameCard(analysis)
    }

    private func previewCard(_ analysis: AnimatedImageAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("播放预览", symbol: "play.rectangle")
            ZStack {
                checkerboard
                if let frame = viewModel.currentFrame {
                    Image(nsImage: frame.image)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 420)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack {
                Button(viewModel.isPlaying ? "暂停" : "播放") {
                    viewModel.isPlaying ? viewModel.stop() : viewModel.start()
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                Text("第 \(viewModel.currentFrameIndex + 1) / \(analysis.frames.count) 帧")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.slate500)
                Spacer()
                Button("清空采样") { viewModel.resetSamples() }
                    .buttonStyle(.bordered)
            }
        }
        .cardStyle()
    }

    private func metricsCard(_ analysis: AnimatedImageAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("分析结果", symbol: "gauge.with.dots.needle.50percent")
            metricRow("格式", analysis.fileURL.pathExtension.uppercased())
            metricRow("画布尺寸", "\(analysis.pixelWidth) × \(analysis.pixelHeight)")
            metricRow("总帧数", "\(analysis.frames.count)")
            metricRow("总时长", String(format: "%.2f 秒", analysis.duration))
            metricRow("平均帧率", String(format: "%.1f FPS", analysis.averageFrameRate))
            Divider()
            metricRow("文件大小", byteText(analysis.fileSize))
            metricRow("帧解码内存", byteText(analysis.decodedBytes))
            metricRow("当前进程内存", byteText(viewModel.latestSample?.residentBytes ?? 0))
            metricRow("峰值进程内存", byteText(viewModel.peakMemory))
            metricRow("当前 CPU", String(format: "%.1f%%", viewModel.latestSample?.cpuPercent ?? 0))
            metricRow("峰值 CPU", String(format: "%.1f%%", viewModel.peakCPU))
            Text("帧解码内存按每帧位图 bytesPerRow × height 累计；进程指标还包含应用自身基础开销。")
                .font(.system(size: 11))
                .foregroundStyle(Color.slate500)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle("最近 60 秒 CPU 采样", symbol: "chart.xyaxis.line")
            if viewModel.samples.isEmpty {
                Text("播放后开始记录采样数据")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
                    .frame(maxWidth: .infinity, minHeight: 130)
            } else {
                Chart(viewModel.samples) { sample in
                    LineMark(
                        x: .value("时间", sample.date),
                        y: .value("CPU", sample.cpuPercent)
                    )
                    .foregroundStyle(Color.orange)
                    .interpolationMethod(.catmullRom)
                    AreaMark(
                        x: .value("时间", sample.date),
                        y: .value("CPU", sample.cpuPercent)
                    )
                    .foregroundStyle(Color.orange.opacity(0.12))
                }
                .chartYAxisLabel("CPU %")
                .frame(height: 160)
            }
        }
        .cardStyle()
    }

    private func frameCard(_ analysis: AnimatedImageAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            cardTitle("逐帧信息", symbol: "square.stack.3d.up")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 10)], spacing: 10) {
                ForEach(analysis.frames) { frame in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("第 \(frame.id + 1) 帧")
                            .font(.system(size: 12, weight: .semibold))
                        Text(String(format: "%.0f ms", frame.duration * 1000))
                        Text(byteText(frame.pixelBytes))
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.slate700)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(frame.id == viewModel.currentFrameIndex ? Color.orange.opacity(0.12) : Color.slate100,
                                in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .cardStyle()
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cell: CGFloat = 14
            for row in 0...Int(size.height / cell) {
                for column in 0...Int(size.width / cell) {
                    let color = (row + column).isMultiple(of: 2) ? Color.white : Color.slate100
                    context.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)), with: .color(color))
                }
            }
        }
    }

    private func cardTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.slate900)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Color.slate500)
            Spacer()
            Text(value).font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .font(.system(size: 12))
    }

    private func byteText(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.slate200, lineWidth: 1))
    }
}

#Preview {
    AnimatedImageAnalyzerView()
        .frame(width: 1080, height: 820)
}
