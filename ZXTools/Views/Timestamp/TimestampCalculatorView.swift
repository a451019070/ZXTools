//
//  TimestampCalculatorView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import AppKit
import SwiftUI

private extension View {
    /// 白底圆角描边卡片。
    func cardStyle() -> some View {
        self
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.slate200, lineWidth: 1)
            )
    }
}
/// 时区列表项。
private struct TimeZoneItem: Identifiable, Hashable {
    let identifier: String
    let title: String
    var id: String { identifier }
}

/// 用户手动输入时生成的候选时区（自定义偏移或 Foundation 可识别的标识符）。
private struct TimeZoneSuggestion {
    let identifier: String
    let title: String
    let subtitle: String
}

struct TimestampCalculatorView: View {
    // MARK: - 时区选项

    /// 本地时区的哨兵标识，避免把系统时区固化到静态列表里。
    private static let localTimeZoneID = "__local__"

    /// 自定义固定偏移时区的标识前缀，形如 `__offset__:19800`。
    private static let offsetPrefix = "__offset__:"

    private static let commonTimeZones: [TimeZoneItem] = [
        TimeZoneItem(identifier: localTimeZoneID, title: "本地时区"),
        TimeZoneItem(identifier: "UTC", title: "UTC · 协调世界时"),
        TimeZoneItem(identifier: "Asia/Shanghai", title: "北京 / 上海"),
        TimeZoneItem(identifier: "Asia/Tokyo", title: "东京"),
        TimeZoneItem(identifier: "Europe/London", title: "伦敦"),
        TimeZoneItem(identifier: "Europe/Paris", title: "巴黎"),
        TimeZoneItem(identifier: "America/New_York", title: "纽约"),
        TimeZoneItem(identifier: "America/Los_Angeles", title: "洛杉矶"),
    ]

    /// IANA 时区数据库中的全部时区（约 600 个），已剔除常用项避免重复。
    private static let otherTimeZones: [TimeZoneItem] = {
        let commonIDs = Set(commonTimeZones.map(\.identifier))
        return TimeZone.knownTimeZoneIdentifiers
            .filter { !commonIDs.contains($0) }
            .sorted()
            .map { TimeZoneItem(identifier: $0, title: $0) }
    }()

    private static let allTimeZones: [TimeZoneItem] = commonTimeZones + otherTimeZones

    /// 支持直接输入的日期时间格式，顺序敏感：更具体的格式需排在前面。
    private static let dateTimeFormats: [String] = [
        "yyyy:MM:dd HH:mm:ss",
        "yyyy:MM:dd HH:mm",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "yyyy/MM/dd HH:mm:ss",
        "yyyy/MM/dd HH:mm",
        "yyyy.MM.dd HH:mm:ss",
        "yyyy.MM.dd HH:mm",
        "yyyy年MM月dd日 HH:mm:ss",
        "yyyy年MM月dd日 HH:mm",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd'T'HH:mm",
        "yyyyMMddHHmmss",
        "yyyy-MM-dd",
        "yyyy/MM/dd",
        "yyyy:MM:dd",
        "yyyy.MM.dd",
        "yyyy年MM月dd日",
        "yyyyMMdd",
    ]

    // MARK: - 状态

    @State private var pickedDate: Date = Date()
    @State private var timestampSeconds: String = ""
    @State private var timestampMillis: String = ""
    @State private var dateTimeInput: String = ""
    @State private var inputError: String?
    @State private var copiedKey: String?
    @State private var selectedTimeZoneID: String = Self.localTimeZoneID
    @State private var showTimeZonePopover: Bool = false
    @State private var timeZoneQuery: String = ""

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            Divider().background(Color.slate200)

