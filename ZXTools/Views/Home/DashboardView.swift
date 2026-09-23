//
//  DashboardView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI

struct DashboardView: View {
    var onSelect: (ToolTab) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 20) {
                    dashboardCard(.color, title: "颜色转换",
                                  subtitle: "Hex 与 RGB 快速互转，自动保留最近 10 条历史记录",
                                  accent: .primaryBlue)
                    dashboardCard(.timestamp, title: "时间戳计算",
                                  subtitle: "日期与 Unix 时间戳（秒/毫秒）双向转换",
                                  accent: .secondaryGreen)
                    dashboardCard(.json, title: "JSON 解析",
                                  subtitle: "支持折叠树状结构、自动解包、格式化、压缩",
                                  accent: .accentIndigo)
                    dashboardCard(.animation, title: "动图性能分析",
                                  subtitle: "加载 WebP / GIF，查看帧信息、解码内存与 CPU 占用",
                                  accent: .orange)
                }
                Spacer().frame(height: 12)
                Text("提示：在左侧导航选择具体工具，或点击上方卡片直接进入。")
                    .font(.system(size: 12))
                    .foregroundStyle(.slate500)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color.canvasBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("欢迎使用 网页辅助工具")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.slate900)
            Text("多功能本地工具集合，所有计算均在本地完成。")
                .font(.system(size: 13))
                .foregroundStyle(Color.slate500)
        }
    }

    private func dashboardCard(_ tab: ToolTab,
                               title: String,
                               subtitle: String,
                               accent: Color) -> some View {
        Button(action: { onSelect(tab) }) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(accent, in: RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.slate400)
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.slate900)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.slate500)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.slate200, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    DashboardView { _ in }
        .frame(width: 900, height: 600)
}
