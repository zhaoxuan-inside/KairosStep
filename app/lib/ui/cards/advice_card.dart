import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import '../detail/advice_detail_sheet.dart';
import '../share/share_sheet.dart';
import 'interactors.dart';

/// 建议交互卡：支持正面（原子行动+专属微交互器）与 3D 翻转背面（配置触发方式与周期）。
///
/// 严格遵循 DESIGN.md 规约：
/// - 纯色块表达状态、温暖纸质圆角 20px、极简细线；
/// - 彻底禁用 Emoji，使用自绘 1.2px 极简细线图标；
/// - 右上角提供配置（3D 原地翻转配置触发与周期）与移除（补全画像不足，带 5 秒撤销）。
class AdviceCard extends StatefulWidget {
  const AdviceCard({
    super.key,
    required this.advice,
    required this.scope,
    this.compact = false,
    this.showDoneBar = true,
  });

  final Advice advice;
  final PeriodScope scope;
  final bool compact;
  final bool showDoneBar;

  @override
  State<AdviceCard> createState() => _AdviceCardState();
}

class _AdviceCardState extends State<AdviceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipCtl;
  late final Animation<double> _flipAnim;

  bool _isFlipped = false;
  bool _isCollapsed = false;

  static const double _radius = 20;

  @override
  void initState() {
    super.initState();
    _flipCtl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtl, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _flipCtl.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    if (_isFlipped) {
      _flipCtl.reverse();
      setState(() => _isFlipped = false);
    } else {
      _flipCtl.forward();
      setState(() => _isFlipped = true);
    }
  }

  void _handleExclude(BuildContext context, AppStore store) {
    HapticFeedback.lightImpact();
    setState(() => _isCollapsed = true);

    final id = widget.advice.id;
    store.excludeAdvice(id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF19191C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
        duration: const Duration(seconds: 5),
        content: const Text(
          '已从日常视图移除 · 画像已更新',
          style: TextStyle(fontSize: 12.5, color: Colors.white),
        ),
        action: SnackBarAction(
          label: '撤销',
          textColor: const Color(0xFFBC924C),
          onPressed: () {
            store.restoreAdvice(id);
            if (mounted) setState(() => _isCollapsed = false);
          },
        ),
      ),
    );
  }

  void _handleMarkHabitFormed(BuildContext context, AppStore store) {
    HapticFeedback.mediumImpact();
    setState(() => _isCollapsed = true);

    final id = widget.advice.id;
    store.markHabitFormed(id);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF132A1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9999),
          side: const BorderSide(color: Color(0xFF2E7D47), width: 1),
        ),
        duration: const Duration(seconds: 5),
        content: const Row(
          children: [
            Icon(Icons.shield, color: Color(0xFF48BB78), size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '🎉 已形成习惯！已为您移出日常待办，沉淀入【我的生活防线】',
                style: TextStyle(fontSize: 12.5, color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: '撤销',
          textColor: const Color(0xFF48BB78),
          onPressed: () {
            store.relearnHabit(id);
            if (mounted) setState(() => _isCollapsed = false);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCollapsed) {
      return const SizedBox.shrink();
    }

    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final isExcluded = store.isExcluded(widget.advice.id);
    final st = store.cardState(widget.scope, widget.advice.id);
    final done = st.isDone;

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: AnimatedBuilder(
        animation: _flipAnim,
        builder: (context, _) {
          final angle = _flipAnim.value * math.pi;
          final isUnder = angle > math.pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isUnder
                ? Transform(
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildBackPanel(context, p, store),
                  )
                : _buildFrontPanel(context, p, store, st, done, isExcluded),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // 卡片正面 (Front Panel)
  // ==========================================================================

  Widget _buildFrontPanel(
    BuildContext context,
    AppPalettes p,
    AppStore store,
    CardState st,
    bool done,
    bool isExcluded,
  ) {
    final detail = catalogOf(context).detailOf(widget.advice.id);
    final trig = store.effectiveTriggerOf(widget.advice);
    final timing = _displayTiming(widget.advice, trig);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(
          color: isExcluded
              ? p.ash.withValues(alpha: 0.3)
              : (done ? p.emerald.withValues(alpha: 0.55) : p.hairline),
          width: done ? 1.4 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: () => HapticFeedback.selectionClick(),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              14,
              widget.compact ? 12 : 14,
              14,
              widget.compact ? 12 : 14,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, p, store, timing, detail != null, isExcluded),
                SizedBox(height: widget.compact ? 6 : 8),
                Text(
                  widget.advice.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isExcluded ? p.inkMute : null,
                      ),
                ),
                if (widget.advice.caveats.isNotEmpty && !widget.compact) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final c in widget.advice.caveats)
                        Text(
                          '· $c',
                          style: TextStyle(
                            fontSize: 11,
                            color: p.inkSub,
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: widget.compact ? 8 : 12),
                if (isExcluded)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: p.surfaceGrey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '当前建议已被移出日常视图',
                          style: TextStyle(fontSize: 11, color: p.inkMute),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => store.restoreAdvice(widget.advice.id),
                          child: Text(
                            '重新启用',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  AdviceInteractor(advice: widget.advice, scope: widget.scope),
                if (widget.showDoneBar && !isExcluded) ...[
                  SizedBox(height: widget.compact ? 8 : 10),
                  _doneBar(context, p, st),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppPalettes p,
    AppStore store,
    ({String badge, Color color}) timing,
    bool hasDetail,
    bool isExcluded,
  ) {
    final isHabitFormed = store.isHabitFormed(widget.advice.id);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: timing.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            timing.badge,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: timing.color,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (store.triggerConfigOf(widget.advice.id) != null) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: p.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text(
              '已自定义',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: p.gold,
              ),
            ),
          ),
        ],
        if (isHabitFormed) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D47).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                color: const Color(0xFF2E7D47).withValues(alpha: 0.5),
                width: 0.6,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield, size: 9, color: Color(0xFF48BB78)),
                SizedBox(width: 3),
                Text(
                  '已形成习惯',
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF48BB78),
                  ),
                ),
              ],
            ),
          ),
        ],
        const Spacer(),
        _hairlineBtn(
          tip: isHabitFormed
              ? '已成为习惯 · 移出待办中（点击重新带我练习）'
              : '我已养成该习惯（移出日常待办，沉淀入生活防线）',
          icon: Icon(
            isHabitFormed ? Icons.shield : Icons.shield_outlined,
            color: isHabitFormed ? const Color(0xFF48BB78) : p.inkMute,
            size: 14,
          ),
          onTap: () {
            if (isHabitFormed) {
              store.relearnHabit(widget.advice.id);
            } else {
              _handleMarkHabitFormed(context, store);
            }
          },
        ),
        if (hasDetail)
          _hairlineBtn(
            tip: '证据出处',
            icon: AppHairlineIcons.info(color: p.inkMute, size: 14),
            onTap: () => showAdviceDetail(context, widget.advice.id),
          ),
        _hairlineBtn(
          tip: '分享卡片',
          icon: AppHairlineIcons.share(color: p.inkMute, size: 14),
          onTap: () => ShareSheet.open(context, widget.advice),
        ),
        _hairlineBtn(
          tip: '配置触发与周期',
          icon: AppHairlineIcons.tune(color: p.inkMute, size: 14),
          onTap: _toggleFlip,
        ),
        _hairlineBtn(
          tip: isExcluded ? '已排除' : '不适合我 / 移出日常',
          icon: AppHairlineIcons.cross(
            color: isExcluded ? p.emerald : p.inkMute,
            size: 14,
          ),
          onTap: () {
            if (isExcluded) {
              store.restoreAdvice(widget.advice.id);
            } else {
              _handleExclude(context, store);
            }
          },
        ),
      ],
    );
  }

  Widget _hairlineBtn({
    required String tip,
    required Widget icon,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: icon,
        ),
      ),
    );
  }

  Widget _doneBar(BuildContext context, AppPalettes p, CardState st) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: st.completionRatio),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (_, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 4,
                backgroundColor: p.pillBg,
                valueColor: AlwaysStoppedAnimation(
                  st.completionRatio >= 1 ? p.emerald : p.action,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: st.completionRatio >= 1
              ? Row(
                  key: const ValueKey('ok'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppHairlineIcons.check(color: p.emerald, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '已闭环',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.emerald,
                      ),
                    ),
                  ],
                )
              : Text(
                  '${(st.completionRatio * 100).round()}%',
                  key: ValueKey(st.completionRatio),
                  style: TextStyle(fontSize: 10.5, color: p.inkMute),
                ),
        ),
      ],
    );
  }

  // ==========================================================================
  // 卡片背面：触发方式与周期配置面板 (Back Panel)
  // ==========================================================================

  Widget _buildBackPanel(BuildContext context, AppPalettes p, AppStore store) {
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: p.action.withValues(alpha: 0.4), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: _BackPanelConfigForm(
        advice: widget.advice,
        store: store,
        onClose: _toggleFlip,
      ),
    );
  }

  ({String badge, Color color}) _displayTiming(Advice a, CustomTriggerConfig trig) {
    switch (trig.mode) {
      case TriggerMode.dormant:
        return (badge: '静默储备 · 指南中随查', color: const Color(0xFF838280));
      case TriggerMode.daily:
        final periods = trig.dailyPeriods.map((pk) {
          final def = PeriodDefinition.byKey(pk);
          if (def != null) return def.name;
          final custom = PeriodDefinition.parseCustomPeriod(pk);
          if (custom != null) return custom.$3;
          return pk;
        }).join('/');
        return (badge: periods.isEmpty ? '每天' : '每天 $periods', color: const Color(0xFF2A72DE));
      case TriggerMode.cadence:
        final s = switch (trig.cadenceScopeKey) {
          'weekly' => '每周循环',
          'monthly' => '每月循环',
          'yearly' => '每年筛查',
          _ => '周期循环',
        };
        return (badge: s, color: const Color(0xFFBC924C));
      case TriggerMode.windowed:
        return (badge: '窗口期 · ${trig.targetDate ?? "待定"}', color: const Color(0xFFE33A22));
    }
  }
}

