# KairosStep 重构设计：数据分层 + 独立执行引擎

> 版本：v1.4（2026-10-31）
> v1.4 变更：增补触发层归并专项设计（MERGE_DESIGN.md）——advice_relation 扩展 kind/weight/mergePolicy、MergeGroup 机制、profileVocabulary 受控词表、Phase 7
> v1.3 变更：增补画像引导专项设计（ONBOARDING_DESIGN.md）——ProfileEngine 第九引擎、L7 新增 onboarding.json、Phase 6
> v1.2 变更：增补 §4.9 关系化数据 Schema——文件存储按数据库规范设计（一个文件一个关系、1NF 拆重复组、联结表、字典表、参照完整性检查、数据字典）；L0 修正为"源归档 S（不进 APK）+ 规范化实体层"
> v1.1 变更：增补 §11 语义能力层设计（BGE-small INT8，模型能力抽象化，不依赖具体模型）
> 状态：Phase 0 已定稿，Phase 1-4 待逐阶段确认实施
> 关联文档：`DESIGN.md`（视觉规约）、`docs/AdviceSortingDesign.md`（排序，本次不落地）、`docs/SignalRoutingDesign.md`（语义路由思想来源）、`docs/inactive_detail_design.md`（触发设计母文档）

---

## 1. 背景与现状问题

KairosStep 是纯本地 Flutter 应用（`app/`，约 2.15 万行 Dart，42 个文件），将《高性价比人生指南》737 条建议转为可交互行动系统。零联网，数据仅存 SharedPreferences 与随包 JSON。

经全量代码分析，当前架构存在四个核心问题：

### 1.1 巨型上帝对象

`app/lib/state/app_store.dart`（2315 行）同时承载至少 6 类引擎职责：

| 职责 | 位置 |
|---|---|
| 触发时间计算引擎 | `effectiveTriggerOf` :807-1025（含时段推断词表 :846-936、黄金提醒时刻表 :938-995） |
| 画像筛选门禁（Gatekeeper） | `matchPersona` :1979-2292（0.5-0.15 十余道门禁，硬编码约 20 组建议 ID）、`evalNodeItem` :2294-2314 |
| 建议流（今日/周期/当下） | `todayAdvices` :1366-1415、`cycleAdvicesOf` :1418-1499、`advicesForWindow` :1502-1668（含排序权重 :1590-1660） |
| 打卡/连击/周期翻零 | :1224-1295、:1740-1781 |
| 用户状态（画像/排除/习惯/待办/复盘/紧急联系人） | :617-1222 |
| 持久化与恢复 | `_persistScope` :1784、`restore()` :1793-1972（约 180 行手写反序列化，17 个 SharedPreferences key） |

### 1.2 五合一数据文件

`assets/data/advice.json`（771KB，737 条）每条记录压平五类信息：内容（`c`/`t`）、样式（`parts`/`timing_badge`/`act_type`）、维度（`tree_path`/`tree_paths`）、触发（`cron`/`prerequisites`）、画像（`tags`）。`tree_display` 是 `tree_path` 在 `taxonomy_tree.json` 下的冗余面包屑副本。无优先级、无独立 trigger 字段——触发语义分散在 `cron`、`timing_badge` 前缀、`tags` 频率词三处。

### 1.3 硬编码配置散落在代码中

以下均属"应数据化的配置住在代码里"（完整迁移映射见 §7）：

- 时段推断词表、黄金提醒时刻表（app_store :846-995）
- 排序按时段关键词加权 +60/+40/+30（app_store :1590-1660）
- 13 个静默储备章节名、6 个非日常 actType（app_store :815-838）
- 门禁命中 ID 集合：减重药物 199/663/665、肠胃 760、止痛 763、独居 675、抑郁干预 568/25/264、孕产急症 644/646/647、婴幼儿 545/686/704、专病用药 44/121/757（:2147-2239）
- 父母清单 139 个 ID（:356-496）、旧 ID 迁移表（:499-530）、习惯→画像演进 3 条规则（:733-748）
- 探测限频参数/三窗口/全部题目文案（probe_scheduler :40-43、:303-310、:334-562）
- probe 绑定规则：12 条显式 ID 映射 + 关键词推断链（probe_binding.dart 全文件）
- 13 种交互形态注册表、12 种时机徽章→色映射（catalog.dart :10-25、:42-69）
- 3 个聚光交互器按建议 ID 硬编码（interactors.dart :70-77：1→车舱、7→血压、136→时薪）
- slider-calc 关键词特化（酒/晒/遛狗，interactors.dart :1233-1253）、daily-streak 闹钟预设（:417-434）
- 静默时段 23:00-05:00、心跳周期、稍后提醒分钟数（reminder_registry :60/:103/:149、probe_scheduler :40-43）

### 1.4 无数据版本与校验机制

加载即 `jsonDecode` + 构造（catalog.dart :134-163），除 `TopicTree.fromJson` 的叶子/唯一性校验外无任何校验；advice 字段坏数据静默落默认值（advice.dart :198-209）。无 schemaVersion、无迁移机制。

---

## 2. 重构目标与策略

**目标**：代码、数据、配置三者分离；通知推送、建议筛选等执行引擎各自独立设计；建议数据按层建设，形成"原始数据 → 维度标签 → 归并展示 → 触发"的单向流水线。

**已定策略**（四项决策）：

| 决策点 | 结论 | 理由 |
|---|---|---|
| 产出形式 | 设计先行，分阶段实施，阶段间确认 | 控制 |
| 行为兼容 | **行为保持重构**：展示/触发/推送结果与 SharedPreferences 用户数据完全不变 | 风险最低；未落地设计（排序分层、语义路由）另立项 |
| 数据加工位置 | **离线流水线预生成**派生层，运行时只读 + 兜底 | 纯离线 App 定位；结果可离线审计；运行时轻 |
| 代码组织 | **单 Flutter 包内分层目录** | 六端构建流程不变，改动成本最低 |

**行为保持的具体承诺**：
1. 737 条建议在今日流/周期流/当下流/紧急面板的出现与排序结果不变；
2. 每条建议的触发模式（dormant/daily/cadence/windowed）、浮出时段、提醒时刻不变；
3. 画像门禁（含专病一票否决、抑郁干预拦截）判定结果逐一不变；
4. SharedPreferences 全部 17 个 key 及其 JSON 结构不变，老用户升级无感；
5. 探测(probe)调度行为不变（含 mandatory 不穿透静默时段的现状——该矛盾裁决延后，见 §4.8）。

---

## 3. 目标架构总览

### 3.1 数据流水线

```
docs/HowToLiveBetter*.md（内容源）
   └─ tools/flutter_app_extract/extract_data.py（已有提取管线，不动）
        └─ app/assets/data/advice.json + detail.json（L0 原始层，现有产物）
             └─ app/tool/advice_pipeline/（新增离线流水线，Dart）
                  ├─ split_raw          校验/固化 L0
                  ├─ build_facets       L0 → L3 分维度标签
                  ├─ build_display      L0+L1+L3+detail → L4 展示信息
                  ├─ resolve_triggers   复刻现词表 → L6 触发数据
                  ├─ extract_styles     代码硬编码 → L2/L5/L7
                  └─ validate           schema 校验 + 737 条计数 + 与旧版 diff
                       └─ 生成 assets/data/ 分层文件（随包发布）
```

### 3.2 代码分层

