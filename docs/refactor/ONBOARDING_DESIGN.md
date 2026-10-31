# 用户画像引导与剪枝设计（Onboarding v2）

> 版本：v1.0（2026-10-31）
> 定位：画像引导子系统专项设计，从属于 [ARCHITECTURE.md](ARCHITECTURE.md)（目标架构）与 [REFACTOR_DESIGN.md](REFACTOR_DESIGN.md) v1.2（数据分层）；实施排期为 Phase 6（依赖 Phase 1-3 产物）。
> 现状问题：`ui/onboarding/onboarding_view.dart` 2098 行、问题集粗粒度、画像维度与 737 条建议的匹配维度脱节，剪枝只发生在引导结束后的 `matchPersona` 一次性判定，"问什么、为什么问、问了能省什么"无数据支撑。

---

## 1. 设计目标与核心思想

**核心思想：引导即剪枝（Onboarding as Pruning）。**

1. **维度分层**：引导的分层结构与 L3 标签维度、L0 prerequisites、L7 门禁规则**同一套词汇**——问的每个问题都能落到一个数据维度上，答案直接参与剪枝计算；
2. **尽可能细致**：问题清单覆盖全部 14 个画像前置键 + 全部画像相关标签维度（阶段/对象/场景/主题/金钱/依赖/角色/健康），约 40 题、7 个分层；支持日常使用中渐进补全，不要求一次答完；
3. **剪枝提高效率**：两层效率——①引导本身的效率：问题按"剪枝收益"动态排序，收益枯竭即停，不浪费用户时间；②使用期的效率：画像越完整，今日流/当下流/库的无关建议越少，提醒越准；
4. **未答不剪（安全默认）**：任何问题跳过 = 该维度全部分支保留。宁可冗余，不可漏推——这是健康类应用的底线，与 docs 设计中"硬条件过滤/软条件保留"一脉相承（ADR-009）。

## 2. 三套词汇的对齐（维度映射表）

引导的每个问题必须声明它服务于哪个数据维度、剪枝作用在哪张表：

| 标签维度（L3 tag_dimension） | 引导层 | 画像字段（Profile v2） | 剪枝作用点 | 类型 |
|---|---|---|---|---|
| stage 阶段 | L0 基本盘 | birth_year → age → stage 推导（22/35/55 分界） | tags.stage 交集 + `min_age` prereq + 节点年龄包 | 硬 |
| audience 对象 | L1 家庭与责任 | has_partner / has_children + childStages[] / has_aging_parents / has_pets / pregnancy | prerequisites 14 键 + tags.audience 交集 | 硬 |
| money 金钱 | L2 居住与资产 | living_type / has_mortgage / has_piped_gas / has_car / has_twowheeler | prerequisites + tags.money + gates（高风险钱） | 硬 |
| （健康域，gates 专用） | L3 健康基线 | healthConcerns[] / is_smoker / height+weight→BMI / medications[] | gates 0.6 慢病一票否决、0.8-0.15 用药/专病门禁 | 硬 |
| （角色域，gates 专用） | L4 职业与角色 | work_status / roles[] / is_entrepreneur / travel_abroad / shift_work | gates 0.7 特殊章节门禁 + tags 角色匹配 | 硬 |
| scene 场景 | L5 生活场景（渐进） | commute_mode / cooking_freq / living_alone / screen_hours / sleep_window | tags.scene 匹配（软） + 当下流排序加权 | 软 |
| theme 主题 | L6 关注域 | focusDomains 六域权重 + 主题多选 | **不剪枝**，只影响排序/默认展开/库的初始视野 | 软 |
| reliance 依赖 | L5 追问 | can_delegate | tags.reliance（软） | 软 |
| frequency / timing / function / validity | —— 建议固有属性，非用户特征 | —— | 由 L6 触发层管辖，**不进画像引导** | —— |

> 设计含义：frequency/timing 等维度的问题**禁止**出现在画像引导里（它们由触发引擎按节律处理），这是"维度分层"的边界纪律。

