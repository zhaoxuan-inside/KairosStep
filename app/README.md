# 数字阶跃 KairosStep（Flutter 跨平台版）

把《高性价比人生指南》**767 条建议**转化为可交互的行动系统 —— 移植自
`docs/AdviceInteractiveDemo.html`（建议深度交互全景 Demo），本地优先，不访问网络。

技术栈：**Flutter 3.47+ / Dart 3**，一套代码，六端发布（Android / iOS / Web / macOS / Windows / Linux）。

---

## 功能总览（对齐 Demo）

| 模块 | 说明 |
|---|---|
| 五 Tab 壳 | 当下 / 今天 / 周期 / 库 / 我的 |
| 当下 | 按真实时段（晨/上午/午后/傍晚/夜间）切换问候与 Hero 卡；齿轮时间尺可拖动预演其他时段 |
| 今天 | 今日聚光流（起床连击 97、安全带 1、血压 7、刷牙 58、燃气窗口 4）+ 完成量胶囊 |
| 周期 | 每周 / 每月 / 每年 三分段聚光流，完成量随分段胶囊滚动 |
| 库 | 767 条全景流：拼音 A–Z 字母矩阵、34 章节矩阵、13 交互形态矩阵三维度筛选；范围三态（画像专属 → 父母适用 139 条 → 全量 767） |
| 交互卡 | 13 种 act_type 微交互器（见下）+ 3 个聚光专项（四座安全带舱 / 血压计 / 家务时薪计算器） |
| 详情层 | 证据包（说人话/成本/收益/证据等级/来源/关联建议），只读不影响打卡闭环 |
| 全局搜索 | 标题/章节/标签/时机徽章全文检索（搜索秒开通道） |
| 我的 | 画像（性别/年龄 → 人生阶段过滤 + 健康节点包触发）、双主题、健康节点筛查包（条件谓词动态求值）、隐私与免责 |
| 持久化 | 打卡、连击、窗口期锚点、提醒时刻、主题、画像，全部本地 SharedPreferences |

### 13 种交互形态

每日连击（连击点阵 + 提醒时刻调节）、持续窗口期（14 天进度 + 防线芯片）、
行动打卡、测算滑块（酒精代谢/日晒特化）、触感卡扣、紧急直达（止付/证据/热线）、
计时屏息（60s 呼吸环）、证据清单（保险箱插槽）、时薪决策、红线铭记（盖章）、
情境拦截、决策核对、办事分步。

行为设计护栏（与产品设计文档一致）：**无断签惩罚、无恐惧倒计时、无排名**；
连击只记录，完成跨周期自然归零。

---

## 数据管线

```
docs/AdviceInteractiveDemo.html
        │  tools/flutter_app_extract/extract_data.py（JS 字面量 → JSON）
        ▼
app/assets/data/{advice,detail,node_packages,pinyin}.json   （随包内置，离线可用）
        │  lib/data/catalog.dart（加载 + 字母/章节/形态索引 + 搜索）
        ▼
lib/ui/cards/*（13 种 act_type 交互器） + lib/state/app_store.dart（打卡/连击/窗口期）
```

重新提取数据（Demo 更新后）：

```bash
python3 tools/flutter_app_extract/extract_data.py
```

---

## 构建与运行

```bash
cd app
flutter pub get

# 开发运行（需连接设备或模拟器）
flutter run

# Android APK（release，无网络权限）
flutter build apk --release          # 产物：build/app/outputs/flutter-apk/app-release.apk（全 ABI 通用包）
flutter build apk --release --split-per-abi
#   ↑ 按 ABI 拆包（现代手机装 app-arm64-v8a-release.apk 即可）
# Android App Bundle（上架 Google Play）
flutter build appbundle --release

# 其他平台（同一套代码）
flutter build web --release          # Web
flutter build ios --release          # iOS（需 macOS + Xcode）
flutter build macos --release        # macOS
flutter build windows --release      # Windows
flutter build linux --release        # Linux
```

依赖仅两个插件，均为官方全平台支持：

- `shared_preferences`（本地持久化：Android/iOS/macOS/Windows/Linux/Web）
- `share_plus`（系统分享：全平台，Web 自动降级）

### Android 说明

- 应用名：`数字阶跃`（`AndroidManifest.xml`），包名 `dev.kairostep.kairo_step`，versionName 1.0.0
- **release 构建不申请任何权限**（INTERNET 仅存在于 debug/profile 清单，用于开发工具；
  装机后系统里唯一可见的是应用自用的签名级 `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`，非敏感权限）
- minSdk/targetSdk 由 Flutter 默认模板管理
- 构建加速：`android/gradle/wrapper/gradle-wrapper.properties` 使用腾讯镜像下载 Gradle，
  `settings.gradle.kts` / `build.gradle.kts` 加了阿里云 Maven 镜像（海外环境可删，`google()`/`mavenCentral()` 已保留为回退）

### Web 说明

Web 端本地持久化基于 localStorage，分享走浏览器降级，其余功能一致。

## 验证状态

- `flutter analyze`：0 issues
- `flutter test`：3 个测试全过（数据完整性 767/34 章/13 形态；画像排除孕产条目；五 Tab 渲染 + 安全带打卡闭环 + 计数）
- `flutter build web --release`：构建成功并经浏览器端到端冒烟验证（当下页、库页、画像过滤 441 条）

## 跨平台注意事项

- 无任何平台通道（platform channel）代码；UI 与状态层纯 Flutter。
- 未用 `dart:io`；时间/路径相关逻辑均走 Flutter API，Web 可直接编译。
- 后续若接入锁屏小组件（Android Widget / iOS WidgetKit），以平台插件增量扩展，不影响现有六端代码。
