import 'package:flutter/material.dart';

import '../models/presentation.dart';

/// 交互形态词表(视图层 UI 数据):与 Demo ACTION_TYPE_DEFS 同构,
/// 图标用 Material 线性图标近似。原属数据层 catalog.dart,按分层原则上移。
const List<ActionTypeDef> actionTypes = [
  ActionTypeDef('all', '全部形态', Icons.apps),
  ActionTypeDef('daily-streak', '每日习惯', Icons.local_fire_department_outlined),
  ActionTypeDef('windowed-cadence', '日期计划', Icons.date_range_outlined),
  ActionTypeDef('quick-checkin', '行动打卡', Icons.check_circle_outline),
  ActionTypeDef('slider-calc', '数值记录', Icons.tune),
  ActionTypeDef('haptic-toggle', '行动核对', Icons.toggle_on_outlined),
  ActionTypeDef('emergency-action', '紧急直达', Icons.emergency_outlined),
  ActionTypeDef('zen-timer', '计时屏息', Icons.timer_outlined),
  ActionTypeDef('evidence-checklist', '材料清单', Icons.inventory_2_outlined),
  ActionTypeDef('wage-calc', '成本比较', Icons.calculate_outlined),
  ActionTypeDef('redline-stamp', '规则速查', Icons.gpp_maybe_outlined),
  ActionTypeDef('context-guard', '情境核对', Icons.fact_check_outlined),
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
