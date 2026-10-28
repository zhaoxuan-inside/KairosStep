#!/usr/bin/env python3
"""同步建议详情文档与 AdviceInteractiveDemo 的交互类型。

依据 Brief 标签（显示方式 × 时机）推导每条建议的正确交互类型，修正三类错配：
1. 知识/红线类被套「14天窗口期」/「确认打卡」 → 红线铭记卡 redline-stamp / 情境拦截卡 context-guard
2. 决策规则类被套「达成度滑块」             → 决策核对卡 decision-check
3. 办事流程类被套「窗口期模板」             → 办事分步卡 process-steps

同时重写详情文档对应条目的「建议理解 / 触发时机与条件 / 交互设计」三节，
并登记新组件到 HowToLiveBetterDesign.md 组件库。

用法：python3 tools/sync_interaction_types.py [--dry-run]
注意：本脚本按「一次性迁移」设计，重复执行前需确认 demo 数据已是迁移后状态。
"""
import json
import re
import sys
from collections import Counter

ROOT = '/home/hardstone/Share/Common/CodeSpace/KairosStep'
DEMO = f'{ROOT}/docs/AdviceInteractiveDemo.html'
DETAIL = f'{ROOT}/docs/inactive_detail_design.md'
COMPONENTS = f'{ROOT}/docs/HowToLiveBetterDesign.md'
DRY = '--dry-run' in sys.argv

# ---------- 分类规则（由 Brief 标签推导，取代手写 id 特判） ----------

KEEP_TYPES = {'emergency-action', 'daily-streak', 'zen-timer',
              'evidence-checklist', 'wage-calc', 'haptic-toggle'}
SLIDER_SPECIAL = {687, 92, 256, 292, 614, 720, 745}  # 有真实量化对象的测算条目

BADGES = {
    'redline-stamp': ('红线知识 · 背熟即防',
                      '无到期日、无周期提醒；进入章节或搜索命中时展示，盖章背熟一次即长期生效'),
    'context-guard': ('情境拦截 · 场景自检',
                      '仅在触发场景出现时弹出合规自检，场景结束即静默，不做每日打卡'),
    'decision-check': ('决策规则 · 用前核对',
                       '仅在花钱/投资/签约等决策情境前置出现，逐项核对规则，不做达成度测算'),
    'process-steps': ('办事流程 · 分步推进',
                      '按办理步骤推进，当前步高亮，材料逐项对照留档；法定时限步骤才用窗口倒计时'),
}


def classify(item):
    """返回新 (act_type, badge, desc) 或 None 表示保持不变。"""
    at, tags = item['act_type'], set(item['tags'])
    if at in KEEP_TYPES:
        return None
    if at == 'slider-calc':
        if item['id'] in SLIDER_SPECIAL:
            return None
        return ('decision-check',) + BADGES['decision-check']
    if at == 'windowed-cadence':
        if '提醒' in tags or '打卡' in tags:
            return None  # 真实周期窗口，保留
        if '办事' in tags or '咨询' in tags:
            return ('process-steps',) + BADGES['process-steps']
        if '收藏' in tags or '速查' in tags:
            return ('redline-stamp',) + BADGES['redline-stamp']
        return None
    if at == 'quick-checkin':
        if '打卡' in tags or '提醒' in tags:
            return None
        if '办事' in tags or '咨询' in tags:
            return ('process-steps',) + BADGES['process-steps']
        if '收藏' in tags:
            t = 'context-guard' if '情境触发' in tags else 'redline-stamp'
            return (t,) + BADGES[t]
        if '速查' in tags:
            return ('redline-stamp',) + BADGES['redline-stamp']
        return None
    return None


def extract_data(html):
    m = re.search(r'const ALL_ENRICHED_ADVICE = (\[.*?\]);\n', html, re.S)
    return m, json.loads(m.group(1))


def rebuild_data_array(items):
    rows = []
    for d in items:
        row = {'id': d['id'], 'c': d['c'], 't': d['t'], 'parts': d['parts'],
               'timing_badge': d['timing_badge'], 'act_type': d['act_type'],
               'tags': d['tags']}
        rows.append(row)
    return 'const ALL_ENRICHED_ADVICE = ' + json.dumps(
        rows, ensure_ascii=False, separators=(',', ': ')) + ';\n'


