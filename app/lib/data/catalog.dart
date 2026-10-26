import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/advice.dart';

/// 交互形态中枢：与 Demo ACTION_TYPE_DEFS 同构，图标用 Material 线性图标近似。
const List<ActionTypeDef> actionTypes = [
  ActionTypeDef('all', '全部形态', Icons.apps),
  ActionTypeDef('daily-streak', '每日连击', Icons.local_fire_department_outlined),
  ActionTypeDef('windowed-cadence', '持续窗口期', Icons.date_range_outlined),
  ActionTypeDef('quick-checkin', '行动打卡', Icons.check_circle_outline),
  ActionTypeDef('slider-calc', '测算滑块', Icons.tune),
  ActionTypeDef('haptic-toggle', '触感卡扣', Icons.toggle_on_outlined),
  ActionTypeDef('emergency-action', '紧急直达', Icons.emergency_outlined),
  ActionTypeDef('zen-timer', '计时屏息', Icons.timer_outlined),
  ActionTypeDef('evidence-checklist', '证据清单', Icons.inventory_2_outlined),
  ActionTypeDef('wage-calc', '时薪决策', Icons.calculate_outlined),
  ActionTypeDef('redline-stamp', '红线铭记', Icons.gpp_maybe_outlined),
  ActionTypeDef('context-guard', '情境拦截', Icons.fact_check_outlined),
  ActionTypeDef('decision-check', '决策核对', Icons.rule_outlined),
  ActionTypeDef('process-steps', '办事分步', Icons.format_list_numbered),
];

String actionTypeName(String id) {
  for (final d in actionTypes) {
    if (d.id == id) return d.name;
  }
  return id;
}

IconData actionTypeIcon(String id) {
  for (final d in actionTypes) {
    if (d.id == id) return d.icon;
  }
  return Icons.category_outlined;
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


/// 建议目录：加载资产、建立索引、计算字母、画像匹配。
class Catalog {
  Catalog._({
    required this.adviceList,
    required this.details,
    required this.nodePackages,
    required this.pinyin,
  });

  final List<Advice> adviceList;
  final Map<int, AdviceDetail> details;
  final List<NodePackage> nodePackages;
  final PinyinMap pinyin;

  late final Map<int, Advice> byId = {
    for (final a in adviceList) a.id: a,
  };

  Advice? adviceById(int id) => byId[id];

  /// 34 章节名（按首现顺序）。
  late final List<String> chapters = [
    ...{for (final a in adviceList) a.chapter}
  ];

  /// 每章节条数。
  late final Map<String, int> chapterCounts = {
    for (final c in chapters)
      c: adviceList.where((a) => a.chapter == c).length,
  };

  /// 拼音首字母（与 Demo getAdviceLetter 同口径：parts[0] 首字 → PINYIN_MAP）。
  String letterOf(Advice a) {
    final s = a.parts.isNotEmpty ? a.parts.first : a.title;
    final trimmed = s.trim();
    final firstChar = trimmed.isEmpty ? '' : trimmed[0];
    return pinyin[firstChar] ?? '#';
  }

  /// 各字母的条数（A–Z 与 #）。
  late final Map<String, int> letterCounts = _countLetters();

  Map<String, int> _countLetters() {
    final counts = <String, int>{};
    for (final a in adviceList) {
      final l = letterOf(a);
      counts[l] = (counts[l] ?? 0) + 1;
    }
    // 字母按序，# 排最后
    final sorted = <String, int>{};
    for (final key
        in counts.keys.toList()..sort((x, y) => x == '#' ? 1 : (y == '#' ? -1 : x.compareTo(y)))) {
      sorted[key] = counts[key]!;
    }
    return sorted;
  }

  /// 每种交互形态的条数。
  late final Map<String, int> modeCounts = {
    for (final d in actionTypes.skip(1))
      d.id: adviceList.where((a) => a.actType == d.id).length,
  };

  static Future<Catalog> load() async {
    Future<Map<String, dynamic>> loadJson(String name) async {
      final raw = await rootBundle.loadString('assets/data/$name.json');
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    final adviceJson = await loadJson('advice');
    final detailJson = await loadJson('detail');
    final nodeJson = await loadJson('node_packages');
    final pinyinJson = await loadJson('pinyin');

    return Catalog._(
      adviceList: (adviceJson['list'] as List)
          .map((e) => Advice.fromJson(e as Map<String, dynamic>))
          .toList(),
      details: {
        for (final e in detailJson.entries)
          int.parse(e.key): AdviceDetail.fromJson(e.value as Map<String, dynamic>),
      },
      nodePackages: (nodeJson['list'] as List)
          .map((e) => NodePackage.fromJson(e as Map<String, dynamic>))
          .toList(),
      pinyin: {
        for (final e in pinyinJson.entries) e.key: e.value as String,
      },
    );
  }

  AdviceDetail? detailOf(int id) => details[id];

  List<Advice> byChapter(String chapter) =>
      adviceList.where((a) => a.chapter == chapter).toList();

  /// 全文搜索：标题、章节、标签、时机徽章。
  List<Advice> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return adviceList.where((a) {
      return a.title.toLowerCase().contains(q) ||
          a.chapter.toLowerCase().contains(q) ||
          a.timingBadge.toLowerCase().contains(q) ||
          a.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }
}
