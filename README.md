# ZXTools

一款基于 SwiftUI 的 macOS 辅助工具集合（窗口标题：网页辅助工具）。除图片压缩需调用 TinyPNG 服务外，其余功能均在本地完成。

## 功能

| 工具 | 说明 |
| --- | --- |
| 颜色转换 | Hex 与 RGB 互转，保留最近 10 条历史记录 |
| 时间戳 | 日期与 Unix 时间戳（秒 / 毫秒）双向转换；可选择常用时区、搜索全部系统时区，也支持输入偏移量（如 `+5:30`、`utc+8`） |
| JSON 解析 | 折叠树状结构、自动解包字符串、格式化、压缩；可在独立窗口中打开；保留最近 50 条历史记录 |
| 编码 / 加密 | 编码：Base64（兼容 URL-safe）、URL、Hex<br>加密：AES-GCM（密码经 PBKDF2 派生密钥）、AES-CBC、AES-ECB、RSA-OAEP（SHA256）、RSA-PKCS1 v1.5<br>哈希：MD5、SHA1、SHA256、SHA512、HMAC-SHA256<br>RSA 支持生成密钥对，导入 X.509 / PKCS#8 / PKCS#1 的 PEM（有无 PEM 头均可） |
| 图片压缩 | 接入 TinyPNG API，批量压缩本地图片或图片链接（支持一次粘贴多个链接，最多 4 个并发）；可转换为 PNG / JPEG / WebP / AVIF 或自动选最小；支持等比缩放、适应、填充裁剪、智能缩略图；可选保留版权、创建时间、位置元数据；保留最近 200 条历史记录 |

## 环境要求

- macOS 26.0 及以上
- Xcode（需支持 macOS 26 SDK）
- Swift 5

## 构建与运行

1. 克隆仓库，用 Xcode 打开 `ZXTools.xcodeproj`。
2. 等待 Swift Package Manager 解析依赖（[GRDB.swift](https://github.com/groue/GRDB.swift)，当前跟踪 `master` 分支）。
3. 选择 `ZXTools` Scheme，按 `Cmd + R` 运行。

## 图片压缩配置

图片压缩依赖 [TinyPNG](https://tinypng.com/developers) API，免费额度为每月 500 次。

1. 在 TinyPNG 开发者页面申请 API Key。
2. 在应用的「图片压缩」页面「TinyPNG API Key」一栏填入并验证。
3. 验证通过后，Key 会保存到系统钥匙串（Keychain），无需重复输入。

## 项目结构

```
ZXTools/
├── ZXToolsApp.swift        # 应用入口（主窗口 + JSON 独立窗口）
├── Views/
│   ├── Home/               # 主页与侧边栏导航
│   ├── Colors/             # 颜色转换
│   ├── Timestamp/          # 时间戳
│   ├── JSON/               # JSON 解析
│   ├── Crypto/             # 编码 / 加密（含 RSAKit）
│   └── ImageCompress/      # 图片压缩
├── Services/TinyPNG/       # TinyPNG 客户端与钥匙串存储
├── Database/               # GRDB 数据库、模型与仓库
└── global/                 # 公共颜色与扩展
```

## 数据存储

颜色、JSON、图片压缩的历史记录通过 GRDB 保存在本地 SQLite 数据库：

```
~/Library/Application Support/<Bundle ID>/Tools.sqlite
```

## 许可证

本项目基于 [MIT License](LICENSE) 开源。
