# ZXTools

一款基于 SwiftUI 的 macOS 开发辅助工具集合（应用内名称：辅助工具）。除图片压缩需调用 TinyPNG 服务外，其余功能均在本地完成。

## 功能

| 工具 | 说明 |
| --- | --- |
| 颜色转换 | Hex 与 RGB 快速互转，自动保留最近 10 条历史记录 |
| 时间戳 | 日期与 Unix 时间戳（秒 / 毫秒）双向转换 |
| JSON 解析 | 折叠树状结构、自动解包、格式化、压缩，支持历史记录 |
| 编码 / 加密 | Base64、URL、Hex 编码；AES（GCM / CBC / ECB）、RSA（OAEP / PKCS1 v1.5）加解密；MD5、SHA1、SHA256、SHA512、HMAC-SHA256 |
| 图片压缩 | 接入 TinyPNG API，批量压缩 PNG / JPEG / WebP / AVIF，支持格式转换与缩放，支持历史记录 |

## 环境要求

- macOS 26.0 及以上
- Xcode（支持 macOS 26 SDK）
- Swift 5

## 构建与运行

1. 克隆仓库并用 Xcode 打开 `ZXTools.xcodeproj`。
2. 等待 Swift Package Manager 解析依赖（[GRDB](https://github.com/groue/GRDB.swift)）。
3. 选择 `ZXTools` Scheme，点击 Run（`Cmd + R`）。

## 图片压缩配置

图片压缩依赖 [TinyPNG](https://tinypng.com/developers) 的 API，需要先申请 API Key，并在应用的图片压缩页面中填写。Key 保存在系统钥匙串（Keychain）中。

## 项目结构

```
ZXTools/
├── ZXToolsApp.swift        # 应用入口
├── Views/                  # 各工具的界面与 ViewModel
│   ├── Home/               # 主页与侧边栏导航
│   ├── Colors/             # 颜色转换
│   ├── Timestamp/          # 时间戳
│   ├── JSON/               # JSON 解析
│   ├── Crypto/             # 编码 / 加密
│   └── ImageCompress/      # 图片压缩
├── Services/TinyPNG/       # TinyPNG 客户端与钥匙串存储
├── Database/               # 基于 GRDB 的 SQLite 存储（模型与仓库）
└── global/                 # 公共颜色与扩展
```

## 数据存储

历史记录（颜色、JSON、图片压缩）使用 GRDB 保存到本地 SQLite 数据库，位于应用的 Application Support 目录下。

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
