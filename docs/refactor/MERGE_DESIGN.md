# 触发层归并设计（Trigger-level Merge）

> 版本：v1.0（2026-10-31）
> 定位：建议归并机制专项设计，从属于 [ARCHITECTURE.md](ARCHITECTURE.md) 与 [REFACTOR_DESIGN.md](REFACTOR_DESIGN.md)；实施排期 Phase 7。样本依据：advice.json 实测 id 210/483/484（尿酸高/痛风三联）。

---

## 1. 问题诊断（基于真实数据）

**归并应该发生在哪一层？裁决：数据层=原子；触发层=归并；相关性=独立关联数据。**

实测三条记录：

| id | 内容 | 章节 | tags | prerequisites |
|---|---|---|---|---|
| 210 | 不要因为体检查出尿酸高、但从没痛过，就开始吃降尿酸药 | 反面清单 | 全民/通用 | **{}** |
| 483 | 确诊痛风后…长期吃降尿酸药，压到 360 µmol/L 以下 | 得了慢性病之后怎么活 | 慢性病/全民 | **{}** |
| 484 | 得过痛风的，吃烧烤聚餐别大量吃肉和海鲜，酒少喝 | 得了慢性病之后怎么活 | 慢性病/全民 | **{}** |

四个缺陷：

1. **画像不可区分**：483/484 是痛风患者专属，但 prerequisites 空、无门禁规则——健康人同样会看到"长期吃降尿酸药"；210 面向尿酸高人群，却全民可见；
2. **无相关性数据**：三条之间的强关联（同一医学主题）只存在于内容语义里，`advice_relation`/`detail.rel` 均无记录——归并无从谈起；
3. **无触发层归并机制**：即使两条同时命中同一提醒时刻，也各自独立弹卡/弹通知，没有"合并展示"通道；
4. **语义强度误配**：483 把"痛风石/骨缺损/年发 2 次以上"多个医学条件压进一条标题，条件子句与动作混写（内容工程问题，Phase 7 一并处理）。

**结论**：数据层已经是原子的（此点做对了，保持）；缺的是**画像区分（门禁）→ 相关性关联数据 → 触发层归并**三段机制。

## 2. 归并分层模型（ADR-010）

```
数据层   advice 原子记录：一条建议 = 一个可独立判定/触发/打卡/完成/排除的行动单元
          ↕（禁止：把相关主题写死进一条记录、或写死进展示代码）
关联层   advice_relation：相关性是独立的关联数据（kind/weight/mergePolicy），
          不是字段冗余、不是 UI 硬编码、更不是"碰巧相邻"
触发层   归并发生地：同一触发时机（锚点/时段/窗口）同时命中 + 双方过门禁
          + 存在 merge_candidate 关系 → 生成 MergeGroup 合并展示
画像层   每条原子建议自带门禁；画像不满足的建议根本不进入归并候选
```

三条铁律：

1. **合并是展示态，不是数据态**：MergeGroup 永远可以在运行时按成员独立解散（排除/完成/门禁变化）；
2. **不满足门禁的成员不参与归并**：痛风组里永远不会出现健康人的内容；
3. **打卡/排除独立**：组内成员各有自己的 CardState；完成 A 不代表完成 B；排除 B 只解散组不消灭 A。

## 3. 关联数据 Schema（扩展 REFACTOR_DESIGN §4.9 的 advice_relation 联结表）

```
entity/advice_relation.json    联结表    PK (from_id, to_id)    [from_id < to_id 规范化存储，双向语义]
  kind        ∈ {related, merge_candidate, prerequisite_of, alternative_of, sequence_of}
  weight      FLOAT 0-1       相关强度（用于组内排序与候选阈值）
  mergePolicy 可空，仅 merge_candidate 使用：
    when      ∈ {same_anchor, same_period, same_window, always}    归并时机条件
    maxGroup  INT      组最大成员数（默认 3，防"合并成大杂烩"）
  basis       ∈ {authored, semantic, rule}                         来源：人工编写 / 语义相似度候选 / 规则推导
```

- `related`：详情页互链（替代现 detail.rel，21 条存量迁入）；
- `merge_candidate`：触发层归并的**唯一准入凭证**；
- `prerequisite_of / alternative_of / sequence_of`：为 SignalRouting 演进位预留（先后/互斥/步骤关系）。

## 4. MergeGroup 运行时机制

**归属**：StreamEngine 输出侧的 grouping pass（不设独立引擎，归并是流的派生视图）：

```
输入：活跃集 A（已过 GatekeeperEngine + TriggerEngine 门禁的建议）
对 (a,b) ∈ A×A 且 advice_relation(from,to).kind = merge_candidate：
  时机满足：mergePolicy.when 判定 ——
    same_anchor：displayAnchorsOf(a) ∩ displayAnchorsOf(b) ≠ ∅（同一提醒时刻）
    same_period：effectiveTriggerOf(a).periods ∩ b 的 ≠ ∅（同浮出时段）
    same_window：同进当下 ±45min 视窗；always：无条件
  → MergeGroup{ leader（weight×门禁强度最高者）, members[], relation 证据 }
输出：List<AdviceOrGroup>（UI/下游只见有序的"条目或组"）
```

**展示语义**（DisplayComposer）：
- 组渲染为一张组合卡：leader 为主交互器，members 折叠为"相关防线"分节（各带独立打卡位）；
- 通知合并：ReminderEngine 同一 ticker 命中多条且互为 merge_candidate → 单条系统通知/应用内弹窗（标题"N 项防线提醒"，点开为组卡）；
- **解散规则**：任一成员被排除/门禁失效 → 组即时解散为独立条目；成员全部完成 → 组标记完成。

