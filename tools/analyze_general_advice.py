"""Rebuild the empty-prerequisite audit without treating it as universal visibility.

Run: py -3 tools/analyze_general_advice.py
Reads generated assets only; never changes runtime data or gating rules.
"""
import json
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'app/assets/data'
OUT = ROOT / 'output/general-advice'
# Legacy defaults have no positive theme meaning. Keep source/runtime tags intact,
# but exclude these values from analytical facets, search, and parameter totals.
DEFAULT_TAGS = {'通用', '泛指'}


def read(name):
    return json.loads((DATA / (name + '.json')).read_text(encoding='utf-8'))


def analyze():
    advice = read('entity/advice')['list']
    dimensions = {r['tag']: r['dimensionKey'] for r in read('facets/tag')['list']}
    tags = defaultdict(lambda: defaultdict(list))
    excluded_ids = defaultdict(set)
    for r in read('facets/advice_tag')['list']:
        if r['tag'] in DEFAULT_TAGS:
            excluded_ids[r['tag']].add(r['id'])
            continue
        tags[r['id']][dimensions[r['tag']]].append(r['tag'])
    paths = defaultdict(list)
    for r in read('entity/advice_node')['list']:
        paths[r['id']].append((r['ordinal'], r['path']))
    labels = {}

    def visit(nodes, parent='', names=()):
        for key, node in nodes.items():
            path = parent + '/' + key if parent else key
            chain = (*names, node['name'])
            labels[path] = ' / '.join(chain)
            visit(node.get('sub', {}), path, chain)

    visit(read('dimensions/taxonomy'))
    plans = {r['id']: r for r in read('triggers/advice_trigger')['list']}
    details = {r['adviceId']: r for r in read('entity/advice_detail')['list']}
    gates = read('config/gates')
    modes = {'daily': '每日计划', 'cadence': '周期计划', 'dormant': '按需储备'}
    all_rows = []
    for a in advice:
        i = a['id']
        memberships = [p for _, p in sorted(paths[i])]
        plan = plans[i]
        # Emergency is a presentation lane, not a newly inferred medical priority.
        lane = '紧急速查' if plan.get('emergency') else modes[plan['mode']]
        t = tags[i]
        all_rows.append(dict(id=i, title=a['title'], chapter=a['chapterCode'],
                         topic=labels[memberships[0]], paths=memberships,
                         lane=lane, mode=plan['mode'], badge=a['badgeKey'],
                         grade=details[i]['grade'], tags=dict(t),
                         ruleSets=[k for k, ids in gates['ruleIdSets'].items() if i in ids]))
    empty_source_ids = {a['id'] for a in advice if not a['prerequisites']}
    rows = [r for r in all_rows if r['id'] in empty_source_ids]
    # Use one primary membership per row for additive totals. Cross-links remain searchable.
    groups = defaultdict(list)
    for r in rows:
        groups[(r['topic'], r['lane'])].append(r['id'])
    metrics = dict(total=len(advice), empty=len(rows), suppliedBaseline=490,
                   baselineDifference=len(rows)-490,
                   lanes=dict(Counter(r['lane'] for r in rows)),
                   primaryTopics=len({r['topic'] for r in rows}),
                   topicLaneGroups=len(groups),
                   largestTopicLaneGroup=max(map(len, groups.values())),
                   explicitRuleSetReferences=sum(bool(r['ruleSets']) for r in rows))
    assert len({r['id'] for r in rows}) == len(rows)
    assert sum(metrics['lanes'].values()) == len(rows)
    assert all(r['paths'] and r['grade'] in 'ABC' for r in rows)
    empty_ids = {r['id'] for r in rows}
    dimension_stats = []
    for dimension in read('facets/tag_dimension')['list']:
        key = dimension['key']
        value_ids = defaultdict(set)
        for advice_id, advice_tags in tags.items():
            for value in advice_tags.get(key, []):
                value_ids[value].add(advice_id)
        covered = set().union(*value_ids.values()) if value_ids else set()
        dimension_stats.append(dict(
            key=key, name=dimension['name'], coverage=len(covered),
            emptyCoverage=len(covered & empty_ids),
            missing=len(advice)-len(covered),
            values=[dict(value=value, coverage=len(ids),
                         emptyCoverage=len(ids & empty_ids))
                    for value, ids in sorted(value_ids.items(),
                                             key=lambda pair: (-len(pair[1]), pair[0]))]))
    metrics['rawParameterCount'] = len(dimensions)
    metrics['effectiveParameterCount'] = sum(len(d['values']) for d in dimension_stats)
    excluded_defaults = [dict(value=value, coverage=len(ids),
                              emptyCoverage=len(ids & empty_ids))
                         for value, ids in sorted(excluded_ids.items())]
    union_ids = set().union(*excluded_ids.values())
    default_splits = []
    for name, ids in [('合并去重', union_ids), *sorted(excluded_ids.items())]:
        selected = [r for r in all_rows if r['id'] in ids]
        split_groups = defaultdict(list)
        for row in selected:
            split_groups[(row['paths'][0], row['lane'])].append(row['id'])
        default_splits.append(dict(
            name=name, count=len(ids), ids=sorted(ids),
            topicCount=len({r['paths'][0] for r in selected}),
            domains=[dict(key=key, name=labels[key], count=count)
                     for key, count in sorted(Counter(r['paths'][0].split('/')[0]
                                                     for r in selected).items())],
            groups=[dict(path=path, topic=labels[path], domain=path.split('/')[0],
                         lane=lane, count=len(group_ids), ids=group_ids)
                    for (path, lane), group_ids in sorted(split_groups.items())]))
    metrics['defaultOverlapCount'] = len(set.intersection(*excluded_ids.values()))
    return dict(metrics=metrics, dimensionStats=dimension_stats,
                excludedDefaults=excluded_defaults, rows=rows,
                defaultSplits=default_splits,
                defaultSplitRows=[r for r in all_rows if r['id'] in union_ids])


