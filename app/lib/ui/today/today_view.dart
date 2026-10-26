import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/icons.dart';
import '../../core/theme.dart';
import '../../state/app_store.dart';
import '../cards/advice_card.dart';
import '../review/carnegie_review_sheet.dart';
import '../tools/tools_sheet.dart';

/// 今天页：今日聚光流 + 完成量胶囊。
///
/// B1 语义：当日完成的卡跨天自然清零（作用域键按天生成），无断签惩罚。
class TodayView extends StatelessWidget {
  const TodayView({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalettes.of(context);
    final store = storeOf(context);
    final todayList = store.todayAdvices;
    final (done, total) = store.countersOf(PeriodScope.today);
    final userTodos = store.userTodos;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今天', style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: 4),
                  Text(
                    '按画像动态匹配 $total 项日常节律 · 跨天自然清零',
                    style: TextStyle(fontSize: 12, color: p.inkSub),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: done >= total && total > 0
                    ? p.emerald.withValues(alpha: 0.14)
                    : p.pillBg,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Text(
                '$done / $total',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: done >= total && total > 0 ? p.emerald : p.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 功能快捷入口：决策树工具箱 & 卡内基周复盘
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => ToolsSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Row(
                    children: [
                      AppHairlineIcons.tree(color: p.action, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '决策树与工具',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => CarnegieReviewSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.hairline),
                  ),
                  child: Row(
                    children: [
                      AppHairlineIcons.carnegie(color: p.gold, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        '卡内基周复盘',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ---- 4. 用户行为数据层：用户自建待办清单 (TodoList) ----
        _buildUserTodoSection(context, p, store, userTodos),
        const SizedBox(height: 18),

        // ---- 5. 今日实证建议流 ----
        Row(
          children: [
            Icon(Icons.bolt_outlined, size: 14, color: p.action),
            const SizedBox(width: 6),
            Text(
              '今日专属实证节律（$total 项）',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (todayList.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.hairline),
            ),
            child: Column(
              children: [
                Icon(Icons.check_circle_outline, size: 36, color: p.emerald),
                const SizedBox(height: 12),
                Text(
                  '今日暂无特定日常待办',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink),
                ),
                const SizedBox(height: 6),
                Text(
                  '可在「我的」页面开启更多角色或在「库」中浏览全景建议',
                  style: TextStyle(fontSize: 12, color: p.inkSub),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final advice in todayList)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AdviceCard(
                advice: advice,
                scope: PeriodScope.today,
              ),
            ),
        const SizedBox(height: 14),
        // 本周复盘卡片入口
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.hairline),
          ),
          child: Row(
            children: [
              AppHairlineIcons.carnegie(color: p.gold, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('卡内基式 4 步周复盘', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      store.carnegieReviews.isNotEmpty
                          ? '已沉淀 ${store.carnegieReviews.length} 次认知跃迁 · 最近：${store.carnegieReviews.first.nextOneSentence}'
                          : '事实 → 反应 → 反思 → 下次只改一句话',
                      style: TextStyle(fontSize: 11, color: p.inkSub),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.hairline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                onPressed: () => CarnegieReviewSheet.show(context),
                child: const Text('开始复盘', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.done_all_outlined, size: 12, color: p.inkMute),
            const SizedBox(width: 5),
            Text(
              '今日已完成 $done 项 · 更多行动见「周期」与「库」',
              style: TextStyle(fontSize: 10.5, color: p.inkMute),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTodoSection(
    BuildContext context,
    AppPalettes p,
    AppStore store,
    List<dynamic> todos,
  ) {
    final doneCount = todos.where((t) => t.isDone).length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, size: 15, color: p.indigo),
              const SizedBox(width: 6),
              Text(
                '我的自建待办',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: p.pillBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '$doneCount/${todos.length}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: p.inkSub),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddTodoDialog(context, store),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: p.action.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 12, color: p.action),
                      const SizedBox(width: 3),
                      Text(
                        '新建待办',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.action),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (todos.isEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '点击「新建待办」自建日常任务，或在建议详情中「一键加入待办」',
              style: TextStyle(fontSize: 11.5, color: p.inkMute),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final todo in todos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => store.toggleUserTodo(todo.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: todo.isDone ? p.emerald : Colors.transparent,
                          border: Border.all(
                            color: todo.isDone ? p.emerald : p.inkMute,
                            width: 1.5,
                          ),
                        ),
                        child: todo.isDone
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        todo.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: todo.isDone ? p.inkMute : p.ink,
                          decoration: todo.isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 14, color: p.inkMute),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => store.removeUserTodo(todo.id),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context, AppStore store) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增专属待办', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '如：预约空腹血糖检查、复核劳动合同...',
            hintStyle: TextStyle(fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                store.addUserTodo(text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}