# ---------- 渲染层新增分支与函数 ----------

RENDER_BRANCHES = r'''
  // ================= 6-F. 红线铭记卡 (redline-stamp) =================
  // 长期成立的规则/红线知识：无到期日、无每日打卡，盖章背熟一次即长期生效
  else if (type === 'redline-stamp') {
    completeMsg = "已盖章背熟，此规则长期生效";
    const note = caveats.length ? caveats.join('；') : '';
    interactiveWidgetHtml = `
      <div class="myth-stamp-card">
        <div class="myth-verdict-tag">长期成立的规则 · 无需每日打卡</div>
        ${note ? `<div style="font-size:11.5px; color:var(--text-pure); margin-bottom:8px; line-height:1.4;">${note}</div>` : ''}
        <div style="display:flex; justify-content:flex-end;">
          <div class="myth-stamp-btn ${isDone ? 'stamped' : ''}" onclick="stampKnowledge(this)">
            <svg class="svg-icon" style="width:12px; height:12px;" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><polyline points="16 8 12 12 8 10" style="display:none"></polyline></svg>
            <span>${isDone ? '已背熟 · 长期生效' : '盖章背熟'}</span>
          </div>
        </div>
      </div>
    `;
  }

  // ================= 6-G. 情境拦截卡 (context-guard) =================
  // 禁止/规避性规则：场景出现时做单次合规自检，不做每日确认打卡
  else if (type === 'context-guard') {
    completeMsg = "本次场景合规自检完成";
    const scene = item.tags.includes('在家') ? '在家' : item.tags.includes('在路上') ? '在路上' : item.tags.includes('在户外') ? '在户外' : '相关场景';
    const note = caveats.length ? caveats.join('；') : '';
    interactiveWidgetHtml = `
      <div class="buckle-interactive-box">
        <div style="font-size:11.5px; color:var(--text-mute); margin-bottom:6px;">触发场景：${scene} · 场景出现时自检一次</div>
        ${note ? `<div style="font-size:11.5px; color:var(--text-sub); margin-bottom:8px; line-height:1.4;">${note}</div>` : ''}
        <div class="k-action-chip ${isDone ? 'active' : ''}" onclick="confirmGuard(this, ${id})">
          <svg class="svg-icon" style="width:11px; height:11px;" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle></svg>
          <span>${isDone ? '本次我做到了' : '场景出现 · 待自检'}</span>
        </div>
      </div>
    `;
  }

  // ================= 6-H. 决策核对卡 (decision-check) =================
  // 决策规则：没有可量化达成度，不做滑块；决策前逐项核对
  else if (type === 'decision-check') {
    completeMsg = "决策规则核对完毕";
    interactiveWidgetHtml = caveats.length > 0 ? `
      <div class="steps-progress-row">
        <span class="steps-progress-label">核对项 <b>0/${caveats.length}</b></span>
        <div class="steps-progress-track"><div class="steps-progress-fill"></div></div>
      </div>
      <div class="action-chips-container">
        ${caveats.map((c) => `
          <div class="k-action-chip" onclick="toggleActionChip(this, '${c.replace(/'/g, "\\'")}')">
            <svg class="svg-icon" style="width:11px; height:11px;" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle></svg>
            <span>${c}</span>
          </div>
        `).join('')}
      </div>
    ` : `
      <div class="checkline ${isDone ? 'done' : ''}" onclick="toggleGenericDone(this)">
        <svg class="svg-icon" style="width:13px; height:13px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
        <span>${isDone ? '已记住，决策时执行' : '下次决策前按此规则核对'}</span>
      </div>
    `;
  }

  // ================= 6-I. 办事分步卡 (process-steps) =================
  // 办事/就诊/维权流程：步骤依次推进，当前步高亮，法定时限步骤才用倒计时
  else if (type === 'process-steps') {
    completeMsg = "全部步骤完成，事项办结";
    const steps = parts.length > 1 ? caveats : [];
    interactiveWidgetHtml = steps.length > 0 ? `
      <div class="steps-progress-row">
        <span class="steps-progress-label">办理进度 <b>0/${steps.length}</b></span>
        <div class="steps-progress-track"><div class="steps-progress-fill"></div></div>
      </div>
      <div class="action-chips-container">
        ${steps.map((s, i) => `
          <div class="k-action-chip" onclick="toggleActionChip(this, '第${i + 1}步：${s.replace(/'/g, "\\'")}')">
            <span style="display:inline-flex; align-items:center; justify-content:center; width:16px; height:16px; border-radius:50%; background:var(--accent-action); color:#fff; font-size:10px; font-weight:700; flex-shrink:0;">${i + 1}</span>
            <span>${s}</span>
          </div>
        `).join('')}
      </div>
    ` : `
      <div class="checkline ${isDone ? 'done' : ''}" onclick="toggleGenericDone(this)">
        <svg class="svg-icon" style="width:13px; height:13px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
        <span>${isDone ? '事项已办结' : '进入办事场景 · 开始办理'}</span>
      </div>
    `;
  }
'''

