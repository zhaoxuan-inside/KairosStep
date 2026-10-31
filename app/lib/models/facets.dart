// 标签域：建议多维属性标签视图（自 models/advice.dart 分域拆出，类名不变）。
import 'package:flutter/material.dart';

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