CANVAS = '''import {useState, useHostTheme} from "cursor/canvas";
const data = __DATA__;
const axes = {topic:"主题",lane:"触发入口",chapter:"章节",grade:"证据等级",scene:"场景",audience:"适用对象",role:"社会角色",stage:"人生阶段",money:"金钱",reliance:"执行依赖",validity:"时效",frequency:"频率",timing:"行动时机"};
export default function Review(){
 const theme=useHostTheme();
 const [filters,setFilters]=useState<Record<string,string>>({});
 const [query,setQuery]=useState(""); const [page,setPage]=useState(0);
 const [parameterDimension,setParameterDimension]=useState("stage");
 const [parameterPage,setParameterPage]=useState(0);
 const [splitScope,setSplitScope]=useState("合并去重");
 const [splitDomain,setSplitDomain]=useState("");
 const [splitGroup,setSplitGroup]=useState("");
 const [splitPage,setSplitPage]=useState(0);
 const split=data.defaultSplits.find(s=>s.name===splitScope)!;
 const splitGroups=split.groups.filter(g=>!splitDomain||g.domain===splitDomain);
 const group=splitGroups.find(g=>g.path+"|"+g.lane===splitGroup)||splitGroups[0];
 const groupIds=new Set(group.ids);
 const splitRows=data.defaultSplitRows.filter(r=>groupIds.has(r.id));
 const splitPages=Math.ceil(splitRows.length/20);
 const parameterStats=data.dimensionStats.find(d=>d.key===parameterDimension)!;
 const parameterPages=Math.ceil(parameterStats.values.length/20);
 const values=(r:any,k:string):string[] => k in r ? [r[k]] : r.tags[k]||[];
 const filtered=data.rows.filter(r=>(!query||JSON.stringify(r).includes(query))&&Object.entries(filters).every(([k,v])=>!v||values(r,k).includes(v)));
 const pages=Math.max(1,Math.ceil(filtered.length/20)); const current=Math.min(page,pages-1);
 const m=data.metrics;
 return <main style={{background:theme.bg.editor,color:theme.text.primary,padding:24,fontSize:14,lineHeight:1.65}}>
 <h1 style={{fontSize:24}}>“无前置”建议重新分析</h1>
 <p>数据源：app/assets/data 当前工作区快照 · 2026-11-08。分析前置字段为空的建议，不计算任何用户的最终可见集合。</p>
 <h2 style={{fontSize:20}}>{m.empty} 条待分流 / 全库 {m.total} 条</h2>
 <p>原反馈为 490 条；当前空前置字段有 {m.empty} 条，相差 {m.baselineDifference} 条，原 490 条的 ID 集尚未提供，不能视为同一统计集合。</p>
 <p>空 prerequisites 只表示该字段没有限制；标签、特定章节和运行时门禁仍可能限制适用性。“所有人可见”应改为“未设置显式画像前置”。</p>
 <section style={{display:"flex",gap:24,flexWrap:"wrap",borderBottom:`1px solid ${theme.stroke.primary}`,paddingBottom:16}}>
 {Object.entries(m.lanes).map(([label,n])=><div key={label}><strong style={{fontSize:20}}>{n}</strong><div>{label}</div></div>)}
 </section>
 <h2 style={{fontSize:18}}>“通用 / 泛指”已按具体主题拆分</h2>
 <p>这是原两个标签对应的全库集合，与下方无前置集合不同。二者重叠 {m.defaultOverlapCount} 条；合并去重 {data.defaultSplits[0].count} 条。按已有主主题和触发入口分组，未重新推断人群适用性。</p>
 <label>原标签范围 <select value={splitScope} onChange={e=>{setSplitScope(e.target.value);setSplitDomain("");setSplitGroup("");setSplitPage(0)}}>{data.defaultSplits.map(s=><option key={s.name} value={s.name}>{s.name}：{s.count} 条 / {s.topicCount} 个主题</option>)}</select></label>
 <p>{split.domains.map(d=>`${d.name} ${d.count} 条`).join(" · ")}</p>
 <label>领域 <select value={splitDomain} onChange={e=>{setSplitDomain(e.target.value);setSplitGroup("");setSplitPage(0)}}><option value="">全部领域</option>{split.domains.map(d=><option key={d.key} value={d.key}>{d.name}（{d.count} 条）</option>)}</select></label>
 <div><label>具体主题与触发入口 <select style={{maxWidth:"100%"}} value={group.path+"|"+group.lane} onChange={e=>{setSplitGroup(e.target.value);setSplitPage(0)}}>{splitGroups.map(g=><option key={g.path+"|"+g.lane} value={g.path+"|"+g.lane}>{g.topic} · {g.lane}（{g.count} 条）</option>)}</select></label></div>
 <p>{group.topic} · {group.lane}：{group.count} 条</p>
 {splitRows.slice(splitPage*20,splitPage*20+20).map(r=><div key={r.id} style={{padding:"6px 0",borderBottom:`1px solid ${theme.stroke.primary}`}}>#{r.id} {r.title}</div>)}
 {splitPages>1&&<nav style={{display:"flex",gap:12,marginTop:12}}><button disabled={splitPage===0} onClick={()=>setSplitPage(splitPage-1)}>上一页建议</button><span>{splitPage+1} / {splitPages}</span><button disabled={splitPage+1>=splitPages} onClick={()=>setSplitPage(splitPage+1)}>下一页建议</button></nav>}
 <p>按主主题分为 {m.primaryTopics} 类，再按触发入口拆为 {m.topicLaneGroups} 组；最大组 {m.largestTopicLaneGroup} 条。交叉挂载保留用于检索，计数只取主挂载，避免重复。每页最多显示 20 条。</p>
 <h2 style={{fontSize:18}}>12 个底层标签维度的覆盖</h2>
 <p>下列数量分别为全库 / 无前置集合，按建议 ID 去重。维度间存在重叠，不能相加。</p>
 <div style={{display:"grid",gridTemplateColumns:"repeat(auto-fit,minmax(220px,1fr))",gap:12}}>{data.dimensionStats.map(d=><div key={d.key}><strong>{d.name}</strong>：{d.coverage} / {d.emptyCoverage} 条<div style={{color:theme.text.secondary}}>实际取值 {d.values.length} 种 · 全库未标注 {d.missing} 条</div></div>)}</div>
 <h2 style={{fontSize:18}}>全部 {m.effectiveParameterCount} 个有效分析参数的建议覆盖数</h2>
 <p>原始字典保留 {m.rawParameterCount} 个标签。“通用”“泛指”作为历史默认值，从本视图的参数、筛选与建议检索数据中排除；原始标签与现有门禁保留。</p>
 <p>选择任意维度查看所有实际出现的参数。每页最多 20 项；数量为全库 / 无前置集合。参数为原始标签的当前分类，不代表最终画像门禁判定。</p>
 <select aria-label="参数所属维度" value={parameterDimension} onChange={e=>{setParameterDimension(e.target.value);setParameterPage(0)}}>{data.dimensionStats.map(d=><option key={d.key} value={d.key}>{d.name}（{d.values.length} 个参数）</option>)}</select>
 <p>{parameterStats.name}覆盖 {parameterStats.coverage} / 737 条，全库未标注 {parameterStats.missing} 条。</p>
 <section>{parameterStats.values.slice(parameterPage*20,parameterPage*20+20).map(v=><div key={v.value} style={{display:"flex",justifyContent:"space-between",padding:"5px 0",borderBottom:`1px solid ${theme.stroke.primary}`}}><span>{v.value}</span><span>{v.coverage} / {v.emptyCoverage} 条</span></div>)}</section>
 {parameterPages>1&&<nav style={{display:"flex",gap:12,marginTop:12}}><button disabled={parameterPage===0} onClick={()=>setParameterPage(parameterPage-1)}>上一页参数</button><span>{parameterPage+1} / {parameterPages}</span><button disabled={parameterPage+1>=parameterPages} onClick={()=>setParameterPage(parameterPage+1)}>下一页参数</button></nav>}
 <h2 style={{fontSize:18}}>交叉筛选建议</h2>
 <input aria-label="搜索标题、标签或 ID" placeholder="搜索标题、标签或 ID" value={query} onChange={e=>{setQuery(e.target.value);setPage(0)}} style={{padding:8,width:"95%"}}/>
 <div style={{display:"flex",gap:12,flexWrap:"wrap",marginTop:12}}>{Object.entries(axes).map(([key,label])=><label key={key}>{label}<br/><select aria-label={label} value={filters[key]||""} onChange={e=>{setFilters({...filters,[key]:e.target.value});setPage(0)}} style={{maxWidth:270,padding:6}}><option value="">全部</option>{Array.from(new Set(data.rows.flatMap(r=>values(r,key)))).sort().map(v=><option key={v} value={v}>{v}</option>)}</select></label>)}</div>
 <p>筛选后 {filtered.length} 条 · 第 {current+1} / {pages} 页 <button onClick={()=>{setFilters({});setQuery("");setPage(0)}}>清空筛选</button></p>
 {filtered.slice(current*20,current*20+20).map(r=><article key={r.id} style={{padding:"14px 0",borderTop:`1px solid ${theme.stroke.primary}`}}><strong>#{r.id} {r.title}</strong><div style={{color:theme.text.secondary}}>{r.topic} · {r.lane} · 证据 {r.grade}</div><div>{r.badge}</div><small>{Object.entries(r.tags).filter(([k])=>["scene","role","audience","timing","reliance"].includes(k)).map(([,v])=>v.join("、")).join(" · ")}</small>{r.ruleSets.length>0&&<div>已有显式门禁规则集引用：{r.ruleSets.join("、")}</div>}</article>)}
 <nav style={{display:"flex",gap:12,marginTop:16}}><button disabled={current===0} onClick={()=>setPage(current-1)}>上一页</button><button disabled={current+1>=pages} onClick={()=>setPage(current+1)}>下一页</button></nav>
 <h2 style={{fontSize:18}}>展示与后续标注规则</h2>
 <ol><li>每日与周期计划进入相应计划入口；按需储备保留在专题库；紧急速查保留独立、易发现入口。此处是分流分析，不代表已启用通知。</li><li>默认折叠专题，只显示数量和摘要；展开后分页。不要将全部“无前置”记录铺在首页。</li><li>新增待人工复核指标：触发事件、所处任务阶段、一次投入时间、资金成本、完成状态、近期重复曝光。现有数据无法可靠推导，不能把未知值写成确定值。</li><li>证据等级仅展示原始 A/B/C，不能当作收益或优先级排序。场景、对象等多值指标允许重叠，不能直接相加。</li><li>本视图不重写门禁。新增适用条件应逐条核对原文，再通过源数据流水线与现有 GatekeeperEngine 验证。</li></ol>
 </main>;
}
'''