NEW_FUNCTIONS = r'''
// 红线铭记卡：盖章背熟一次即长期生效，不做每日打卡
function stampKnowledge(btnEl) {
  btnEl.classList.toggle('stamped');
  const stamped = btnEl.classList.contains('stamped');
  const textSpan = btnEl.querySelector('span');
  if (textSpan) textSpan.innerHTML = stamped ? '<svg class="svg-icon" style="width:12px; height:12px; margin-right:3px; vertical-align:-1px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>已背熟 · 长期生效' : '盖章背熟';
  notifyIsland(stamped ? '已盖章背熟，长期生效，无需每日打卡' : '已撤销盖章');
  updateCardProgress(btnEl.closest('.action-bento'), '.myth-stamp-btn', 'stamped');
}

// 情境拦截卡：场景出现时单次合规自检，无连续计数
function confirmGuard(chipEl, id) {
  chipEl.classList.toggle('active');
  const active = chipEl.classList.contains('active');
  const icon = chipEl.querySelector('svg');
  if (icon) icon.innerHTML = active ? '<polyline points="20 6 9 17 4 12"></polyline>' : '<circle cx="12" cy="12" r="9"></circle>';
  const label = chipEl.querySelector('span');
  if (label) label.textContent = active ? '本次我做到了' : '场景出现 · 待自检';
  const item = ALL_ENRICHED_ADVICE.find(i => i.id === id);
  if (item) item._done = active;
  const card = chipEl.closest('.action-bento');
  if (card) card.classList.toggle('completed', active);
  notifyIsland(active ? '本次场景合规自检完成' : '已重置本次自检');
}
'''

NEW_ICONS = r'''
    'redline-stamp': `<svg class="svg-icon ${extraClass}" style="width:${size}px; height:${size}px;" viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>`,
    'context-guard': `<svg class="svg-icon ${extraClass}" style="width:${size}px; height:${size}px;" viewBox="0 0 24 24"><path d="M12 2L2 7l10 5 10-5-10-5z"></path><path d="M2 17l10 5 10-5"></path><path d="M2 12l10 5 10-5"></path></svg>`,
    'decision-check': `<svg class="svg-icon ${extraClass}" style="width:${size}px; height:${size}px;" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"></path><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>`,
    'process-steps': `<svg class="svg-icon ${extraClass}" style="width:${size}px; height:${size}px;" viewBox="0 0 24 24"><line x1="8" y1="6" x2="21" y2="6"></line><line x1="8" y1="12" x2="21" y2="12"></line><line x1="8" y1="18" x2="21" y2="18"></line><line x1="3" y1="6" x2="3.01" y2="6"></line><line x1="3" y1="12" x2="3.01" y2="12"></line><line x1="3" y1="18" x2="3.01" y2="18"></line></svg>`,'''

NEW_TYPE_DEFS = """  { id: 'redline-stamp', name: '红线铭记', iconName: 'redline-stamp' },
  { id: 'context-guard', name: '情境拦截', iconName: 'context-guard' },
  { id: 'decision-check', name: '决策核对', iconName: 'decision-check' },
  { id: 'process-steps', name: '办事分步', iconName: 'process-steps' }
];"""

# ---------- 详情文档分节模板 ----------

