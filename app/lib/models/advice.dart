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
  const AdviceFacets({
    required this.tags,
  });

  final List<String> tags;

  /// 人生阶段标签（少年/青年/中年/老年/全民）
  List<String> get stages => tags
      .where((t) => const ['少年', '青年', '中年', '老年', '全民'].contains(t))
      .toList();

  /// 频率节奏标签（每天/每周/每月/每年/单次/偶发/每次/每日多次）
  List<String> get frequencies => tags
      .where((t) => const [
            '每天',
            '每周',
            '每月',
            '每年',
            '单次',
            '偶发',
            '每次',
            '每日多次'
          ].contains(t))
      .toList();

  /// 是否包含某特定标签
  bool contains(String tag) => tags.contains(tag);

  /// 是否命中候选集合中的任意标签
  bool any(Iterable<String> candidates) => tags.any(candidates.contains);

  factory AdviceFacets.fromJson(Map<String, dynamic> json) => AdviceFacets(
        tags: ((json['tags'] as List?) ?? const []).cast<String>(),
      );

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
  });

  final RawAdvice raw;
  final AdviceFacets facets;
  final AdvicePresentation presentation;

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

  factory Advice.fromJson(Map<String, dynamic> json) => Advice(
        raw: RawAdvice.fromJson(json),
        facets: AdviceFacets.fromJson(json),
        presentation: AdvicePresentation.fromJson(json),
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
  }) =>
      UserTodoItem(
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
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
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

  factory NodePackageItem.fromJson(Map<String, dynamic> json) => NodePackageItem(
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
    chapters: [
      '不要浪费时间',
      '不要浪费精力',
    ],
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