## 3. 剪枝机制：三类作用 + 一个安全阀

| 类型 | 语义 | 作用点 | 例 |
|---|---|---|---|
| **硬剪枝** | 答案使建议确定出局/入选 | prerequisites、gates idSet/profile 条件 | 未育 → 婴幼儿门禁 545/686/704 出局；吸烟者 → 戒烟线保留 |
| **软剪枝** | 答案降低排序权重或折叠，不出局 | StreamEngine 排序权重、库的分组视野 | 不通勤 → 通勤类不消失，当下流不再加权 |
| **聚焦展示** | 引导期的实时反馈（正向措辞"为你聚焦 N 条"，禁用"排除/淘汰"恐吓语） | UI 层统计 | 737 → 512 → 445 |
| **安全阀** | 跳过 = 不剪；"我的"页一键回全量模式（现 prunedOnly 开关语义保留） | ProfileEngine | 任何问题可 skip |

## 4. ProfileEngine（新增第九引擎，domain/profile_engine.dart）

```dart
class ProfileEngine {
  ProfileEngine({required GatekeeperEngine gatekeeper, required Catalog catalog,
                 required OnboardingConfig config});          // L7 onboarding.json
  /// 归一：答案 → 画像字段 → normalized 标签集（现 UserProfile.normalized 语义迁移至此）
  NormalizedProfile normalize(UserProfile p);
  /// 剪枝核心：当前画像下的活跃建议集（判定复用 GatekeeperEngine.matchPersona，本引擎不做判定）
  Set<int> activeAdviceIds(UserProfile p);
  /// 问题排序：对每个未答问题 q，按选项逐一评估存活数，返回收益排序
  List<QuestionYield> rankQuestions(UserProfile p, Set<int> activeSet);
  /// 引导状态机：当前层、已答集、推荐下一题、聚焦统计、完成判定
  OnboardingState onboardingState(UserProfile p);
}
```

**问题排序算法（max-yield 贪心）**：

```
对每个未答候选问题 q（其维度未答且依赖已满足）：
  对每个选项 o：s(o) = |{a ∈ activeSet : compatible(a, o)}|    // compatible = 剪枝作用点求值
  yield(q) = |activeSet| − min_o s(o)                          // 最坏情况收益，保证下界
  （可选）expected = |activeSet| − Σ p(o)·s(o)，p(o) 来自 onboarding.json 先验表
排序取 yield 最大者出题；required 标记的问题（性别/年龄/慢病等安全相关）不参与竞争，固定在前。
终止条件：max yield < minMarginalYield（默认 3 条）或已答题数达 maxQuestions（默认 24）→ 硬性问题答完即可结束，剩余转为"可选细化"。
```

**依赖的索引**（全部来自重构后数据层，无需新算）：`L0 advice.prerequisites`、`L3 advice_tag（stage/audience/scene/theme/money/relation 维度）`、`L7 gates.json`。兼容性函数 `compatible(a, o)` 即 GatekeeperEngine 判定谓词的选项局部求值。

## 5. 引导分层与问题清单（config/onboarding.json，L7 新增）

问题与分层数据化（同"模型即配置"原则），UI 只做数据驱动渲染——现 2098 行 onboarding_view 收敛为渲染器 + 进度反馈。