            ScrollView {
                HStack(alignment: .top, spacing: 20) {
                    pickerCard
                        .frame(width: 304)
                    resultCard
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color.canvasBackground)
        }
        .onAppear { recalc() }
    }

    // MARK: - Header

    private var heroHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.secondaryGreen, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("时间戳计算")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text("日期与 Unix 时间戳（秒 / 毫秒）双向转换")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
                    .lineLimit(1)
            }
            Spacer()
            timeZoneButton
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: - 时区选择

    private var timeZoneButton: some View {
        Button { showTimeZonePopover = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.system(size: 12, weight: .medium))
                Text(timeZoneLabel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(Color.slate700)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.slate50, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.slate200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTimeZonePopover, arrowEdge: .bottom) {
            timeZonePopover
        }
        .onChange(of: showTimeZonePopover) { _, isShowing in
            if !isShowing { timeZoneQuery = "" }
        }
    }

    private var timeZonePopover: some View {
        VStack(spacing: 0) {
            timeZoneSearchField

            if let suggestion = customTimeZoneSuggestion {
                Divider()
                customSuggestionRow(suggestion)
            }

            Divider()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if isSearching {
                        if searchResults.isEmpty && customTimeZoneSuggestion == nil {
                            Text("未找到匹配的时区")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.slate400)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        } else {
                            ForEach(searchResults) { timeZoneRow($0) }
                        }
                    } else {
                        timeZoneSectionHeader("常用")
                        ForEach(Self.commonTimeZones) { timeZoneRow($0) }
                        timeZoneSectionHeader("全部时区（\(Self.otherTimeZones.count)）")
                        ForEach(Self.otherTimeZones) { timeZoneRow($0) }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: 300)
        }
        .frame(width: 340)
    }

    private var timeZoneSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.slate400)
            TextField("城市 / 时区 / 偏移（如 +5:30）", text: $timeZoneQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    if let suggestion = customTimeZoneSuggestion {
                        selectTimeZone(suggestion.identifier)
                    } else if let first = searchResults.first {
                        selectTimeZone(first.identifier)
                    }
                }
            if !timeZoneQuery.isEmpty {
                Button { timeZoneQuery = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.slate300)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    /// 手动填写入口：把输入当作固定偏移或时区标识符直接使用。
    private func customSuggestionRow(_ suggestion: TimeZoneSuggestion) -> some View {
        Button { selectTimeZone(suggestion.identifier) } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryGreen)
                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.slate900)
                        .lineLimit(1)
                    Text(suggestion.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.slate400)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "return")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.slate300)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(Color.secondaryGreen.opacity(0.07))
        }
        .buttonStyle(.plain)
    }

    private func timeZoneSectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.slate400)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeZoneRow(_ item: TimeZoneItem) -> some View {
        let isSelected = item.identifier == selectedTimeZoneID
        return Button {
            selectTimeZone(item.identifier)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(Color.slate900)
                        .lineLimit(1)
                    Text(timeZoneDetail(for: item))
                        .font(.system(size: 10))
                        .foregroundStyle(Color.slate400)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.secondaryGreen)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? Color.secondaryGreen.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 时区数据与解析

    private var isSearching: Bool {
        !timeZoneQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchResults: [TimeZoneItem] {
        let query = timeZoneQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !query.isEmpty else { return [] }

        let offsetQuery = parseOffsetQuery(query)
        return Self.allTimeZones.filter { item in
            if item.identifier.lowercased().contains(query)
                || item.title.lowercased().contains(query) {
                return true
            }
            let seconds = timeZone(from: item.identifier).secondsFromGMT()
            if let offsetQuery, seconds == offsetQuery { return true }
            // 兜底：直接命中偏移文本（补零 / 不补零两种写法都试）
            return offsetSearchTexts(seconds).contains { $0.contains(query) }
        }
    }

    /// 把 `+5`、`+5:30`、`utc+8`、`gmt-3:30`、`-11` 解析为秒数偏移。
    private func parseOffsetQuery(_ raw: String) -> Int? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        for prefix in ["utc", "gmt"] where text.hasPrefix(prefix) {
            text = String(text.dropFirst(prefix.count))
            break
        }
        guard let signChar = text.first, signChar == "+" || signChar == "-" else { return nil }
        let sign = signChar == "-" ? -1 : 1

        let parts = text.dropFirst().split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let first = parts.first, !first.isEmpty, let hours = Int(first), hours >= 0, hours <= 18 else {
            return nil
        }
        var minutes = 0
        if parts.count == 2 {
            guard let value = Int(parts[1]), value >= 0, value < 60 else { return nil }
            minutes = value
        }
        return sign * (hours * 3600 + minutes * 60)
    }

    /// 供搜索兜底匹配的偏移写法集合，例如 `+5:30` 与 `+05:30` 都可命中。
    private func offsetSearchTexts(_ seconds: Int) -> [String] {
        let sign = seconds < 0 ? "-" : "+"
        let absSeconds = Swift.abs(seconds)
        let hours = absSeconds / 3600
        let minutes = (absSeconds % 3600) / 60
        var texts = [
            offsetLabel(seconds).lowercased(),
            String(format: "%@%02d:%02d", sign, hours, minutes),
            String(format: "%@%d:%02d", sign, hours, minutes),
        ]
        if minutes == 0 {
            texts.append("\(sign)\(hours)")
            texts.append("utc\(sign)\(hours)")
            texts.append("gmt\(sign)\(hours)")
        }
        return texts
    }

    /// 搜索时的手动填写候选：优先解析为固定偏移，其次尝试 Foundation 可识别的标识符。
    private var customTimeZoneSuggestion: TimeZoneSuggestion? {
        let raw = timeZoneQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        if let seconds = parseOffsetQuery(raw) {
            let identifier = Self.offsetPrefix + String(seconds)
            guard identifier != selectedTimeZoneID else { return nil }
            return TimeZoneSuggestion(
                identifier: identifier,
                title: "使用自定义偏移 \(offsetLabel(seconds))",
                subtitle: "固定偏移，不随夏令时变化"
            )
        }

        let lower = raw.lowercased()
        let exists = Self.allTimeZones.contains { $0.identifier.lowercased() == lower }
        if !exists, let zone = TimeZone(identifier: raw) {
            return TimeZoneSuggestion(
                identifier: zone.identifier,
                title: "使用「\(raw)」",
                subtitle: "\(zone.identifier) · \(offsetLabel(zone.secondsFromGMT()))"
            )
        }
        return nil
    }

    // MARK: - 时区取值

    private func timeZone(from identifier: String) -> TimeZone {
        if identifier == Self.localTimeZoneID {
            return .current
        }
        if identifier.hasPrefix(Self.offsetPrefix),
           let seconds = Int(identifier.dropFirst(Self.offsetPrefix.count)),
           let zone = TimeZone(secondsFromGMT: seconds) {
            return zone
        }
        return TimeZone(identifier: identifier) ?? .current
    }

    private var selectedTimeZone: TimeZone {
        timeZone(from: selectedTimeZoneID)
    }

    private var timeZoneLabel: String {
        if selectedTimeZoneID == Self.localTimeZoneID {
            return "本地 · \(utcOffsetText(for: selectedTimeZoneID))"
        }
        if selectedTimeZoneID.hasPrefix(Self.offsetPrefix) {
            return "自定义 · \(utcOffsetText(for: selectedTimeZoneID))"
        }
        let offset = utcOffsetText(for: selectedTimeZoneID)
        if let title = Self.allTimeZones.first(where: { $0.identifier == selectedTimeZoneID })?.title,
           title != selectedTimeZoneID {
            return "\(title) · \(offset)"
        }
        return "\(selectedTimeZoneID) · \(offset)"
    }

    private func timeZoneDetail(for item: TimeZoneItem) -> String {
        let offset = utcOffsetText(for: item.identifier)
        if item.identifier == Self.localTimeZoneID {
            return "本机当前时区 · \(offset)"
        }
        return "\(item.identifier) · \(offset)"
    }

    private func utcOffsetText(for identifier: String) -> String {
        offsetLabel(timeZone(from: identifier).secondsFromGMT())
    }

    private func offsetLabel(_ seconds: Int) -> String {
        let sign = seconds < 0 ? "-" : "+"
        let absSeconds = Swift.abs(seconds)
        return String(format: "UTC%@%02d:%02d", sign, absSeconds / 3600, (absSeconds % 3600) / 60)
    }

    /// 按当前所选时区格式化的选中时间。
    private var formattedPickedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = selectedTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: pickedDate)
    }

    // MARK: - 时 / 分 / 秒 绑定

    private var hourBinding: Binding<Int> {
        Binding(get: { timeComponent(.hour) }, set: { updateTime(hour: $0) })
    }

    private var minuteBinding: Binding<Int> {
        Binding(get: { timeComponent(.minute) }, set: { updateTime(minute: $0) })
    }

    private var secondBinding: Binding<Int> {
        Binding(get: { timeComponent(.second) }, set: { updateTime(second: $0) })
    }

    private func timeComponent(_ unit: Calendar.Component) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = selectedTimeZone
        return calendar.component(unit, from: pickedDate)
    }

    /// 只改动时分秒，保持年月日不变（步进器不跨天）。
    private func updateTime(hour: Int? = nil, minute: Int? = nil, second: Int? = nil) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = selectedTimeZone
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: pickedDate
        )
        if let hour { components.hour = hour }
        if let minute { components.minute = minute }
        if let second { components.second = second }
        guard let newDate = calendar.date(from: components) else { return }
        pickedDate = newDate
        recalc()
    }

    // MARK: - 左栏：选择日期

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionLabel("选择日期")
                Spacer()
                Button(action: useCurrentTime) {
                    Label("现在", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondaryGreen)
                .controlSize(.small)
            }

            DatePicker("", selection: $pickedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.graphical)
                .environment(\.timeZone, selectedTimeZone)
                .onChange(of: pickedDate) { _, _ in recalc() }
                .frame(maxWidth: .infinity)

            Divider().background(Color.slate100)

            sectionLabel("选择时间")
            timeAdjuster
        }
        .padding(18)
        .cardStyle()
    }

    // MARK: - 右栏：转换结果

    private var resultCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                sectionLabel("转换结果")
                Text(timeZoneLabel)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.secondaryGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondaryGreen.opacity(0.10), in: Capsule())
                Spacer()
            }

            resultField(
                title: "日期时间",
                placeholder: "如 2025:10:11 11:46",
                text: $dateTimeInput,
                onSubmit: applyDateTimeInput
            )
            resultField(
                title: "时间戳（秒）",
                placeholder: "10 位整数",
                text: $timestampSeconds,
                onSubmit: applySecondsInput
            )
            resultField(
                title: "时间戳（毫秒）",
                placeholder: "13 位整数",
                text: $timestampMillis,
                onSubmit: applyMillisInput
            )

            if let inputError {
                Label(inputError, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.orange)
            } else {
                Text("在任意一栏输入后按回车，其余内容会自动换算")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.slate400)
            }
        }
        .padding(18)
        .cardStyle()
    }

    private func resultField(title: String,
                             placeholder: String,
                             text: Binding<String>,
                             onSubmit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.slate500)
            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.slate900)
                    .onSubmit(onSubmit)
                Button { copyToPasteboard(text.wrappedValue, key: title) } label: {
                    Image(systemName: copiedKey == title ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(copiedKey == title ? Color.secondaryGreen : Color.slate400)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("复制")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.slate50, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.slate200, lineWidth: 1)
            )
        }
    }

    private func copyToPasteboard(_ value: String, key: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        copiedKey = key
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if copiedKey == key { copiedKey = nil }
        }
    }

    // MARK: - 时 / 分 / 秒 微调

    private var timeAdjuster: some View {
        HStack(spacing: 6) {
            timeUnit(value: hourBinding, range: 0...23, caption: "时")
            timeSeparator
            timeUnit(value: minuteBinding, range: 0...59, caption: "分")
            timeSeparator
            timeUnit(value: secondBinding, range: 0...59, caption: "秒")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Color.slate50, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private var timeSeparator: some View {
        Text(":")
            .font(.system(size: 20, weight: .semibold, design: .monospaced))
            .foregroundStyle(Color.slate300)
            .padding(.bottom, 14)
    }

    private func timeUnit(value: Binding<Int>,
                          range: ClosedRange<Int>,
                          caption: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text(String(format: "%02d", value.wrappedValue))
                    .font(.system(size: 24, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.slate900)
                Stepper("", value: value, in: range)
                    .labelsHidden()
                    .controlSize(.small)
            }
            Text(caption)
                .font(.system(size: 10))
                .foregroundStyle(Color.slate400)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 行为

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.slate700)
    }

    private func selectTimeZone(_ identifier: String) {
        let oldValue = selectedTimeZoneID
        selectedTimeZoneID = identifier
        showTimeZonePopover = false
        timeZoneQuery = ""
        rebasePickedDate(from: oldValue, to: identifier)
    }

    private func recalc() {
        let ms = Int64(pickedDate.timeIntervalSince1970 * 1000)
        timestampSeconds = String(ms / 1000)
        timestampMillis = String(ms)
        dateTimeInput = formattedPickedDate
    }

    private func useCurrentTime() {
        pickedDate = Date()
        recalc()
    }

    // MARK: - 输入解析

    /// 秒时间戳 → 日期时间。
    private func applySecondsInput() {
        inputError = nil
        let raw = timestampSeconds.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int64(raw) else {
            inputError = "秒时间戳需要是整数，例如 1760154360"
            return
        }
        pickedDate = Date(timeIntervalSince1970: TimeInterval(value))
        recalc()
    }

    /// 毫秒时间戳 → 日期时间。
    private func applyMillisInput() {
        inputError = nil
        let raw = timestampMillis.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int64(raw) else {
            inputError = "毫秒时间戳需要是整数，例如 1760154360000"
            return
        }
        pickedDate = Date(timeIntervalSince1970: TimeInterval(value) / 1000.0)
        recalc()
    }

    /// 日期时间 → 时间戳。
    private func applyDateTimeInput() {
        inputError = nil
        let raw = dateTimeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            inputError = "请输入日期时间，例如 2025:10:11 11:46"
            return
        }
        guard let date = resolveInput(raw) else {
            inputError = "无法识别「\(raw)」，试试 2025:10:11 11:46"
            return
        }
        pickedDate = date
        recalc()
    }

    /// 依次尝试：合理范围内的时间戳 → 日期时间字符串 → 其余时间戳写法。
    private func resolveInput(_ raw: String) -> Date? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let date = parseTimestamp(text), isPlausible(date) {
            return date
        }
        if let date = parseDateTime(text) {
            return date
        }
        return parseTimestamp(text)
    }

    /// 纯数字解析为时间戳；去掉负号后 >= 13 位按毫秒处理，支持小数秒。
    private func parseTimestamp(_ raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        guard raw.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "." }) else { return nil }
        guard raw.contains(where: \.isNumber) else { return nil }

        if raw.contains(".") {
            guard let value = Double(raw) else { return nil }
            return Date(timeIntervalSince1970: value)
        }
        guard let value = Int64(raw) else { return nil }
        let digits = raw.hasPrefix("-") ? raw.count - 1 : raw.count
        return digits >= 13
            ? Date(timeIntervalSince1970: TimeInterval(value) / 1000.0)
            : Date(timeIntervalSince1970: TimeInterval(value))
    }

    /// 按当前所选时区解析日期时间字符串。
    private func parseDateTime(_ raw: String) -> Date? {
        let zone = selectedTimeZone
        for format in Self.dateTimeFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = zone
            formatter.dateFormat = format
            formatter.isLenient = false
            if let date = formatter.date(from: raw) {
                return date
            }
        }

        // 带时区偏移的 ISO8601 写法（如 2025-10-11T11:46:30+08:00）
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    /// 时间戳解析结果的合理性检查，避免把 14 位紧凑日期误当成毫秒。
    private func isPlausible(_ date: Date) -> Bool {
        let year = Calendar(identifier: .gregorian).component(.year, from: date)
        return (1900...2200).contains(year)
    }

    /// 时区切换时，把同一个"日历时间"按新时区重新解释，保持用户感知的年月日时分不变。
    private func rebasePickedDate(from oldID: String, to newID: String) {
        guard oldID != newID else { return }
        let oldTZ = timeZone(from: oldID)
        let newTZ = timeZone(from: newID)

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = oldTZ
        let comps = cal.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: pickedDate
        )
        cal.timeZone = newTZ
        if let newDate = cal.date(from: comps) {
            pickedDate = newDate
        }
        recalc()
    }
}

#Preview {
    TimestampCalculatorView()
        .frame(width: 920, height: 700)
}
