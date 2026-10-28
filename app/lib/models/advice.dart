import 'package:flutter/material.dart';

// ============================================================================
// 1. 原始建议数据层 (Raw Advice Domain)
// ============================================================================

/// 原始建议事实元：包含建议原文、所属章节与全书编号。
@immutable
class RawAdvice {
  const RawAdvice({
    required this.id,
    required this.chapter,
    required this.title,
  });

  final int id;
  final String chapter;
  final String title;

  factory RawAdvice.fromJson(Map<String, dynamic> json) => RawAdvice(
    id: (json['id'] as num).toInt(),
    chapter: json['c'] as String,
    title: json['t'] as String,
  );

  Map<String, dynamic> toJson() => {'id': id, 'c': chapter, 't': title};
}

/// 原始建议详情与证据包：包含通俗解读、经济成本、收益估算、证据等级、科学文献出处。
@immutable
class AdviceDetail {
  const AdviceDetail({
    required this.humanized,
    this.cost,
    this.plain,
    this.benefit,
    required this.grade,
    this.sources = const [],
    this.notes,
    this.rel = const [],
  });

  final String humanized;
  final String? cost;
  final String? plain;
  final String? benefit;
  final String grade; // A / B / C 证据等级
  final List<List<String>> sources; // [文献名称, 链接?]
  final String? notes;
  final List<int> rel; // 关联建议 id

  factory AdviceDetail.fromJson(Map<String, dynamic> json) => AdviceDetail(
    humanized: json['h'] as String,
    cost: json['cost'] as String?,
    plain: json['plain'] as String?,
    benefit: json['benefit'] as String?,
    grade: (json['grade'] as String?) ?? 'C',
    sources: ((json['sources'] as List?) ?? const [])
        .map((s) => (s as List).cast<String>())
        .toList(),
    notes: json['notes'] as String?,
    rel: ((json['rel'] as List?) ?? const [])
        .map((n) => (n as num).toInt())
        .toList(),
  );
}

// ============================================================================
// 2. 建议属性标签数据层 (Facet & Semantic Tags Domain)
// ============================================================================

/// 建议多维属性标签元：从标题与正文中提炼的多维标签，专门用于多维搜索和画像剪枝。
@immutable
class AdviceFacets {
  const AdviceFacets({required this.tags});

  final List<String> tags;

  /// 人生阶段标签（少年/青年/中年/老年/全民）
  List<String> get stages => tags
      .where((t) => const ['少年', '青年', '中年', '老年', '全民'].contains(t))
      .toList();

  /// 频率节奏标签（每天/每周/每月/每年/单次/偶发/每次/每日多次）
  List<String> get frequencies => tags
      .where(
        (t) => const [
          '每天',
          '每周',
          '每月',
          '每年',
          '单次',
          '偶发',
          '每次',
          '每日多次',
        ].contains(t),
      )
      .toList();

  /// 是否包含某特定标签
  bool contains(String tag) => tags.contains(tag);

  /// 是否命中候选集合中的任意标签
  bool any(Iterable<String> candidates) => tags.any(candidates.contains);

  factory AdviceFacets.fromJson(Map<String, dynamic> json) =>
      AdviceFacets(tags: ((json['tags'] as List?) ?? const []).cast<String>());

  Map<String, dynamic> toJson() => {'tags': tags};
}

// ============================================================================
// 3. 建议交互与样式表现层 (Presentation & Interaction Spec Domain)
// ============================================================================

/// 建议样式表现元：时机徽章、原子动作与约束拆解、微交互器形态，用于优雅呈现并驱动习惯。
@immutable
class AdvicePresentation {
  const AdvicePresentation({
    required this.parts,
    required this.timingBadge,
    required this.actType,
  });

  /// 拆分后的「原子动作 + 附加约束」，首段是核心动作
  final List<String> parts;

  /// 时机徽章文案（时机模型 + 副题）
  final String timingBadge;

  /// 交互形态（13 种卡片微交互器）
  final String actType;

  /// 核心执行动作（parts 首段）
  String get coreAction => parts.isNotEmpty ? parts.first : '';

  /// 附加约束边界
  List<String> get caveats => parts.length > 1 ? parts.sublist(1) : const [];

  factory AdvicePresentation.fromJson(Map<String, dynamic> json) =>
      AdvicePresentation(
        parts: ((json['parts'] as List?) ?? const []).cast<String>(),
        timingBadge: json['timing_badge'] as String? ?? '日常 · 建议',
        actType: json['act_type'] as String? ?? 'quick-checkin',
      );

