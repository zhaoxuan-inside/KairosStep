# KairosStep 目标架构设计

> 版本：v1.0（2026-10-31）
> 定位：本文档描述重构完成后的**目标架构蓝图**（系统是什么）；施工步骤与迁移映射见 [REFACTOR_DESIGN.md](REFACTOR_DESIGN.md) v1.2（怎么迁过去）。两者冲突时以本文档为准并回改施工图。
> 输入：REFACTOR_DESIGN v1.2（数据分层 L0-L8 / 关系化 Schema / 七引擎 / 语义能力层）、DESIGN.md（视觉规约）、docs/SignalRoutingDesign.md 与 AdviceSortingDesign.md（未落地思想，见 §12 演进位）

---

## 1. 架构驱动因素（质量属性）

| 属性 | 要求 | 架构回应 |
|---|---|---|
| **纯离线** | 零网络权限、零遥测、数据不出端 | 一切能力本地化；模型随包；外部服务仅存在于构建期流水线 |
| **六端一致** | Android/iOS/Web/Linux/macOS/Windows | 平台差异封闭在 `infra/` 与能力 Port 后；能力缺席统一降级 |
| **轻量可达** | 低端老年机（2-4GB RAM）流畅；大字模式 | 启动只载 JSON；推理惰性 isolate；APK 体积有预算（§8） |
| **确定性可审计** | 健康类应用的门禁/触发决策必须可解释 | 决策=规则+数据（L6/L7）；概率模型只许做信号（ADR-006） |
| **可演进** | 模型可替换、数据可重建、引擎可独立测试 | 依赖倒置 Port（EmbeddingProvider/NotificationSink）；派生层物化视图可重建 |
| **行为兼容** | 重构期用户无感 | 17 个持久化 key 冻结；行为快照测试（ADR-002） |

## 2. 总体架构：五层两纵一流水线

```
                    ┌──────────────────────────────────────────────────┐
                    │   tool/advice_pipeline/（构建期离线流水线）          │
                    │   S 源归档 + 词表/规则 → L0-L8 分层数据（随包发布）    │
                    └───────────────────────┬──────────────────────────┘
                                            │ 生成（单向，运行时只读）
┌───────────────────────────────────────────▼──────────────────────────────────┐
│ ⑤ 表现层  ui/          五 Tab 壳 · 建议卡片 + 13 交互器 · 弹层 · 搜索          │
├──────────────────────────────────────────────────────────────────────────────┤
│ ④ 应用层  state/       AppStore(facade)：装配引擎 · 用户会话状态 · 持久化委托    │
├──────────────────────────────────────────────────────────────────────────────┤
│ ③ 领域层  domain/      TriggerEngine  GatekeeperEngine  StreamEngine          │
│                        CheckinEngine   ReminderEngine(+Sinks)  ProbeEngine   │
│                        DisplayComposer  SemanticSearchEngine  ProfileEngine  │
├──────────────────────────────────────────────────────────────────────────────┤
│ ② 能力层  semantic/    EmbeddingProvider Port · ModelManager · VectorStore    │
│           （未来能力按同模式挂入；能力缺席=Noop 降级）                            │
├──────────────────────────────────────────────────────────────────────────────┤
│ ① 数据层  data/        Catalog · Repositories（L0-L8 分层加载/索引/校验）       │
├──────────────────────────────────────────────────────────────────────────────┤
│ ⓪ 基础设施 infra/      prefs · 通知插件封装 · 时区 · isolate · core/(theme,icons) │
└──────────────────────────────────────────────────────────────────────────────┘
  纵轴 A：配置（L7 config/*.json → 各引擎参数/规则/词表）
  纵轴 B：用户会话状态（state ↔ SharedPreferences 17 key，结构冻结）
```

**依赖规则（架构守恒律，CI 可检）**：

1. 严格自上而下单向依赖，禁止跨层与反向（ui 不直接触碰 data/semantic）；
2. `domain/` 不 import `state/`、`ui/`、`SharedPreferences`；需要用户态由 state 注入快照；
3. `semantic/` 只被 domain 经 Port 消费，不感知业务模型；
4. 平台设施（通知插件、prefs）只在 `infra/` 出现，经接口（NotificationSink）注入领域层；
5. `core/`（设计系统）可被除流水线外所有层引用；
6. 流水线（tool/）只读仓库文件、只写 `assets/data/`，永不 import `lib/`。

## 3. 模块视图：目录终态

