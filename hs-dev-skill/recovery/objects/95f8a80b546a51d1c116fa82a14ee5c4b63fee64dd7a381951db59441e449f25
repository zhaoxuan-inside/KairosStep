#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""HowToLiveBetterBrief.md 标签体系（14 维 v3）全量体检脚本。

用法：python3 tools/tag_audit.py [brief路径]
默认路径：docs/HowToLiveBetterBrief.md

校验项：
  A 基本一致性：条目数 / id 唯一 / 每条 14 行标签
  B 词表符合性：各维度取值是否越出附录声明词表
  C 二义性：同一标签词跨维度出现（词形冲突）
  D 唯一性：14 维组合是否全局唯一；前 13 维冲突组明细
  E 区分力：各维度信息熵、主导值占比
  F 耦合抽查：显示方式×触发 等条件分布
  G 残留检查：声明中已改名/合并的词是否仍在数据中
  H 定位力：最优小维度子集能唯一识别多少条
"""
import collections
import itertools
import math
import os
import re
import sys

DIMS = ['频率', '触发', '类别', '关系角色', '人生阶段', '社会角色',
        '显示方式', '时机', '适用群体', '涉金', '场景', '依赖', '时效', '动作对象']

VOCAB = {  # 附录声明的封闭词表（类别/动作对象为开放词表，不在此列）
    0: '单次 每次 每天 每日多次 每周 每月 每年 季节性 定期 偶发'.split(),
    1: '日历时点 情境触发 突发事件 决策点'.split(),
    3: '自身 家人 子女 伴侣 父母 医生 雇主 合伙人 上级 下级 朋友 房东 陌生人'.split(),
    4: '婴幼儿 少年 青年 中年 老年 孕产'.split(),
    5: '全民 学生 求职者 上班族 灵活就业者 体力劳动者 程序员 创业者 司机 教师 家长 准父母 照护者 留学生 军人 创作者'.split(),
    6: '打卡 提醒 咨询 办事 速查 收藏'.split(),
    7: '事前 事中 事后'.split(),
    8: '通用 女性 男性 确诊慢病 残障人士 吸烟者 饮酒者 超重 性少数 经济困难 家有老人 租房人 购房人 出境者 养犬人 职工医保'.split(),
    9: '不涉及钱 能拿钱 要花钱 高风险钱'.split(),
    10: '在家 在职场 在医院 在户外 在夜里 在线上 在路上 不限场景'.split(),
    11: '可独立完成 需医生介入 需专业人士 需机构窗口 需家人配合 需单位配合'.split(),
    12: '长期有效 窗口期 政策敏感'.split(),
}
RENAME_LEFTOVER = ['慢性病', '省钱', '居家安全', '老人', '分时段', '多次', '每餐', '长期坚持']

CONTENT_DIMS = [0, 1, 2, 6, 7, 9, 11, 12, 13]  # 内容坐标
AUDIENCE_DIMS = [3, 4, 5, 8, 10]               # 受众剪枝


def toks(line):
    return [t.lstrip('#') for t in line.split() if t.startswith('#')]


def parse(path):
    items, cur, cur_sec = [], None, None
    item_re = re.compile(r'^#### (\d+)\. (.*)$')
    sec_re = re.compile(r'^## (\d+)\. (.*)$')
    for ln in open(path, encoding='utf-8').read().split('\n'):
        m = sec_re.match(ln)
        if m:
            if cur: items.append(cur); cur = None
            cur_sec = int(m.group(1)); continue
        if ln.startswith('## '):
            if cur: items.append(cur); cur = None
            cur_sec = None; continue
        m = item_re.match(ln)
        if m:
            if cur: items.append(cur)
            cur = {'sec': cur_sec, 'num': int(m.group(1)),
                   'title': m.group(2).strip(), 'tags': []}
            continue
        if cur is not None:
            s = ln.strip()
            if s.startswith('#'):
                cur['tags'].append(s)
            elif cur['tags']:
                items.append(cur); cur = None
    if cur: items.append(cur)
    return items


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'docs', 'HowToLiveBetterBrief.md')
    items = parse(path)

    print('== A 基本一致性 ==')
    print('条目数:', len(items))
    ids = [(it['sec'], it['num']) for it in items]
    dup = [k for k, v in collections.Counter(ids).items() if v > 1]
    print('重复 id:', dup or '无')
    hist = collections.Counter(len(it['tags']) for it in items)
    print('每条标签行数:', dict(sorted(hist.items())))
    for it in items:
        if len(it['tags']) != 14:
            print('  行数异常:', it['sec'], it['num'], it['title'][:30])

    print('\n== B 词表符合性 ==')
    for d, vocab in VOCAB.items():
        bad = collections.Counter()
        for it in items:
            for t in toks(it['tags'][d]):
                if t not in vocab: bad[t] += 1
        print(f'[{DIMS[d]}] 越出词表: {dict(bad) or "无"}')

    print('\n== C 跨维同词（词形二义性）==')
    sets = []
    for d in range(14):
        s = set()
        for it in items: s.update(toks(it['tags'][d]))
        sets.append(s)
    coll = [(t, DIMS[d], DIMS[e])
            for d in range(14) for e in range(d + 1, 14) for t in sets[d] if t in sets[e]]
    print('跨维同词:', coll or '无')

    print('\n== D 组合唯一性 ==')
    def key(it, dims): return tuple(it['tags'][d] for d in dims)
    c14 = collections.Counter(key(it, range(14)) for it in items)
    print('全14维 最大组:', max(c14.values()))
    c13 = collections.defaultdict(list)
    for it in items: c13[key(it, range(13))].append(f"{it['sec']}-{it['num']}")
    groups = [v for v in c13.values() if len(v) > 1]
    print('前13维 冲突组:', len(groups), '涉及条目:', sum(len(g) for g in groups))

    print('\n== E 各维度区分力 ==')
    for d in range(14):
        c = collections.Counter(it['tags'][d] for it in items)
        n = sum(c.values())
        H = -sum(v / n * math.log2(v / n) for v in c.values())
        top, topv = c.most_common(1)[0]
        print(f'{DIMS[d]:6s} H={H:5.2f}bit 主导 {top} {topv / n:5.1%} 取值 {len(c)}')

    print('\n== F 耦合抽查：显示方式×触发 ==')
    t = collections.Counter((it['tags'][6], it['tags'][1]) for it in items)
    for (a, b), n in sorted(t.items(), key=lambda x: -x[1])[:10]:
        print(f'   {a} × {b}: {n}')

    print('\n== G 改名/合并残留 ==')
    all_toks = collections.Counter(t for it in items for ln in it['tags'] for t in toks(ln))
    for w in RENAME_LEFTOVER:
        hits = {f'#{w}': all_toks[w]} if all_toks[w] else {}
        print(f'  {w}: {hits or "无"}')
    c13泛指 = sum(1 for it in items if '泛指' in toks(it['tags'][13]))
    print(f'  动作对象=泛指: {c13泛指}/{len(items)} ({c13泛指 / len(items):.1%})')

    print('\n== H 最优小维度子集（唯一识别条目数）==')
    def stats(dims):
        c = collections.Counter(key(it, dims) for it in items)
        u = sum(1 for it in items if c[key(it, dims)] == 1)
        return u, max(c.values())
    for label, pool, r in [('全14维', range(14), 2), ('内容侧9维', CONTENT_DIMS, 3),
                           ('内容侧9维', CONTENT_DIMS, 4)]:
        best = sorted(itertools.combinations(pool, r), key=lambda ds: (-stats(ds)[0],))[:3]
        for ds in best:
            u, mx = stats(ds)
            print(f'   {label} {r}维 {"+".join(DIMS[d] for d in ds)}: 唯一 {u}/{len(items)} ({u / len(items):.1%}) 最大组 {mx}')
    u, mx = stats(AUDIENCE_DIMS + CONTENT_DIMS)
    print(f'   内容+受众(除动作对象)13维: 唯一 {u}/{len(items)} 最大组 {mx}')


if __name__ == '__main__':
    main()
