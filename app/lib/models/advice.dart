import 'package:flutter/widgets.dart';

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
