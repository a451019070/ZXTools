//
//  HomeView.swift
//  Tools
//
//  Created by ZX on 2026/9/21.
//

import SwiftUI

enum ToolTab: String, CaseIterable, Identifiable {
    case dashboard = "主页"
    case color = "颜色转换"
    case timestamp = "时间戳"
    case json = "JSON 解析"
    case animation = "动图性能"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .dashboard: return "house"
        case .color: return "paintbrush"
        case .timestamp: return "clock"
        case .json: return "curlybraces"
        case .animation: return "waveform.path.ecg.rectangle"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return .slate600
        case .color: return .primaryBlue
        case .timestamp: return .secondaryGreen
        case .json: return .accentIndigo
        case .animation: return .orange
        }
    }
}

struct HomeView: View {
    @State private var selection: ToolTab = .dashboard

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            selectedPage
                .frame(minWidth: 760, minHeight: 600)
        }
        .navigationTitle("辅助工具")
    }

    private var sidebar: some View {
        List(ToolTab.allCases, selection: $selection) { tab in
            NavigationLink(value: tab) {
                Label {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: .medium))
                } icon: {
                    Image(systemName: tab.symbol)
                        .foregroundStyle(tab.color)
                }
                .padding(.vertical, 4)
            }
            .tag(tab)
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }

    @ViewBuilder
    private var selectedPage: some View {
        switch selection {
        case .dashboard:
            DashboardView { selection = $0 }
        case .color:
            ColorConverterView()
        case .timestamp:
            TimestampCalculatorView()
        case .json:
            JSONParserView()
        case .animation:
            AnimatedImageAnalyzerView()
        }
    }
}

#Preview {
    HomeView()
        .frame(width: 1180, height: 820)
}