```json
{"schemaVersion": 1,
 "pruning": {"strategy": "max_yield", "minMarginalYield": 3, "maxQuestions": 24},
 "layers": [
   {"key": "baseline",  "title": "基本盘",     "required": true,  "questions": ["gender", "birth_year", "height_weight"]},
   {"key": "family",    "title": "家庭与责任", "required": false, "questions": ["partner", "children", "aging_parents", "cohabit", "pets", "pregnancy"]},
   {"key": "asset",     "title": "居住与资产", "required": false, "questions": ["living_type", "piped_gas", "vehicle", "twowheeler"]},
   {"key": "health",    "title": "健康基线",   "required": true,  "questions": ["smoking", "chronic", "medications", "exercise_freq"]},
   {"key": "career",    "title": "职业与角色", "required": false, "questions": ["work_status", "roles", "travel_abroad", "shift_work"]},
   {"key": "scene",     "title": "生活场景",   "progressive": true, "questions": ["commute_mode", "cooking_freq", "living_alone", "screen_hours", "sleep_window"]},
   {"key": "interest",  "title": "关注域",     "progressive": true, "questions": ["focus_domains", "themes"]}
 ],
 "questions": [
   {"id": "gender", "dimension": "stage", "kind": "single_choice", "required": true,
    "prompt": "你的性别", "options": [
      {"value": "female", "label": "女", "profilePatch": {"gender": "女"}},
      {"value": "male",   "label": "男", "profilePatch": {"gender": "男"}}]},
   {"id": "children", "dimension": "audience", "kind": "multi_choice", "skipAllowed": true,
    "prompt": "你需要照看的孩子年龄段（可多选/无）", "options": [
      {"value": "none",      "label": "没有孩子", "profilePatch": {"hasChildren": false}},
      {"value": "infant",    "label": "婴幼儿(0-3)", "profilePatch": {"hasChildren": true, "childStages+": ["infant"]}},
      {"value": "preschool", "label": "学龄前(3-6)", "profilePatch": {"hasChildren": true, "childStages+": ["preschool"]}},
      {"value": "school",    "label": "中小学(6-18)", "profilePatch": {"hasChildren": true, "childStages+": ["school"]}},
      {"value": "adult",     "label": "已成年", "profilePatch": {"hasChildren": true, "childStages+": ["adult"]}}]},
   {"id": "chronic", "dimension": "health", "kind": "multi_choice", "required": true,
    "prompt": "长期健康状况（用于过滤不适用的建议，可多选/无）", "options": [
      {"value": "hypertension", "label": "高血压", "profilePatch": {"healthConcerns+": ["高血压"]}},
      {"value": "diabetes",     "label": "糖尿病", "profilePatch": {"healthConcerns+": ["糖尿病"]}},
      {"value": "gout",         "label": "痛风",   "profilePatch": {"healthConcerns+": ["痛风"]}},
      {"value": "high_uric_acid", "label": "尿酸偏高（未确诊痛风）", "profilePatch": {"healthConcerns+": ["尿酸高"]}},
      {"value": "high_lipid",   "label": "高血脂", "profilePatch": {"healthConcerns+": ["高血脂"]}},
      {"value": "fatty_liver",  "label": "脂肪肝", "profilePatch": {"healthConcerns+": ["脂肪肝"]}},
      {"value": "kidney_stone", "label": "肾结石", "profilePatch": {"healthConcerns+": ["肾结石"]}},
      {"value": "depression",   "label": "抑郁/焦虑史", "profilePatch": {"healthConcerns+": ["抑郁"]},
       "note": "相关干预只会在心情打卡时出现，日常不打扰"}]}
 ]
}
```

> v1.1 注（触发层归并联动，见 MERGE_DESIGN.md §5）：慢病选项即 **profileVocabulary 受控词表**，与 gates.json 规则、advice_relation 归并同源，validate 步三处互检。痛风与尿酸高必须分开勾选——两者画像行为不同：483/484（痛风用药/饮食）属痛风硬门禁，210（尿酸高反面清单）按尿酸高软门禁；蕴含规则 `痛风 → 尿酸高` 由 gates.json 声明，痛风患者无需重复勾选即可被 210 覆盖。

**问题清单盘点（约 40 题）**：L0 三题（性别/出生年/身高体重）；L1 六题（伴侣/子女年龄段/父母照护/同住/宠物/孕产）；L2 四题（居住类型/管道燃气/汽车/两轮车）；L3 四题（吸烟/慢病多选/长期用药/运动频率）；L4 四题（就业状态/职业多选/出境/轮班）；L5 五题渐进（通勤/下厨/独居/屏幕时长/睡眠窗口）；L6 两组软性问题（六域权重/主题多选）。全部问题支持跳过；required 仅 5 题（性别、出生年、身高体重、慢病、吸烟）。