**限流协同**：组在今日流计 1 个"卡片位"但 N 条活跃建议（计数器语义不变，进度环按成员算）——防止归并反而挤掉其他建议。

## 5. 画像区分：慢病词表与蕴含规则（痛风/尿酸高实例）

**gates.json 扩展**（L7）：

```json
{"schemaVersion": 1,
 "profileVocabulary": {
   "healthConcerns": ["高血压", "糖尿病", "痛风", "尿酸高", "高血脂", "脂肪肝",
                      "肾结石", "骨质疏松", "胃肠疾病", "抑郁", "残疾"],
   "implications": [
     {"if": "痛风", "then": ["尿酸高"]}          // 痛风蕴含尿酸高关注，210 对痛风患者也活跃
   ]},
 "rules": [
   {"id": "gate-gout-medication", "kind": "idSet", "adviceIds": [483, 484],
    "requireConcerns": ["痛风"], "effect": "blockUnlessConcern"},
   {"id": "gate-uric-acid", "kind": "idSet", "adviceIds": [210],
    "requireConcernsAny": ["尿酸高", "痛风"], "effect": "softRank"}     // 软门禁：不满足则降权不出局
 ]}
```

- `requireConcerns`（硬）：不满足 → 出局。483/484 由此只属于痛风患者；
- `requireConcernsAny`（软）：不满足 → 降权/折叠。210 对无痛风无尿酸高者退居"更多"；
- **蕴含规则**解决"痛风者该不该看尿酸高内容"：痛风 → 尿酸高，一条 rule 声明，两处（210 的软门禁、合并候选）同时受益；
- onboarding.json 慢病多选选项同步扩展（尿酸高/高血脂/脂肪肝…），options 的 profilePatch 直接写入受控词表——**画像词汇、门禁规则、引导选项三处同源**，validate 步互检。

**实例走查**：

| 画像 | 210 尿酸高 | 483 用药 | 484 饮食 | 归并结果 |
|---|---|---|---|---|
| 健康人 | 软降权（不可见→"更多"） | **门禁拦** | **门禁拦** | 无 |
| 尿酸高、无痛风 | 活跃 | 门禁拦 | 门禁拦 | 单条，无组（组≥2 才成组） |
| 痛风患者（蕴含尿酸高） | 活跃 | 活跃 | 活跃 | 三条同时段命中 → MergeGroup「痛风管理」：leader 484 饮食卡，members 483 用药 + 210 反面清单 |

## 6. 相关性从哪来：离线语义候选 + 人工审核

1. 流水线 `embed_docs`（L8）产出全库向量 → 相似度 Top-K；
2. 候选过滤：`cosine ≥ 0.72` 且共享同一 tag_dimension.theme 叶（如"痛风"）→ `merge_candidate` 候选集（basis: semantic）；
3. 产出审计文件 `tool/advice_pipeline/audit/merge_candidates.json`（每对：双方标题/相似度/主题/建议操作）→ **人工确认后**写入 advice_relation（basis 改 authored）——相关性的最终责任在内容编辑，语义模型只提名；
4. `--check` 门禁：relation 表与审计文件 diff，未审核候选不得入包。

210↔483↔484 三对即首批人工确认样本（语义上"降尿酸药""痛风饮食""尿酸高认知"高度相关）。

## 7. 阶段与行为兼容

| 项 | 安排 |
|---|---|
| Phase 1-4 | relation 表建立（kind 枚举就位，merge_candidate 集=空）、MergeGroup 代码通道就绪 —— **行为零变化**，快照不变 |
| Phase 6 | profileVocabulary 受控词表 + implications + onboarding 慢病选项扩展（随画像引导一并交付） |
| **Phase 7（新增）** | ①存量内容画像补全（483/484 加硬门禁、210 软门禁等，全库清理"全民/慢性病标签但实为画像专属"的条目）②merge_candidate 首批入库 ③归并启用 ④**快照预期变化清单**（本阶段是有设计意图的行为变更：哪些画像下哪些条目新增/消失，逐条列出供所有者确认） |
| 验收 | 画像三态走查表（健康/尿酸高/痛风）逐格断言；组解散/独立打卡/通知合并冒烟；`--check` relation-审计一致性；快照差异清单 100% 覆盖且经确认 |

## 8. ADR-010（追加至 ARCHITECTURE §9）

**数据原子化、归并只发生在触发/展示层、相关性是独立关联数据（advice_relation）、画像区分先于归并（门禁不满足不进组）。** 否决项：内容层写死合并（多主题塞一条）、UI 硬编码关联、无关联数据的"碰巧合并"、跳过画像直接归并。

---

## 附：快照预期变化清单（Phase 7 执行前分析，2026-11-01）

**结论：483/484 的痛风硬门禁已由现行 0.6 慢病门禁生效**（标题含"痛风"→ 非痛风者一票否决，
已被 profile_engine_test 痛风三态测试证明），无需新增门禁；210（反面清单）保持全民可见
（其语义是"用药决策提醒"，对未检出者无害且具有科普价值），仅按 MERGE_DESIGN §5 记
软排序口径，不产生快照差异。

| 项 | 预期快照影响 |
|---|---|
| 483/484 痛风门禁 | **零变化**（现行 0.6 门禁已生效，测试佐证） |
| 210 软排序 | **零变化**（仅文档口径，未实现降权——避免无谓行为变更） |
| relation merge_candidate 入库 | **零行为变化**（消费方仅取 kind=related；merg e_candidate 为展示层新数据） |
| MergeGroup 展示组 | **新增能力不改存量输出**（todayAdvices 等流保持平铺；分组经新 API adviceGroups 暴露，UI 接线后续单独验收） |
