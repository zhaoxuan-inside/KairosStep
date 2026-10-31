// 展示域：样式表现元 + 交互形态注册类型 + 时机模型 + 六大人生领域
import 'package:flutter/material.dart';

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


@immutable
class ActionTypeDef {
  const ActionTypeDef(this.id, this.name, this.icon);
  final String id;
  final String name;
  final IconData icon;
}

/// 时机徽章前缀（模型名）→ 风险色语义，用于卡片徽章着色。
enum TimingModel {
  situational('情境感知', Color(0xFF3B82F6)),
  continuous('持续事件', Color(0xFFF59E0B)),
  redline('红线知识', Color(0xFFF43F5E)),
  daily('每日节律', Color(0xFF10B981)),
  process('办事流程', Color(0xFF6366F1)),
  decision('决策规则', Color(0xFF6366F1)),
  contextGuard('情境拦截', Color(0xFFF43F5E)),
  emergency('P0 紧急', Color(0xFFF43F5E)),
  search('搜索秒开', Color(0xFF3B82F6)),
  periodic('周期节律', Color(0xFF10B981)),
  slider('时长感知', Color(0xFF3B82F6)),
  finance('理财决策', Color(0xFF10B981));

  const TimingModel(this.label, this.color);
  final String label;
  final Color color;

  static TimingModel of(String badge) {
    final prefix = badge.split(' · ').first.trim();
    for (final m in values) {
      if (prefix.contains(m.label) || m.label.contains(prefix)) return m;
    }
    // 每日 XX / 每周 / 每月 / N年周期 一律归节律
    if (prefix.startsWith('每日') || prefix.contains('周期')) return periodic;
    return search;
  }
}

// ============================================================================
// 5. 建议全景六大人生领域 (Life Domain Pillars) - 100% 覆盖全库 737 条建议
// ============================================================================

enum LifeDomain {
  health(
    id: 'health',
    title: '身体健康与防病长寿',
    shortTitle: '健康防线',
    icon: Icons.health_and_safety_outlined,
    accentColor: Color(0xFF10B981),
    totalCount: 170,
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
    totalCount: 123,
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
    totalCount: 197,
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
    totalCount: 35,
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