DOC_BLOCKS = {
    'redline-stamp': """**2）建议理解**：
- **主行动性质**：长期成立的规则/红线知识，不存在到期日与「完成」状态；价值在于被记住、并在关键情境被想起来，而不是被每天打卡。
- **伴随备忘**：规则内含的避坑要点与后果（钱/刑/时限）随卡片一并展示，无需逐日确认。

**3）触发时机与条件**：
- **时机模型**：红线知识铭记型（Knowledge Stamp）。
- **触发源**：进入相关章节、本地搜索命中关键词，或路由表命中关联场景时展示；不做日常推荐打扰。
- **频率约束**：同一规则对同一用户 30 天内至多主动浮现一次。

**4）交互设计**：
- **红线铭记卡**：展示规则要点，用户「盖章背熟」一次即长期生效，卡片沉入收藏可复习；无连续计数、无周期提醒。
- **操作响应**：`[ 盖章背熟 ]` · `[ 稍后 ]`""",
    'context-guard': """**2）建议理解**：
- **主行动性质**：只在特定场景下需要生效的禁止/规避性规则；「确认打卡」表达不了「场景出现时没违反」，必须绑定场景信号做单次合规自检。

**3）触发时机与条件**：
- **时机模型**：情境拦截型（Context Guard）。
- **触发源**：触发场景信号出现（进入相关地点/开始相关活动）时弹出，或用户手动进入场景时自检。
- **提示形态**：一次性自检提示，场景结束即静默；无周期、无连续计数、不进入日常提醒池。

**4）交互设计**：
- **情境拦截卡**：显示触发场景与该场景下的合规要点，单次确认「本次我做到了」；发现已违反时给纠正指引。
- **操作响应**：`[ 本次做到了 ]` · `[ 需要纠正 ]`""",
    'decision-check': """**2）建议理解**：
- **主行动性质**：花钱/投资/签约前适用的决策规则；没有可量化的「达成度」，不应使用滑块测算，正确形态是决策前的规则核对。

**3）触发时机与条件**：
- **时机模型**：决策核对型（Decision Check）。
- **触发源**：决策情境前置出现（记账/理财/大额支付/签约清单打开）或本地搜索命中需求词；不进入日常提醒池。

**4）交互设计**：
- **决策核对卡**：把规则的比较维度列成核对项，决策前逐项过一遍；输出只引建议原文，不做个性化理财建议。
- **操作响应**：`[ 核对完毕 ]` · `[ 稍后再看 ]`""",
    'process-steps': """**2）建议理解**：
- **主行动性质**：有先后顺序的办事/就诊/维权流程，核心是「走到哪一步、下一步带什么」；不是单日提醒，也不是量化测算。

**3）触发时机与条件**：
- **时机模型**：办事分步推进型（Process Steps）。
- **触发源**：进入办事场景（办证/维权/报销/申请）时启用；步骤由用户依次推进，无固定日历节律。
- **窗口约束**：仅存在法定/机构时限的步骤给出截止日倒计时，属于窗口提醒的窄例外。

**4）交互设计**：
- **办事分步流程**：步骤列表当前步高亮、完成数可见；材料类步骤逐项对照，可拍照留档不上云。
- **操作响应**：`[ 完成当前步 ]` · `[ 查看材料清单 ]`""",
}

TAXONOMY_ROWS = """
| **时机模型 6：红线知识铭记型** | 进入章节、本地搜索命中、关联场景路由命中 | 野蘑菇辟谣、不买彩票、法律红线 | 无到期日与周期提醒；盖章背熟一次长期生效，30 天内至多主动浮现一次 |

| **时机模型 7：情境拦截型** | 场景信号（进入地点/开始活动）、手动进入场景 | 电动车不进电梯、不捡来路不明金属件 | 场景出现时一次性合规自检，场景结束即静默，无连续计数 |

| **时机模型 8：决策核对型** | 记账/理财/大额支付/签约场景前置、搜索命中需求词 | 基金费率比较、沉没成本、提前还贷比较 | 仅决策前置阶段出现，逐项核对规则，不做达成度测算 |

| **时机模型 9：办事分步推进型** | 进入办事场景（办证/维权/报销/申请） | 办证材料、维权举证、报销流程 | 步骤由用户推进，仅法定时限步骤给截止日倒计时 |
"""