  Map<String, dynamic> toJson() => {
    'parts': parts,
    'timing_badge': timingBadge,
    'act_type': actType,
  };
}

/// 聚合根：整合原始数据、属性标签数据与样式表现数据，向下兼容并提供高内聚访问。
@immutable
class Advice {
  const Advice({
    required this.raw,
    required this.facets,
    required this.presentation,
    this.treePath = 'daily/lifestyle/diet',
    this.treeDisplay = '日常与起居 > 衣食养生 > 饮食营养与贮存',
    this.treePaths = const [],
    this.prerequisites = const {},
    this.cron = '* * * * *',
  });

  final RawAdvice raw;
  final AdviceFacets facets;
  final AdvicePresentation presentation;
  final String treePath;
  final String treeDisplay;
  final List<String> treePaths;

  /// Legacy records with one path continue to work; new records support cross-listing.
  List<String> get topicPaths => treePaths.isEmpty ? [treePath] : treePaths;
  final Map<String, dynamic> prerequisites;
  final String cron;

  // 向下兼容代理
  int get id => raw.id;
  String get chapter => raw.chapter;
  String get title => raw.title;
  List<String> get parts => presentation.parts;
  String get timingBadge => presentation.timingBadge;
  String get actType => presentation.actType;
  List<String> get tags => facets.tags;
  String get coreAction =>
      presentation.coreAction.isNotEmpty ? presentation.coreAction : raw.title;
  List<String> get caveats => presentation.caveats;

  /// 是否属于突发事件、急救处置、黄金救治等偶发应急建议（非日常固定时段流，如中暑、骨折、海姆立克等）
  bool get isEmergencyOrIncident {
    if (chapter == '紧急情况：先做什么') return true;
    if (actType == 'emergency-action') return true;
    if (tags.contains('急救') || tags.contains('速查')) return true;
    if (tags.contains('事中') && tags.contains('突发事件')) return true;
    if (timingBadge.contains('黄金救治') || timingBadge.contains('紧急')) return true;
    final t = title;
    if (t.contains('中暑') ||
        t.contains('海姆立克') ||
        t.contains('心肺复苏') ||
        t.contains('触电') ||
        t.contains('溺水') ||
        t.contains('毒蛇咬伤') ||
        t.contains('骨折制动') ||
        t.contains('破水') ||
        t.contains('洗胃') ||
        t.contains('催吐')) {
      return true;
    }
    return false;
  }

  factory Advice.fromJson(Map<String, dynamic> json) => Advice(
    raw: RawAdvice.fromJson(json),
    facets: AdviceFacets.fromJson(json),
    presentation: AdvicePresentation.fromJson(json),
    treePath: json['tree_path'] as String? ?? 'daily/lifestyle/diet',
    treeDisplay: json['tree_display'] as String? ?? '日常与起居 > 衣食养生 > 饮食营养与贮存',
    treePaths: List.unmodifiable(
      (json['tree_paths'] as List? ?? []).cast<String>(),
    ),
    prerequisites: (json['prerequisites'] as Map<String, dynamic>?) ?? const {},
    cron: json['cron'] as String? ?? '* * * * *',
  );
}

// ============================================================================
// 4. 用户行为与自建待办数据层 (User Behavior & Todo Domain)
// ============================================================================

/// 用户自建待办项或由建议转化的行动任务。
@immutable
class UserTodoItem {
  const UserTodoItem({
    required this.id,
    required this.title,
    this.adviceId,
    this.isDone = false,
    required this.createdAt,
    this.targetDate,
    this.note,
  });

  final String id;
  final String title;
  final int? adviceId; // 可选关联的建议编号
  final bool isDone;
  final DateTime createdAt;
  final String? targetDate; // yyyy-mm-dd
  final String? note;

  UserTodoItem copyWith({
    bool? isDone,
    String? title,
    String? targetDate,
    String? note,
  }) => UserTodoItem(
    id: id,
    title: title ?? this.title,
    adviceId: adviceId,
    isDone: isDone ?? this.isDone,
    createdAt: createdAt,
    targetDate: targetDate ?? this.targetDate,
    note: note ?? this.note,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'adviceId': adviceId,
    'isDone': isDone,
    'createdAt': createdAt.toIso8601String(),
    'targetDate': targetDate,
    'note': note,
  };

