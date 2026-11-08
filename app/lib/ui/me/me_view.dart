import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../library/topic_tree_sheet.dart';
import '../onboarding/onboarding_view.dart';
import '../tools/decision_tree_sheet.dart';
import '../tools/tools_sheet.dart';
import '../widgets/stagger_in.dart';
import 'excluded_advices_view.dart';
import 'me_detail_views.dart';

/// 我的页：本地安全画像中枢。
///
/// L1 只做摘要与导航：画像详情 / 生活防线 / 筛查包明细下沉到二级页
/// （me_detail_views.dart），完整画像编辑统一走全息引导向导。
class MeView extends StatelessWidget {
  const MeView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final profile = store.profile;
    final packages = catalogOf(context).nodePackages;
    final activePackages = packages
        .where((pkg) => profile.age >= pkg.trigger)
        .length;

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

        // ---- 身份卡（点击进入画像详情二级页） ----
        StaggerIn(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.selectionClick();
              ProfileDetailView.show(context);
            },
            child: _card(
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
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 16, color: p.inkMute),
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
                  const SizedBox(height: 12),
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
                            '当前画像专属匹配：${catalogOf(context).adviceList.where(store.matchPersona).length} / 737 条\n'
                            '${store.profile.focusTopics.isEmpty ? '具体主题未限定' : '已关注 ${store.profile.focusTopics.length} 个具体主题'} · 可重设画像调整',
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
                      icon: Icon(
                        Icons.explore_outlined,
                        size: 15,
                        color: p.action,
                      ),
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
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- 二级页入口行 ----
        StaggerIn(
          delay: const Duration(milliseconds: 50),
          child: _card(
            context,
            child: Column(
              children: [
                _entryRow(
                  context,
                  Icons.shield_outlined,
                  p.emerald,
                  '我的生活防线',
                  '已筑牢 ${store.formedHabits.length} 项本能 · 自动免打扰',
                  () {
                    HapticFeedback.selectionClick();
                    DefenseLineView.show(context);
                  },
                ),
                Divider(color: p.hairline, height: 16),
                _entryRow(
                  context,
                  Icons.monitor_heart_outlined,
                  p.rose,
                  '健康节点筛查包',
                  '活跃 $activePackages / 共 ${packages.length} 项 · 按年龄触发',
                  () {
                    HapticFeedback.selectionClick();
                    NodePackagesView.show(context);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ---- 设置与工具箱 ----
        StaggerIn(
          delay: const Duration(milliseconds: 100),
          child: _card(
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
                // 音效直接跟随手机系统音量/静音状态，应用内不设开关
                Divider(color: p.hairline, height: 16),
                // ListTile 需自有 Material 承载墨水，避免被外层带背景色的
                // 卡片容器遮挡并触发框架断言
                Material(
                  type: MaterialType.transparency,
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.account_tree_outlined, color: p.action),
                    title: const Text('主题分类与剪枝'),
                    subtitle: Text(
                      '已隐藏 ${store.excludedTopicPaths.length} 个分支 · 可展开与恢复',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showTopicTree(
                      context,
                      manage: true,
                      personalized: true,
                    ),
                  ),
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
                                style: TextStyle(
                                  fontSize: 11,
                                  color: p.inkMute,
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
                Divider(color: p.hairline, height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => DecisionTreeSheet.show(context),
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
                                '离线决策树向导',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '劳动争议与欠薪、租房押金退还、工伤认定维权',
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
                Divider(color: p.hairline, height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => ToolsSheet.show(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calculate_outlined,
                          size: 15,
                          color: p.amber,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '实用精算工具箱',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '个税测算、房贷月供对比、补充养老金、基本养老金领取',
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
                Divider(color: p.hairline, height: 16),
                const _PrivacyDisclosure(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '数字阶跃 KairosStep v1.0.24 (25) · Flutter 跨平台构建',
            style: TextStyle(fontSize: 10, color: p.inkMute),
          ),
        ),
      ],
    );
  }

  TextStyle _cardTitle(BuildContext context) =>
      const TextStyle(fontSize: 13, fontWeight: FontWeight.w700);

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

  /// 二级页入口行：图标 + 标题 + 副标题 + chevron（与工具箱行同构）。
  Widget _entryRow(
    BuildContext context,
    IconData icon,
    Color color,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    final p = AppPalettes.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: p.inkMute),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: p.inkMute),
          ],
        ),
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

/// 隐私与免责：默认折叠的说明行，避免法务文案在 L1 平铺。
class _PrivacyDisclosure extends StatefulWidget {
  const _PrivacyDisclosure();

  @override
  State<_PrivacyDisclosure> createState() => _PrivacyDisclosureState();
}

class _PrivacyDisclosureState extends State<_PrivacyDisclosure> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.privacy_tip_outlined, size: 15, color: p.emerald),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '隐私与免责',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more, size: 16, color: p.inkMute),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 240),
          sizeCurve: Curves.easeOut,
          crossFadeState: _expanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fact(context, '本地优先：不访问网络、相册、蓝牙、语音；通讯录仅经系统选择器按需读取，数据不出本机'),
                _fact(context, '医疗/法律内容仅供参考，按当地政策与医生/律师意见执行'),
                _fact(context, '内容来源《高性价比人生指南》，标注来源与更新时间'),
              ],
            ),
          ),
        ),
      ],
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
}