if __name__ == '__main__':
    result = analyze()
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'analysis.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (OUT / 'general-advice.canvas.tsx').write_text(CANVAS.replace('__DATA__', json.dumps(result, ensure_ascii=False)), encoding='utf-8')
    report = [
        '# 全库维度与参数覆盖明细', '',
        '统计日期：2026-11-08。由 `py -3 tools/analyze_general_advice.py` 重建。', '',
        '数据源：`app/assets/data/facets/{tag_dimension,tag,advice_tag}.json` 与 `entity/advice.json`。', '',
        f"全库 {result['metrics']['total']} 条；无前置集合 {result['metrics']['empty']} 条。共 {len(result['dimensionStats'])} 个底层维度、{result['metrics']['effectiveParameterCount']} 个有效分析参数；原始字典保留 {result['metrics']['rawParameterCount']} 个标签。", '',
        '每项数字依次为 **全库 / 无前置集合** 的建议数，按建议 ID 去重。多值参数可以重叠，不能将参数数量相加作为覆盖条数；未标注不等于不适用。这里只统计当前字典实际出现的参数，不包含未使用的预留词。', '',
        '“通用”“泛指”作为历史默认值，从有效分析参数、筛选和建议检索数据中排除，原始标签与原有角色门禁语义仍保留。这两项不再充当主题分类或作为推荐相关性的正向依据。App 的具体主题关注通过 focusTopics 单独保存与筛选，不从这两个默认标签推导。', '',
        *[f"已排除默认值 {v['value']}：原始覆盖 {v['coverage']} / {v['emptyCoverage']} 条（仅供审计，不计入下方参数）。" for v in result['excludedDefaults']], '',
        '当前 theme 是未命中受控词表的开放集合，其中仍混有“在户外、婴幼儿、季节性”等非主题含义的标签。本报告忠实列出当前分类，不把该分类视为已经完成语义审核。', '',
    ]
    for dimension in result['dimensionStats']:
        report.extend([
            f"## {dimension['name']}（{dimension['key']}）", '',
            f"参数 {len(dimension['values'])} 个；覆盖 {dimension['coverage']} / {dimension['emptyCoverage']} 条；未标注 {dimension['missing']} / {result['metrics']['empty']-dimension['emptyCoverage']} 条。", '',
            *[f"- {v['value']}：{v['coverage']} / {v['emptyCoverage']} 条。" for v in dimension['values']], '',
        ])
    (ROOT / 'docs/optimization/2026-11-08-维度参数覆盖明细.md').write_text('\n'.join(report), encoding='utf-8')
    split_report = [
        '# 通用与泛指建议拆分明细', '',
        '统计日期：2026-11-08；运行 `py -3 tools/analyze_general_advice.py` 重建。', '',
        '按已有主主题挂载与触发计划分组，不从标题猜测新门禁条件。每个范围内，每条建议只进入一个主主题与触发入口组合，额外主题挂载保留在 JSON 中。', '',
        '、'.join(f"{s['name']} {s['count']} 条" for s in result['defaultSplits'][1:]) + f"，重叠 {result['metrics']['defaultOverlapCount']} 条；合并去重 {result['defaultSplits'][0]['count']} 条。两个原标签范围的数量不可直接相加。此处是全库原标签范围，不是 {result['metrics']['empty']} 条无前置集合。", '',
        '这是分析与浏览分组，不是把原始通用/泛指标签改成多个画像标签；原始门禁语义保留。完整建议 ID、标题及其他主题挂载见 output/general-advice/analysis.json。', '',
        'App 正式分类数据为 app/assets/data/views/advice_classification.json，覆盖全部建议；生活指南按领域、主题与触发入口折叠并分页。画像引导新增具体主题选择，使用 focusTopics 字段持久化，空数组不限定主题。', '',
    ]
    for split in result['defaultSplits']:
        split_report.extend([f"## {split['name']}：{split['count']} 条 / {split['topicCount']} 个主主题", ''])
        for domain in split['domains']:
            split_report.extend([f"### {domain['name']}：{domain['count']} 条", ''])
            for group in split['groups']:
                if group['domain'] == domain['key']:
                    split_report.append(f"- {group['topic']} · {group['lane']}：{group['count']} 条；ID：" + '、'.join(map(str, group['ids'])) + '。')
            split_report.append('')
    (ROOT / 'docs/optimization/2026-11-08-通用与泛指拆分明细.md').write_text('\n'.join(split_report), encoding='utf-8')
    print(json.dumps(result['metrics'], ensure_ascii=False, indent=2))