  factory UserTodoItem.fromJson(Map<String, dynamic> json) => UserTodoItem(
    id: json['id'] as String,
    title: json['title'] as String,
    adviceId: json['adviceId'] as int?,
    isDone: json['isDone'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    targetDate: json['targetDate'] as String?,
    note: json['note'] as String?,
  );
}

// ============================================================================
// 节点包与交互形态定义
// ============================================================================

@immutable
class NodePackageItem {
  const NodePackageItem({
    this.src,
    required this.label,
    required this.freq,
    this.female = false,
    this.bone = false,
    this.soft,
  });

  final int? src;
  final String label;
  final String freq;
  final bool female;
  final bool bone;
  final String? soft;

  factory NodePackageItem.fromJson(Map<String, dynamic> json) =>
      NodePackageItem(
        src: (json['src'] as num?)?.toInt(),
        label: json['label'] as String,
        freq: json['freq'] as String,
        female: json['female'] as bool? ?? false,
        bone: json['bone'] as bool? ?? false,
        soft: json['soft'] as String?,
      );
}

@immutable
class NodePackage {
  const NodePackage({
    required this.no,
    required this.title,
    required this.trigger,
    required this.headline,
    required this.items,
  });

  final String no;
  final String title;
  final int trigger;
  final String headline;
  final List<NodePackageItem> items;