## 6. Profile v2 数据结构（kProfile JSON 增量演进）

17 个 key 冻结承诺（ADR-007）不破坏：key 名与顶层结构不变，**新增可选字段**，`fromJson` 缺省 = 未答 = 不剪枝——老用户升级零感。

```json
{"gender": "男", "age": 28, "roles": [...], "healthConcerns": [...],
 "新增": {
   "childStages": ["school"],
   "hasPartner": true, "hasPets": "dog",
   "livingType": "own_mortgage", "commuteMode": ["transit", "twowheeler"],
   "cookingFreq": "often", "livingAlone": false, "workStatus": "employed",
   "medications": [], "sleepWindow": "23:30-07:00",
   "questionnaire": {"version": 2, "answeredAt": "2026-10-31", "skipped": ["themes"]}
 }}
```

字段全登记进 DATA_DICTIONARY.md；新字段与 gates.json 规则的引用关系由 validate 步做参照检查（规则引用的 profile 键必须存在于 schema）。

## 7. 交互流程（分层卡片式）

1. **引导态**：维度分层导航（L0→L6）→ 每题一卡（单选/多选/滑杆/跳过）→ 顶部实时聚焦条"已为你聚焦 445/737 条"（正向措辞，无恐吓）→ required 答完 + 收益枯竭即出完成页；
2. **完成态**：画像摘要卡（每个维度可点击回改）+ 聚焦结果预览（今日流 + 库）；不强制答完软性问题；
3. **渐进补全**：我的 → 画像 → 各维度"细化"入口（带该维度可聚焦的剩余条数提示，如"补充通勤方式，可为当下流精准排序 63 条建议"）——把"细致"延伸到日常使用而不止首次引导；
4. **回退**：一键"全量模式"（prunedOnly=false）与按维度清除重答。

## 8. 与引擎/数据的衔接

- **GatekeeperEngine**（Phase 3）：判定谓词唯一来源，ProfileEngine 复用其 matchPersona/evalNodeItem，不另写一套判定——避免两套门禁漂移；
- **StreamEngine**：消费 `activeAdviceIds` + 软剪枝权重（scene/interest 只影响排序）；
- **ReminderEngine/ProbeEngine**：活跃集更精准 → 提醒与探测的信噪比直接受益（这是"剪枝提高效率"的最终兑现处）；
- **数据层**：onboarding.json 挂 L7（validate 步校验问题引用的维度键/画像字段/gates 规则 id 均存在）；剪枝索引来自 L0/L3/L7，无新数据文件；
- **快照兼容**：已答字段下 matchPersona 输出不变（Phase 6 快照复用 Phase 3 基线 + 新增"未答字段=全保留"性质测试）。

## 9. 验收标准（Phase 6）

1. 问题数 ≤24 且动态截断生效（收益枯竭提前结束）；required 5 题不可跳过，其余可跳；
2. **未答不剪**性质测试：任意字段置空 → 该维度相关建议全部保留；
3. 聚焦统计正确：每答一题的 "N/737" 与 ProfileEngine.activeAdviceIds 一致；
4. 老用户迁移无感：旧 kProfile 恢复后直接可用，无字段丢失；
5. 引导全程可跳过可回退；恐吓性措辞 0（行为负面清单检查）；
6. onboarding_view 瘦身：问题渲染数据驱动，UI 文件目标 <600 行；
7. flutter analyze 0 issues + 全量快照通过。

## 10. ADR-009（追加至 ARCHITECTURE §9）

**引导即剪枝；未答不剪（安全默认）；问题与分层数据化（L7 onboarding.json）。** 否决项：引导期一次性弹全量问卷、把剪枝逻辑写在 UI 里、画像字段与标签维度各说各话。
