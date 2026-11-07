// 探查内容快照（Phase 4 防回归）：probes.json 外置前后，三窗口探查的题目/选项/
// 关联建议逐一不变；probe 绑定规则（AdviceProbeBindingEngine）判定不变。
// 用法：GOLDEN_UPDATE=1 flutter test test/probe_content_test.dart 重建基线。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kairo_step/data/catalog.dart';
import 'package:kairo_step/domain/probe_engine.dart';
import 'package:kairo_step/infra/notifications/mobile_notification_service.dart';
import 'package:kairo_step/models/probe_model.dart';
import 'package:kairo_step/models/user.dart';

const _goldenFile = 'test/golden/probes.json';
final _now = DateTime(2026, 1, 15, 9, 45);

Map<String, dynamic> _serialize(ProbePayload p) => {
  'title': p.title,
  'description': p.description,
  'signalLevel': p.signalLevel.name,
  'categories': [for (final c in p.categories) c.name],
  'isMerged': p.isMerged,
  'questions': [
    for (final q in p.questions)
      {
        'id': q.id,
        'category': q.category.name,
        'title': q.title,
        'subtitle': q.subtitle,
        'options': [
          for (final o in q.options)
            {
              'key': o.key,
              'label': o.label,
              'emoji': o.emoji,
              'description': o.description,
              'associatedAdviceIds': o.associatedAdviceIds,
            },
        ],
      },
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Catalog catalog;

  setUpAll(() async {
    catalog = await Catalog.load();
  });

  ProbeEngine engineFor(List<String> roles) {
    final e = ProbeEngine(MobileNotificationService(), catalog.engines.probe, probes: catalog.probes);
    e.registerAdvices(const [], UserProfile(roles: roles));
    return e;
  }

  Map<String, dynamic> bindingOf(int adviceId) {
    final advice = catalog.adviceById(adviceId)!;
    final spec = engineFor(const ['全民']).bindingSpecFor(advice);
    return {
      'category': spec.category.name,
      'signalLevel': spec.signalLevel.name,
      'promptQuestion': spec.promptQuestion,
      'matchingOption': spec.matchingOption,
      'responseGuidance': spec.responseGuidance,
    };
  }

  test('probe content snapshot: 题目/选项/绑定外置不改内容', () {
    final snapshot = {
      'morning': _serialize(engineFor(const ['全民']).createMorningContextProbe(_now)),
      'afternoon': _serialize(
        engineFor(const ['全民']).createAfternoonBodyProbe(_now),
      ),
      'evening_worker': _serialize(
        engineFor(const ['全民', '上班族']).createEveningMoodAndActivityProbe(_now),
      ),
      'evening_student': _serialize(
        engineFor(const ['全民', '学生']).createEveningMoodAndActivityProbe(_now),
      ),
      'evening_default': _serialize(
        engineFor(const ['全民']).createEveningMoodAndActivityProbe(_now),
      ),
      // 绑定规则判定（显式 ID：44 急救 / 401 久坐 / 568 心理 / 113 睡眠；
      // 关键词链：1 安全带-交通 / 210 尿酸-慢病；兜底 lifestyle：7）
      'bindings': {
        '44': bindingOf(44),
        '401': bindingOf(401),
        '568': bindingOf(568),
        '113': bindingOf(113),
        '1': bindingOf(1),
        '210': bindingOf(210),
        '7': bindingOf(7),
      },
    };

    final f = File(_goldenFile);
    final rendered = const JsonEncoder.withIndent('  ').convert(snapshot);
    final update = Platform.environment['GOLDEN_UPDATE'] == '1';
    if (update) {
      f.writeAsStringSync(rendered);
      // ignore: avoid_print
      print('已重建探查内容基线 → $_goldenFile');
      return;
    }
    expect(f.existsSync(), isTrue, reason: '缺少基线 $_goldenFile');
    // Windows 下 git autocrlf 会把仓库内 LF 基线检出为 CRLF，
    // 内容快照按行尾归一后比较（语义一致即通过）。
    final onDisk = f.readAsStringSync().replaceAll('\r\n', '\n');
    if (onDisk != rendered) {
      fail('探查内容与基线不一致（probes.json 外置不得改变题目/选项/绑定判定）');
    }
  });
}