COMPONENT_ROWS = """| 红线铭记卡 | 显示方式 #收藏（红线/辟谣知识） | 长期规则盖章背熟一次即生效；无每日打卡、无周期提醒；后果对照（钱/刑/时限）随卡展示 |
| 情境拦截卡 | #情境触发 的禁止/规避项 | 场景出现时单次合规自检「本次我做到了」，场景结束即静默；无连续计数 |
| 决策核对卡 | 决策规则类（理财/消费/签约原则） | 决策前置出现，把比较维度列成核对项逐项过一遍；输出只引建议原文 |
| 办事分步卡 | 显示方式 #办事 / #咨询 | 步骤依次推进、当前步高亮；材料逐项对照可拍照留档；仅法定时限步骤用截止日倒计时 |"""


def rewrite_detail_doc(assignments):
    doc = open(DETAIL).read()
    sections = list(re.finditer(r'^#### 建议 (\d+)：.*?(?=^#### 建议 \d+：|^### |\Z)', doc, re.S | re.M))
    changed = 0
    out = doc
    for m in reversed(sections):
        sid = int(m.group(1))
        new = assignments.get(sid)
        if not new:
            continue
        at = new[0]
        sec = m.group(0)
        new_sec, n = re.subn(r'\*\*2）建议理解\*\*：.*?(?=\n---)', DOC_BLOCKS[at], sec, flags=re.S)
        if n == 1:
            out = out[:m.start()] + new_sec + out[m.end():]
            changed += 1
    return out, changed


def main():
    html = open(DEMO).read()
    m, items = extract_data(html)
    assignments = {d['id']: classify(d) for d in items}
    reassigned = {k: v for k, v in assignments.items() if v}
    print('重分配条目数:', len(reassigned))
    print('新类型分布:', Counter(v[0] for v in reassigned.values()))
    print('保留类型分布:', Counter(d['act_type'] for d in items if d['id'] not in reassigned))

    if DRY:
        return

    # 1) Demo 数据层：更新 act_type/badge，删除死字段 timing_desc
    for d in items:
        if d['id'] in reassigned:
            d['act_type'], d['timing_badge'], d['timing_desc'] = reassigned[d['id']]
        else:
            d.pop('timing_desc', None)
    html = html[:m.start()] + rebuild_data_array(items) + html[m.end():]

    # 2) 渲染层：图标、形态筛选、渲染分支、新函数
    assert "'windowed-cadence':" in html
    html = html.replace("'windowed-cadence':", NEW_ICONS + "\n    'windowed-cadence':", 1)
    html = html.replace("  { id: 'wage-calc', name: '时薪决策', iconName: 'wage-calc' }\n];",
                        "  { id: 'wage-calc', name: '时薪决策', iconName: 'wage-calc' },\n" + NEW_TYPE_DEFS, 1)
    anchor = '  // ================= 7. 周期窗口推进引擎 (windowed-cadence) ================='
    assert anchor in html
    html = html.replace(anchor, RENDER_BRANCHES + '\n' + anchor, 1)
    fn_anchor = 'function notifyIsland'
    assert fn_anchor in html
    html = html.replace(fn_anchor, NEW_FUNCTIONS + '\n' + fn_anchor, 1)

    # 3) #97 三重冗余修复：闹钟标签去掉括注重复，抽屉底注改为功能性文案
    html = html.replace('晨间闹钟 <b>07:00</b>（工作日与周末同步）', '晨间闹钟 <b>07:00</b>')
    html = html.replace('已启用系统智能唤醒联动，周末同步守护不倒时差',
                        '选择后立即生效，同步到锁屏与手表组件')
    open(DEMO, 'w').write(html)
    print('Demo 已更新:', DEMO)

    # 4) 详情文档：分节重写 + 元型表登记
    doc, changed = rewrite_detail_doc(assignments)
    anchor13 = '### 1.4 卡片信息架构与极简化原则'
    assert anchor13 in doc
    doc = doc.replace(anchor13, TAXONOMY_ROWS + '\n' + anchor13, 1)
    open(DETAIL, 'w').write(doc)
    print('详情文档已重写分节:', changed)

    # 5) 组件库登记
    comp = open(COMPONENTS).read()
    anchor_row = '| 画像开关 | 群体 ≠ #通用 | 按画像显隐，答案改变即换组 |'
    assert anchor_row in comp
    comp = comp.replace(anchor_row, anchor_row + '\n' + COMPONENT_ROWS, 1)
    open(COMPONENTS, 'w').write(comp)
    print('组件库已更新:', COMPONENTS)


if __name__ == '__main__':
    main()
