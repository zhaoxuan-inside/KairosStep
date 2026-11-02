# KairosStep 重构设计方案（数据分层 + 独立执行引擎）

## 一、背景与现状问题

KairosStep 是纯本地 Flutter 应用（app/，约 2.15 万行 Dart），将 737 条人生建议转为可交互行动系统。经全面分析，当前架构的四个核心问题：

1. **巨型上帝对象**：`app/lib/state/app_store.dart`（2315 行）同时承载触发时间计算（`effectiveTriggerOf` :807-1025）、画像门禁（`matchPersona` :1979-2292）、三个建议流（`todayAdvices` :1365 / `cycleAdvicesOf` :1417 / `advicesForWindow` :1501）、打卡连击、持久化恢复（:1793-1972）等至少 6 类引擎职责。
2. **五合一数据文件**：`assets/data/advice.json` 每条记录压平了内容(c/t)、样式(parts/timing_badge/act_type)、维度(tree_path)、触发(cron/prerequisites)、画像(tags) 五类信息；`tree_display` 还是维度树的冗余副本。
3. **硬编码散落**：时段推断词表与黄金提醒时刻（app_store :815-995）、排序权重（:1590-1660）、13 个静默章节、约 20 组门禁建议 ID（:2043-2239）、139 个父母清单 ID（:356）、探测题目与窗口（probe_scheduler :88-543）、probe 绑定规则（probe_binding.dart）、3 个聚光交互器按 ID 硬编码（interactors.dart :70-77）、slider-calc 关键词特化（:1233-1253）——全部是"应数据化的配置住在代码里"。
4. **无数据版本/校验机制**：除维度树外无加载校验，坏数据静默落默认值。

**重构策略（已定）**：行为保持重构——只做架构拆分与数据外置，重构前后展示/触发/推送结果与 SharedPreferences 用户数据完全兼容；离线脚本预生成派生数据层；单 Flutter 包内分层目录。

## 二、目标架构总览

```
docs/HowToLiveBetter*.md（内容源）
   └─ tool/advice_pipeline/（离线流水线，Dart）
        └─ app/assets/data/（分层数据，随包发布）
             └─ data/repository 层 ──→ 执行引擎层(domain/) ──→ state/(装配 facade) ──→ ui/
```

```
app/lib/
├── domain/                     # 执行引擎层：纯 Dart、零 UI 依赖、可单测
│   ├── trigger_engine.dart     # 触发计算引擎
│   ├── gatekeeper_engine.dart  # 建议筛选门禁引擎
│   ├── stream_engine.dart      # 建议流引擎（今日/周期/当下 + 排序）
│   ├── reminder_engine.dart    # 通知推送引擎（应用内弹窗 + 系统通知双 sink）
│   ├── probe_engine.dart       # 主动探测引擎
│   ├── checkin_engine.dart     # 打卡状态引擎
│   └── display_composer.dart   # 展示合成引擎（运行时薄层）
├── data/                       # 数据仓库层：分层加载、索引、校验
│   ├── catalog.dart            # 入口（保留，改为加载分层文件 + schemaVersion 校验）
│   └── repositories/           # advice/taxonomy/facet/display/style/trigger/config 各仓库
├── models/                     # 模型层：按数据层分域（类名不变，仅挪文件）
│   ├── advice_core.dart  facets.dart  presentation.dart  trigger.dart  user.dart
├── state/                      # 装配层：AppStore 瘦身为 facade（目标 <800 行）
├── core/                       # theme/icons（不动）
└── ui/                         # 基本不动，仅改引用
```

## 三、数据分层设计（对应你的七项要求）

