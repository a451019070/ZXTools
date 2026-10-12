//
//  CryptoView.swift
//  ZXTools
//
//  编码 / 加密 / 哈希 工具页
//

import SwiftUI

struct CryptoView: View {
    @StateObject private var viewModel = CryptoViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroHeader
            Divider().background(Color.slate200)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    algorithmCard
                    ioCard
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(Color.canvasBackground)
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Color.accentAmber, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("编码 / 加密")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text("Base64、URL、Hex 编码，AES / RSA 加解密，MD5 / SHA 哈希，全部在本地完成")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: - 算法与参数

    private var algorithmCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("", selection: $viewModel.category) {
                ForEach(CryptoCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 320)

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    sectionLabel("算法")
                    Picker("", selection: $viewModel.algorithm) {
                        ForEach(viewModel.category.algorithms) { algorithm in
                            Text(algorithm.rawValue).tag(algorithm)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }

                Text(viewModel.algorithm.description)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 20)
            }

            if hasParameters {
                parameterPanel
            }
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private var hasParameters: Bool {
        let a = viewModel.algorithm
        return a.usesPassword || a.usesKey || a.usesIV || a.usesCipherFormat || usesHexCase
    }

    private var usesHexCase: Bool {
        let a = viewModel.algorithm
        return a == .hex || a.category == .hash
    }

    private var parameterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.algorithm.usesPassword {
                secureField(title: "密码", placeholder: "用于派生 AES-256 密钥", text: $viewModel.password)
            }

            if viewModel.algorithm.usesKey {
                HStack(alignment: .top, spacing: 12) {
                    secureField(title: viewModel.algorithm.keyTitle,
                                placeholder: keyPlaceholder,
                                text: $viewModel.key)
                    if viewModel.algorithm.usesIV {
                        plainField(title: "IV", placeholder: "16 个字符", text: $viewModel.iv)
                    }
                }
            }

            if viewModel.algorithm.usesRSA {
                rsaPanel
            }

            if viewModel.algorithm.usesCipherFormat {
                HStack(spacing: 20) {
                    if viewModel.algorithm.usesAESOptions {
                        HStack(spacing: 8) {
                            sectionLabel("密钥长度")
                            Picker("", selection: $viewModel.keySize) {
                                ForEach(AESKeySize.allCases) { size in
                                    Text(size.title).tag(size)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                        }
                    }
                    HStack(spacing: 8) {
                        sectionLabel("密文格式")
                        Picker("", selection: $viewModel.outputFormat) {
                            ForEach(CryptoOutputFormat.allCases) { format in
                                Text(format.rawValue).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 140)
                    }
                    Spacer()
                }
            }

            if usesHexCase {
                Toggle("十六进制输出使用大写", isOn: $viewModel.uppercaseHex)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate700)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.slate50, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private var rsaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                sectionLabel("密钥长度")
                Picker("", selection: $viewModel.rsaKeySize) {
                    ForEach(RSAKeySize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .labelsHidden()
                .frame(width: 100)

                Button(action: viewModel.generateRSAKeyPair) {
                    Label(viewModel.isGeneratingKey ? "生成中…" : "生成密钥对",
                          systemImage: "key")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isGeneratingKey)

                if viewModel.isGeneratingKey {
                    ProgressView().controlSize(.small)
                }
                Spacer()
            }

            HStack(alignment: .top, spacing: 12) {
                keyEditor(title: "公钥（加密使用）",
                          text: $viewModel.rsaPublicKey,
                          placeholder: "-----BEGIN PUBLIC KEY-----")
                keyEditor(title: "私钥（解密使用）",
                          text: $viewModel.rsaPrivateKey,
                          placeholder: "-----BEGIN PRIVATE KEY-----")
            }

            Text("支持 PEM 格式的 X.509 公钥、PKCS#8 / PKCS#1 私钥，也可粘贴不带头尾的纯 Base64；生成的密钥为 X.509 公钥 + PKCS#8 私钥")
                .font(.system(size: 10))
                .foregroundStyle(Color.slate400)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func keyEditor(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                sectionLabel(title)
                Spacer()
                Button {
                    viewModel.copyText(text.wrappedValue)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .disabled(text.wrappedValue.isEmpty)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: text)
                    .font(.system(size: 11, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(4)
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.slate300)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 130)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.slate200, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var keyPlaceholder: String {
        if viewModel.algorithm.usesAESOptions {
            return "\(viewModel.keySize.byteCount) 个字符"
        }
        return "任意长度"
    }

    private func secureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            SecureField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func plainField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionLabel(title)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 输入输出

    private var ioCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                editorPanel(title: "输入") {
                    TextEditor(text: $viewModel.input)
                        .font(.system(size: 13, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .frame(minHeight: 200)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.slate200, lineWidth: 1)
                        )
                }

                editorPanel(title: "输出") {
                    ScrollView {
                        Text(viewModel.output.isEmpty ? "结果会显示在这里" : viewModel.output)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(viewModel.output.isEmpty ? Color.slate400 : Color.slate800)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .padding(10)
                    }
                    .frame(minHeight: 200)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.slate200, lineWidth: 1)
                    )
                }
            }

            actionBar

            if let message = viewModel.errorMessage {
                errorBanner(message)
            }
        }
        .padding(18)
        .background(Color.slate50, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.slate200, lineWidth: 1)
        )
    }

    private func editorPanel<Content: View>(title: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.run(.forward)
            } label: {
                Label(viewModel.category.forwardTitle, systemImage: forwardIcon)
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentAmber)
            .controlSize(.regular)

            if let backward = viewModel.category.backwardTitle {
                Button {
                    viewModel.run(.backward)
                } label: {
                    Label(backward, systemImage: "lock.open")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }

            Spacer()

            Button(action: viewModel.useOutputAsInput) {
                Label("结果作为输入", systemImage: "arrow.uturn.left")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.output.isEmpty)

            Button(action: viewModel.copyOutput) {
                Label(viewModel.copied ? "已复制" : "复制结果",
                      systemImage: viewModel.copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.output.isEmpty)

            Button(action: viewModel.clear) {
                Label("清空", systemImage: "eraser")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var forwardIcon: String {
        switch viewModel.category {
        case .encoding: return "arrow.right"
        case .cipher: return "lock"
        case .hash: return "number"
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
        }
        .font(.system(size: 12))
        .foregroundStyle(Color.red)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.slate700)
    }
}

#Preview {
    CryptoView()
        .frame(width: 920, height: 720)
}