```
app/lib/
├── domain/                     # 执行引擎层：纯 Dart、零 UI 依赖、不碰 SharedPreferences、可单测
│   ├── trigger_engine.dart     # 触发计算引擎
│   ├── gatekeeper_engine.dart  # 建议筛选门禁引擎
│   ├── stream_engine.dart      # 建议流引擎（今日/周期/当下 + 排序）
│   ├── reminder_engine.dart    # 通知推送引擎（应用内弹窗 + 系统通知双 sink）
│   ├── probe_engine.dart       # 主动探测引擎
│   ├── checkin_engine.dart     # 打卡状态引擎
│   └── display_composer.dart   # 展示合成引擎（运行时薄层）
├── data/
│   ├── catalog.dart            # 入口：加载分层文件 + schemaVersion 校验（保留类名）
│   └── repositories/           # 按 L0-L7 分仓库：advice/taxonomy/facet/style/display/trigger/config
├── models/                     # 模型层：类名不变，按数据域拆文件
│   ├── advice_core.dart        # RawAdvice / Advice / AdviceDetail
│   ├── facets.dart             # AdviceFacets（维度标签视图）
│   ├── presentation.dart       # AdvicePresentation / ActStyleDef
│   ├── trigger.dart            # TriggerMode / CustomTriggerConfig / PeriodDefinition / TriggerPlan
│   └── user.dart               # UserProfile / UserTodoItem / CardState / StreakState / NodePackage / CarnegieReviewItem / EmergencyContact / NinetyDayPlan
├── state/                      # 装配层
│   ├── app_store.dart          # 瘦身为 facade（目标 <800 行）：装配引擎 + 用户状态 + 持久化委托
│   └── user_preferences.dart   # SharedPreferences 读写与 restore()
├── core/                       # theme / icons（不动）
└── ui/                         # 基本不动，仅改引用
```

### 3.3 引擎依赖图（单向，禁止反向）

```
Catalog（数据仓库层，L0-L7 全量只读）
   │
AppStore（facade：装配、UserProfile、SharedPreferences、ChangeNotifier）
   │
   ├─ TriggerEngine      ← L6 trigger_plans + 用户自定义覆盖
   ├─ GatekeeperEngine   ← L3 facets + L7 gates.json + UserProfile
   ├─ CheckinEngine      ← 用户打卡状态（AppStore 注入）
   ├─ StreamEngine       ← TriggerEngine + GatekeeperEngine + CheckinEngine + L7 engines.json
   │      ↑  todayAdvices 是所有下游的唯一输入（维持现 syncReminderRegistry 刷新模型）
   ├─ ReminderEngine     ← StreamEngine 活跃集 + L7 reminder 配置 → [InAppSink | SystemSink]
   ├─ ProbeEngine        ← StreamEngine 活跃集 + L7 probes.json
   └─ DisplayComposer    ← L4 display_info + L5 bindings + 用户态(seniorMode)
```

---

## 4. 数据分层设计

### 4.0 层总表（对齐需求的七项数据要求）

| 层 | 名称 | 文件（assets/data/ 下） | 性质 | 来源 |
|---|---|---|---|---|
| **L0** | 原始建议数据（关系化实体表，§4.9） | `entity/`、`dimensions/` 规范化表 | 基表（只增不改） | 源归档 S（现 advice.json/detail.json 原样封存 `data-src/`，不进 APK）拆分规范化 |
| **L1** | 建议分析维度结构数据 | `dimensions/taxonomy.json`、`dimensions/life_domains.json` | 权威字典 | 现 taxonomy_tree.json；LifeDomain 枚举数据化 |
| **L2** | 建议交互样式数据 | `styles/act_styles.json` | 注册表 | catalog.dart:10-25 + interactors.dart 特化参数 |
| **L3** | 原始建议数据分维度标签 | `facets/advice_tags.json`、`facets/tag_vocabulary.json` | 派生 | 流水线按词表归类 274 个自由标签 |
| **L4** | 展示信息（归并+人性化产物） | `display/display_info.json` | 派生 | 流水线归并 L0+L1+L3+detail.h |
| **L5** | 展示信息↔交互样式关联 | `styles/display_bindings.json` | 绑定表 | interactors.dart:70-77、spotlight_interactors.dart |
| **L6** | 展示信息触发方式/触发时间 | `triggers/trigger_plans.json` | 派生 | 流水线复刻 effectiveTriggerOf 结论回写 |
| **L7** | 引擎运行配置 | `config/engines.json`、`config/gates.json`、`config/probes.json`、`config/onboarding.json`（v1.3 增补，画像引导问题与分层） | 配置 | app_store / probe_scheduler / reminder_registry 硬编码外置；onboarding 见 ONBOARDING_DESIGN.md |
| **L8** | 语义向量层（v1.1 增补，见 §11） | `semantic/doc_vectors.json` | 派生 | 流水线 `embed_docs` 步骤 |

保留不动：`assets/data/pinyin.json`（字母索引）、`assets/data/node_packages.json`（年龄节点包）、`assets/branding/`。

**通用规约**：每个文件顶层带 `"schemaVersion": 1`；catalog 加载时校验（737 条完整性、id 唯一、叶子路径合法——复用 TopicTree 校验）；L0 为唯一原始源，L3-L6 全部可由流水线从 L0+L1+L2+L7 重建，任何手工修订必须回到 L0 或流水线参数，禁止直接改派生文件。

### 4.1 源归档 S 与 L0 关系化拆分

**源归档 S**（仓库 `data-src/`，git 管理，**不进 APK**）：现 advice.json（771KB）与 detail.json（2.2MB）原样封存，只增不改——这是流水线的唯一输入与历史追溯凭据（`tools/flutter_app_extract` 的输出路径同步改到此处）。

**L0 实体层**：由流水线从 S 拆分规范化生成（schema 见 §4.9），进 APK。五域混存的宽表与 `tree_display` 冗余在实体层不复存在。

### 4.2 L1 维度结构数据

`dimensions/taxonomy.json`：现 taxonomy_tree.json 原样（6 根域、46 叶、`name/description/aliases/sub`）。

`dimensions/life_domains.json`：把 `advice.dart:444-569` 的 `LifeDomain` 枚举数据化：

```json
{
  "schemaVersion": 1,
  "list": [
    {"key": "health", "title": "健康与身心", "shortTitle": "健康", "icon": "pulse",
     "accentColor": "0xFF…", "description": "…", "chapters": ["不要早死", "紧急情况：先做什么", …]}
  ]
}
```

章节→域映射、兜底规则（`ofChapter` 默认 health）随数据外置；图标 key 指向 `core/icons.dart` 的 `AppHairlineIcons` 注册名。

### 4.3 L3 分维度标签数据

现状：`tags` 是 274 个自由字符串，被三处代码按名硬消费（`AdviceFacets.stages/frequencies` advice.dart:80-98、probe_binding 关键词链、`isEmergencyOrIncident` :193）。

`facets/tag_vocabulary.json`：受控维度词表（人工可维护，流水线据此归类）：

```json
{
  "schemaVersion": 1,
  "dimensions": [
    {"key": "stage",     "name": "人生阶段", "multi": true,  "tags": ["少年", "青年", "中年", "老年", "全民"]},
    {"key": "frequency", "name": "频率",     "multi": true,  "tags": ["每天", "每日多次", "每周", "每月", "每年", "单次", "偶发", "每次"]},
    {"key": "timing",    "name": "时机",     "multi": false, "tags": ["事前", "事中", "事后"]},
    {"key": "scene",     "name": "场景",     "multi": true,  "tags": ["在家", "在路上", "在线上", "在医院", "在职场", "不限场景"]},
    {"key": "audience",  "name": "对象",     "multi": true,  "tags": ["自身", "家人", "子女", "伴侣", "陌生人", "雇主", "医生"]},
    {"key": "money",     "name": "金钱",     "multi": false, "tags": ["不涉及钱", "要花钱", "能拿钱", "高风险钱"]},
    {"key": "function",  "name": "功能",     "multi": true,  "tags": ["打卡", "提醒", "速查", "收藏", "决策点", "日历时点", "情境触发", "突发事件", "需机构窗口", "需医生介入"]},
    {"key": "theme",     "name": "主题",     "multi": true,  "open": true},
    {"key": "reliance",  "name": "依赖",     "multi": false, "tags": ["可独立完成", "需他人协助"]},
    {"key": "validity",  "name": "时效",     "multi": false, "tags": ["长期有效", "限时有效"]}
  ]
}
```

