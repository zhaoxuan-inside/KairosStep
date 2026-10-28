import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../models/advice.dart';
import '../../state/app_store.dart';
import '../detail/advice_detail_sheet.dart';
import '../onboarding/onboarding_view.dart';
import '../tools/tools_sheet.dart';
import 'excluded_advices_view.dart';
import '../library/topic_tree_sheet.dart';

/// 我的页：本地安全画像中枢。
///
/// 画像（年龄/性别/角色）→ 主题切换 → 健康节点筛查包 → 免责声明。
class MeView extends StatelessWidget {
  const MeView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final profile = store.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text('我的', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 4),
        Text(
          '本地安全画像中枢 · 所有数据仅存本机',
          style: TextStyle(fontSize: 12, color: p.inkSub),
        ),
        const SizedBox(height: 16),

        // ---- 画像卡 ----
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.badge_outlined, size: 15, color: p.action),
                  const SizedBox(width: 6),
                  Text('我的画像', style: _cardTitle(context)),
                  const Spacer(),
                  Text(
                    profile.label,
                    style: TextStyle(fontSize: 10.5, color: p.inkMute),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('性别', style: _fieldLabel(p)),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final g in const ['男', '女'])
                    _pill(
                      context,
                      g,
                      on: profile.gender == g,
                      onTap: () =>
                          store.profile = store.profile.copyWith(gender: g),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text('年龄 · ${profile.age} 岁', style: _fieldLabel(p)),
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
              const SizedBox(height: 10),
              Text('职业形态', style: _fieldLabel(p)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in const ['上班族', '程序员', '创业者', '学生', '灵活就业者'])
                    _pill(
                      context,
                      r,
                      on: profile.roles.contains(r),
                      onTap: () {
                        final next = Set<String>.from(profile.roles);
                        if (next.contains(r)) {
                          next.remove(r);
                        } else {
                          next.add(r);
                        }
                        store.profile = profile.copyWith(roles: next.toList());
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('家庭与责任', style: _fieldLabel(p)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final r in const [
                    ('家有老人', '家有老人'),
                    ('育儿', '家长'),
                    ('伴侣', '伴侣'),
                  ])
                    _pill(
                      context,
                      r.$1,
                      on: profile.roles.contains(r.$2),
                      onTap: () {
                        final next = Set<String>.from(profile.roles);
                        if (next.contains(r.$2)) {
                          next.remove(r.$2);
                        } else {
                          next.add(r.$2);
                        }
                        store.profile = profile.copyWith(roles: next.toList());
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('居住与日常', style: _fieldLabel(p)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in const ['租房人', '购房人', '司机', '出境者'])
                    _pill(
                      context,
                      c,
                      on: profile.livingConditions.contains(c),
                      onTap: () {
                        final next = Set<String>.from(profile.livingConditions);
                        if (next.contains(c)) {
                          next.remove(c);
                        } else {
                          next.add(c);
                        }
                        final isDriver = next.contains('司机');
                        store.profile = profile.copyWith(
                          livingConditions: next.toList(),
                          hasCar: isDriver || profile.hasCar,
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text('通勤与生活实体守卫', style: _fieldLabel(p)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _pill(
                    context,
                    '🚗 机动车/驾乘',
                    on: profile.hasCar,
                    onTap: () => store.profile = profile.copyWith(
                      hasCar: !profile.hasCar,
                    ),
                  ),
                  _pill(
                    context,
                    '🛵 两轮电动车/骑行',
                    on: profile.hasTwowheeler,
                    onTap: () => store.profile = profile.copyWith(
                      hasTwowheeler: !profile.hasTwowheeler,
                    ),
                  ),
                  _pill(
                    context,
                    '👶 抚育子女',
                    on: profile.hasChildren || profile.roles.contains('家长'),
                    onTap: () => store.profile = profile.copyWith(
                      hasChildren: !profile.hasChildren,
                    ),
                  ),
                  _pill(
                    context,
                    '🧓 孝亲关照老人',
                    on:
                        profile.hasAgingParents ||
                        profile.livingConditions.contains('家有老人'),
                    onTap: () => store.profile = profile.copyWith(
                      hasAgingParents: !profile.hasAgingParents,
                    ),
                  ),
                  _pill(
                    context,
                    '🐾 伴侣宠物',
                    on:
                        profile.hasPets ||
                        profile.livingConditions.contains('养犬人'),
                    onTap: () => store.profile = profile.copyWith(
                      hasPets: !profile.hasPets,
                    ),
                  ),
                  _pill(
                    context,
                    '🚭 吸烟(戒烟守护)',
                    on: profile.isSmoker,
                    onTap: () => store.profile = profile.copyWith(
                      isSmoker: !profile.isSmoker,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                        '当前画像专属匹配：${catalogOf(context).adviceList.where(store.matchPersona).length} / 767 条',
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
                        builder: (_) =>
                            const OnboardingView(isReconfiguring: true),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- 外观 ----
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined, size: 15, color: p.indigo),
                  const SizedBox(width: 6),
                  Text('外观', style: _cardTitle(context)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _pill(
                    context,
                    '深邃曜石黑',
                    on: store.themeMode == ThemeMode.dark,
                    onTap: () => store.themeMode = ThemeMode.dark,
                  ),
                  const SizedBox(width: 6),
                  _pill(
                    context,
                    '极简暖纸白',
                    on: store.themeMode == ThemeMode.light,
                    onTap: () => store.themeMode = ThemeMode.light,
                  ),
                  const SizedBox(width: 6),
                  _pill(
                    context,
                    '跟随系统',
                    on: store.themeMode == ThemeMode.system,
                    onTap: () => store.themeMode = ThemeMode.system,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- 个性化管理与离线工具箱 ----
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune, size: 15, color: p.action),
                  const SizedBox(width: 6),
                  Text('个性化掌控与工具箱', style: _cardTitle(context)),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.account_tree_outlined, color: p.action),
                title: const Text('主题分类与剪枝'),
                subtitle: Text(
                  '已隐藏 ${store.excludedTopicPaths.length} 个分支 · 可展开与恢复',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    showTopicTree(context, manage: true, personalized: true),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => ExcludedAdvicesView.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: 15,
                        color: p.inkSub,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '已排除建议管理',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '当前已手动移出日常视图：${store.excludedAdviceIds.length} 条 · 可随时恢复',
                              style: TextStyle(fontSize: 11, color: p.inkMute),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: p.inkMute),
                    ],
                  ),
                ),
              ),
              Divider(color: p.hairline, height: 16),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => ToolsSheet.show(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        size: 15,
                        color: p.action,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '决策树向导与精算工具箱',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '离线劳动维权决策树、清单生成器、真实年化利率换算',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: p.inkMute),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ---- 健康节点筛查包 ----
        Text('健康节点筛查包', style: _cardTitle(context)),
        const SizedBox(height: 4),
        Text(
          '按年龄触发 · 条件谓词随画像动态求值',
          style: TextStyle(fontSize: 10.5, color: p.inkMute),
        ),
        const SizedBox(height: 10),
        for (final pkg in catalogOf(context).nodePackages)
          _NodePackageCard(pkg: pkg),
        const SizedBox(height: 12),

        // ---- 隐私与免责 ----
        _card(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 15, color: p.emerald),
                  const SizedBox(width: 6),
                  Text('隐私与免责', style: _cardTitle(context)),
                ],
              ),
              const SizedBox(height: 10),
              _fact(context, '本地优先：不访问网络、相册、通讯录、蓝牙、语音'),
              _fact(context, '打卡只作记录与复盘入口，无断签惩罚、无排名'),
              _fact(context, '医疗/法律内容仅供参考，按当地政策与医生/律师意见执行'),
              _fact(context, '内容来源《高性价比人生指南》，标注来源与更新时间'),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '数字阶跃 KairosStep v1.0.4 · Flutter 跨平台构建',
            style: TextStyle(fontSize: 10, color: p.inkMute),
          ),
        ),
      ],
    );
  }

  TextStyle _cardTitle(BuildContext context) =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

  TextStyle _fieldLabel(AppPalettes p) =>
      TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: p.inkSub);

  Widget _card(BuildContext context, {required Widget child}) {
    final p = AppPalettes.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: child,
    );
  }

  Widget _fact(BuildContext context, String text) {
    final p = AppPalettes.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 13, color: p.emerald),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, height: 1.5, color: p.inkSub),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    String label, {
    required bool on,
    required VoidCallback onTap,
  }) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(9999),
      onTap: () {
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? p.action.withValues(alpha: 0.14) : p.pillBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: on ? p.action.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
            color: on ? p.action : p.inkSub,
          ),
        ),
      ),
    );
  }
}

/// 健康节点包卡：当前活跃 / 未到节点 两态；条目按画像硬条件过滤。
class _NodePackageCard extends StatelessWidget {
  const _NodePackageCard({required this.pkg});

  final NodePackage pkg;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final catalog = catalogOf(context);
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
          Row(
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
            ],
          ),
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
