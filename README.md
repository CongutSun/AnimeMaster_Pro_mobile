```markdown
# 🌟 AnimeMaster Pro (动漫大师 Pro) - Mobile

![Flutter](https://img.shields.io/badge/Flutter-%5E3.11.4-blue.svg?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2.svg?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![Shorebird](https://img.shields.io/badge/OTA_Update-Shorebird-FF4500.svg)

**AnimeMaster Pro** 是一款基于 [Flutter](https://flutter.dev/) 构建的高颜值、全功能综合性追番与资源聚合神器。
完美整合了 **Bangumi (番组计划)** 的数据生态与全网 **RSS 磁力搜刮**，致力于为二次元爱好者提供“找番 ➔ 看评价 ➔ 追进度 ➔ 找资源下载”的一站式极致体验。

---

## ✨ 核心特性 (Features)

* 📊 **深度整合 Bangumi 生态**
  * 完整的番剧/书籍详情展示：每日放送表、角色声优、制作人员、关联条目、用户吐槽。
  * 完美解析并突破 CDN 防盗链限制（支持 `chii.in`, `bgm.tv` 图片智能 Referer 注入）。
* ☁️ **云端追番进度管理**
  * 登录 Bgm 账号，实时同步「想看/在看/看过/搁置/抛弃」状态。
  * 记录集数/卷数进度，支持长评与短评打分，数据多端防丢失。
* 🚀 **硬核 RSS 聚合磁力搜刮**
  * 内置智能聚合搜索器，一键查询全网资源（默认支持 动漫花园、蜜柑计划 等）。
  * 支持高度自定义：自定义 RSS 源、画质匹配、排除过滤词、繁简匹配。
  * 一键复制 Magnet 磁力链接或**直接唤起本地下载工具/网盘**。
* 🎨 **现代化 UI 与个性化**
  * 极致流畅的 Material Design 3 设计，支持全局**深色/浅色模式 (Dark/Light Mode)** 切换。
  * 支持自定义全局背景壁纸，打造专属追番空间。
  * 图片高斯模糊与沉浸式沉浸状态栏设计。
* ⚡ **极速热更新 (OTA)**
  * 接入 [Shorebird](https://shorebird.dev/) Code Push，应用内逻辑修改无缝热更，告别频繁的商店审核。


## 🛠️ 技术栈 (Tech Stack)

* **UI 框架**: Flutter (^3.11.4)
* **状态管理**: [provider](https://pub.dev/packages/provider)
* **网络请求**: [dio](https://pub.dev/packages/dio) & [http](https://pub.dev/packages/http)
* **数据解析**: [dart_rss](https://pub.dev/packages/dart_rss) (磁力源解析), [html](https://pub.dev/packages/html) (网页抓取)
* **图片处理**: [cached_network_image](https://pub.dev/packages/cached_network_image) (缓存机制)
* **数据存储**: [shared_preferences](https://pub.dev/packages/shared_preferences) (普通配置), [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (加密 Token 存储)
* **OTA 更新**: [shorebird_code_push](https://shorebird.dev/)

---

## 📂 项目结构 (Project Structure)

```text
lib/
├── api/                  # 网络请求层
│   ├── bangumi_api.dart  # Bangumi (Bgm.tv) 数据接口
│   ├── dio_client.dart   # Dio 单例与拦截器配置
│   └── magnet_api.dart   # RSS 磁力搜索解析接口
├── models/               # 数据模型 (如 Anime 实体类)
├── providers/            # Provider 状态管理
│   └── settings_provider.dart # 设置与账号状态管理
├── screens/              # UI 页面
│   ├── home_page.dart    # 首页 (新番时间表、热门等)
│   ├── detail_page.dart  # 条目详情页 (含虚化 Header 与多 Tab)
│   ├── search_page.dart  # 全局搜索页
│   ├── magnet_config_page.dart # 磁力搜刮配置与结果页
│   ├── collection_page.dart # 用户收藏页
│   ├── category_result_page.dart # 标签/角色/声优聚合页
│   └── settings_page.dart # 应用设置页
├── utils/                # 工具类
│   └── image_request.dart # 突破图片防盗链的核心逻辑
├── widgets/              # 可复用组件 (如 AnimeCard, TopToolBar)
└── main.dart             # App 入口与路由配置
```

---

## 🚀 快速开始 (Getting Started)

### 环境要求
* Flutter SDK: `^3.11.4` 或更高版本 (Dart 3.x 健全的空安全环境)
* Android Studio / VS Code
* 可用的网络环境 (部分接口可能需要特殊网络访问)

### 克隆与运行
1. **克隆项目到本地:**
   ```bash
   git clone [https://github.com/yourusername/animemaster_pro_mobile.git](https://github.com/yourusername/animemaster_pro_mobile.git)
   cd animemaster_pro_mobile
   ```

2. **获取依赖:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **运行项目:**
   ```bash
   # Debug 模式运行
   flutter run
   
   # Release 打包 (Android APK)
   flutter build apk --release
   ```

### 关于 Shorebird (可选)
本项目集成了 Shorebird 热更新。如果您需要发布热更新补丁，请确保您已安装 Shorebird CLI：
```bash
# 初始化 Release
shorebird release android

# 发布 Patch (热更新补丁)
shorebird patch android
```

---

## ⚙️ 配置说明 (Configuration)

1. **Bangumi API 授权**: 
   应用内通过页面引导用户输入 Bgm 账号 (UID) 和授权 Token (Personal Access Token)，并将敏感信息安全储存在 `flutter_secure_storage` 中。无需在代码中硬编码任何 Secret。
2. **RSS 源配置**:
   默认在 `settings_provider.dart` 中内置了 `dmhy` 和 `Mikan` 的搜索接口，用户可在 App 设置中自由增删自定义 RSS 节点。

---

## ⚠️ 声明与免责 (Disclaimer)

* 本项目仅作为 Flutter 技术学习与交流使用。
* App 内提供的所有动漫元数据均来自开源的 **Bangumi API** 以及公开网络抓取，版权归原网站及原作者所有。
* App 内的「磁力搜刮」功能仅为**本地 RSS 链接聚合工具**。本项目**不存储、不提供、不发布**任何视频文件与盗版资源。请用户自觉遵守当地法律法规，支持正版。

---

## 🤝 参与贡献 (Contributing)

欢迎提交 Pull Requests 或开启 Issues！如果您对界面优化、API 效率或者新的 RSS 聚合逻辑有任何好点子，非常期待您的加入！

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 将您的修改推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启一个 Pull Request

---

## 📄 开源协议 (License)

该项目基于 **MIT License** 开源 - 详情请查看 [LICENSE](LICENSE) 文件。
```