`facets/advice_tags.json`：每条建议按维度归类后的标签视图（派生）：

```json
{"schemaVersion": 1, "list": [
  {"id": 1, "stage": ["少年", "青年", "中年", "老年", "全民"], "frequency": ["每次"],
   "timing": ["事前"], "scene": ["在路上"], "audience": ["自身"], "money": ["不涉及钱"],
   "function": ["打卡", "情境触发"], "theme": ["交通", "安全"], "reliance": ["可独立完成"],
   "validity": ["长期有效"], "keywords": ["安全带"]}
]}
```

归类失败的标签进 `theme`（open 维度）并在 validate 步骤报告，不允许静默丢弃。

### 4.4 L2 交互样式数据

`styles/act_styles.json`：13 种 act_type 注册表 + 参数 schema：

```json
{"schemaVersion": 1, "list": [
  {"style": "quick-checkin", "name": "快速打卡", "icon": "check",
   "params": {"longTitleThreshold": 14}},
  {"style": "daily-streak", "name": "每日连击", "icon": "pulse",
   "params": {"windowDays": 14,
              "alarmPresets": [
                {"match": ["起床"],      "label": "晨间闹钟", "times": ["07:00"]},
                {"match": ["午睡", "午休", "小憩"], "label": "午后小憩", "times": ["12:45"]},
                {"match": ["屏幕"], "titleAlsoMatch": ["睡"], "label": "睡前", "times": ["21:30"]},
                {"match": ["刷牙", "牙缝"], "label": "早晚", "times": ["07:30", "22:30"]},
                {"match": ["血压", "吃药"], "label": "每日晨起定点", "times": []}
              ],
              "quickOptions": ["06:30 晨光", "07:00 标准", "07:30 宽裕", "23:00 就寝"]}},
  {"style": "slider-calc", "name": "滑杆测算", "icon": "calculator",
   "variants": [
     {"match": ["酒"],       "label": "标准杯", "max": 10,  "unit": "杯",   "verdict": "…"},
     {"match": ["晒", "太阳"], "label": "时长",   "max": 60,  "unit": "分钟", "verdict": "…"},
     {"match": ["遛狗"],      "label": "时长",   "max": 120, "unit": "分钟", "verdict": "…"}
   ],
   "default": {"label": "强度档位"}},
  {"style": "windowed-cadence", "name": "窗口期节律", "icon": "tree", "params": {"windowDays": 14}}
]}
```

`match` 为关键词匹配（对齐现 interactors.dart:1233-1253、:417-434 行为），`titleAlsoMatch` 表达现"标题含屏幕且正文含睡"的组合条件。UI 交互器组件保留在 `ui/cards/interactors.dart`，只按 `style` key 分派、参数全部来自本层。

### 4.5 L4 展示信息（归并 + 人性化处理产物）

`display/display_info.json`：流水线把 L0 的 `parts`/`timing_badge`、L1 的面包屑、detail 的 `h` 归并为每条建议的**展示信息**：

```json
{"schemaVersion": 1, "list": [
  {"id": 1,
   "coreAction": "系安全带",
   "caveats": ["前排后排都系"],
   "badge": {"model": "context_aware", "text": "情境感知 · 出发即扣"},
   "breadcrumb": "日常与起居 > 交通出行 > 机动车出行",
   "humanized": "…",
   "leadSentence": "…"}
]}
```

- `coreAction` = `parts[0]`，`caveats` = `parts[1:]`（现 `AdvicePresentation.coreAction/caveats` 的运行时裁剪前移到流水线）；
- `badge.model` 是 12 种时机模型的结构化枚举（取代 catalog.dart:42-69 的"字符串 contains 前缀匹配"），`text` 为原文案；
- `breadcrumb` 由 L1 维度树重算生成，**消除 `tree_display` 冗余**（L0 仍保留原值）；
- `humanized` 取 detail.h（一句话人话版）。
- 运行时 `DisplayComposer` 只做薄合成：seniorMode 字号切换、用户自定义覆盖；不再承担裁剪/拼接逻辑。

### 4.6 L5 展示信息↔交互样式关联

`styles/display_bindings.json`：

```json
{"schemaVersion": 1, "list": [
  {"id": 1,   "style": "haptic-toggle", "override": "cabin-seats",
   "params": {"seats": ["主驾", "副驾", "后排左", "后排右"]}},
  {"id": 7,   "style": "slider-calc", "override": "blood-pressure",
   "params": {"sysRange": [90, 180], "diaRange": [50, 120],
              "thresholds": {"normalSys": 120, "normalDia": 80, "highSys": 140, "highDia": 90}}},
  {"id": 136, "style": "wage-calc", "params": {"defaultCost": 1500, "defaultHours": 20, "defaultWage": 80}}
]}
```

- 无显式绑定的建议按 `act_type` 默认关联（style == act_type）；
- `override` 指向聚光专项交互器 key（现 interactors.dart:70-77 的 ID switch 数据化）；
- 血压阈值、时薪默认值等聚光参数全部入 `params`（现 spotlight_interactors.dart 硬编码外置）。

### 4.7 L6 触发数据（触发方式 + 触发时间）

`triggers/trigger_plans.json`：流水线**复刻** `effectiveTriggerOf`（app_store:807-1025）的决策链，把结论回写为数据：

```json
{"schemaVersion": 1, "list": [
  {"id": 1,   "mode": "daily", "periods": ["morning", "evening"],
   "reminderTimes": ["08:15", "18:15"], "cron": "30 7,18 * * 1-5", "emergency": false},
  {"id": 3,   "mode": "windowed", "periods": ["morning"], "reminderTimes": ["09:00"],
   "cron": "0 9 1 10 *", "emergency": false},
  {"id": 414, "mode": "dormant", "emergency": true}
]}
```

- `mode` 四值对齐 `TriggerMode`（dormant/daily/cadence/windowed）；
- `periods` 引用 L7 `engines.json` 的标准时段 key（morning/focus/afternoon/evening/night + `custom:HH:mm-HH:mm`）；
- `reminderTimes` 是"黄金提醒时刻"词表（:938-995）的逐条结论；
- `emergency` 对齐 `isEmergencyOrIncident`；
- **运行时规则**：TriggerEngine 先查 L6，用户自定义（`CustomTriggerConfig`，卡片背面表单）叠加其上；L6 缺条目时回退到 TriggerEngine 内置保守兜底（与现 advice.dart:198-209 默认值一致）。
- **验收**：快照测试证明 737 条 L6 数据与旧 `effectiveTriggerOf` 输出逐一相等（见 §9）。

### 4.8 L7 引擎配置

`config/engines.json`（运行参数，键对齐现状值）：

