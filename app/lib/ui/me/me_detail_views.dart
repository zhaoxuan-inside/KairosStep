import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../detail/advice_detail_sheet.dart';
import '../onboarding/onboarding_view.dart';

/// 「我的」二级页集合：画像详情 / 生活防线 / 健康节点筛查包。
///
/// 页面模式复用 ExcludedAdvicesView（透明 AppBar + MaterialPageRoute）：
/// L1「我的」页只保留摘要与入口行，明细统一下沉到本文件。
class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: '返回',
          icon: AppHairlineIcons.cross(color: p.ink, size: 14),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: p.ink,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: children,
        ),
      ),
    );
  }
}

Widget _detailCard(AppPalettes p, Widget child) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: p.hairline),
    ),
    child: child,
  );
}

Widget _tag(AppPalettes p, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: p.pillBg,
      borderRadius: BorderRadius.circular(9999),
      border: Border.all(color: p.hairline),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: p.inkSub)),
  );
}

// ══════════════════ 画像详情 ══════════════════

class ProfileDetailView extends StatelessWidget {
  const ProfileDetailView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileDetailView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final profile = store.profile;

    return _DetailScaffold(
      title: '画像详情',
      children: [
        _detailCard(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, size: 15, color: p.action),
                  const SizedBox(width: 6),
                  Text(
                    '我的画像',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    profile.label,
                    style: TextStyle(fontSize: 10.5, color: p.inkMute),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${profile.gender} · ${profile.age} 岁 · '
                '${(profile.heightCm ?? 170).round()} cm / '
                '${(profile.weightKg ?? 65).toStringAsFixed(1)} kg · '
                'BMI ${(profile.bmi ?? 22.0).toStringAsFixed(1)}'
                '${profile.isOverweightOrObese ? ' · 超重/需管理' : ' · 健康范围'}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '年龄快速调整',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: p.inkSub,
                ),
              ),
              Slider(
                value: profile.age.toDouble(),
                min: 14,
                max: 88,
                divisions: 74,
                activeColor: p.action,
                label: '${profile.age}',
                onChanged: (v) =>
                    store.profile = store.profile.copyWith(age: v.round()),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: p.action.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 14, color: p.action),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '当前画像专属匹配：${catalogOf(context).adviceList.where(store.matchPersona).length} / 737 条',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.action,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: p.hairline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                  icon: Icon(Icons.explore_outlined, size: 15, color: p.action),
                  label: Text(
                    '重设画像 · 进入全息引导向导',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: p.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OnboardingView(
                          isReconfiguring: true,
                          // 带入当前画像：选择态据此推断，重配置不再从空白起步
                          initialProfile: storeOf(context).profile,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '性别、角色、健康关注等完整画像项请在向导内调整',
                style: TextStyle(fontSize: 10.5, color: p.inkMute),
              ),
            ],
          ),
        ),
        _tagGroup(p, '角色与职业', _groupRoles(profile)),
        _tagGroup(p, '居住与日常', _groupLiving(profile)),
        _tagGroup(p, '健康与处境', _groupHealth(profile)),
      ],
    );
  }

  Widget _tagGroup(AppPalettes p, String title, List<String> tags) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return _detailCard(
      p,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: p.ink),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final t in tags) _tag(p, t)],
          ),
        ],
      ),
    );
  }
}

List<String> _groupRoles(UserProfile profile) {
  final tags = [for (final r in profile.roles) if (r != '全民') r];
  void add(String label, bool on) {
    if (on && !tags.contains(label)) tags.add(label);
  }

  add('程序员/技术研发', profile.isProgrammer);
  add('备孕/孕产', profile.isPregnantOrPlanning);
  return tags;
}

List<String> _groupLiving(UserProfile profile) {
  final tags = [...profile.livingConditions];
  void add(String label, bool on) {
    if (on && !tags.contains(label)) tags.add(label);
  }

  add('机动车/驾乘', profile.hasCar);
  add('两轮车/骑行', profile.hasTwowheeler);
  add('抚育子女', profile.hasChildren);
  add('孝亲老人', profile.hasAgingParents);
  add('伴侣宠物', profile.hasPets);
  add('出国/留学', profile.hasAbroadTravelOrStudy);
  add('债务压力', profile.hasDebtPressure);
  add('平台运营', profile.hasDigitalAssetsConcern);
  add('残障照护', profile.hasDisabilityCare);
  return tags;
}

List<String> _groupHealth(UserProfile profile) {
  final tags = [...profile.healthConcerns];
  void add(String label, bool on) {
    if (on && !tags.contains(label)) tags.add(label);
  }

  add('吸烟守护', profile.isSmoker);
  add('血压关注', profile.hasHypertension);
  add('血糖关注', profile.hasDiabetes);
  add('痛风/高尿酸', profile.hasGout);
  add('肾结石病史', profile.hasKidneyStones);
  add('减重塑形', profile.hasWeightLossGoal);
  add('反酸胃炎', profile.hasGastroAcidOrStomach);
  add('止痛用药', profile.hasFrequentPainOrAnalgesic);
  add('心理危机', profile.hasCrisisOrMentalStress);
  return tags;
}

// ══════════════════ 我的生活防线 ══════════════════

