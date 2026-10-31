// 行为快照基线（重构守护）：
// 目的：在数据层/引擎拆分的各个阶段，保证 737 条建议的触发、流、门禁输出逐一不变。
// 用法：
//   GOLDEN_UPDATE=1 flutter test test/golden_test.dart   // 重建基线（test/golden/*.json）
//   flutter test test/golden_test.dart                    // 与基线比对，任何差异即失败
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/state/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _goldenDir = 'test/golden';

/// 三个种子画像：默认画像 / 35 岁男开发 / 慢病组合（痛风+高血压+老人+房贷）。
const _seedProfiles = <String, UserProfile>{
  'default': UserProfile(),
  'dev35': UserProfile(
    gender: '男',
    age: 35,
    roles: ['全民', '上班族', '程序员'],
    livingConditions: ['租房人'],
    healthConcerns: ['久坐伏案'],
    isProgrammer: true,
    isTenant: true,
    hasPipedGas: true,
    relationshipStatus: 'married',
  ),
  'chronic': UserProfile(
    gender: '女',
    age: 52,
    roles: ['全民', '家人'],
    livingConditions: <String>[],
    healthConcerns: <String>[],
    hasGout: true,
    hasHypertension: true,
    hasAgingParents: true,
    hasMortgage: true,
    hasPets: true,
    hasPipedGas: true,
    isTenant: false,
    childAgeStage: 'adult',
    relationshipStatus: 'married',
  ),
};

/// 当下流抽样时刻（固定日期，确定性）。
final _windowSamples = [
  DateTime(2026, 1, 15, 7, 0),
  DateTime(2026, 1, 15, 10, 30),
  DateTime(2026, 1, 15, 12, 45),
  DateTime(2026, 1, 15, 19, 0),
  DateTime(2026, 1, 15, 21, 30),
];