```json
{
  "schemaVersion": 1,
  "reminder":  {"tickerSeconds": 10, "quietHours": {"start": "23:00", "end": "05:00"}, "snoozeMinutes": 10},
  "probe":     {"tickerMinutes": 10, "maxDailyRoutine": 3, "cooldownMinutes": 90,
                "quietHours": {"start": "23:00", "end": "05:00"},
                "routineWindows": [{"label": "上午", "start": "09:30", "end": "10:15"},
                                   {"label": "下午", "start": "14:15", "end": "15:00"},
                                   {"label": "晚间", "start": "20:00", "end": "21:00"}],
                "dailySystemNotifications": [{"id": 9101, "time": "09:30"}, {"id": 9102, "time": "14:15"}, {"id": 9103, "time": "20:00"}],
                "mandatoryBypassesQuietHours": false,
                "_note": "mandatory 穿透静默与 probe_model.dart 注释矛盾，行为保持模式取 false，裁决延后"},
  "stream":    {"windowMinutes": 45,
                "ranking": {"distanceScale": 300, "periodBoost": [
                  {"hours": [22, 5],  "match": ["屏幕", "睡"],           "boost": 60},
                  {"hours": [6, 8],   "match": ["安全带", "头盔"],        "boost": 60},
                  {"hours": [6, 8],   "match": ["早餐", "血压"],          "boost": 40},
                  {"hours": [9, 12],  "match": ["久坐", "专注", "工位", "单线程"], "boost": 60}
                ]}},
  "periods":   [{"key": "morning", "name": "清晨", "start": "05:00", "end": "09:30"},
                {"key": "focus", "name": "专注", "start": "09:30", "end": "12:00"},
                {"key": "afternoon", "name": "午后", "start": "12:00", "end": "18:00"},
                {"key": "evening", "name": "傍晚", "start": "18:00", "end": "22:00"},
                {"key": "night", "name": "夜晚", "start": "22:00", "end": "05:00"}],
  "defaults":  {"leadDays": 15, "bmiOverweight": 24.0, "stageBoundaries": [22, 35, 55],
                "ninetyDayDefaultGoals": [1, 387, 13],
                "cyclePhases": {"launch": [1, 21], "consolidate": [22, 66], "assess": [67, 90], "maintain": [91, null]}}
}
```

`config/gates.json`（门禁规则，统一 schema，引擎通用解释）：

```json
{"schemaVersion": 1, "rules": [
  {"id": "dormant-chapters",  "kind": "chapterBlacklist",  "chapters": ["紧急情况：先做什么", …13 个]},
  {"id": "dormant-actTypes",  "kind": "actTypeBlacklist",  "styles": ["redline-stamp", "decision-check", "process-steps", "context-guard", "emergency-action", "evidence-checklist"]},
  {"id": "prereq-tree",       "kind": "prerequisite"},
  {"id": "gate-chronic",      "kind": "chronicVeto",       "conditions": {"肾结石": …, "痛风": …, "高血压": …, "糖尿病": …, "残疾": …}},
  {"id": "gate-special-chapters", "kind": "chapterRules",  "rules": [{"chapter": "程序员…", "requireTags": […]}]},
  {"id": "gate-weightloss-drug", "kind": "idSet", "adviceIds": [199, 663, 665], "profile": {"healthConcerns": ["正在服用减重药物"]}},
  {"id": "gate-depression",   "kind": "idSet", "adviceIds": [568, 25, 264], "effect": "moodTriggerOnly"},
  {"id": "gate-maternity-emergency", "kind": "idSet", "adviceIds": [644, 646, 647], "profile": {"isPregnantOrParent": false}},
  {"id": "gate-infant",       "kind": "idSet", "adviceIds": [545, 686, 704], "requirePrereq": "has_children"},
  {"id": "gate-medication",   "kind": "idSet", "adviceIds": [44, 121, 757]},
  {"id": "parents-list",      "kind": "idSet", "adviceIds": [139 个], "effect": "parentsOnly"},
  {"id": "habit-evolution",   "kind": "habitEvolution", "rules": [
      {"habitId": 49, "profilePatch": {"healthConcernsRemove": ["吸烟"]}},
      {"habitId": 7,  "also": [57], "profilePatch": {"healthConcernsAdd": ["血压"]}},
      {"habitId": 61, "profilePatch": {"healthConcernsAdd": ["睡眠"]}}]}
]}
```

`config/probes.json`：探测调度与内容（现 probe_scheduler:88-543、probe_binding 全文件外置）：

```json
{"schemaVersion": 1,
 "bindings": [
   {"adviceIds": [44],  "category": "body",     "signalLevel": "mandatory", "promptQuestion": "…", "matchingOption": "…", "targetPeriods": […], "responseGuidance": "…"},
   {"match": {"tagsContain": ["睡眠"]}, "category": "sleep", "signalLevel": "routine"}
 ],
 "questions": {"morning": {"context": {"text": "…", "options": […]}, …},
               "afternoon": {…}, "evening": {…}}}
```

绑定解析顺序保持现状：显式 ID 表 → emergency 判定 → 关键词规则链 → 兜底 lifestyle。

**裁决记录**：`mandatoryBypassesQuietHours` 取 `false`（维持现状，与 probe_scheduler:153 注释一致）；`probe_model.dart:69` 的"绝不合并无视免打扰"注释在 Phase 3 修正为与配置一致，实际裁决延后另议。

### 4.9 关系化数据 Schema（v1.2 增补）：文件存储，数据库纪律

> 原则：**即使不用数据库，数据设计也必须遵守数据库设计规范**。JSON 文件只是存储介质，schema 纪律不变——现 advice.json 本质是违反 1NF 的宽表（五域混存 + 重复组 + 自由串反规范化），本节将其重构为显式的关系模型。

**十条总规约**：

1. **一个文件 = 一个关系**（实体表 / 联结表 / 字典表 / 物化视图），禁止跨实体混表；
2. **重复组出子表（1NF）**：`parts`、`sources`、`rel`、`periods`、`reminderTimes` 等不定长重复字段拆为带 `ordinal` 的子表；
3. **多对多出联结表**：自由标签归并为 `tag` 字典 + `advice_tag` 联结，消除 737 行重复字符串；
4. **枚举出字典表**：act_style / timing_model / badge / life_domain / grade / trigger_mode 全部受控域，字段存 key 不存文案；
5. **参照完整性检查**：所有跨表引用存键值（advice_id / path / tag），validate 步做孤儿与外键解析检测——现 detail.json 的 30 个 id 缺口必须显式登记为"库内无对应建议"或修复，不再静默存在；
6. **主键显式化**：每表声明 PK（单列或复合），联结表用复合主键天然去重；
7. **约束**：NOT NULL / UNIQUE / CHECK（cron 5 段、grade ∈ {A,B,C}、mode ∈ 4 枚举、HH:mm 格式）在 validate 步执行，等价 DB CHECK；
8. **数据字典**：每个关系的每个字段登记（类型 / 可空 / 域 / 含义 / 来源），落 `docs/refactor/DATA_DICTIONARY.md`（Phase 1 交付物）；
9. **派生层 = 物化视图**：L4（display_info）、L6（trigger 两表）、L8（doc_vectors）声明为定义在基表上的物化视图（文档给出视图定义 = join + 投影 + 加工规则），可由流水线全量重建；
10. **反规范化白名单**：仅允许物化视图与字典内 `aliases` 数组两类；其余违规（如 `tree_display`）一律清除。字段全名化：`c/t/h` 等历史缩写在实体层改为全名（chapter_code/title/humanized），缩写映射登记数据字典。

**E-R 图**：

