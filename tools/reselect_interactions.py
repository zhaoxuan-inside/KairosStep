#!/usr/bin/env python3
"""从交互库为每条建议重选合适的交互（act_type 重选）。

依据 = 调度语义（assets/triggers/advice_trigger.json 的实际 mode）× 标签 × 标题动词，
交互样式必须与调度一致（交互库口径）：
  cadence(周期循环)  → quick-checkin   周期核查卡：到期打卡确认（每年/每三年筛查疫苗类）
  daily(每日节律)    → quick-checkin   每日打卡卡：习惯/饮食/护理类
  dormant(静默储备)  → 按内容三分：
      设置动词（装/换/护/接…）→ haptic-toggle    一次设置即长期生效
      突发事件标签            → context-guard   情境拦截自检
      否定守护（别/不/拒绝…） → redline-stamp   红线铭记背熟即防
      其余                    → 保持 windowed-cadence（真时效窗口走方向A/倒排）

用法：
  python3 tools/reselect_interactions.py            # dry-run，仅打印报告
  python3 tools/reselect_interactions.py --apply    # 写回 data-src/advice.json
写回后需重新编译 assets/data/entity/advice.json（本脚本 --apply 已同步生成）。
"""
import json
import re
import sys
from collections import Counter

ROOT = 'app'
SRC = f'{ROOT}/data-src/advice.json'
TRIGGERS = f'{ROOT}/assets/data/triggers/advice_trigger.json'
ASSET = f'{ROOT}/assets/data/entity/advice.json'
APPLY = '--apply' in sys.argv

KEEP_TYPES = {'emergency-action', 'daily-streak', 'zen-timer', 'evidence-checklist',
              'wage-calc', 'haptic-toggle', 'redline-stamp', 'context-guard',
              'decision-check', 'process-steps', 'quick-checkin', 'slider-calc'}
SETUP_RE = re.compile(r'装|更换|换成|换一|护罩|护目镜|报警器|限位器|软管|接种|疫苗|滤芯|电池')
NEGATE_RE = re.compile(r'别|不要|不喝|不吃|不买|拒绝|远离|绝不|别指望')
DEADLINE_RE = re.compile(r'时效|期限|截止|维权|仲裁|诉讼|逾期')


def reselect(item, mode):
    """返回新 act_type 或 None 表示保持不变。"""
    at = item['act_type']
    if at != 'windowed-cadence':
        return None  # 其余类型此前已按标签精确分类，保持
    if DEADLINE_RE.search(item['t']):
        return None  # 真时效窗口：保留窗口卡（方向A/倒排计划渲染）
    if mode == 'cadence':
        return 'quick-checkin'
    if mode == 'daily':
        return 'quick-checkin'
    if mode == 'dormant':
        tags = set(item['tags'])
        if '突发事件' in tags:
            return 'context-guard'
        if SETUP_RE.search(item['t']):
            return 'haptic-toggle'
        if NEGATE_RE.search(item['t']):
            return 'redline-stamp'
    return None


def main():
    items = json.load(open(SRC, encoding='utf-8'))['list']
    triggers = {t['id']: t['mode'] for t in json.load(open(TRIGGERS, encoding='utf-8'))['list']}

    assignments = {}
    for item in items:
        mode = triggers.get(item['id'], 'dormant')
        new_at = reselect(item, mode)
        if new_at and new_at != item['act_type']:
            assignments[item['id']] = (item['act_type'], new_at, item['t'])

    print(f'重选条数: {len(assignments)}')
    print('== 迁移分布 (旧 → 新) ==')
    for (old, new), n in Counter((v[0], v[1]) for v in assignments.values()).most_common():
        print(f'  {old} → {new}: {n}')
    print('== 样例 ==')
    for id_, (old, new, title) in list(assignments.items())[:12]:
        print(f'  #{id_} [{old} → {new}] {title[:32]}')

    after = Counter((i['act_type'] if i['id'] not in assignments else assignments[i['id']][1]) for i in items)
    print('== 重选后全局分布 ==')
    for k, v in after.most_common():
        print(f'  {k}: {v}')

    if not APPLY:
        print('(dry-run，未写回。加 --apply 执行写回)')
        return

    for item in items:
        if item['id'] in assignments:
            item['act_type'] = assignments[item['id']][1]
    json.dump({'list': items}, open(SRC, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)

    # 同步编译 assets/data/entity/advice.json（字段映射与既有产物一致）
    assets = [{'id': i['id'], 'chapterCode': i['c'], 'title': i['t'],
               'badgeKey': i['timing_badge'], 'style': i['act_type'],
               'prerequisites': i.get('prerequisites', {}), 'cron': i['cron']}
              for i in items]
    json.dump({'schemaVersion': 1, 'list': assets}, open(ASSET, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print(f'已写回 {SRC} 与 {ASSET}')


if __name__ == '__main__':
    main()
