//
//  TimestampCalculatorView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI

struct TimestampCalculatorView: View {
    @State private var pickedDate: Date = Date()
    @State private var timestampSeconds: String = ""
    @State private var timestampMillis: String = ""
    @State private var timestampInput: String = ""
    @State private var showTimestampSheet: Bool = false
    @State private var alertMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            Divider().background(Color.slate200)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    dateCard
                    actionButtons
                    Spacer().frame(height: 12)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color.canvasBackground)
        }
        .onAppear { recalc() }
        .sheet(isPresented: $showTimestampSheet) {
            timestampInputSheet
        }
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("好") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
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
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: - Date card

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("当前时间")
            DatePicker("", selection: $pickedDate)
                .labelsHidden()
                .datePickerStyle(.graphical)
                .onChange(of: pickedDate) { _, _ in recalc() }

            sectionLabel("时间戳（秒）")
            TextField("", text: $timestampSeconds)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .disabled(true)

            sectionLabel("时间戳（毫秒）")
            TextField("", text: $timestampMillis)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .disabled(true)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: useCurrentTime) {
                Label("获取当前时间", systemImage: "clock.arrow.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondaryGreen)
            .controlSize(.large)

            Button(action: { showTimestampSheet = true }) {
                Label("时间戳转日期", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondaryGreen)
            .controlSize(.large)
        }
    }

    // MARK: - 时间戳转日期 sheet

    private var timestampInputSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("输入时间戳（秒）")
                .font(.system(size: 14, weight: .semibold))
            TextField("例如：1716000000 或 1716000000000", text: $timestampInput)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .onSubmit { applyTimestampInput() }
            HStack {
                Spacer()
                Button("取消") { showTimestampSheet = false; timestampInput = "" }
                    .keyboardShortcut(.cancelAction)
                Button("应用") { applyTimestampInput() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .tint(.secondaryGreen)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    // MARK: - 行为

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.slate700)
    }

    private func recalc() {
        let ms = Int64(pickedDate.timeIntervalSince1970 * 1000)
        timestampSeconds = String(ms / 1000)
        timestampMillis = String(ms)
    }

    private func useCurrentTime() {
        pickedDate = Date()
        recalc()
    }

    private func applyTimestampInput() {
        let raw = timestampInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int64(raw) else {
            alertMessage = "请输入有效的时间戳（整数）"
            return
        }
        // 启发式：>= 10^12 视为毫秒，否则视为秒
        let seconds: TimeInterval
        if raw.count >= 13 {
            seconds = TimeInterval(value) / 1000.0
        } else {
            seconds = TimeInterval(value)
        }
        let date = Date(timeIntervalSince1970: seconds)
        pickedDate = date
        recalc()
        showTimestampSheet = false
        timestampInput = ""
    }
}

#Preview {
    TimestampCalculatorView()
        .frame(width: 920, height: 700)
}
