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
        const Spacer(),
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
        return (badge: '静默储备 · 库中随查', color: const Color(0xFF838280));
      case TriggerMode.daily:
        final periods = trig.dailyPeriods.map((pk) => switch (pk) {
          'morning' => '早晨',
          'focus' => '上午',
          'afternoon' => '午后',
          'evening' => '傍晚',
          'night' => '夜深',
          _ => '日常',
        }).join('/');
        return (badge: '每天 $periods', color: const Color(0xFF2A72DE));
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

  @override
  void initState() {
    super.initState();
    final cfg = widget.store.effectiveTriggerOf(widget.advice);
    _mode = cfg.mode;
    _periods = Set<String>.from(cfg.dailyPeriods);
    _cadenceScope = cfg.cadenceScopeKey;
    _targetDate = cfg.targetDate;
    _leadDays = cfg.leadDays;
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
              '静默储备：不在 Now/今天/每周/每月 占位，仅在全景库中随用随查。',
              style: TextStyle(fontSize: 10.5, color: p.inkMute),
            ),
          ),
        if (_mode == TriggerMode.daily) ...[
          Text('浮出时段（多选）', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.inkSub)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final (k, label) in const [
                ('morning', '早晨'),
                ('focus', '上午'),
                ('afternoon', '午后'),
                ('evening', '傍晚'),
                ('night', '夜深'),
              ])
                _chip(label, _periods.contains(k), () {
                  setState(() {
                    if (_periods.contains(k)) {
                      _periods.remove(k);
                    } else {
                      _periods.add(k);
                    }
                  });
                }, p),
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
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 30)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
                final newCfg = CustomTriggerConfig(
                  mode: _mode,
                  dailyPeriods: _periods.toList(),
                  cadenceScopeKey: _cadenceScope,
                  targetDate: _targetDate,
                  leadDays: _leadDays,
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
}
