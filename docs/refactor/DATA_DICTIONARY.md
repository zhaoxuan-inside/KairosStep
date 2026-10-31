# KairosStep 数据字典（Data Dictionary）

> 版本：v1.0（2026-10-31，随 Phase 1 交付）
> 对应 Schema：REFACTOR_DESIGN §4.9（关系化数据 Schema）；生成器：`app/tool/advice_pipeline/`
> 铁律：`data-src/` 源归档只增不改；`assets/data/` 派生文件一律由流水线生成（`dart run tool/advice_pipeline/build.dart`），禁止手改；`--check` 验证幂等。

## 0. 库级事实（v1.0.17 数据实测）

| 事实 | 值 |
|---|---|
| 建议总数 | 737（id ∈ 1..767，30 个 id 为库内缺口，如 104） |
| 明细总数 | 737（与建议一一对应） |
| 维度树叶 | 52（6 域；REFACTOR_DESIGN 早期口径"46 叶"以实测为准） |
| 时机徽章 | 51 种 → 12 个 TimingModel |
| 标签 | 274 种 / 12871 行；受控维度 72 种，theme 开放维度 202 种 |
| 关联行 | 32（kind=related；含 1 条已登记缺口 103→104） |
| 原子动作 | 1673 行 |
| 触发计划分布 | dormant 630 / cadence 67 / daily 40 |
| 面包屑 | 737 条重算与源 tree_display 全等（tree_display 冗余自此消除） |

## 1. 源归档 S（app/data-src/，git 管理，不进 APK）

| 文件 | 内容 |
|---|---|
| `advice.json` | 737 条五合一原始记录（12 字段：id/c/t/parts/timing_badge/act_type/tags/tree_path/tree_display/prerequisites/cron/tree_paths） |
| `detail.json` | 字符串化 id → 证据包（h/cost/plain/benefit/grade/sources/notes/rel） |
| `taxonomy_tree.json` | 嵌套维度树（6 域 52 叶，节点 {name, description?, aliases?, sub?}） |

## 2. L0 实体层（assets/data/entity/）

### entity/advice.json — 建议基表
| 字段 | 类型 | 空 | 域/说明 |
|---|---|---|---|
| id | int | 否 | PK，全库唯一 |
| chapterCode | string | 否 | FK → 34 章节（Phase 2 数据化为 chapter 字典） |
| title | string | 否 | 建议正文（原 `t`） |
| badgeKey | string | 否 | FK → dimensions/badge.json（原 timing_badge 全文） |
| style | string | 否 | 13 种交互形态枚举（原 act_type）；Phase 4 的 display_bindings 在其上叠加参数 |
| prerequisites | map | 否 | 画像前置键（见 §2.1）；空 map = 无前置 |
| cron | string | 否 | 五段 cron；`* * * * *` = 静默储备 |

### entity/advice_action.json — 原子动作子表（1NF 拆 parts）
| 字段 | 类型 | 域 |
|---|---|---|
| id | int | FK → advice.id |
| ordinal | int | 0..n，保序 |
| kind | string | `core`（ordinal=0，核心动作）\| `caveat`（约束） |
| text | string | 动作/约束文本 |

### entity/advice_detail.json — 证据包（1:1）
| 字段 | 类型 | 空 | 域 |
|---|---|---|---|
| adviceId | int | 否 | PK/FK → advice.id |
| humanized | string | 否 | 一句话人话版（原 h） |
| cost / plain / benefit / notes | string | 是 | 仅非空时落盘 |
| grade | string | 否 | `A`(473) / `B`(212) / `C`(52) |

### entity/detail_source.json — 文献来源子表
| 字段 | 类型 | 域 |
|---|---|---|
| adviceId | int | FK |
| ordinal | int | 保序（原 sources 数组序） |
| name | string | 文献名（原 sources[i][0]） |
| url | string? | 链接（原 sources[i][1]，缺失则单元素） |

### entity/advice_relation.json — 建议关联联结表
| 字段 | 类型 | 域 |
|---|---|---|
| fromId | int | FK（原 detail.rel 属主） |
| toId | int | FK；孤儿允许但必须 `status: known_gap`（已登记：103→104） |
| kind | string | Phase 1 仅 `related`；预留 `merge_candidate / prerequisite_of / alternative_of / sequence_of`（MERGE_DESIGN.md） |
| ordinal | int | 保序（UI chip 渲染顺序） |
| weight / mergePolicy / basis | — | Phase 7 归并启用时新增（schema 预留） |

### entity/advice_node.json — 维度挂载联结表（多重挂载）
| 字段 | 类型 | 域 |
|---|---|---|
| id | int | FK |
| ordinal | int | 0 = 主挂载（原 tree_path）；全量 = 原 tree_paths（760 行 / 737 条，22 条多挂载） |
| path | string | FK → taxonomy 叶路径（validate 强制叶子） |

