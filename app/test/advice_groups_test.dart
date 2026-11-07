// 归并展示组验收（MERGE_DESIGN §4/§9，按真实数据口径）：
// 210（反面清单章节）与 484（context-guard 形态）为静默储备——dormant 门禁使其永不进流；
// 483 单独出现于年度页。分组机制以直传列表验证：同 cadence 键成组、dormant 不并。
import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/checkin_engine.dart';
import 'package:kairo_step/domain/gatekeeper_engine.dart';
import 'package:kairo_step/domain/stream_engine.dart';
import 'package:kairo_step/domain/trigger_engine.dart';
import 'package:kairo_step/models/advice.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;

  setUpAll(() async => catalog = await Catalog.load());

  StreamEngine engineFor(UserProfile p) => StreamEngine(
    catalog: catalog,
    trigger: TriggerEngine(catalog, onPersist: () {}),
    gatekeeper: GatekeeperEngine(catalog),
    checkin: CheckinEngine(_NoopPersistence()),
  );

  StreamInputs inputs(UserProfile p) => StreamInputs(
    excludedIds: const {},
    topicAllowed: (_) => true,
    formedHabitIds: const {},
    profile: p,
    userTodos: const [],
  );

  test('真实形态：三联均含 dormant 成员 → 无组（同场判定的数据侧印证）', () {
    final p = const UserProfile(hasGout: true, age: 52).normalized();
    final e = engineFor(p);
    // 触发形态实录：210=反面清单章节（dormant 门禁优先于 tags）、
    // 483=cadence-yearly、484=context-guard（dormant）
    expect(
      e.trigger.effectiveTriggerOf(catalog.adviceById(210)!).mode.name,
      'dormant',
      reason: '210 反面清单章节 → 静默储备',
    );
    expect(e.trigger.effectiveTriggerOf(catalog.adviceById(483)!).mode.name, 'cadence');
    expect(e.trigger.effectiveTriggerOf(catalog.adviceById(484)!).mode.name, 'dormant');
    final source = [210, 483, 484]
        .map((id) => catalog.adviceById(id)!)
        .toList();
    expect(e.adviceGroupIds(inputs(p), source), isEmpty,
        reason: '任一对都含 dormant 成员——同场判定正确地拒绝成组；'
            '机制生效依赖非 dormant 候选对（内容工程待办）或'
            '「相关建议」位（dormant 条目的查看场景）接线');
  });

  test('真实流走查：61↔103 authored 候选组成立，静默储备对不成组', () {
    final p = const UserProfile(hasGout: true, age: 52).normalized();
    final e = engineFor(p);
    final yearly = e.cycleAdvicesOf(inputs(p), PeriodScope.yearly);
    expect(yearly.any((a) => a.id == 483), isTrue, reason: '483 出现在年度页');
    final groups = e.adviceGroupIds(inputs(p), yearly);
    // advice_relation 新增 authored merge_candidate：61↔103（weight .85，
    // mergePolicy same_period）。二者均 daily-night 活跃于今日流，年度页
    // 包含今日流 → 该组正确成立；dormant 成员对（210/484）仍拒绝成组。
    expect(groups, contains(equals([61, 103])),
        reason: '61↔103 为 authored 候选且同场（daily 同 night 时段）');
    expect(
      groups.any((g) => g.contains(210) || g.contains(484)),
      isFalse,
      reason: '210/484 静默储备永不入流，组自然不成立',
    );
  });
}

class _NoopPersistence implements CheckinPersistence {
  @override
  void persistScope(PeriodScope s, Map<int, CardState> c, String e) {}
  @override
  void clearScope(PeriodScope s, String e) {}
  @override
  void persistEpoch(PeriodScope s, String e) {}
  @override
  void persistStreak(int id, StreakState st) {}
  @override
  void persistWindowAnchor(int id, DateTime at) {}
}
