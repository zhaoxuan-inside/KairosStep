#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""标签有效性分析：DF/IDF、语义覆盖宽度、默认值坍缩、章节别名、幽灵标签。

用法：python3 tools/tag_effectiveness.py [brief路径]
"""
import collections
import math
import os
import re
import sys

DIMS = ['频率', '触发', '类别', '关系角色', '人生阶段', '社会角色',
        '显示方式', '时机', '适用群体', '涉金', '场景', '依赖', '时效', '动作对象']
VOCAB = {
    3: '自身 家人 子女 伴侣 父母 医生 雇主 合伙人 上级 下级 朋友 房东 陌生人'.split(),
    5: '全民 学生 求职者 上班族 灵活就业者 体力劳动者 程序员 创业者 司机 教师 家长 准父母 照护者 留学生 军人 创作者'.split(),
    8: '通用 女性 男性 确诊慢病 残障人士 吸烟者 饮酒者 超重 性少数 经济困难 家有老人 租房人 购房人 出境者 养犬人 职工医保'.split(),
}


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
    N = len(items)

    # ---- token -> DF（按条目去重）、所属维度 ----
    tok_dims = collections.defaultdict(set)
    tok_df = collections.defaultdict(set)
    for idx, it in enumerate(items):
        for d, ln in enumerate(it['tags']):
            for t in toks(ln):
                tok_dims[t].add(d)
                tok_df[t].add(idx)

    def bits(df): return math.log2(N / df)

    print(f'== 1. 全库标签 token 总数: {len(tok_df)} ==')

    print('\n== 2. DF 排名（前 35，bits=log2(N/DF) 越大区分力越强）==')
    rank = sorted(tok_df.items(), key=lambda kv: -len(kv[1]))
    for t, s in rank[:35]:
        ds = '/'.join(DIMS[d] for d in sorted(tok_dims[t]))
        print(f'   #{t:<8s} [{ds}] DF={len(s):3d} ({len(s)/N:5.1%})  {bits(len(s)):5.2f} bit')

    print('\n== 3. 有效性分带 ==')
    bands = [('DF=N（全库都有，无效标签）', lambda df: df == N),
             ('DF≥40%（近常量，接近无效）', lambda df: df >= 0.4 * N),
             ('DF=1（幽灵标签，实为关键词）', lambda df: df == 1),
             ('DF=2-4（过窄，聚合价值低）', lambda df: 2 <= df <= 4)]
    for label, cond in bands:
        sel = [(t, len(s)) for t, s in tok_df.items() if cond(len(s))]
        print(f'   {label}: {len(sel)} 个  例: ' + ', '.join(
            f'#{t}({df})' for t, df in sorted(sel, key=lambda x: -x[1])[:12]))
    hist = collections.Counter()
    for t, s in tok_df.items():
        df = len(s)
        hist['1' if df == 1 else '2-4' if df <= 4 else '5-19' if df <= 19
             else '20-99' if df <= 99 else '100-399' if df <= 399 else '≥400'] += 1
    print('   DF 分布:', dict(hist))

    print('\n== 4. 声明词表中 DF=0 的死词 ==')
    for d, vocab in VOCAB.items():
        dead = [w for w in vocab if not tok_df.get(w)]
        if dead: print(f'   [{DIMS[d]}] {dead}')

    print('\n== 5. 章节别名检测（受众维 token 的最大章节占比≥70% 且 DF≥5）==')
    for d in (3, 4, 5, 8, 10):
        bytok = collections.defaultdict(collections.Counter)
        for it in items:
            for t in toks(it['tags'][d]):
                bytok[t][it['sec']] += 1
        for t, c in sorted(bytok.items()):
            df = sum(c.values()); sec, cnt = c.most_common(1)[0]
            if cnt / df >= 0.7 and df >= 5:
                print(f'   #{t:<6s} DF={df:3d}  节{sec} 占 {cnt/df:.0%}')

    print('\n== 6. 默认值坍缩抽查：应打未打 ==')
    FEM = ['HPV', '宫颈', '乳腺', '痛经', '绝经', '潮热', '子宫', '卵巢',
           '月经', '妇科', '产妇', '孕', '哺乳']
    MAL = ['前列腺', '勃起', '睾丸', '遗精', '精子']
    for name, terms, want in [('女性', FEM, '女性'), ('男性', MAL, '男性')]:
        hits = [it for it in items if any(w in it['title'] for w in terms)]
        dist = collections.Counter('女性' in toks(it['tags'][8]) or '男性' in toks(it['tags'][8])
                                   for it in hits)
        print(f'   标题含{name}特征的条目 {len(hits)} 条，其中适用群体已标[{want}]: {dist.get(True, 0)}')
        for it in hits[:6]:
            print(f'      {it["sec"]}-{it["num"]} 适用群体={it["tags"][8]}  {it["title"][:28]}')
    s16 = [it for it in items if it['sec'] == 16]
    d16 = collections.Counter('确诊慢病' in toks(it['tags'][8]) for it in s16)
    print(f'   节16(慢性病生活) {len(s16)} 条，标[确诊慢病]: {d16.get(True, 0)}')

    print('\n== 7. 上位词坍缩抽查（大伞标签的子词混居）==')
    def fam(parent, children):
        both = only_p = only_c = 0
        for it in items:
            ts = set(toks(it['tags'][2]))
            if parent in ts and ts & children: both += 1
            elif parent in ts: only_p += 1
            elif ts & children: only_c += 1
        print(f'   {parent}: 仅父 {only_p} | 父+子 {both} | 仅子 {only_c}')
    fam('健康', {'用药', '筛查', '疫苗', '急救', '睡眠', '运动', '饮食', '慢性病', '女性健康', '性健康', '医疗'})
    fam('安全', {'居家安全', '网络安全', '防骗'})
    fam('家庭', {'育儿', '老人', '婚恋', '生育'})
    st = [it for it in items if '学生' in toks(it['tags'][5])]
    print(f'   #学生 {len(st)} 条的人生阶段分布:',
          dict(collections.Counter(it['tags'][4] for it in st)))

    print('\n== 8. 负定义/默认值 token 清单（定义含"无/不/不限/泛指"语义）==')
    for t, s in sorted(tok_df.items(), key=lambda kv: -len(kv[1])):
        if t in {'泛指', '通用', '不限场景', '偶发', '定期', '全民', '不涉及钱', '自身'}:
            ds = '/'.join(DIMS[d] for d in sorted(tok_dims[t]))
            print(f'   #{t:<6s} [{ds}] DF={len(s):3d} ({len(s)/N:5.1%})')


if __name__ == '__main__':
    main()