## 3. L1 维度层（assets/data/dimensions/）

### dimensions/taxonomy.json
源归档字节级拷贝（嵌套树）。首层为域键（health/daily/relationships/career/finance/safety），深层节点挂在上级 `sub` 键下；叶子含 `aliases`（搜索扩展）。

### dimensions/badge.json — 时机徽章字典
| 字段 | 域 |
|---|---|
| text | PK，51 种徽章全文（原 timing_badge） |
| modelKey | 12 枚举：situational/continuous/redline/daily/process/decision/contextGuard/emergency/search/periodic/slider/finance（复刻 TimingModel.of 前缀匹配，顺序敏感） |

## 4. L3 分维度标签层（assets/data/facets/）

### facets/tag_dimension.json — 维度字典
`{key, name, multi}`：stage/frequency/timing/scene/audience/money/function/reliance/validity/role/gender + theme(open)。
> role 维度与 app_store.matchPersona 的 17 个 specificRoleTags 及 probe/normalized() 消费标签同源；gender（女性/男性）对应女性专属门禁。

### facets/tag.json — 标签字典
`{tag, dimensionKey}`：274 种，每标签必属一个维度；未受控者归 theme（open）并在流水线报告列名。

### facets/advice_tag.json — 保序联结表
`{id, ordinal, tag}`：12871 行；按 (id, ordinal) 还原出与源数据 byte 级一致的 tags 列表（运行时依赖该顺序：搜索索引 join、stages/frequencies 过滤）。维度归类是附加视图，不改变存储顺序。

## 5. L4 展示信息（assets/data/views/display_info.json，物化视图）

视图定义：`advice ⋈ advice_action ⋈ breadcrumb(taxonomy) ⋈ advice_detail`
| 字段 | 说明 |
|---|---|
| id | PK |
| coreAction | parts[0]（kind=core） |
| caveats | parts[1:] |
| badgeModel / badgeText | 结构化时机模型 + 徽章全文（取代字符串前缀 contains 的运行时匹配） |
| breadcrumb | 由 taxonomy 重算（737 条与源 tree_display 全等） |
| humanized | detail.h |
| leadSentence | 由 detail.plain 首句截取（逐字对齐 advice_detail_sheet._lead：[。！？] ≤180 字符） |

## 6. L6 触发层（assets/data/triggers/advice_trigger.json）

视图定义：流水线复刻 `effectiveTriggerOf`（app_store:807-1025）的默认推断；等价性由 `test/trigger_plan_equivalence_test.dart` 逐条证明。
| 字段 | 说明 |
|---|---|
| id | PK/FK |
| mode | `dormant`(630) / `daily`(40) / `cadence`(67) / `windowed`(0，Phase 1 无默认窗口) |
| dailyPeriods | mode=daily 时的浮出时段（morning/focus/afternoon/evening/night） |
| cadenceScopeKey | mode=cadence 时的周期键（weekly/monthly/yearly） |
| reminderTimes | 黄金提醒时刻（HH:mm） |
| emergency | isEmergencyOrIncident（突发事件 ∧ (事中∨事后)） |

> §4.9 Schema 精化记录：cron/prerequisites/style 为作者原始 1:1 字段，留在 advice 基表；advice_trigger 仅承载派生计划（mode/periods/times）——Phase 3 TriggerEngine 接管前，运行时仍走旧算法，本表只读不改行为。

## 7. 保留资产（未分层，原样）

`assets/data/node_packages.json`（5 个年龄节点包，items[].src → advice.id，可为 null）、`assets/data/pinyin.json`（首字 → A-Z/#）。

## 8. 用户运行时数据（未分层，结构冻结，ADR-007）

SharedPreferences 17 key：kThemeMode / kProfile / kHasCompletedOnboarding / kSeniorMode / kExcludedAdviceIds / kExcludedTopicPaths / kFormedHabits / kFormedHabitDates / kCustomTriggers / kNinetyDayPlan / kCarnegieReviews / kEmergencyContacts / kUserTodos / kScope.{today,weekly,monthly,yearly} / kScopeEpoch.{scope} / kStreak.{id} / kWindow.{id}。

## 9. 校验矩阵（validate 步执行，等价 DB 约束）

| 约束 | 实现 |
|---|---|
| PK 唯一 | advice.id / advice_detail.adviceId / badge.text / tag.tag |
| FK 完整 | detail↔advice 双向、relation.toId、node.path∈叶子、badge 覆盖、tag 覆盖 |
| CHECK | grade∈ABC、cron 五段、prerequisites 键∈14 且类型正确、mode∈4、reminderTimes HH:mm |
| 计数 | advice=737、detail=737、node ≥1/条 |
| 一致性 | breadcrumb 重算 == tree_display（737）、tags 保序还原、L6==运行时（测试） |
| 幂等 | `--check`：磁盘 == 重算（byte 级） |