```
life_domain 1─∞ chapter 1─∞ advice
advice 1──1 advice_detail 1─∞ detail_source
advice 1─∞ advice_action                       (kind: core|caveat, ordinal)
advice ∞─∞ tag            经 advice_tag        ; tag ∞─1 tag_dimension
advice 1──1 advice_style_binding ∞─1 act_style
advice 1──1 advice_trigger 1─∞ advice_trigger_time
advice ∞─∞ advice         经 advice_relation   (自联结)
advice ∞─∞ taxonomy_node  经 advice_node       (多重挂载; tree_display 冗余清除)
advice ∞──1 badge ∞──1 timing_model           (badge = "前缀 · 副题" 拆字典+外键)
node_package 1─∞ node_package_item ∞─1 advice (src 可空 = 合法 NULL)
taxonomy_node：邻接表 (path PK, parent_path 自FK, is_leaf)
```

**关系清单**（assets/data/ 下，每文件一表）：

| 表 | 类型 | 主键 | 外键 / 域约束 |
|---|---|---|---|
| `entity/advice.json` | 基表 | `id` | `chapter_code→chapter`、`badge_key→badge` |
| `entity/advice_action.json` | 子表 | `(id, ordinal)` | `kind ∈ {core, caveat}` |
| `entity/advice_detail.json` | 1:1 | `advice_id` | `grade ∈ {A,B,C}` NOT NULL |
| `entity/detail_source.json` | 子表 | `(advice_id, ordinal)` | `url` 可空 |
| `entity/advice_relation.json` | 联结 | `(from_id, to_id)` | `kind ∈ {related, merge_candidate, prerequisite_of, alternative_of, sequence_of}`、`weight 0-1`、`mergePolicy{when,maxGroup}`（v1.4，归并机制见 MERGE_DESIGN.md）、`basis ∈ {authored, semantic, rule}` |
| `entity/advice_node.json` | 联结 | `(id, path)` | `path` 必须是 taxonomy 叶 |
| `dimensions/taxonomy_node.json` | 邻接表 | `path` | `parent_path` 自 FK、`is_leaf` |
| `dimensions/life_domain.json` | 字典 | `key` | 图标 key → AppHairlineIcons 注册名 |
| `dimensions/chapter.json` | 字典 | `code` | `domain_key→life_domain` |
| `dimensions/timing_model.json` | 字典 | `key` | 12 种枚举（替代字符串前缀 contains） |
| `dimensions/badge.json` | 字典 | `text` | `model_key→timing_model`，51 条去重 |
| `facets/tag_dimension.json` | 字典 | `key` | 10 个受控维度 |
| `facets/tag.json` | 字典 | `tag` | `dimension_key→tag_dimension` |
| `facets/advice_tag.json` | 联结 | `(id, tag)` | 复合主键天然去重 |
| `styles/act_style.json` | 字典 | `style` | 13 种 + 参数 schema |
| `styles/advice_style_binding.json` | 1:1 | `id` | `style→act_style`、`override?`（聚光专项） |
| `triggers/advice_trigger.json` | 1:1 | `id` | `mode ∈ {dormant,daily,cadence,windowed}`、cron CHECK |
| `triggers/advice_trigger_time.json` | 子表 | `(id, ordinal)` | `kind ∈ {period, reminder}` |
| `views/display_info.json` | 物化视图（L4） | `id` | 视图定义 = `advice ⋈ action ⋈ breadcrumb(taxonomy) ⋈ detail` + 人性化处理（leadSentence ≤180 字等） |

**代价评估**：APK 内数据总量与现在相当（源归档出包 −3MB，规范化键名展开 +~0.3MB，净省）；加载文件数 5→约 15（每文件更小，顺序加载实测差异预计 <50ms，catalog 内存索引构建逻辑不变）；换来的收益是完整性可校验、无冗余、L4/L6/L8 可重建、以及未来若迁 drift/SQLite 可按表机械映射——数据字典即 DDL。

---

## 5. 执行引擎设计（独立设计，逐一列接口）

> 以下为拟定接口签名（Phase 3 实施时可微调参数，但职责边界不变）。约定：引擎构造时注入所需仓库/配置/状态快照；方法保持与现 AppStore 同名同语义，便于快照对比。

### 5.1 TriggerEngine 触发计算引擎

```dart
class TriggerEngine {
  TriggerEngine({required TriggerRepository triggers,        // L6 查表
                 required EngineConfig config});              // L7 periods/defaults
  /// 生效触发计划：L6 数据 + 用户自定义覆盖（现 effectiveTriggerOf :807-1025 语义）
  CustomTriggerConfig effectiveTriggerOf(Advice advice);
  void setTriggerConfig(int adviceId, CustomTriggerConfig config);   // 写后由 store 调 syncReminderRegistry
  void resetTriggerConfig(int adviceId);
  /// 当下流的精确锚点（现 _displayAnchors :1342-1348）
  List<TimeOfDay> displayAnchorsOf(Advice advice);
}
```

### 5.2 GatekeeperEngine 建议筛选门禁引擎

```dart
class GatekeeperEngine {
  GatekeeperEngine({required GateConfig gates,               // L7 gates.json
                    required FacetRepository facets});       // L3
  /// 画像门禁：0 领域 → 0.5 前置条件 → 0.6 慢病一票否决 → 0.7-0.15 专病/心理/孕产/儿童 → 1-3 标签匹配
  bool matchPersona(Advice advice, UserProfile profile);
  /// 健康节点包求值（现 evalNodeItem :2294-2314）
  bool evalNodeItem(NodePackageItem item, UserProfile profile);
  /// 紧急/突发事件判定（现 isEmergencyOrIncident 语义，读 L6 emergency 位）
  bool isEmergencyOrIncident(Advice advice);
}
```

### 5.3 StreamEngine 建议流引擎

```dart
class StreamEngine {
  StreamEngine({required Catalog catalog, required TriggerEngine trigger,
                required GatekeeperEngine gatekeeper, required CheckinEngine checkin,
                required EngineConfig config, required StreamInputs inputs});
  /// inputs = exclusions / formedHabits / excludedTopics / userTodos / profile（AppStore 注入的快照）
  List<Advice> todayAdvices(DateTime now);
  List<Advice> cycleAdvicesOf(PeriodScope scope, DateTime now);
  List<Advice> advicesForWindow(DateTime centerTime);
  List<Advice> emergencyAdvices();
}
```

### 5.4 ReminderEngine 通知推送引擎

```dart
/// 通知出口抽象：应用内弹窗与系统通知是同一引擎的两个 sink
abstract class NotificationSink {
  Future<void> showAlert(ReminderAlert alert);
  Future<void> scheduleDaily(List<DailyNotification> items);
}
class ReminderEngine extends ChangeNotifier {
  ReminderEngine({required NotificationSink sink, required EngineConfig config});
  void registerActiveReminders(List<Advice> active);   // 现 ReminderRegistry.registerActiveReminders
  ReminderAlert? get currentAlert;                     // 10s 心跳命中（秒数来自 L7）
  void completeCurrentAlert();  void snoozeCurrentAlert();  void dismissCurrentAlert();
}
```

`MobileNotificationService` 保留为 `NotificationSink` 的系统实现（flutter_local_notifications + timezone 初始化逻辑原样），应用内弹窗实现为 `InAppAlertSink`（经 shell.dart 呈现）。静默时段、去重幂等键（当日+时点+adviceId）、已完成跳过等策略从 L7 读。

### 5.5 ProbeEngine 主动探测引擎

```dart
class ProbeEngine extends ChangeNotifier {
  ProbeEngine({required NotificationSink sink, required ProbeConfig probes});
  void registerAdvices(List<Advice> active, UserProfile profile);
  void checkScheduledProbes();                         // 10min 心跳 + App resumed 触发
  void handleNotificationTap(String payload);
  void dismissCurrentPayload(); void snoozeCurrentPayload(); void dismissForToday();
}
```