const _searchQueries = ['安全带', '血压', '痛风', '欠薪', '烟雾报警器'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;

  setUpAll(() async {
    catalog = await Catalog.load();
  });

  Future<Map<String, String>> captureAll() async {
    final out = <String, String>{};

    // ── 1. 目录层：737 条全字段快照（捕捉任何数据/加载回归） ──
    out['catalog'] = jsonEncode({
      'count': catalog.adviceList.length,
      'chapters': catalog.chapters,
      'chapterCounts': catalog.chapterCounts,
      'letterCounts': catalog.letterCounts,
      'modeCounts': catalog.modeCounts,
      'emergencyLeafLabel': catalog.topics.labelOf('health/emergency/first_aid'),
      'emergencyBreadcrumb': catalog.topics.breadcrumbOf(
        'health/emergency/first_aid',
      ),
      'emergencyUnderTopic': [
        for (final a in catalog.underTopic('health/emergency')) a.id,
      ],
      'advices': [
        for (final a in catalog.adviceList)
          {
            'id': a.id,
            'chapter': a.chapter,
            'title': a.title,
            'parts': a.parts,
            'timingBadge': a.timingBadge,
            'actType': a.actType,
            'tags': a.tags,
            'treePath': a.treePath,
            'treePaths': a.treePaths,
            'treeDisplay': a.treeDisplay,
            'prerequisites': a.prerequisites,
            'cron': a.cron,
          },
      ],
    });

    // ── 2. 证据包层：detail 全量（含 sources/rel 关联） ──
    out['details'] = jsonEncode({
      'count': catalog.details.length,
      'details': [
        for (final id in catalog.details.keys.toList()..sort())
          {
            'id': id,
            'humanized': catalog.details[id]!.humanized,
            'cost': catalog.details[id]!.cost,
            'plain': catalog.details[id]!.plain,
            'benefit': catalog.details[id]!.benefit,
            'grade': catalog.details[id]!.grade,
            'sources': catalog.details[id]!.sources,
            'notes': catalog.details[id]!.notes,
            'rel': catalog.details[id]!.rel,
          },
      ],
    });

    // ── 3. 触发层：effectiveTriggerOf 全量（默认推断，无自定义覆盖） ──
    final plainStore = await _store(catalog);
    out['triggers'] = jsonEncode({
      'count': catalog.adviceList.length,
      'plans': [
        for (final a in catalog.adviceList)
          {
            'id': a.id,
            'mode': plainStore.effectiveTriggerOf(a).mode.name,
            'dailyPeriods': plainStore.effectiveTriggerOf(a).dailyPeriods,
            'cadenceScopeKey': plainStore.effectiveTriggerOf(a).cadenceScopeKey,
            'reminderTimes': plainStore.effectiveTriggerOf(a).reminderTimes,
            'targetDate': plainStore.effectiveTriggerOf(a).targetDate,
            'leadDays': plainStore.effectiveTriggerOf(a).leadDays,
            'emergency': a.isEmergencyOrIncident,
          },
      ],
    });

    // ── 4. 流与门禁：分画像快照 ──
    for (final entry in _seedProfiles.entries) {
      final store = await _store(catalog);
      store.updateProfile(entry.value);
      out['stream_${entry.key}'] = jsonEncode({
        'today': [for (final a in store.todayAdvices) a.id],
        'cycleWeekly': [
          for (final a in store.cycleAdvicesOf(PeriodScope.weekly)) a.id,
        ],
        'cycleMonthly': [
          for (final a in store.cycleAdvicesOf(PeriodScope.monthly)) a.id,
        ],
        'cycleYearly': [
          for (final a in store.cycleAdvicesOf(PeriodScope.yearly)) a.id,
        ],
        'windows': [
          for (final t in _windowSamples)
            {
              'at': t.toIso8601String(),
              'ids': [for (final a in store.advicesForWindow(t)) a.id],
            },
        ],
        'emergency': [for (final a in store.emergencyAdvices) a.id],
        'persona': {
          for (final a in catalog.adviceList) '${a.id}': store.matchPersona(a),
        },
      });
    }

    // ── 5. 搜索（词法通道回归） ──
    out['search'] = jsonEncode({
      for (final q in _searchQueries)
        q: [for (final a in plainStore.catalog.search(q)) a.id],
    });

    return out;
  }

  test('golden behavior snapshot: baseline must not drift', () async {
    final snapshot = await captureAll();

    // 确定性自检：同进程内二次采集必须完全一致（排除时间依赖/隐藏状态）。
    final second = await captureAll();
    expect(second, snapshot, reason: '快照采集自身不确定，无法作为基线');

    final dir = Directory(_goldenDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final update = Platform.environment['GOLDEN_UPDATE'] == '1';
    if (update) {
      for (final e in snapshot.entries) {
        File('$_goldenDir/${e.key}.json').writeAsStringSync(e.value);
      }
      // ignore: avoid_print
      print('GOLDEN_UPDATE=1：已重建 ${snapshot.length} 份基线 → $_goldenDir/');
      return;
    }

    expect(dir.existsSync(), isTrue,
        reason: '缺少基线目录 $_goldenDir/，先以 GOLDEN_UPDATE=1 重建');
    for (final e in snapshot.entries) {
      final f = File('$_goldenDir/${e.key}.json');
      expect(f.existsSync(), isTrue, reason: '缺少基线文件 ${f.path}');
      final baseline = f.readAsStringSync();
      if (baseline != e.value) {
        // 提供首个差异的定位信息，便于排障
        final diffAt = _firstDiff(baseline, e.value);
        fail('快照不一致：${e.key}.json $diffAt');
      }
    }
  });
}

String _firstDiff(String a, String b) {
  var i = 0;
  while (i < a.length && i < b.length && a[i] == b[i]) {
    i++;
  }
  final from = (i - 60).clamp(0, a.length);
  return '首个差异@char $i\n  基线: ...${a.substring(from, (i + 60).clamp(0, a.length))}\n'
      '  当前: ...${b.substring(from, (i + 60).clamp(0, b.length))}';
}

Future<AppStore> _store(Catalog catalog) async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(catalog, await SharedPreferences.getInstance());
}