```
app/
├── tool/advice_pipeline/        # 构建期：split_raw → normalize → build_facets → build_display
│                               #   → resolve_triggers → extract_styles → embed_docs → validate
├── assets/
│   ├── data/                    # L0-L8（§4，关系化 Schema）
│   └── models/                  # bge-small-zh-int8.onnx + vocab（manifest 登记）
├── data-src/                    # 源归档 S（出 APK，git 管理，只增不改）
└── lib/
    ├── core/                    # 设计系统：AppPalettes 语义色板 / AppHairlineIcons 1.2px 细线
    ├── infra/
    │   ├── preferences.dart     # SharedPreferences 读写原语（17 key 冻结）
    │   ├── notifications/       # flutter_local_notifications 封装（SystemSink 实现）
    │   └── isolate_runner.dart  # 后台推理 isolate
    ├── data/
    │   ├── catalog.dart         # 入口：分层加载 + schemaVersion + 参照完整性校验
    │   ├── schema/              # 关系表 ↔ Dart 类型 + 校验器（数据字典的代码化）
    │   └── repositories/        # advice / taxonomy / facet / style / display / trigger / config / vector
    ├── semantic/
    │   ├── embedding_provider.dart   # ★ Port：项目内唯一可见抽象
    │   ├── model_manifest.dart  model_manager.dart
    │   ├── providers/           # noop_provider / bge_small_int8/(provider+tokenizer+manifest)
    │   └── vector_store.dart    # L8 加载 + modelVersion 绑定校验 + 暴力余弦
    ├── domain/
    │   ├── trigger_engine.dart      gatekeeper_engine.dart
    │   ├── stream_engine.dart       checkin_engine.dart
    │   ├── profile_engine.dart      # 画像引擎（引导即剪枝，ONBOARDING_DESIGN.md）
    │   ├── delivery/reminder_engine.dart + notification_sink.dart + sinks/
    │   ├── delivery/probe_engine.dart
    │   ├── display_composer.dart    search/semantic_search_engine.dart
    │   └── stream_inputs.dart       # 用户态快照类型（exclusions/habits/todos/profile）
    ├── state/
    │   ├── app_store.dart           # facade（目标 <800 行）：装配 + 会话状态 + sync 总开关
    │   └── user_preferences.dart    # restore()/persist()（17 key，结构冻结）
    └── ui/                          # 基本沿用现结构（shell/today/now/cycle/library/me/cards/…）
```

## 4. 数据架构

完整关系模型、十条规约、E-R 图、19 关系清单见 REFACTOR_DESIGN §4.9，此处只定架构级事实：

| 事实 | 内容 |
|---|---|
| 存储介质 | 内容库 = 随包 JSON 关系文件（一个文件一个关系）；用户态 = SharedPreferences（KV + JSON 序列化）；**无 SQLite**（ADR-004） |
| 数据分层 | S（源归档，出包）→ L0 基表/子表/联结/字典 → L1 维度 → L2 样式 → L3 标签 → L4 展示视图 → L5 绑定 → L6 触发 → L7 配置 → L8 语义向量 |
| 流向 | 构建期单向生成（S→L0-L8），运行时只读；用户态单独走 state↔prefs 回路，两流永不混写 |
| 完整性 | schemaVersion 每文件；validate 步 = 参照完整性 + CHECK/UNIQUE/NOT NULL；L4/L6/L8 为物化视图可全量重建 |
| 版本兼容 | 17 个 prefs key 结构冻结；L8.modelVersion ↔ provider.modelVersion 绑定校验；canonicalAdviceId 旧 ID 迁移表保留 |
| 演进位 | 关系模型即未来 drift/SQLite 的 DDL：表→表机械映射，仓库层是唯一改动点 |

## 5. 运行时视图

**进程/线程模型**：

```
主 isolate ── UI 帧 · 引擎 · 心跳
   │  ReminderEngine ticker 10s（L7 可配）
   │  ProbeEngine ticker 10min + App.resumed 钩子
   └─(提交推理任务)→ 推理 isolate：EmbeddingProvider.embed（结果回传，UI 不卡）
进程死亡后：系统级 zonedSchedule 定时通知由 OS 按 L7 配置执行（引擎不在执行路径上）
```

**启动序列**：`main` → `Catalog.load`（顺序加载 L0-L8，schemaVersion + 参照完整性校验，失败 fail-fast）→ `AppStore` 装配八引擎（注入仓库/配置/Port）→ `restore()`（17 key）→ `sync()` 总开关重算活跃集 → 首帧。语义 provider **不在启动路径**（首次搜索惰性 ensureLoaded）。