题目内容、绑定规则、限频参数全部来自 `config/probes.json`；`AdviceProbeBindingEngine` 退化为数据解释器。

### 5.6 CheckinEngine 打卡状态引擎

```dart
class CheckinEngine {
  CheckinEngine({required EngineConfig config});
  CardState cardState(String adviceId, PeriodScope scope);
  int streakOf(String id);  Duration? windowAnchorOf(String id);
  void toggleDone(...);  void updateCard(...);  void checkinStreak(...);
  void ensureWindowAnchor(...);  void checkPeriodRollover(DateTime now);
  /// 状态由 AppStore 注入/委托持久化（key 不变：kScope.* / kStreak.* / kWindow.*）
}
```

### 5.7 DisplayComposer 展示合成引擎

```dart
class DisplayComposer {
  DisplayComposer({required DisplayRepository display,   // L4
                   required StyleRepository styles});    // L2 + L5
  AdviceDisplay displayOf(Advice advice, {required bool seniorMode});
  ActStyleBinding bindingOf(Advice advice);              // style + override + params
}
```

### 5.8 ProfileEngine 画像引擎（v1.3 增补，详见 ONBOARDING_DESIGN.md）

```dart
class ProfileEngine {
  ProfileEngine({required GatekeeperEngine gatekeeper, required Catalog catalog,
                 required OnboardingConfig config});   // L7 onboarding.json
  NormalizedProfile normalize(UserProfile p);          // 答案 → 画像 → normalized 标签集
  Set<int> activeAdviceIds(UserProfile p);             // 活跃集（判定复用 GatekeeperEngine，不另写门禁）
  List<QuestionYield> rankQuestions(UserProfile p, Set<int> activeSet);   // max-yield 问题排序
  OnboardingState onboardingState(UserProfile p);      // 引导状态机 + 聚焦统计
}
```

**引导即剪枝**：分层问题（约 40 题/7 层，数据化于 onboarding.json）按剪枝收益贪心排序，收益枯竭即停；**未答不剪**为安全默认（ADR-009）；软硬剪枝分级（硬=prerequisites/gates 出局，软=scene/theme 排序加权）。

### 5.9 组装规则

1. `AppStore` 持有全部引擎实例，`syncReminderRegistry()`（:602）语义保留：画像/打卡/触发变更 → 重算活跃集 → 刷新 ReminderEngine 与 ProbeEngine；
2. 引擎间只经构造注入与显式方法调用，禁止互相持有 ChangeNotifier 监听；
3. 引擎不得 import `ui/`、不得直接访问 `SharedPreferences`（经 AppStore 注入快照或回调）；
4. `restore()` 与全部持久化 key 原样保留在 `state/user_preferences.dart`。

---

## 6. 离线流水线详细设计（tool/advice_pipeline/）

```
app/tool/advice_pipeline/
├── build.dart            # 入口：dart run tool/advice_pipeline/build.dart [--check]
├── steps/
│   ├── split_raw.dart        # ① 校验源归档（737 条/12 字段）→ 封存 data-src/（只增不改）
│   ├── normalize.dart        # ② 拆分规范化：S → L0 实体/子表/联结/字典（§4.9 关系模型）
│   ├── build_facets.dart     # ③ tags 归并 → facets/tag + advice_tag（按词表归类，失败报错不丢弃）
│   ├── build_display.dart    # ④ 物化视图 L4：join 实体+维度+detail + 人性化处理
│   ├── resolve_triggers.dart # ⑤ 移植 effectiveTriggerOf 词表/时刻表 → triggers/ 两表
│   ├── extract_styles.dart   # ⑥ 代码常量提取 → styles/*, config/*（半自动：生成 + 人工校对）
│   └── validate.dart         # ⑦ 参照完整性(孤儿/外键解析) + 约束 + 计数/叶子校验；--check 与已发布版本 diff
└── snapshot/
    └── golden_*.json     # 行为快照基线（见 §9）
```

原则：
- 流水线只依赖 L0/L1/L2/L7 与词表，**幂等**：重复运行输出 byte 级一致；
- `resolve_triggers` 与 Dart 侧 `TriggerEngine` 共享同一份词表数据（词表本身也是流水线的输入文件，不放代码）；
- `--check` 模式在 CI/本地验证"数据与流水线同步"，防止手改派生文件。

---

## 7. 迁移映射表（现状 → 目标，Phase 1-4 的施工图）

### 7.1 数据外置（Phase 1-2）

| 现状位置 | 内容 | 目标 |
|---|---|---|
| assets/data/advice.json | 五合一原始记录 | 源归档 `data-src/`（出 APK）→ 规范化拆分 `entity/` + `dimensions/` + 联结/字典表（§4.9） |
| assets/data/detail.json | 证据包 | 源归档 → `entity/advice_detail.json`（1:1）+ `entity/detail_source.json`（来源子表） |
| assets/data/taxonomy_tree.json | 维度树 | L1 `dimensions/taxonomy.json` |
| advice.dart:444-569 LifeDomain 枚举 | 域/图标/色/34 章节映射 | L1 `dimensions/life_domains.json` |
| catalog.dart:10-25 actionTypes | 13 种交互形态注册表 | L2 `styles/act_styles.json` |
| catalog.dart:42-69 TimingModel | 徽章前缀→色 | L4 `badge.model` 枚举 + L1 域色板 |
| advice.dart:80-98 stages/frequencies | 标签维度常量 | L3 `tag_vocabulary.json` |
| advice.dart:599/655 leadDays=15 | 窗口提前浮出天数 | L7 engines.json defaults |
| advice.dart:685-737 PeriodDefinition | 5 标准时段 | L7 engines.json periods |
| advice.dart:838-867 CyclePhase 边界 | 90 天阶段 | L7 engines.json defaults.cyclePhases |
| interactors.dart:70-77 聚光专项 | ID→专属交互器 | L5 display_bindings.json override |
| interactors.dart:417-434 _alarmPreset | 关键词→闹钟预设 | L2 act_styles.json daily-streak.params |
| interactors.dart:536 quickOptions | 4 时刻快捷项 | L2 act_styles.json |
| interactors.dart:1233-1253 slider 特化 | 酒/晒/遛狗参数 | L2 act_styles.json slider-calc.variants |
| spotlight_interactors.dart | 血压阈值/时薪默认值/座名 | L5 display_bindings.json params |
| app_store.dart:846-995 词表+黄金时刻 | 触发推断启发式 | 流水线 resolve_triggers → L6 |
| app_store.dart:1590-1660 排序加权 | 时段关键词 boost | L7 engines.json stream.ranking |
| app_store.dart:356-496 parentsAdviceIds | 139 个 ID | L7 gates.json parents-list |
| app_store.dart:499-530 adviceIdAliases | 旧 ID 迁移表 | L0 advices.json `aliases` 字段 |
| app_store.dart:733-748 习惯→画像演进 | 3 条规则 | L7 gates.json habit-evolution |
| app_store.dart:2147-2239 门禁 ID 组 | 0.8-0.15 各门禁 | L7 gates.json idSet 规则 |
| probe_scheduler.dart:40-43 | 限频/静默参数 | L7 engines.json probe |
| probe_scheduler.dart:88-127 | 每日系统通知 ID/时刻 | L7 engines.json probe.dailySystemNotifications |
| probe_scheduler.dart:303-310 | 三探测窗口 | L7 engines.json probe.routineWindows |
| probe_scheduler.dart:334-562 | 探测题目文案/选项/关联 ID | L7 config/probes.json questions |
| probe_binding.dart 全文件 | 12 显式绑定 + 关键词链 | L7 config/probes.json bindings |
| reminder_registry.dart:60/103/149 | 心跳/静默/稍后 | L7 engines.json reminder |
| mobile_notification_service.dart:97-168 | 通道/调度模式 | L7 engines.json（sink 实现参数） |