| 层 | 内容 | 新文件（assets/data/ 下） | 来源 |
|---|---|---|---|
| **L0 原始建议数据** | id、章节 c、标题 t；证据包(h/cost/plain/benefit/grade/sources/notes/rel) | `raw/advices.json`、`raw/details.json`（=现 detail.json 原样保留） | advice.json 拆出 |
| **L1 维度结构数据** | 6 域 46 叶维度树；LifeDomain 枚举（标题/图标/颜色/34 章节归属）数据化 | `dimensions/taxonomy.json`（=现 taxonomy_tree.json）、`dimensions/life_domains.json` | taxonomy_tree.json + advice.dart:444-569 |
| **L3 分维度标签数据** | 274 个自由标签归入受控维度（阶段/频率/时机/场景/对象/金钱/功能/主题/依赖/时效），id→维度→标签 | `facets/advice_tags.json`、`facets/tag_vocabulary.json` | advice.json tags + advice.dart:80-98 现有消费规则 |
| **L2 交互样式数据** | 13 种 act_type 注册表（中文名/图标 key/参数 schema，如 slider-calc 的酒/晒/遛狗参数化、daily-streak 闹钟预设） | `styles/act_styles.json` | catalog.dart:10-25 + interactors.dart 关键词特化 |
| **L4 展示信息** | 归并+人性化处理的产物：核心动作 parts[0]、约束 caveats、时机徽章文案、面包屑、一句话人话版(取 detail.h) | `display/display_info.json` | 流水线归并 L0+L1+L3，消除 tree_display 冗余 |
| **L5 展示↔样式关联** | adviceId → styleId + 参数 + 聚光专项覆盖（1→车舱、7→血压、136→时薪） | `styles/display_bindings.json` | interactors.dart:70-77、spotlight_interactors.dart |
| **L6 触发数据** | 触发方式+触发时间：mode(dormant/daily/cadence/windowed)、periods、reminderTimes、cron、窗口期(targetDate/leadDays)、应急通道标记 | `triggers/trigger_plans.json` | 流水线复刻 effectiveTriggerOf 词表结论回写 |
| **L7 引擎配置** | 静默时段 23-5、探测限频(3 条/90min/三窗口)、排序权重、5 标准时段定义、门禁规则(chapter/actType/idSet/tag 规则 schema)、probe 绑定 | `config/engines.json`、`config/gates.json`、`config/probes.json` | app_store/probe_scheduler/reminder_registry 硬编码外置 |

**设计要点**：
- 每个文件带 `schemaVersion`；catalog 加载时校验（737 条完整性、叶子路径合法、id 唯一——复用 TopicTree 校验逻辑）。
- L4/L6 是"派生层"：由流水线离线生成，运行时只读；用户自定义触发（CustomTriggerConfig）仍是运行时覆盖层，叠加在 L6 之上。
- 门禁规则（dormant 章节、0.6-0.15 专病门禁、习惯→画像演进 3 条规则）统一为 `gates.json` 规则 schema（type: chapterBlacklist/actTypeBlacklist/idSet/tagMatch/prerequisite），引擎通用解释——对齐 docs/SignalRoutingDesign.md"规则→动作"思想，但本次不改行为。
- 行为保持承诺：L6 由流水线复刻现词表生成，需通过快照测试证明 737 条逐一与旧算法输出一致。

## 四、执行引擎设计（各自独立）

| 引擎 | 职责（现状出处） | 输入 → 输出 |
|---|---|---|
| **TriggerEngine** | 触发方式/时间解析；用户自定义覆盖（app_store:807-1025） | trigger_plans + customTriggers → TriggerPlan(mode/periods/reminderTimes) |
| **GatekeeperEngine** | 画像门禁 + 前置条件 + 专病一票否决（matchPersona:1979-2292、evalNodeItem） | facets + gates.json + UserProfile → 通过/拦截 |
| **StreamEngine** | todayAdvices/cycleAdvicesOf/advicesForWindow + 排序权重（:1365-1668） | TriggerEngine + GatekeeperEngine + CheckinEngine + engines.json 权重 → 各流 |
| **ReminderEngine** | 合并 ReminderRegistry(10s 心跳/应用内弹窗) + MobileNotificationService(系统通知) + 静默/去重/稍后提醒策略，通知出口抽象为 sink | StreamEngine 活跃集 + reminderTimes → 弹窗/系统通知 |
| **ProbeEngine** | 探测调度（10min 心跳/三窗口/限频）+ 题目内容外置 + 绑定数据化（probe_scheduler + probe_binding） | 活跃集 + probes.json → 系统通知/应用内问卷 |
| **CheckinEngine** | CardState/连击/周期翻零/窗口锚点（:1224-1295, 1740-1781） | 用户打卡事件 → 状态查询 |
| **DisplayComposer** | 运行时组装展示信息（seniorMode/自定义覆盖），主体是透传 L4+L5 | display_info + bindings + 用户态 → UI 展示视图 |

