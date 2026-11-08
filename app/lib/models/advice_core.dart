// 建议核心域：原始事实元 + 证据包 + 聚合根（自 models/advice.dart 分域拆出，类名不变）。
import 'package:flutter/material.dart';

import 'facets.dart';
import 'advice_classification.dart';
import 'presentation.dart';

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
    this.classification,
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
  final AdviceClassification? classification;

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

  /// 当前事件的处置建议。章节、标题中的风险词和展示文案不构成事件分类。
  bool get isEmergencyOrIncident {
    return tags.contains('突发事件') &&
        (tags.contains('事中') || tags.contains('事后'));
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

typedef PinyinMap = Map<String, String>;