### 7.2 引擎抽取（Phase 3，按序）

| 步骤 | 从 app_store.dart 迁出 | 目标 | 验收 |
|---|---|---|---|
| ① TriggerEngine | :801-1049（含 :1028-1049 set/reset） | domain/trigger_engine.dart | 快照：737 条 effectiveTriggerOf 逐一相等 |
| ② GatekeeperEngine | :1977-2314（matchPersona/evalNodeItem）+ :356-530 规则 | domain/gatekeeper_engine.dart | 快照：3 种子画像全库 matchPersona 逐一相等 |
| ③ CheckinEngine | :538-577、:1224-1295、:1740-1781 | domain/checkin_engine.dart | 打卡/连击/翻零单测 |
| ④ StreamEngine | :1366-1499、:1502-1730、:1281-1348 cron 解析 | domain/stream_engine.dart | 快照：today/cycle/window 三流逐一相等 |
| ⑤ ReminderEngine | reminder_registry.dart 整体 + mobile_notification_service.dart 整体 | domain/reminder_engine.dart + sinks | 提醒弹窗冒烟 |
| ⑥ ProbeEngine | probe_scheduler.dart 整体 | domain/probe_engine.dart | 探测冒烟 |
| ⑦ DisplayComposer | AdvicePresentation 派生 getter 消费点 | domain/display_composer.dart | UI 走查 |

同时删除死代码：`periodAdvicesOf` :1671-1725、`markKickoffReview` :1079、`windowAnchorOf` :1279（确认无 UI 引用后）。

### 7.3 保留在代码中的部分（明确不数据化）

- 机制层：JSON 解析、索引构建（byId/searchIndex/倒排）、搜索分词、cron 解析器、心跳循环、持久化序列化、3D 翻转动画；
- UI 组件：13 个交互器 Widget 本体、卡片翻转表单（用户自定义触发 UI）；
- 通用文案：SnackBar/按钮文案本次不外置（无 i18n 需求，DESIGN.md 规约沿用）；
- `TopicTree.fromJson` 校验逻辑（迁入 taxonomy repository）。

---

## 8. 兼容性承诺与风险

### 8.1 兼容承诺

| 项 | 承诺 |
|---|---|
| SharedPreferences | 17 个 key（kThemeMode/kProfile/kHasCompletedOnboarding/kSeniorMode/kExcludedAdviceIds/kExcludedTopicPaths/kFormedHabits/kFormedHabitDates/kCustomTriggers/kNinetyDayPlan/kCarnegieReviews/kEmergencyContacts/kUserTodos/kScope.*/kScopeEpoch.*/kStreak.*/kWindow.*）名称与 JSON 结构不变 |
| 触发/流/门禁输出 | 快照测试逐一相等（§9） |
| 通知行为 | 通道 ID、系统通知 ID 9101-9103、静默时段、冷却参数不变 |
| 旧 ID 兼容 | adviceIdAliases 迁移表保留（L0 aliases），canonicalAdviceId 语义不变 |

### 8.2 风险与对策

| 风险 | 对策 |
|---|---|
| 触发词表移植偏差 | 快照对比 737 条全量；偏差即流水线 bug，禁止改 Dart 端凑数 |
| 加载文件数 5→约 15 | 每文件更小、总字节量相当（源归档出包 −3MB）；catalog 顺序加载（现状即顺序）；必要时合并视图层交付 |
| UI 引用面广（me_view 50 处） | facade 保留原方法签名与字段名，UI 改引用可渐进，不强制一次清零 |
| 流水线与 Dart 逻辑漂移 | 词表数据单源；`--check` diff 门禁 |
| probe 题目外置后 payload 兼容 | handleNotificationTap 的 payload 前缀协议不变 |

### 8.3 明确不做（后续另立项）

AdviceSortingDesign 落地（Tier/粘滞/轮换）、SignalRoutingDesign 完整路由引擎、mandatory 穿透静默裁决、UI 文案 i18n、多 package 拆分、云同步。

---

## 9. 验证方案

1. **静态**：`cd app && flutter analyze` 维持 0 issues；
2. **行为快照**（Phase 1 建基线，Phase 2-4 每步复跑）：
   - `test/golden_test.dart`：3 个种子画像（默认画像、35 岁男开发北京[对齐 HowToLiveBetterFor35Dev]、孕产+慢病组合画像）；
   - 记录：全部 737 条 `effectiveTriggerOf` 输出、`todayAdvices`、`cycleAdvicesOf(四 scope)`、`advicesForWindow(整点抽样 24 次)`、全库 `matchPersona` 结果 → JSON 基线，逐一比对；
3. **流水线自检**：`dart run tool/advice_pipeline/build.dart --check` → 737 条校验通过、与已发布数据 diff 为空；
4. **单测**：TriggerEngine（cron/时段/自定义覆盖）、GatekeeperEngine（各门禁规则表）、CheckinEngine（跨周期翻零）、现有 3 个测试保持通过；
5. **手工冒烟**：`flutter run`（web + Android）走查五 Tab、卡片翻转触发配置表单、提醒弹窗（完成/稍后/忽略）、心情打卡干预路径（advice 568）、紧急面板、搜索、分享卡。

---

## 10. 实施阶段与验收

| 阶段 | 内容 | 验收 | 状态 |
|---|---|---|---|
| **Phase 0** | 本设计文档落库 | 文档评审通过 | ✅ 本次 |
| **Phase 1** | 流水线 + 源归档 S 封存 + L0-L6 关系化数据生成 + catalog 分层加载 + 快照基线 + 数据字典 | `--check` 通过（含参照完整性/孤儿检测）；快照与旧算法一致；DATA_DICTIONARY.md 交付；analyze 0 issues | 待确认 |
| **Phase 2** | models 五文件重组 + L7 三配置外置 + ConfigRepository | 快照一致；无行为变化 | 待确认 |
| **Phase 3** | 引擎按 §7.2 顺序抽取，AppStore 瘦身 <800 行；依赖守护脚本 tool/arch_guard.dart（ARCHITECTURE §10） | 每步快照一致；arch_guard 依赖规则 0 违例；死代码删除 | 待确认 |
| **Phase 4** | 交互样式绑定数据化收尾（聚光/slider/alarm 全走 L2/L5）+ README 架构更新 | 冒烟通过；硬编码清单（§1.3）清零 | 待确认 |
| **Phase 5** | 语义能力层（v1.1 增补）：semantic 模块 + BGE-small INT8 provider + L8 向量 + 混合检索，独立 feature flag | 混合检索冒烟；三端降级验证（含 noop 路径）；主线快照不受影响 | 待确认 |
| **Phase 6** | 画像引导重构（v1.3 增补，ONBOARDING_DESIGN.md）：ProfileEngine + onboarding.json + 引导 UI 数据驱动化 + Profile v2 增量字段 | 未答不剪性质测试通过；聚焦统计一致；老用户 kProfile 迁移无感；onboarding_view <600 行；全量快照通过 | 待确认 |
| **Phase 7** | 触发层归并（v1.4 增补，MERGE_DESIGN.md）：relation 首批入库（L8 语义候选→人工审核）+ 存量内容画像补全（如 483/484 痛风硬门禁、210 软门禁）+ MergeGroup 启用 | **快照预期变化清单**逐条确认（有意图的行为变更）；画像三态走查（健康/尿酸高/痛风）；组解散与独立打卡冒烟；--check relation-审计一致 | 待确认 |