class DefenseLineView extends StatelessWidget {
  const DefenseLineView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DefenseLineView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);

    return _DetailScaffold(
      title: '我的生活防线',
      children: [
        _detailCard(
          p,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield, size: 16, color: Color(0xFF48BB78)),
                  const SizedBox(width: 6),
                  Text(
                    '已筑牢本能',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D47).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                        color: const Color(0xFF2E7D47).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '已筑牢 ${store.formedHabits.length} 项本能',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF48BB78),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '已沉淀为潜意识本能的习惯 · 自动从日常待办中剪枝移出，不再反复打扰',
                style: TextStyle(fontSize: 11, color: p.inkMute, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (store.formedHabits.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: p.surfaceGrey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '正在日常中练习微动作。\n在建议卡片点击【🛡️ 我已养成】即可沉淀为生活防线并移出每日待办。',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: p.inkSub,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (final id in store.formedHabits)
                      Builder(
                        builder: (ctx) {
                          final a = catalogOf(context).byId[id];
                          final dateStr = store.habitFormedDate(id);
                          if (a == null) return const SizedBox.shrink();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: p.surfaceGrey,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: p.hairline),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_outline,
                                  size: 14,
                                  color: Color(0xFF48BB78),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.title,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: p.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '已形成肌肉记忆${dateStr != null ? " · $dateStr 养成" : ""} · 待办已免打扰',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: p.inkMute,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    store.relearnHabit(id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '已将“${a.title}”恢复至今日待办流，重新练习',
                                        ),
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    '重新练习',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFFBC924C),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ══════════════════ 健康节点筛查包 ══════════════════

class NodePackagesView extends StatelessWidget {
  const NodePackagesView({super.key});

  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NodePackagesView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final packages = catalogOf(context).nodePackages;

    // 已到节点排在前面并默认展开；未到节点折叠沉底
    final ordered = [
      ...packages.where((pkg) => store.profile.age >= pkg.trigger),
      ...packages.where((pkg) => store.profile.age < pkg.trigger),
    ];

    return _DetailScaffold(
      title: '健康节点筛查包',
      children: [
        Text(
          '按年龄触发的年度自查清单 · 点击卡片展开',
          style: TextStyle(fontSize: 11.5, color: p.inkMute),
        ),
        const SizedBox(height: 10),
        for (final pkg in ordered)
          _NodePackageCard(
            pkg: pkg,
            initiallyExpanded: store.profile.age >= pkg.trigger,
          ),
      ],
    );
  }
}

/// 健康节点包卡：当前活跃 / 未到节点 两态；默认折叠，点击标题行展开条目。
class _NodePackageCard extends StatefulWidget {
  const _NodePackageCard({required this.pkg, required this.initiallyExpanded});

  final NodePackage pkg;
  final bool initiallyExpanded;

  @override
  State<_NodePackageCard> createState() => _NodePackageCardState();
}

class _NodePackageCardState extends State<_NodePackageCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final catalog = catalogOf(context);
    final pkg = widget.pkg;
    final active = store.profile.age >= pkg.trigger;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: active ? p.surface : p.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? p.emerald.withValues(alpha: 0.4) : p.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Text(
                  '节点 ${pkg.no}',
                  style: TextStyle(fontSize: 10.5, color: p.inkMute),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pkg.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: active ? p.emerald.withValues(alpha: 0.12) : p.pillBg,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    active ? '当前活跃' : '未到节点 · ${pkg.trigger} 岁前触发',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: active ? p.emerald : p.inkMute,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, size: 18, color: p.inkMute),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 240),
            sizeCurve: Curves.easeOut,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  pkg.headline,
                  style: TextStyle(fontSize: 11.5, color: p.inkSub, height: 1.5),
                ),
                const SizedBox(height: 10),
                for (final item in pkg.items)
                  _NodeItemRow(
                    item: item,
                    advice: item.src == null ? null : catalog.byId[item.src],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeItemRow extends StatelessWidget {
  const _NodeItemRow({required this.item, this.advice});

  final NodePackageItem item;
  final Advice? advice;

  /// 打卡状态键：有来源用建议 id，无来源用标签哈希（保持独立行状态）。
  int get stateKey => item.src ?? ('node|${item.label}'.hashCode & 0x3fffffff);

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final v = store.evalNodeItem(item);
    final checked = store.cardState(PeriodScope.yearly, stateKey).isDone;

    if (!v.show) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            Icon(Icons.visibility_off_outlined, size: 13, color: p.inkMute),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${item.label}\n${v.reason ?? ''}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: p.inkMute,
                  height: 1.4,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: p.inkMute,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => store.updateCard(PeriodScope.yearly, stateKey, (s) {
          checked ? s.doneParts.clear() : s.doneParts.add('__done__');
          s.completionRatio = checked ? 0 : 1;
        }),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              Icon(
                checked ? Icons.check_box : Icons.check_box_outline_blank,
                size: 15,
                color: checked ? p.emerald : p.inkMute,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: checked ? p.emerald : p.ink,
                        fontWeight: checked ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    if (v.note != null)
                      Text(
                        v.note!,
                        style: TextStyle(fontSize: 9.5, color: p.amber),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: p.pillBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  item.freq,
                  style: TextStyle(fontSize: 9, color: p.inkMute),
                ),
              ),
              if (advice != null) ...[
                const SizedBox(width: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(9999),
                  onTap: () => showAdviceDetail(context, item.src!),
                  child: Icon(Icons.info_outline, size: 13, color: p.inkMute),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