// ============================================================================
// 卡片背面表单控件
// ============================================================================

class _BackPanelConfigForm extends StatefulWidget {
  const _BackPanelConfigForm({
    required this.advice,
    required this.store,
    required this.onClose,
  });

  final Advice advice;
  final AppStore store;
  final VoidCallback onClose;

  @override
  State<_BackPanelConfigForm> createState() => _BackPanelConfigFormState();
}

class _BackPanelConfigFormState extends State<_BackPanelConfigForm> {
  late TriggerMode _mode;
  late Set<String> _periods;
  late String _cadenceScope;
  late String? _targetDate;
  late int _leadDays;
  late List<String> _reminderTimes;

  @override
  void initState() {
    super.initState();
    final cfg = widget.store.effectiveTriggerOf(widget.advice);
    _mode = cfg.mode;
    _periods = Set<String>.from(cfg.dailyPeriods);
    _cadenceScope = cfg.cadenceScopeKey;
    _targetDate = cfg.targetDate;
    _leadDays = cfg.leadDays;
    _reminderTimes = List<String>.from(cfg.reminderTimes);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            AppHairlineIcons.tune(color: p.action, size: 14),
            const SizedBox(width: 6),
            Text(
              '配置触发方式与周期 · #${widget.advice.id}',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(9999),
              onTap: widget.onClose,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: AppHairlineIcons.cross(color: p.inkMute, size: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('触发形态', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.inkSub)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _modePill('静默储备', TriggerMode.dormant, p),
            _modePill('日常节律', TriggerMode.daily, p),
            _modePill('周期循环', TriggerMode.cadence, p),
            _modePill('指定窗口期', TriggerMode.windowed, p),
          ],
        ),
        const SizedBox(height: 10),
        if (_mode == TriggerMode.dormant)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: p.surfaceGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '静默储备：不在 Now/今天/每周/每月 占位，仅在生活指南中随用随查。',
              style: TextStyle(fontSize: 10.5, color: p.inkMute),
            ),
          ),
        if (_mode == TriggerMode.daily) ...[
          Row(
            children: [
              Text('浮出时段（多选）', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.inkSub)),
              const Spacer(),
              GestureDetector(
                onTap: () => _showCustomPeriodDialog(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 12, color: p.action),
                      const SizedBox(width: 3),
                      Text(
                        '自定义时段',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.action,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final def in PeriodDefinition.standardPeriods)
                _chip('${def.name} (${def.timeRangeLabel})', _periods.contains(def.key), () {
                  setState(() {
                    if (_periods.contains(def.key)) {
                      _periods.remove(def.key);
                    } else {
                      _periods.add(def.key);
                    }
                  });
                }, p),
              for (final pk in _periods.where((s) => s.startsWith('custom:')))
                _customChip(pk, p),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '弹窗提醒时刻',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: p.inkSub,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 8, minute: 0),
                  );
                  if (picked != null) {
                    final tStr =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                    if (!_reminderTimes.contains(tStr)) {
                      setState(() {
                        _reminderTimes.add(tStr);
                        _reminderTimes.sort();
                      });
                    }
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_add_outlined, size: 12, color: p.action),
                      const SizedBox(width: 3),
                      Text(
                        '添加提醒',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: p.action,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_reminderTimes.isEmpty)
            Text(
              '未设定精准提醒（仅在日常时段视窗内浮出）',
              style: TextStyle(fontSize: 10.5, color: p.inkMute),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in _reminderTimes)
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
                    decoration: BoxDecoration(
                      color: p.action.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: p.action.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm, size: 11, color: p.action),
                        const SizedBox(width: 4),
                        Text(
                          t,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: p.action,
                          ),
                        ),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () => setState(() => _reminderTimes.remove(t)),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(Icons.close, size: 12, color: p.action),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
        if (_mode == TriggerMode.cadence) ...[
          Text('周期频次', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.inkSub)),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final (k, label) in const [
                ('weekly', '每周'),
                ('monthly', '每月'),
                ('yearly', '每年'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _chip(label, _cadenceScope == k, () {
                    setState(() => _cadenceScope = k);
                  }, p),
                ),
            ],
          ),
        ],
        if (_mode == TriggerMode.windowed) ...[
          Text('目标到期日', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.inkSub)),
          const SizedBox(height: 4),
          InkWell(
            onTap: () async {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final existing = _targetDate == null ? null : DateTime.tryParse(_targetDate!);
              final d = await showDatePicker(
                context: context,
                initialDate: existing != null && !existing.isBefore(today)
                    ? existing : now.add(const Duration(days: 30)),
                firstDate: today,
                lastDate: now.add(const Duration(days: 365 * 5)),
              );
              if (d != null) {
                setState(() {
                  _targetDate =
                      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: p.hairline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _targetDate ?? '点击选择目标到期日',
                style: TextStyle(fontSize: 11, color: _targetDate == null ? p.inkMute : p.ink),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('提前多久开始提醒', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.inkSub)),
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final days in const [7, 15, 30, 60])
                _chip('提前 $days 天', _leadDays == days, () {
                  setState(() => _leadDays = days);
                }, p),
            ],
          ),
          const SizedBox(height: 4),
          Text('按准备所需时间选择；目标日由上方日期决定。',
              style: TextStyle(fontSize: 10, color: p.inkMute)),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            TextButton(
              onPressed: () {
                widget.store.resetTriggerConfig(widget.advice.id);
                widget.onClose();
              },
              child: Text('恢复默认', style: TextStyle(fontSize: 11, color: p.inkMute)),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: p.ink,
                foregroundColor: p.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
              onPressed: () {
                if (_mode == TriggerMode.windowed && _targetDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请先选择目标到期日')),
                  );
                  return;
                }
                final newCfg = CustomTriggerConfig(
                  mode: _mode,
                  dailyPeriods: _periods.toList(),
                  cadenceScopeKey: _cadenceScope,
                  targetDate: _targetDate,
                  leadDays: _leadDays,
                  reminderTimes: _reminderTimes,
                );
                widget.store.setTriggerConfig(widget.advice.id, newCfg);
                widget.onClose();
              },
              child: const Text('保存并翻回', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modePill(String label, TriggerMode m, AppPalettes p) {
    final on = _mode == m;
    return GestureDetector(
      onTap: () => setState(() => _mode = m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: on ? p.action : p.pillBg,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
            color: on ? Colors.white : p.ink,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap, AppPalettes p) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: on ? p.ink : p.surfaceGrey,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: on ? p.surface : p.ink,
            fontWeight: on ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _customChip(String key, AppPalettes p) {
    final parsed = PeriodDefinition.parseCustomPeriod(key);
    final label = parsed != null ? parsed.$3 : key;
    final on = _periods.contains(key);

    return Container(
      decoration: BoxDecoration(
        color: on ? p.action.withValues(alpha: 0.15) : p.surfaceGrey,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: on ? p.action : p.hairline,
          width: on ? 1.3 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                if (_periods.contains(key)) {
                  _periods.remove(key);
                } else {
                  _periods.add(key);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 4, 3, 4),
              child: Text(
                '自定义 $label',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: on ? FontWeight.w700 : FontWeight.w400,
                  color: on ? p.action : p.ink,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _periods.remove(key)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 4, 7, 4),
              child: Icon(Icons.close, size: 12, color: on ? p.action : p.inkMute),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCustomPeriodDialog(BuildContext context) async {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 9, minute: 30);

    final res = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            final p = AppPalettes.of(ctx);
            String format(TimeOfDay t) =>
                '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

            return AlertDialog(
              backgroundColor: p.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '添加自定义时段',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: p.ink),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '为此建议设定具体浮出的时间区间：',
                    style: TextStyle(fontSize: 12, color: p.inkSub),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: p.hairline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: startTime,
                            );
                            if (picked != null) {
                              setDlgState(() => startTime = picked);
                            }
                          },
                          child: Text(
                            '起始 ${format(startTime)}',
                            style: TextStyle(fontSize: 11.5, color: p.ink),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text('至', style: TextStyle(fontSize: 12, color: p.inkSub)),
                      ),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: p.hairline),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: endTime,
                            );
                            if (picked != null) {
                              setDlgState(() => endTime = picked);
                            }
                          },
                          child: Text(
                            '结束 ${format(endTime)}',
                            style: TextStyle(fontSize: 11.5, color: p.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('快捷时段推荐：', style: TextStyle(fontSize: 11, color: p.inkMute)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final (s, e) in const [
                        ('07:00', '08:30'),
                        ('08:00', '10:00'),
                        ('12:30', '14:00'),
                        ('17:30', '19:00'),
                        ('20:00', '21:30'),
                        ('22:30', '23:30'),
                      ])
                        GestureDetector(
                          onTap: () {
                            final sp = s.split(':');
                            final ep = e.split(':');
                            setDlgState(() {
                              startTime = TimeOfDay(hour: int.parse(sp[0]), minute: int.parse(sp[1]));
                              endTime = TimeOfDay(hour: int.parse(ep[0]), minute: int.parse(ep[1]));
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: p.surfaceGrey,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: p.hairline),
                            ),
                            child: Text(
                              '$s-$e',
                              style: TextStyle(fontSize: 10.5, color: p.inkSub),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('取消', style: TextStyle(color: p.inkMute)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: p.action),
                  onPressed: () {
                    final key = 'custom:${format(startTime)}-${format(endTime)}';
                    Navigator.pop(ctx, key);
                  },
                  child: const Text('确认添加'),
                ),
              ],
            );
          },
        );
      },
    );

    if (res != null && mounted) {
      setState(() {
        _periods.add(res);
      });
    }
  }
}
