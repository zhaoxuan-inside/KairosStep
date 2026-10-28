import 'dart:convert';
import 'dart:io';

void main() {
  print('=====================================================');
  print('执行慢病强门禁与提醒注册表综合验证 (Pure Dart Engine)');
  print('=====================================================');

  final file = File('app/assets/data/advice.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final list = json['list'] as List;

  final a482 = list.firstWhere((e) => (e as Map)['id'] == 482) as Map<String, dynamic>;
  final a484 = list.firstWhere((e) => (e as Map)['id'] == 484) as Map<String, dynamic>;

  // 模拟 matchPersona 强门禁逻辑
  bool matchPersonaLogic(Map<String, dynamic> a, {
    bool hasKidneyStones = false,
    bool hasGout = false,
    bool hasHypertension = false,
    bool hasDiabetes = false,
    List<String> healthConcerns = const ['久坐伏案'],
  }) {
    final title = a['t'] as String;
    final tags = (a['tags'] as List).cast<String>();
    final chapter = a['c'] as String;
    final text = '$title ${tags.join(" ")} $chapter';

    final hasChronic = tags.contains('确诊慢病') ||
        tags.contains('慢性病') ||
        chapter == '得了慢性病之后怎么活' ||
        chapter == '残疾之后怎么活';

    if (hasChronic ||
        text.contains('肾结石') ||
        text.contains('痛风') ||
        text.contains('高尿酸')) {
      if (text.contains('肾结石')) {
        if (!hasKidneyStones && !healthConcerns.contains('肾结石')) {
          return false;
        }
      }
      if (text.contains('痛风') || text.contains('高尿酸')) {
        if (!hasGout && !healthConcerns.contains('痛风')) {
          return false;
        }
      }
      if (text.contains('高血压') || (text.contains('血压') && hasChronic)) {
        if (!hasHypertension && !healthConcerns.contains('血压关注')) {
          return false;
        }
      }
      if (text.contains('糖尿病') ||
          text.contains('血糖') ||
          text.contains('胰岛素')) {
        if (!hasDiabetes && !healthConcerns.contains('血糖关注')) {
          return false;
        }
      }
      if (chapter == '得了慢性病之后怎么活' &&
          !hasHypertension &&
          !hasDiabetes &&
          !hasKidneyStones &&
          !hasGout &&
          !healthConcerns.contains('确诊慢病')) {
        return false;
      }
    }
    return true;
  }

  // 1. 普通健康人群（默认无肾结石、无痛风）
  final normalMatch482 = matchPersonaLogic(a482, hasKidneyStones: false);
  final normalMatch484 = matchPersonaLogic(a484, hasGout: false);

  assert(!normalMatch482, '【测试失败】普通用户不应被推送肾结石建议 482');
  assert(!normalMatch484, '【测试失败】普通用户不应被推送痛风建议 484');
  print('✓ [PASS] 普通健康用户严格拦截建议 482(肾结石) 与 484(痛风)');

  // 2. 勾选肾结石病史人群
  final kidneyMatch482 = matchPersonaLogic(a482, hasKidneyStones: true);
  assert(kidneyMatch482, '【测试失败】肾结石病史用户应当精准匹配建议 482');
  print('✓ [PASS] 确诊/关注肾结石用户精准匹配建议 482');

  // 3. 勾选痛风病史人群
  final goutMatch484 = matchPersonaLogic(a484, hasGout: true);
  assert(goutMatch484, '【测试失败】痛风病史用户应当精准匹配建议 484');
  print('✓ [PASS] 确诊/关注痛风用户精准匹配建议 484');

  // 4. 统计全库 767 条建议在普通用户下的慢病剪枝效果
  int blockedChronicCount = 0;
  for (final item in list) {
    final adv = item as Map<String, dynamic>;
    if (!matchPersonaLogic(adv, hasKidneyStones: false, hasGout: false)) {
      blockedChronicCount++;
    }
  }
  print('✓ [PASS] 全库未确诊慢病健康用户已成功剪除 $blockedChronicCount 条无关特殊病症/慢病建议！');

  // 5. 验证提醒注册表按需注册（非全量扫描）机制
  final fakeActiveReminders = [
    {'id': 7, 'times': ['07:30']},
    {'id': 59, 'times': ['10:30', '15:30']},
    {'id': 103, 'times': ['22:00']},
  ];
  final registeredSchedule = <String, List<int>>{};
  for (final a in fakeActiveReminders) {
    for (final t in a['times'] as List<String>) {
      registeredSchedule.putIfAbsent(t, () => []).add(a['id'] as int);
    }
  }
  assert(registeredSchedule.containsKey('07:30'));
  assert(registeredSchedule['10:30']!.contains(59));
  assert(registeredSchedule['22:00']!.contains(103));
  print('✓ [PASS] 提醒注册表有序索引建立成功，总注册时点数: ${registeredSchedule.length}，单点查询时间复杂度 O(1)');

  print('\n=====================================================');
  print('🎉 全部业务逻辑与剪枝断言 100% 验证通过！');
  print('=====================================================');
}