**刷新总开关**：`sync()`（沿用现 syncReminderRegistry 语义）——画像/打卡/触发/排除任一变更 → StreamEngine 重算活跃集 → ReminderEngine/ProbeEngine 重注册。所有引擎状态变更单向汇聚于此。

## 6. 关键流程（时序）

**F0 引导与剪枝**：分层问题（L7 onboarding.json，7 层约 40 题）→ 答案 → ProfileEngine 归一 + GatekeeperEngine 判定 → activeSet 重算 → 实时聚焦反馈（"为你聚焦 N/737"，正向措辞）→ **未答不剪**（安全默认，任意可跳过）；日常经"我的-画像"渐进补全；软维度（scene/theme）只影响排序不剪枝。

**F1 今日流构建**：`StreamEngine.todayAdvices` = 全库 → Gatekeeper（L7 gates 规则 × 画像）→ TriggerEngine（L6 mode 四分支门：dormant 禁入/windowed 窗口判定/cadence 让周期页）→ 应急门禁 → 融合自建待办 → CheckinEngine 完成态沉底 + L7 排序权重 → **MergeGroup grouping pass**（同触发时机 + advice_relation.merge_candidate + 双方过门禁 → 合并展示组；成员打卡/排除独立，门禁失效即解散，见 MERGE_DESIGN.md）。

**F2 提醒命中**：ticker → 活跃集内 reminderTimes 命中当前分钟 → 静默时段(23-5)/幂等键/已完成检查 → NotificationSink.showAlert → 前台 InAppAlertSink 弹窗（后台由 SystemSink 提前调度）→ 用户动作（完成/稍后/忽略）→ CheckinEngine → sync。

**F3 语义搜索**：query → 双通道并行：词法（分词 AND + 标题置顶 + 拼音首字母）∥ 向量（queryPrefix → embed → L8 暴力余弦，<0.35 丢弃）→ RRF 融合 → 结果。任一通道不可用 → 单通道；两者皆不可用 → 词法必达（兜底 T0）。

**F4 打卡反馈闭环**：checkin → CheckinEngine（CardState/连击/scope 翻零）→ 累计达成习惯养成 → gates.json habit-evolution 规则反向演进画像 → sync 重算 → 今日流剪枝。

**F5 probe 探测**：10min ticker / resumed → 注册活跃集 → 绑定解析（probes.json 显式 ID → emergency → 关键词链 → 语义兜底信号[可选]）→ 限频（3/日、90min 冷却、静默）→ 窗口命中 → sink 出题 → 回答转化待办/画像。

## 7. 接口契约

| 边界 | 契约 | 测试 |
|---|---|---|
| state → domain | 引擎构造注入 + §5(REFACTOR_DESIGN) 方法签名，同名同语义 | 行为快照（golden_test：3 画像全量输出比对） |
| domain → capability | `EmbeddingProvider`（§11 REFACTOR_DESIGN）：isAvailable/embed/null 降级 | tokenizer 黄金样本对齐（Python 侧生成）；Noop 路径单测 |
| domain → infra | `NotificationSink`：showAlert/scheduleDaily | InApp/System 双实现冒烟 |
| data → 全体 | 仓库只读查询；schemaVersion 校验 | `--check` 数据 diff；参照完整性 |
| 流水线 → 数据 | 幂等重建：同输入 byte 级一致输出 | `--check` CI 门禁 |

## 8. 部署视图

| 项 | 决策 |
|---|---|
| 交付物 | 按 ABI 拆分 APK / appbundle / 六端构建；checksums 入库（沿用现发布流程） |
| 体积预算 | 基线 APK 22MB；数据层 ~3MB（源归档出包后持平）；语义层 +~40-55MB/ABI（模型 24MB + ONNX runtime 15-25MB）→ 单 ABI ~60MB |
| 端差异矩阵 | 通知：移动=系统级定时+应用内双通道；桌面/Web=仅应用内弹窗。语义：移动/桌面=ONNX；Web=backend:none 词法兜底。prefs：全端可用（Web=localStorage） |
| 权限 | 保持零 INTERNET；通知权限运行时请求（现状不变） |

## 9. 架构决策记录（ADR）汇总