**组装与依赖规则**：引擎单向依赖（StreamEngine → Trigger/Gatekeeper/Checkin；Reminder/Probe → StreamEngine）；引擎不 import UI、不直接读 SharedPreferences（用户状态经 AppStore 注入）；`syncReminderRegistry`（:602）保留为引擎刷新总开关。AppStore 瘦身为装配 + 用户状态 + 持久化委托。

**遗留矛盾裁决**：probe 的 mandatory 是否穿透静默时段（probe_scheduler:153 与 probe_model:69 注释矛盾）——行为保持模式下维持现状（不穿透），在 engines.json 加注释字段留待后续决策。

## 五、离线流水线（tool/advice_pipeline/，Dart 脚本）

`dart run tool/advice_pipeline/build.dart` 依次执行：
1. `split_raw` — advice.json → L0 + 抽出 tags/tree/cron 原值
2. `build_facets` — 按词表归类 274 标签 → L3（词表本身入 tag_vocabulary.json 可人工维护）
3. `build_display` — L0+L1+L3 归并 → L4（含面包屑重算，去掉 tree_display 冗余）
4. `resolve_triggers` — 移植 effectiveTriggerOf 词表/时刻表 → L6
5. `extract_styles` — 交互样式/绑定/门禁/引擎配置提取 → L2/L5/L7
6. `validate` — schema/计数/叶子/id 校验 + 与旧版输出 diff（防流水线回归）

## 六、实施阶段（每阶段独立可验收，阶段间需你确认再继续）

- **Phase 0（本次执行）**：设计文档落库 `docs/refactor/REFACTOR_DESIGN.md`（含数据层 schema 定义、门禁规则 schema、引擎接口签名、迁移映射表），不改任何代码。
- **Phase 1 数据层**：写流水线 → 生成新 assets/data 结构 → catalog 按层加载 → 建立行为快照基线（固定画像下 effectiveTriggerOf/todayAdvices/advicesForWindow 全量输出存 JSON，改前后比对）。旧 advice.json 删除（git 可回溯）。
- **Phase 2 模型与配置**：models/ 五文件重组；engines.json/gates.json/probes.json 外置 + ConfigRepository。
- **Phase 3 引擎抽取**：按 Trigger → Gatekeeper → Checkin → Stream → Reminder → Probe 顺序逐个搬出，每抽一个跑快照对比 + flutter analyze。
- **Phase 4 收尾**：交互样式绑定数据化（聚光专项/slider 参数/alarm 预设）；删除死代码（periodAdvicesOf:1671、markKickoffReview:1079、windowAnchorOf:1279）；更新 app/README 架构说明。

## 七、兼容与风险

- **用户数据兼容**：SharedPreferences 全部 key（kProfile/kScope.*/kStreak.* 等 17 个）不动；restore() 逻辑原样搬迁到 facade。
- **主要风险**：①触发词表移植偏差——靠 737 条快照对比兜底；②启动加载文件数增加——5→约 10 个，总量不变，必要时后续合并派生层；③UI 引用面广（me_view 50 处）——facade 保持原方法签名，UI 逐步改引用不强制一次到位。
- **明确不做**（后续另立项）：SortingDesign 分层排序落地、mandatory 穿透静默裁决、UI 文案 i18n、多 package 拆分。

## 八、验证方式

1. `cd app && flutter analyze` 0 issues（现状基线）。
2. 快照测试：新增 test/golden_test.dart，对 3 个种子画像（含 For35Dev 的 35 岁男开发）比对重构前后 todayAdvices / advicesForWindow / effectiveTriggerOf 全量输出。
3. 流水线自检：`dart run tool/advice_pipeline/build.dart` 输出 737 条校验通过 + 与上一版数据 diff 为空。
4. 手工冒烟：flutter run（web + Android）走查当下/今天/周期/指南/我的五 Tab、卡片翻转配置、提醒弹窗、心情打卡干预路径（568）。

---

**本次批准后执行**：仅 Phase 0——把上述设计扩写为完整设计文档写入 docs/refactor/（不改任何 .dart/.json）。Phase 1-4 待你逐阶段确认后开工。