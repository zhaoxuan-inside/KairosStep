<div align="center">

<img src="app/assets/branding/kairosstep-icon.png" width="96" alt="KairosStep" />

# 数字阶跃 · KairosStep

**把《高性价比人生指南》的 737 条建议，变成今天就能做的一件小事。**

本地优先 · 不联网 · 不做社交 · 不制造焦虑

[下载 Android 版](https://github.com/zhaoxuan-inside/KairosStep/releases) ·
[核心功能](#核心功能) ·
[技术架构](#技术架构) ·
[开发与构建](#开发与构建) ·
[设计原则](#设计原则)

![License](https://img.shields.io/badge/license-MIT-green)
![Flutter](https://img.shields.io/badge/Flutter-3.47+-02569B?logo=flutter)
![Android](https://img.shields.io/badge/Android-arm64--v8a-3DDC84?logo=android)
[![Release](https://img.shields.io/github/v/release/zhaoxuan-inside/KairosStep)](https://github.com/zhaoxuan-inside/KairosStep/releases)

</div>

---

## 它是什么

数字阶跃（KairosStep）是一个**本地优先的生活行动系统**。

它不提供新的信息流，也不试图再写第 738 条建议。它做的是把《高性价比人生指南》里已经写清楚的 737 条建议，按你的画像、当下时间和具体场景，重新组织成一张一张可以执行的行动卡。

- **不联网**：发布版不申请网络权限，画像、待办、打卡、复盘只存在你自己的设备上。
- **不催更**：没有断签惩罚、没有排行榜、没有恐惧倒计时。
- **不替代判断**：它把成本、收益、证据等级和来源放在详情里，最终决定仍然由你做。

> Kairos，是古希腊语里的“恰当的时机”；Step，是“一步”。

## 它从哪来

项目的灵感与内容基底来自 **《高性价比人生指南》**（也常被称作“高性价比人生”）：

> 用最少的钱、时间和精力换回寿命、金钱和人身自由。
> 全书 34 节 737 条，每条写明成本、收益、证据等级和原始出处。

原书解决的是“内容值不值得信”。数字阶跃想补上后面那一段：**怎么在真实生活里用起来。**

于是有了这本可以交互的“账本”：同样的 737 条建议，重新拆成原子行动、触发时机、风险等级和可执行步骤，再按人与时间重新排序。

## 核心功能

| 模块 | 你能得到什么 |
|---|---|
| **画像引导** | 7 层、21 个问题，了解年龄、角色、居住、健康关注、家庭责任与生活场景；可跳过，未答不会粗暴剪枝 |
| **当下** | 一条可拖动的时间尺，围绕此刻展开 1.5 小时窗口，只显示这个时间点真正该做的事 |
| **今天** | 今日节律清单 + 自建待办；支持标题、内容、触发时间、时段、提醒时点、提前提醒与频次 |
| **周期** | 每周 / 每月 / 每年视角，外加 90 天培养周期；有些事一年做一次就够，不必每天自责 |
| **指南** | 737 条建议、34 个章节、六大人生支柱；主题树逐层收窄，支持词法 + 本地语义搜索 |
| **我的** | 生活防线（已养成的习惯）、排除库、卡内基式四步周复盘、紧急联系人、主题与长辈模式 |
| **紧急模式** | 顶栏常驻红色入口，突发疾病、意外伤害、欠薪、裁员、法律风险快速直达 |
| **小工具** | 决策树、精算工具、心情晴雨表、周复盘；不喧宾夺主，需要时出现 |
| **本地提醒** | 到点提醒、提前提醒、主动探查；通知权限被拒时自动回退到应用内提示 |

### 六大人生支柱

| 支柱 | 条数 | 涵盖 |
|---|---:|---|
| 健康防线 | 170 | 防癌早筛、慢病康复、科学用药、就医防坑、运动与减压 |
| 职场事业 | 123 | 在职维权、工伤离职、技术人红线、创业合伙、技能投资 |
| 家庭守护 | 113 | 伴侣法务、孕产育儿、子女学业、父母照护、身后事 |
| 财产法律 | 197 | 法律红线、防诈反骗、房产租售、金钱节省、债务隔离 |
| 应急自救 | 99 | 突发意外、重大打击心理自救、境外安全、数字账号防线 |
| 日常节律 | 35 | 微习惯打卡、时间精力管理、昼夜节律、专注与复盘 |

## 设计原则

- **状态即信息**：完成是森林绿，进行中是淘金，未做是银灰，紧急是朱红。不用渐变、毛玻璃和满屏 emoji。
- **一屏一件事**：卡片主体只保留原子行动和它的微交互器，不露出所属分组或章节名。
- **不制造焦虑**：无断签惩罚、无排名、无恐惧倒计时；连击只记录，跨周期自然归零。
- **能算账就算账**：重要条目保留成本、收益、证据等级与来源，详情层可查。
- **安静的提醒**：本地通知与主动探查都有免打扰时段和频次上限，拒绝用红点换停留。

## 隐私与本地优先

- 发布版 **不申请 `INTERNET` 权限**；`INTERNET` 只存在于 debug/profile 清单，供开发工具使用。
- 画像、待办、打卡、复盘、紧急联系人保存在本地 `SharedPreferences`，不登录、不上传、不做额外追踪。
- 语义检索使用随包内置的 BGE small zh int8 模型（ONNX），断网可用；模型不可用时自动回退到词法检索。
- 737 条建议与详情以分层 JSON 随包发布，首次启动不依赖网络。

## 下载与安装

前往 [Releases](https://github.com/zhaoxuan-inside/KairosStep/releases) 下载最新 Android 安装包：

- 架构：`arm64-v8a`（Android 7.0+）
- 体积：约 56.8 MB
- 当前版本：`1.0.20+21`
- 每个 Release 同时提供 `.apk`、`.sha256` 与构建信息

当前为本地构建的测试签名包；如果设备上已安装其他签名的旧版本，请先卸载再安装。

> iOS / Web / macOS / Windows / Linux 使用同一套 Flutter 代码，当前优先维护 Android 安装包。

## 技术架构

```
Flutter 3.47+ / Dart 3
├─ lib/data/         分层数据加载、schema 校验、搜索索引
├─ lib/domain/       六个引擎：Trigger / Gatekeeper / Checkin / Stream / Reminder / Probe
├─ lib/state/        应用门面：引擎装配 + 用户会话 + 本地持久化
├─ lib/semantic/     本地 BGE 向量检索（ONNX，随包）
├─ lib/infra/        系统通知通道
└─ lib/ui/           五 Tab 壳 + 十余种微交互卡片 + 详情/紧急/工具/复盘
```

- **数据分层**：L0 实体关系表、L1 维度、L2 交互样式、L3 标签、L4 展示物化视图、L5 样式绑定、L6 触发计划、L7 引擎配置、L8 语义向量。
- **六个引擎**：触发、门禁、打卡、时间流、提醒、主动探查分离，UI 只做呈现与交互。
- **十余种微交互**：每日连击、持续窗口、行动打卡、测算滑块、触感卡扣、紧急直达、计时呼吸、证据清单、时薪决策、红线盖章、情境拦截、决策核对、办事分步等。
- **可追溯构建**：一键打包脚本把版本号、commit、源码指纹、构建时间与 sha256 写入 `BUILD_INFO.txt`。

详细开发文档见 [`app/README.md`](app/README.md)、[`docs/refactor/ARCHITECTURE.md`](docs/refactor/ARCHITECTURE.md) 与 [`docs/产品设计文档.md`](docs/产品设计文档.md)。

## 开发与构建

```bash
cd app
flutter pub get

# 开发运行
flutter run

# 测试
flutter test

# Android Release（arm64）
flutter build apk --release --target-platform android-arm64
```

仓库内另提供一键增量打包脚本（默认在本地磁盘构建，保留 Gradle/Flutter 增量缓存）：

```bash
tools/build_apk_remote.sh               # 增量打包
tools/build_apk_remote.sh --clean       # 全量重编
tools/build_apk_remote.sh --no-sync     # 只重跑打包
tools/build_apk_remote.sh --minify      # 开启 R8 混淆/瘦身
```

脚本可通过 `KAIROS_BUILD_DIR` 指定本地构建目录；产物统一归档到 `output/mobile/`，并生成 `BUILD_INFO.txt` 与 sha256。

### 目录结构

```
KairosStep/
├─ app/                  Flutter 应用
│  ├─ lib/               应用代码
│  ├─ assets/data/       L0-L8 分层数据与本地模型
│  ├─ data-src/          内容源归档
│  ├─ test/              单元 / Widget / Golden 测试
│  └─ android/           Android 工程
├─ docs/                 产品、设计、数据与重构文档
├─ tools/                数据提取与打包脚本
├─ output/mobile/        本地安装包归档（gitignored）
└─ README.md
```

## 版本

当前版本：**1.0.20+21**

更新记录、安装包与校验文件统一放在 [Releases](https://github.com/zhaoxuan-inside/KairosStep/releases)。

## 免责声明

本项目内容用于生活参考与行动提示，不构成医疗、法律、财务或投资建议。遇到急症、法律纠纷或重大财务决策，请及时联系当地专业机构与持证专业人士。

## 致谢

- 内容基底与灵感：[《高性价比人生指南》](docs/HowToLiveBetter.md)（项目内全文）
- 交互与视觉参考：`docs/AdviceInteractiveDemo.html`
- Flutter / Dart 及其生态

## License

[MIT](LICENSE) © 2026 zhaoxuan