  factory NodePackage.fromJson(Map<String, dynamic> json) => NodePackage(
    no: json['no'] as String,
    title: json['title'] as String,
    trigger: (json['trigger'] as num).toInt(),
    headline: json['headline'] as String,
    items: ((json['items'] as List?) ?? const [])
        .map((e) => NodePackageItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

@immutable
class ActionTypeDef {
  const ActionTypeDef(this.id, this.name, this.icon);
  final String id;
  final String name;
  final IconData icon;
}

typedef PinyinMap = Map<String, String>;

// ============================================================================
// 5. 建议全景六大人生领域 (Life Domain Pillars) - 100% 覆盖全库 767 条建议
// ============================================================================

enum LifeDomain {
  health(
    id: 'health',
    title: '身体健康与防病长寿',
    shortTitle: '健康防线',
    icon: Icons.health_and_safety_outlined,
    accentColor: Color(0xFF10B981),
    totalCount: 180,
    description: '涵盖防癌早筛、慢病康复、科学用药、就医防坑、运动与减压',
    chapters: [
      '不要早死',
      '不要慢慢死',
      '家里的常备药别吃出事',
      '得了慢性病之后怎么活',
      '看病：怎么少花钱少走弯路',
      '残疾之后怎么活',
      '别为了外形把身体搞坏',
      '怎么放松：娱乐场所和减压',
    ],
  ),
  career(
    id: 'career',
    title: '职场合规与事业长青',
    shortTitle: '职场事业',
    icon: Icons.business_center_outlined,
    accentColor: Color(0xFF3B82F6),
    totalCount: 128,
    description: '涵盖在职维权、工伤离职、技术人红线、创业合伙、技能投资',
    chapters: [
      '在职、离职和工伤',
      '程序员和技术人容易踩的红线',
      '创业与做生意：别把家底赔进去',
      '做一个网站或平台：资质、备案和服务器',
      '学什么技能划算',
      '十八岁之后有哪几条路',
    ],
  ),
  family(
    id: 'family',
    title: '家庭守护与亲密关系',
    shortTitle: '家庭守护',
    icon: Icons.family_restroom_outlined,
    accentColor: Color(0xFF8B5CF6),
    totalCount: 113,
    description: '涵盖伴侣婚前法务、孕产育儿、子女学业、父母照护、身后事公证',
    chapters: [
      '恋爱和结婚划不划算',
      '怀孕和生产：从发现怀孕到出院办证',
      '刚出生的孩子怎么带',
      '养孩子划不划算',
      '上学以后的孩子',
      '家里有老人',
      '人走了以后要办什么',
    ],
  ),
  finance(
    id: 'finance',
    title: '财产安全与避坑底线',
    shortTitle: '财产法律',
    icon: Icons.shield_outlined,
    accentColor: Color(0xFFF59E0B),
    totalCount: 202,
    description: '涵盖法律红线、防诈反骗、房产租售、反面清单、金钱节省与债务隔离',
    chapters: [
      '别把自己搭进去：法律与财产安全',
      '普通人容易踩的法律红线',
      '反面清单',
      '不要浪费钱',
      '没钱的时候怎么活',
      '租房与买房',
    ],
  ),
  emergency(
    id: 'emergency',
    title: '应急自救与危机防御',
    shortTitle: '应急自救',
    icon: Icons.emergency_outlined,
    accentColor: Color(0xFFF43F5E),
    totalCount: 99,
    description: '涵盖突发意外先做什么、重大打击心理自救、境外安全与数字账号防线',
    chapters: [
      '紧急情况：先做什么',
      '遭遇重大打击之后',
      '出国、旅行与境外安全',
      '出国留学：身份、打工、保险和回国认证',
      '账号与信息安全',
    ],
  ),
  cadence(
    id: 'cadence',
    title: '日常节律与生活效能',
    shortTitle: '日常节律',
    icon: Icons.today_outlined,
    accentColor: Color(0xFF06B6D4),
    totalCount: 45,
    description: '涵盖每日微习惯打卡、时间精力管理、昼夜节律与专注复盘',
    chapters: ['不要浪费时间', '不要浪费精力'],
  );

  const LifeDomain({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.icon,
    required this.accentColor,
    required this.totalCount,
    required this.description,
    required this.chapters,
  });

  final String id;
  final String title;
  final String shortTitle;
  final IconData icon;
  final Color accentColor;
  final int totalCount;
  final String description;
  final List<String> chapters;

  static LifeDomain ofChapter(String chapter) {
    for (final domain in values) {
      if (domain.chapters.contains(chapter)) return domain;
    }
    return health;
  }
}

// ============================================================================
// 6. 建议触发方式与周期配置模型 (Trigger Mode & Custom Cadence Config)
// ============================================================================

/// 建议触发模式
enum TriggerMode {
  /// 静默储备态：无明确触发日期/偶发情境，绝不进入 Now/今天/每周/每月，仅在全景库中随用随查
  dormant,

  /// 日常节律态：明确进入“今天”与“当下 Now”指定时段
  daily,

  /// 周期循环态：明确进入“周期”页面（每周/每月/每年）
  cadence,

  /// 到期窗口期：到期日前设定天数开始浮出
  windowed,
}

/// 用户自定义触发与周期配置
@immutable
class CustomTriggerConfig {
  const CustomTriggerConfig({
    required this.mode,
    this.dailyPeriods =
        const [], // 'morning', 'focus', 'afternoon', 'evening', 'night'
    this.cadenceScopeKey = 'weekly', // 'weekly', 'monthly', 'yearly'
    this.targetDate, // yyyy-mm-dd
    this.leadDays = 15,
    this.weekday = 1, // 1~7
    this.monthDay = 1, // 1~31
    this.reminderTimes = const [], // 提醒时间列表，如 ['07:30', '12:30']
  });

  final TriggerMode mode;
  final List<String> dailyPeriods;
  final String cadenceScopeKey;
  final String? targetDate;
  final int leadDays;
  final int weekday;
  final int monthDay;
  final List<String> reminderTimes;

  CustomTriggerConfig copyWith({
    TriggerMode? mode,
    List<String>? dailyPeriods,
    String? cadenceScopeKey,
    String? targetDate,
    int? leadDays,
    int? weekday,
    int? monthDay,
    List<String>? reminderTimes,
  }) => CustomTriggerConfig(
    mode: mode ?? this.mode,
    dailyPeriods: dailyPeriods ?? this.dailyPeriods,
    cadenceScopeKey: cadenceScopeKey ?? this.cadenceScopeKey,
    targetDate: targetDate ?? this.targetDate,
    leadDays: leadDays ?? this.leadDays,
    weekday: weekday ?? this.weekday,
    monthDay: monthDay ?? this.monthDay,
    reminderTimes: reminderTimes ?? this.reminderTimes,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'dailyPeriods': dailyPeriods,
    'cadenceScopeKey': cadenceScopeKey,
    'targetDate': targetDate,
    'leadDays': leadDays,
    'weekday': weekday,
    'monthDay': monthDay,
    'reminderTimes': reminderTimes,
  };

  factory CustomTriggerConfig.fromJson(Map<String, dynamic> json) =>
      CustomTriggerConfig(
        mode: TriggerMode.values.firstWhere(
          (m) => m.name == json['mode'],
          orElse: () => TriggerMode.dormant,
        ),
        dailyPeriods:
            (json['dailyPeriods'] as List?)?.cast<String>() ?? const [],
        cadenceScopeKey: json['cadenceScopeKey'] as String? ?? 'weekly',
        targetDate: json['targetDate'] as String?,
        leadDays: json['leadDays'] as int? ?? 15,
        weekday: json['weekday'] as int? ?? 1,
        monthDay: json['monthDay'] as int? ?? 1,
        reminderTimes:
            (json['reminderTimes'] as List?)?.cast<String>() ?? const [],
      );
}

/// 浮出时段规范定义：包含具体时间段范围与交叠判定算法
class PeriodDefinition {
  const PeriodDefinition({
    required this.key,
    required this.name,
    required this.startMinute,
    required this.endMinute,
    required this.timeRangeLabel,
  });

  final String key;
  final String name;
  final int startMinute; // 0 ~ 1440
  final int endMinute; // 0 ~ 1440
  final String timeRangeLabel; // 如 "05:00-09:30"

  String get fullLabel => '$name $timeRangeLabel';

  static const morning = PeriodDefinition(
    key: 'morning',
    name: '早晨',
    startMinute: 300, // 05:00
    endMinute: 570, // 09:30
    timeRangeLabel: '05:00-09:30',
  );

  static const focus = PeriodDefinition(
    key: 'focus',
    name: '上午',
    startMinute: 570, // 09:30
    endMinute: 720, // 12:00
    timeRangeLabel: '09:30-12:00',
  );

  static const afternoon = PeriodDefinition(
    key: 'afternoon',
    name: '午后',
    startMinute: 720, // 12:00
    endMinute: 1080, // 18:00
    timeRangeLabel: '12:00-18:00',
  );

  static const evening = PeriodDefinition(
    key: 'evening',
    name: '傍晚',
    startMinute: 1080, // 18:00
    endMinute: 1320, // 22:00
    timeRangeLabel: '18:00-22:00',
  );

  static const night = PeriodDefinition(
    key: 'night',
    name: '夜深',
    startMinute: 1320, // 22:00
    endMinute: 300, // 05:00（跨午夜）
    timeRangeLabel: '22:00-05:00',
  );

  static const standardPeriods = [morning, focus, afternoon, evening, night];

  static PeriodDefinition? byKey(String key) {
    for (final p in standardPeriods) {
      if (p.key == key) return p;
    }
    return null;
  }

  /// 检查给定区间 [windowStart, windowEnd] 是否与本时段发生交叠
  bool overlaps(int windowStart, int windowEnd) {
    return timeRangesOverlap(startMinute, endMinute, windowStart, windowEnd);
  }

  /// 通用时间段交叠判定（支持跨午夜，如 22:00-05:00）
  static bool timeRangesOverlap(int aStart, int aEnd, int bStart, int bEnd) {
    final aIntervals = _splitInterval(aStart, aEnd);
    final bIntervals = _splitInterval(bStart, bEnd);
    for (final a in aIntervals) {
      for (final b in bIntervals) {
        if (a.$1 < b.$2 && b.$1 < a.$2) return true;
      }
    }
    return false;
  }

  static List<(int, int)> _splitInterval(int start, int end) {
    if (start <= end) {
      return [(start, end)];
    } else {
      // 跨越午夜
      return [(start, 1440), (0, end)];
    }
  }

  /// 解析自定义时段字符串，例如 'custom:08:00-10:00'
  static (int, int, String)? parseCustomPeriod(String str) {
    if (!str.startsWith('custom:')) return null;
    final parts = str.substring(7).split('-');
    if (parts.length != 2) return null;
    final sParts = parts[0].split(':');
    final eParts = parts[1].split(':');
    if (sParts.length != 2 || eParts.length != 2) return null;
    final sh = int.tryParse(sParts[0]);
    final sm = int.tryParse(sParts[1]);
    final eh = int.tryParse(eParts[0]);
    final em = int.tryParse(eParts[1]);
    if (sh == null || sm == null || eh == null || em == null) return null;
    final startMin = sh * 60 + sm;
    final endMin = eh * 60 + em;
    final label = '${parts[0]}-${parts[1]}';
    return (startMin, endMin, label);
  }

  static String formatPeriodTag(String periodKey) {
    final def = byKey(periodKey);
    if (def != null) return '${def.name} (${def.timeRangeLabel})';
    final custom = parseCustomPeriod(periodKey);
    if (custom != null) return '自定义 (${custom.$3})';
    return periodKey;
  }
}

// ============================================================================
// 7. 90 天周期培养体系与卡内基复盘模型 (90-Day Plan & Carnegie Review)
// ============================================================================

/// 90 天培养周期阶段
enum CyclePhase {
  /// 启动期（第 1–21 天）：只练最小动作，第 7/14/21 天轻复盘
  kickoff('启动期', '建立肌肉记忆 · 只练最小动作', 1, 21),

  /// 巩固期（第 22–66 天）：情景模拟与红线间隔复习
  consolidate('巩固期', '强化防线 · 红线复习与模拟', 22, 66),

  /// 评估期（第 67–90 天）：压力测试与报告生成
  evaluate('评估期', '减少提醒 · 压力测试与评估', 67, 90),

  /// 维护期（第 90 天之后）：常态化自律
  maintenance('维护期', '常态自检与年度筛查', 91, 9999);

  const CyclePhase(this.label, this.desc, this.startDay, this.endDay);
  final String label;
  final String desc;
  final int startDay;
  final int endDay;

  static CyclePhase ofDay(int day) {
    if (day <= 21) return kickoff;
    if (day <= 66) return consolidate;
    if (day <= 90) return evaluate;
    return maintenance;
  }
}

/// 90 天周期计划
@immutable
class NinetyDayPlan {
  const NinetyDayPlan({
    required this.startDate,
    required this.goalAdviceIds, // [安全底线ID, 财务防线ID, 健康/关系ID]
    this.kickoffReviewDay7 = false,
    this.kickoffReviewDay14 = false,
    this.kickoffReviewDay21 = false,
    this.isCompleted = false,
  });

  final DateTime startDate;
  final List<int> goalAdviceIds;
  final bool kickoffReviewDay7;
  final bool kickoffReviewDay14;
  final bool kickoffReviewDay21;
  final bool isCompleted;

  int get currentDay {
    final diff = DateTime.now().difference(startDate).inDays + 1;
    return diff < 1 ? 1 : diff;
  }

  CyclePhase get phase => CyclePhase.ofDay(currentDay);

  NinetyDayPlan copyWith({
    DateTime? startDate,
    List<int>? goalAdviceIds,
    bool? kickoffReviewDay7,
    bool? kickoffReviewDay14,
    bool? kickoffReviewDay21,
    bool? isCompleted,
  }) => NinetyDayPlan(
    startDate: startDate ?? this.startDate,
    goalAdviceIds: goalAdviceIds ?? this.goalAdviceIds,
    kickoffReviewDay7: kickoffReviewDay7 ?? this.kickoffReviewDay7,
    kickoffReviewDay14: kickoffReviewDay14 ?? this.kickoffReviewDay14,
    kickoffReviewDay21: kickoffReviewDay21 ?? this.kickoffReviewDay21,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'goalAdviceIds': goalAdviceIds,
    'kickoffReviewDay7': kickoffReviewDay7,
    'kickoffReviewDay14': kickoffReviewDay14,
    'kickoffReviewDay21': kickoffReviewDay21,
    'isCompleted': isCompleted,
  };

  factory NinetyDayPlan.fromJson(Map<String, dynamic> json) => NinetyDayPlan(
    startDate:
        DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
    goalAdviceIds:
        (json['goalAdviceIds'] as List?)?.cast<int>() ?? const [1, 387, 13],
    kickoffReviewDay7: json['kickoffReviewDay7'] as bool? ?? false,
    kickoffReviewDay14: json['kickoffReviewDay14'] as bool? ?? false,
    kickoffReviewDay21: json['kickoffReviewDay21'] as bool? ?? false,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}

/// 卡内基式 4 步周复盘条目
@immutable
class CarnegieReviewItem {
  const CarnegieReviewItem({
    required this.id,
    required this.createdAt,
    required this.eventFact,
    required this.myAction,
    required this.theirReaction,
    required this.nextOneSentence,
    this.tag = '职场沟通',
  });

  final String id;
  final DateTime createdAt;
  final String eventFact;
  final String myAction;
  final String theirReaction;
  final String nextOneSentence;
  final String tag;

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'eventFact': eventFact,
    'myAction': myAction,
    'theirReaction': theirReaction,
    'nextOneSentence': nextOneSentence,
    'tag': tag,
  };

  factory CarnegieReviewItem.fromJson(Map<String, dynamic> json) =>
      CarnegieReviewItem(
        id: json['id'] as String,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        eventFact: json['eventFact'] as String? ?? '',
        myAction: json['myAction'] as String? ?? '',
        theirReaction: json['theirReaction'] as String? ?? '',
        nextOneSentence: json['nextOneSentence'] as String? ?? '',
        tag: json['tag'] as String? ?? '日常自检',
      );
}

/// 紧急联系人
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.phone,
    required this.relation,
  });

  final String name;
  final String phone;
  final String relation;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'relation': relation,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
      );
}