| # | 决策 | 理由 | 否决项 |
|---|---|---|---|
| ADR-001 | 单包内分层目录 | 六端构建零改动；边界用 lint 守护 | 多 package 拆分 |
| ADR-002 | 行为保持重构 + 快照测试 | 健康类应用回归风险不可接受 | 借机改行为 |
| ADR-003 | 离线流水线预生成派生层 | 纯离线定位；可审计；运行时轻 | 运行时实时计算派生数据 |
| ADR-004 | 文件存储 + 数据库纪律；暂不迁 SQLite | 数据量小；关系模型预留机械迁移路径 | 现在引入 drift |
| ADR-005 | 语义能力 Port 抽象 + BGE-small INT8 首实现 + Noop 降级 | 模型可替换；能力缺席不致命 | 直接依赖具体模型/Jev 类决策模型 |
| ADR-006 | 通知/门禁决策确定性（规则+数据），模型只做信号 | 可解释可审计；系统级调度无模型路径；安全路径（568）不容概率 | 概率模型做推送决策 |
| ADR-007 | 17 个 SharedPreferences key 结构冻结 | 用户数据兼容承诺 | 迁移存储介质 |
| ADR-008 | 引擎间单向依赖 + sync 总开关 | 消除环依赖；刷新语义单点 | 事件总线/响应式框架引入 |
| ADR-009 | 引导即剪枝；未答不剪（安全默认）；问题与分层数据化（L7 onboarding.json） | 健康类应用宁可冗余不可漏推；问题价值可度量（max-yield） | 引导期一次性全量问卷；剪枝逻辑写死 UI |
| ADR-010 | 数据原子化；归并只发生在触发/展示层；相关性是独立关联数据（advice_relation）；画像区分先于归并 | 合并可随时按成员解散；门禁不满足不进组；相关性可离线审计（L8 语义提名+人工确认） | 内容层写死合并（多主题塞一条）；UI 硬编码关联；无关联数据的碰巧合并 |

## 10. 架构守护（如何防止腐化）

1. **依赖规则 CI**：import 扫描脚本（Phase 3 交付，`tool/arch_guard.dart`）：ui→data、domain→state、semantic→domain 等违例即失败；
2. **行为快照**：golden_test 三画像全量输出比对，每阶段必跑；
3. **数据门禁**：pipeline `--check`（幂等 + 参照完整性 + 与已发布 diff）；
4. **设计红线**：DESIGN.md 视觉规约 + 行为负面清单（无恐惧倒计时/无 Emoji/卡片禁露章节名）作为 UI code review 检查单；
5. **体积预算**：发布流程记录 APK 体积，超阈值（单 ABI >65MB）需 ADR 评审。

## 11. 视图 ↔ 路线图映射

| 路线图阶段（REFACTOR_DESIGN §10） | 落地的架构视图 |
|---|---|
| Phase 1 数据层 | §4 数据架构（S 封存、关系化拆分、catalog 分层加载、数据字典） |
| Phase 2 模型与配置 | §3 模块视图（models/ 分域）、纵轴 A（L7 配置仓库） |
| Phase 3 引擎抽取 | §2 领域层七引擎、§5 运行时视图、§10 依赖守护脚本 |
| Phase 4 收尾 | §3 目录终态（L2/L5 绑定全数据化）、死代码清理 |
| Phase 5 语义能力 | §2 能力层、F3 语义搜索流程、§8 端差异矩阵 |
| Phase 6 画像引导 | §6 F0、ProfileEngine（第九引擎）、纵轴 B 扩展（Profile v2 增量字段）、L7 onboarding.json |
| Phase 7 触发层归并 | §6 F1 尾段（MergeGroup pass）、advice_relation 关联层、profileVocabulary 受控词表、L8 语义候选→人工审核 |

## 12. 明确的演进位（设计已留座，不在本次范围）

1. **SignalRouting 完整路由**：D1-D9 信号 → Route → Action 的决策层；本架构的 GatekeeperEngine/L6/L7/SignalContributor 即其零件箱，未来以"路由引擎"形态组装；
2. **AdviceSorting 分层排序**：Tier/粘滞/轮换需要"展示日志"时序数据——届时按 ADR-004 演进位评估 drift，仅动 data 仓库层；
3. **建议库热更新**：assets 整包 → 增量包/DB，仓库层隔离改动；
4. **能力层扩员**：语音/TTS、桌面快捷键、小组件等按 semantic 同模式（Port + Noop + 具体实现）挂入；
5. **mandatory 穿透静默裁决**、UI 文案 i18n、多 package（若六端差异膨胀再启）。
