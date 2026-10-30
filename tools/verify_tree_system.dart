import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('app/assets/data/advice.json');
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final list = json['list'] as List;

  print('验证 advice.json: 共 ${list.length} 条建议');

  assert(list.length == 737, '总数必须为 737 条');

  int hasCarCount = 0;
  int hasTwowheelerCount = 0;
  int hasChildrenCount = 0;
  int hasAgingParentsCount = 0;
  int isSmokerCount = 0;
  int hasPipedGasCount = 0;

  for (final item in list) {
    final m = item as Map<String, dynamic>;
    final id = m['id'] as int;
    final title = m['t'] as String;
    final path = m['tree_path'] as String?;
    final display = m['tree_display'] as String?;
    final cron = m['cron'] as String?;
    final prereqs = m['prerequisites'] as Map<String, dynamic>? ?? {};

    assert(path != null && path.isNotEmpty, 'id $id 缺少 tree_path');
    assert(display != null && display.isNotEmpty, 'id $id 缺少 tree_display');
    assert(cron != null && cron.isNotEmpty, 'id $id 缺少 cron');

    if (prereqs['has_car'] == true) hasCarCount++;
    if (prereqs['has_twowheeler'] == true) hasTwowheelerCount++;
    if (prereqs['has_children'] == true) hasChildrenCount++;
    if (prereqs['has_aging_parents'] == true) hasAgingParentsCount++;
    if (prereqs['is_smoker'] == true) isSmokerCount++;
    if (prereqs['has_piped_gas'] == true) hasPipedGasCount++;
  }

  print('【校验通过】全部 737 条建议均已具备树路径、层级描述、调度Cron！');
  print('画像守卫统计：');
  print('  机动车守卫 (has_car): $hasCarCount 条');
  print('  两轮车守卫 (has_twowheeler): $hasTwowheelerCount 条');
  print('  子女抚育守卫 (has_children): $hasChildrenCount 条');
  print('  父母照护守卫 (has_aging_parents): $hasAgingParentsCount 条');
  print('  吸烟戒烟守卫 (is_smoker): $isSmokerCount 条');
  print('  管道燃气守卫 (has_piped_gas): $hasPipedGasCount 条');

  // 特别验证 建议 1（系安全带）
  final adv1 = list.firstWhere((e) => e['id'] == 1);
  assert(adv1['prerequisites']['has_car'] != true, '建议 1 适用于乘客，不要求有车');
  print('建议 1 乘客可达性验证通过: ${adv1['t']} -> ${adv1['tree_path']}');

  // 验证 建议 2（电动车头盔）
  final adv2 = list.firstWhere((e) => e['id'] == 2);
  assert(adv2['prerequisites']['has_twowheeler'] == true, '建议 2 必须绑定 has_twowheeler 守卫');
  print('建议 2 守卫验证通过: ${adv2['t']} -> ${adv2['tree_path']} (has_twowheeler: true)');

  // 验证 建议 4（燃气软管）
  final adv4 = list.firstWhere((e) => e['id'] == 4);
  assert(adv4['prerequisites']['has_piped_gas'] == true, '建议 4 必须绑定 has_piped_gas 守卫');
  print('建议 4 守卫验证通过: ${adv4['t']} -> ${adv4['tree_path']} (has_piped_gas: true)');
}
