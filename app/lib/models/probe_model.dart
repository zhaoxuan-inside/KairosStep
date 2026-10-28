import 'package:flutter/foundation.dart';

import 'advice.dart';

/// 探查归并核心类别
enum ProbeCategory {
  /// 当前活动情境（正在干什么：上班办公 / 课堂学习 / 健身运动 / 居家休息 / 外出通勤）
  activity,

  /// 身体状况与微症状（反酸烧心、止痛药需求、低血糖心慌、眼部酸胀、久坐僵硬等）
  body,

  /// 心情与心理韧性关怀（压力紧绷、情绪低落消沉、人际冲突摩擦、孤独需倾听）
  mood,

  /// 体重与体形管理（减重意向、运动量化盲区、减肥药/司美格鲁肽门禁）
  weight,

  /// 睡眠作息与精力（失眠、早醒、熬夜后修复、褪黑素使用注意）
  sleep,

  /// 突发高危与生命安全底线（胸痛心梗、海姆立克、严重外伤中毒，必须立即通知）
  urgent,

  /// 常规习惯生活防御（饮食卫生、居家防火防盗、契约理财）
  lifestyle,
}

extension ProbeCategoryExt on ProbeCategory {
  String get label {
    switch (this) {
      case ProbeCategory.activity:
        return '活动情境';
      case ProbeCategory.body:
        return '身体体征';
      case ProbeCategory.mood:
        return '心理关照';
      case ProbeCategory.weight:
        return '体形体重';
      case ProbeCategory.sleep:
        return '睡眠精力';
      case ProbeCategory.urgent:
        return '紧急安全';
      case ProbeCategory.lifestyle:
        return '生活习惯';
    }
  }

  String get iconEmoji {
    switch (this) {
      case ProbeCategory.activity:
        return '📍';
      case ProbeCategory.body:
        return '🩺';
      case ProbeCategory.mood:
        return '🌿';
      case ProbeCategory.weight:
        return '⚖️';
      case ProbeCategory.sleep:
        return '🌙';
      case ProbeCategory.urgent:
        return '🚨';
      case ProbeCategory.lifestyle:
        return '🛡️';
    }
  }
}

/// 探查信号紧迫等级
enum ProbeSignalLevel {
  /// 必须的信号：突发严重健康风险、紧急求生自救。立即通知，绝不合并，无视免打扰
  mandatory,

  /// 非必须常规信号：日常状态与情境探查。遵循合并通知规则，并受频次与免打扰严格控制
  routine,
}

/// 建议的主动探查方式规范定义
@immutable
class AdviceProbeSpec {
  const AdviceProbeSpec({
    required this.category,
    this.signalLevel = ProbeSignalLevel.routine,
    required this.promptQuestion,
    required this.matchingOption,
    this.targetPeriods = const ['morning', 'focus', 'afternoon', 'evening'],
    this.responseGuidance = '',
  });

  /// 归并所属的主分类
  final ProbeCategory category;

  /// 信号等级：立即通知 vs 合并限频通知
  final ProbeSignalLevel signalLevel;

  /// 探查时呈现给用户的问候或问题
  final String promptQuestion;

  /// 当用户选择此项时的触发键名（例如：'反酸烧心', '健身运动', '心情低落'）
  final String matchingOption;

  /// 适合探查的时段
  final List<String> targetPeriods;

  /// 命中后对用户的针对性解答或指引要点
  final String responseGuidance;
}

/// 探查题目中的单个选项
@immutable
class ProbeOption {
  const ProbeOption({
    required this.key,
    required this.label,
    required this.emoji,
    this.description,
    this.associatedAdviceIds = const [],
  });

  final String key;
  final String label;
  final String emoji;
  final String? description;
  final List<int> associatedAdviceIds;
}

/// 探查交互题目
@immutable
class ProbeQuestion {
  const ProbeQuestion({
    required this.id,
    required this.category,
    required this.title,
    this.subtitle,
    required this.options,
  });

  final String id;
  final ProbeCategory category;
  final String title;
  final String? subtitle;
  final List<ProbeOption> options;
}

/// 发送给 UI 的主动探查通知数据包（支持单题或合并多题）
@immutable
class ProbePayload {
  const ProbePayload({
    required this.id,
    required this.signalLevel,
    required this.categories,
    required this.title,
    required this.description,
    required this.questions,
    required this.boundAdvices,
    required this.createdAt,
    this.isMerged = false,
  });

  final String id;
  final ProbeSignalLevel signalLevel;
  final List<ProbeCategory> categories;
  final String title;
  final String description;
  final List<ProbeQuestion> questions;
  final List<Advice> boundAdvices;
  final DateTime createdAt;
  final bool isMerged;

  bool get isMandatory => signalLevel == ProbeSignalLevel.mandatory;
}