**每阶段结束提交一次 git commit，提交信息格式 `refactor(phaseN): …`；阶段之间需项目所有者确认后再进入下一阶段。**

---

## 11. 增补设计：语义能力层（v1.1）

> 决策记录：引入 BGE-small-zh-v1.5 INT8 作为首个端侧语义检索实现；**项目代码不得直接依赖具体模型**——模型能力经抽象模块封装，可整体替换（换嵌入模型/换推理后端均不动业务层）。本节为增量设计，不改变 §1-10 的行为保持重构主线。

### 11.1 设计原则

1. **依赖倒置**：业务与引擎只依赖 `lib/semantic/` 的 Dart 抽象（Port）；BGE、ONNX、tokenizer 细节全部封闭在 `providers/bge_small_int8/` 内；
2. **模型即配置**：模型文件、词表、维度、池化方式、查询指令前缀等模型特有行为全部进 manifest 数据（挂 L7），换模型 = 换 manifest + 换 provider，业务零改动；
3. **Fail-safe 降级**：模型是增强不是依赖。任何不可用（平台不支持 / 资产校验失败 / 加载失败 / 向量版本不匹配）一律静默退回词法检索，UI 无感；
4. **通知决策不交给模型**：触发/门禁/静默维持 L6/L7 确定性规则（§5）；语义能力只以"信号贡献者"身份参与，缺席自然退化。

### 11.2 模块结构

```
app/lib/semantic/                      # 语义能力层：基础设施，不依赖 domain/ui
├── embedding_provider.dart            # ★ 项目内唯一可见抽象（Port）
├── model_manifest.dart                # ModelManifest / ModelHandle 类型
├── model_manager.dart                 # 资产生命周期：惰性加载 / sha256 校验 / 版本 / 释放
├── providers/
│   ├── noop_provider.dart             # 降级空实现（isAvailable = false）
│   └── bge_small_int8/                # 可整体替换的具体实现
│       ├── bge_provider.dart          # ONNX Runtime 推理（后台 isolate，不阻塞 UI）
│       ├── bge_tokenizer.dart         # 中文 BERT WordPiece
│       └── bge_manifest.dart          # 读取 config/models.json
├── vector_store.dart                  # L8 库向量加载 + 版本一致性校验 + 暴力余弦检索
└── index/
```

依赖方向：`domain/`（检索编排）→ `semantic/` Port；`semantic/` 不 import `domain/`、`ui/`。

### 11.3 核心接口（拟定）

```dart
abstract class EmbeddingProvider {
  String get modelId;                 // 'bge-small-zh-v1.5-int8'
  String get modelVersion;            // 权重指纹，与 L8 向量强绑定
  int get dimensions;                 // 512
  bool get isAvailable;               // 平台支持 ∧ 资产完整 ∧ 加载成功
  Future<void> ensureLoaded();        // 惰性：首次搜索才初始化，不拖慢启动
  Future<Float32List?> embed(String text);   // null = 不可用，调用方走词法兜底
  Future<List<Float32List?>> embedBatch(List<String> texts);   // 供流水线/批量
  void dispose();
}

abstract class ModelManager {
  Future<ModelHandle> resolve(ModelManifest manifest);   // 查找/校验 sha256/版本
  Future<void> warmUp();
  void release();
}
```

后端选型：**ONNX Runtime**（transformers 导出路径成熟、有现成 Flutter 插件、六端含桌面可用）；manifest 的 `backend` 字段保留 `onnx|tflite|none`，将来换 MediaPipe TFLite 不动接口。

### 11.4 模型清单（挂 L7：config/models.json）

```json
{
  "schemaVersion": 1,
  "providers": {
    "embedding": {
      "id": "bge-small-zh-v1.5-int8",
      "backend": "onnx",
      "asset": "assets/models/bge-small-zh-int8.onnx",
      "vocab": "assets/models/bge-vocab.txt",
      "sha256": "…", "sizeBytes": 24000000,
      "dimensions": 512, "maxTokens": 512,
      "pooling": "cls", "normalize": true,
      "queryPrefix": "为这个句子生成表示以用于检索相关文章：",
      "similarityFloor": 0.35
    }
  }
}
```

`queryPrefix`（BGE 查询侧指令）与 `similarityFloor`（低于阈值的向量结果丢弃，不强行凑数）属模型特有行为，必须随 manifest 走而不是写死代码。

### 11.5 新数据层 L8：语义向量

- 流水线新增 `embed_docs` 步骤（开发机执行，SentenceTransformers）：对 L4 展示信息（coreAction + caveats + humanized 拼接）计算向量 → `assets/data/semantic/doc_vectors.json`；
- 存储：737×512 **FP16 ≈ 737KB**（Q8 int8 备选 377KB），737 条规模暴力余弦即可，**不引入 ANN 索引**；
- 文件头带 `modelId` + `modelVersion` + 维度；运行时校验 `doc_vectors.modelVersion == provider.modelVersion`，不匹配即弃用向量索引、降级词法（模型-向量版本错位是换模型时最易翻车点，用数据校验兜死）；
- Tokenizer 一致性：Dart 侧 WordPiece 用 Python 侧生成的黄金样本做单测对齐，防止向量空间错位；
- 管控同 L4/L6：流水线生成、禁止手改、`--check` diff 门禁。

### 11.6 混合检索编排（domain/semantic_search_engine.dart）

- 词法通道：现有 `catalog.search`（分词 AND + 标题命中置顶 + 拼音首字母）原样保留；
- 向量通道：查询句（加 queryPrefix）embed → 与 L8 暴力余弦 → Top-K；
- 融合：RRF（`score = 1/(60+rank_lex) + 1/(60+rank_vec)`），`similarityFloor` 以下丢弃；
- 短文本专有名词/编号类查询（如"P0 触电"、建议 id）由词法兜住，口语化模糊查询由向量补——两条通道各自独立可用。

### 11.7 通知侧边界

- 触发时刻、门禁、静默时段、限频：**全部维持确定性规则**（§5，行为保持）；
- 向量的角色限定为"信号贡献者"（`SignalContributor` 接口）：候选场景 ① probe 绑定关键词链的语义兜底（probe_binding 的 match 规则缺命中时，向量相似度补位）；② 意图信号（SignalRoutingDesign D8）供路由参考；
- 信号权重可配（L7），模型不可用时信号集合自然退化，通知引擎零感知。

### 11.8 降级矩阵与体积账

| 端 | 策略 |
|---|---|
| Android / iOS / 桌面 | ONNX INT8：模型 ~24MB + runtime ~15-25MB/ABI；初始化失败 → NoopProvider |
| Web | 默认 `backend: none`（WASM 需 20MB+ 下载，不值得），词法检索 |

体积：单 ABI APK 约 22MB → **~60MB**；模型随包发布（不做首次启动下载，保纯离线定位）。性能：查询句单条 embed 中高端 5-50ms、低端 100-300ms，后台 isolate 执行；库向量 737 条暴力余弦 <1ms。

### 11.9 实施落点

- **Phase 1**：流水线预留 `--with-embeddings` 可选步骤（纯增量文件，不影响行为快照）；
- **Phase 5**（新增，见 §10 阶段表）：semantic 模块 + BGE provider + 混合检索接入，独立 feature flag，单独验收（含 noop 降级路径测试），不与 Phase 1-4 的快照测试纠缠。
