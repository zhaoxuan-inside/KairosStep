import re
import sys

def main():
    path = "docs/AdviceInteractiveDemo.html"
    with open(path, "r", encoding="utf-8") as f:
        html = f.read()

    # 1. Add CSS styles before </style>
    css_addition = """
/* ================= 每日习惯打卡与成就分享 (Daily Habit Streak & Share Card) ================= */
.daily-streak-box {
  background: var(--bg-interactive);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 12px 14px;
  margin-top: 8px;
}
.streak-alarm-pill {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 10px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 20px;
  font-size: 11px;
  margin-bottom: 10px;
}
.streak-alarm-tag {
  display: flex;
  align-items: center;
  gap: 5px;
  color: var(--text-main);
  font-weight: 500;
}
.streak-defense-rule {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 11px;
  color: var(--accent-amber);
  background: rgba(245, 158, 11, 0.08);
  border: 1px dashed rgba(245, 158, 11, 0.25);
  padding: 6px 10px;
  border-radius: 8px;
  margin-bottom: 10px;
  line-height: 1.4;
}
.streak-stat-bar {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-bottom: 8px;
}
.streak-count-text {
  font-size: 13px;
  font-weight: 700;
  color: var(--text-pure);
  display: flex;
  align-items: center;
  gap: 4px;
}
.streak-rate-text {
  font-size: 11px;
  color: var(--text-mute);
}
.calendar-week-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 5px;
  margin-bottom: 12px;
}
.calendar-week-day {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 3px;
}
.calendar-day-label {
  font-size: 9px;
  color: var(--text-mute);
  font-weight: 600;
}
.calendar-day-dot {
  width: 100%;
  aspect-ratio: 1;
  max-width: 32px;
  border-radius: 8px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 10px;
  font-weight: 600;
  color: var(--text-mute);
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}
.calendar-day-dot.done {
  background: #224228;
  color: #ffffff;
  border-color: #224228;
}
.calendar-day-dot.today-pending {
  border-color: #bc924c;
  color: #bc924c;
  background: rgba(188, 146, 76, 0.12);
  animation: todayPulse 2s infinite ease-in-out;
}
@keyframes todayPulse {
  0%, 100% { box-shadow: 0 0 0 0 rgba(188, 146, 76, 0.4); }
  50% { box-shadow: 0 0 0 4px rgba(188, 146, 76, 0); }
}
.streak-btn-actions {
  display: grid;
  grid-template-columns: 1.6fr 1fr;
  gap: 8px;
}
.streak-main-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  padding: 8px 12px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  border: none;
  background: var(--accent-action);
  color: #fff;
  transition: all 0.18s ease;
}
.streak-main-btn.checked {
  background: #224228;
  color: #ffffff;
}
.streak-share-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  padding: 8px 10px;
  border-radius: 9999px;
  font-size: 11.5px;
  font-weight: 500;
  cursor: pointer;
  background: var(--bg-surface);
  color: var(--text-pure);
  border: 1px solid var(--border-subtle);
  transition: all 0.18s ease;
}
.streak-share-btn:hover {
  border-color: var(--border-active);
  transform: translateY(-1px);
}

/* Oura/Wieland 风格深色质感打卡成就卡片 (Share Card) */
.share-modal-sheet {
  background: #19191c;
  color: #ffffff;
  width: 90%;
  max-width: 320px;
  border-radius: 20px;
  padding: 24px 20px 18px;
  box-shadow: 0 20px 48px rgba(0, 0, 0, 0.6);
  border: 1px solid rgba(255, 255, 255, 0.1);
  text-align: center;
  position: relative;
  animation: deckFadeIn 0.25s cubic-bezier(0.16, 1, 0.3, 1);
}
.share-card-brand-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
}
.share-card-brand {
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 1.5px;
  color: #a8a5a0;
  text-transform: uppercase;
}
.share-stamp-green {
  background: #eef0e4;
  color: #224228;
  border: 1.5px solid #224228;
  font-size: 9.5px;
  font-weight: 700;
  padding: 2px 7px;
  border-radius: 4px;
  letter-spacing: 0.5px;
  display: inline-flex;
  align-items: center;
  gap: 3px;
}
.share-card-days-number {
  font-family: Georgia, "Songti SC", "Noto Serif SC", serif;
  font-size: 40px;
  font-weight: 600;
  color: #ffffff;
  line-height: 1;
  margin: 6px 0 2px;
}
.share-card-days-label {
  font-size: 11px;
  color: #838280;
  letter-spacing: 1px;
  text-transform: uppercase;
  margin-bottom: 14px;
}
.share-card-action-title {
  font-family: Georgia, "Songti SC", serif;
  font-size: 17px;
  font-weight: 500;
  color: #f7f1e8;
  margin-bottom: 6px;
  line-height: 1.35;
}
.share-card-quote {
  font-size: 11.5px;
  color: #a8a5a0;
  line-height: 1.5;
  margin-bottom: 18px;
  padding: 0 4px;
}
.share-card-grid {
  display: flex;
  justify-content: center;
  gap: 6px;
  margin-bottom: 20px;
}
.share-card-dot {
  width: 22px;
  height: 22px;
  border-radius: 6px;
  background: #2a292d;
  color: #717075;
  font-size: 9px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
}
.share-card-dot.active {
  background: #224228;
  color: #ffffff;
  border: 1px solid #3d6f45;
}
.share-card-btn-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-top: 10px;
}
.share-card-btn {
  padding: 9px 12px;
  border-radius: 9999px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  border: none;
  transition: all 0.16s ease;
}
.share-card-btn-main {
  background: #ffffff;
  color: #19191c;
}
.share-card-btn-sub {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
  border: 1px solid rgba(255, 255, 255, 0.15);
}
.share-modal-close-x {
  position: absolute;
  top: 12px;
  right: 12px;
  width: 26px;
  height: 26px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.08);
  border: none;
  color: #a8a5a0;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
}
"""
    if "/* ================= 每日习惯打卡与成就分享" not in html:
        html = html.replace("</style>", css_addition + "\n</style>", 1)

    # 2. Add icons in getAppIcon
    icon_entries = """    'daily-streak': `<svg class="svg-icon ${extraClass}" style="width:${size}px; height:${size}px;" viewBox="0 0 24 24"><path d="M12 2c1.5 3 4 5 4 9a6 6 0 1 1-12 0c0-4 2.5-6 4-9 1 2 2 3 4 3s2-1 0-3z"></path></svg>`,
    'share': `<svg class="svg-icon ${extraClass}" style="width:${size}px; height:${size}px;" viewBox="0 0 24 24"><circle cx="18" cy="5" r="3"></circle><circle cx="6" cy="12" r="3"></circle><circle cx="18" cy="19" r="3"></circle><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"></line><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"></line></svg>`,
"""
    if "'daily-streak':" not in html:
        html = html.replace("'windowed-cadence':", icon_entries + "    'windowed-cadence':", 1)

    # 3. Add to ACTION_TYPE_DEFS
    streak_def = "  { id: 'daily-streak', name: '每日连击', iconName: 'daily-streak' },\n"
    if "'daily-streak'" not in html.split("ACTION_TYPE_DEFS = [")[1].split("];")[0]:
        html = html.replace(
            "{ id: 'all', name: '全部形态', iconName: 'archetypes' },\n",
            "{ id: 'all', name: '全部形态', iconName: 'archetypes' },\n" + streak_def,
            1
        )

    # 4. Update ALL_ENRICHED_ADVICE item 97 and other daily habits
    # item 97
    old_item_97 = "\"id\": 97, \"c\": \"不要浪费精力\", \"t\": \"固定起床时间，周末也一样\", \"parts\": [\"固定起床时间\", \"周末也一样\"], \"timing_badge\": \"日常自检 · 闲暇时段\", \"timing_desc\": \"画像匹配时平铺推荐，闲暇时段一键备忘确认\", \"act_type\": \"quick-checkin\""
    new_item_97 = "\"id\": 97, \"c\": \"不要浪费精力\", \"t\": \"固定起床时间，周末也一样\", \"parts\": [\"固定起床时间\", \"周末也一样\"], \"timing_badge\": \"每日晨间 · 07:00 节律\", \"timing_desc\": \"晨间固定闹钟提醒与唤醒感知，每日早起打卡、坚持连击记录与成就卡片分享\", \"act_type\": \"daily-streak\""
    if old_item_97 in html:
        html = html.replace(old_item_97, new_item_97)

    # item 98: 每晚睡够 7 到 8 小时
    html = html.replace(
        "\"id\": 98, \"c\": \"不要浪费精力\", \"t\": \"每晚睡够 7 到 8 小时，别把 6 小时当作够用\", \"parts\": [\"每晚睡够 7 到 8 小时\", \"别把 6 小时当作够用\"], \"timing_badge\": \"日常自检 · 闲暇时段\", \"timing_desc\": \"画像匹配时平铺推荐，闲暇时段一键备忘确认\", \"act_type\": \"quick-checkin\"",
        "\"id\": 98, \"c\": \"不要浪费精力\", \"t\": \"每晚睡够 7 到 8 小时，别把 6 小时当作够用\", \"parts\": [\"每晚睡够 7 到 8 小时\", \"别把 6 小时当作够用\"], \"timing_badge\": \"每日睡前 · 23:00 节律\", \"timing_desc\": \"睡前放下手机与节律感知，每日睡眠打卡与达标连击统计\", \"act_type\": \"daily-streak\""
    )

    # 5. Add Spotlight & generic daily-streak rendering in createFullInteractiveAdviceCard
    widget_render_logic = """
  // ================= 1-C-0. 建议 97 及每日节律习惯连击打卡 (daily-streak) =================
  else if (id === 97 || type === 'daily-streak') {
    completeMsg = "今日按时起床打卡完成，作息节律已锁定";
    const streakDays = item._streakDays || 14;
    const isChecked = item._streakChecked || false;
    const defenseRule = (parts && parts[1]) ? parts[1] : '周末也一样 · 守住生物钟不倒时差';
    const isWakeup = id === 97 || t.includes('起床');
    const actionLabel = isWakeup ? '固定起床时间' : (parts[0] || t);
    const alarmTime = isWakeup ? '07:00' : (t.includes('睡') ? '23:00' : '08:30');
    const punchTime = isWakeup ? '07:15 起床' : '已达成';

    interactiveWidgetHtml = `
      <div class="daily-streak-box">
        <div class="streak-alarm-pill">
          <div class="streak-alarm-tag">
            <svg class="svg-icon" style="width:12px; height:12px; color:var(--accent-action);" viewBox="0 0 24 24"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg>
            <span>晨间闹钟 <b>${alarmTime}</b>（工作日与周末同步）</span>
          </div>
          <span style="font-size:10.5px; color:var(--accent-emerald); font-weight:600;">已开启每日提醒</span>
        </div>

        <div class="streak-defense-rule">
          <svg class="svg-icon" style="width:12px; height:12px; flex-shrink:0;" viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
          <span><b>关键防线</b>：${defenseRule}</span>
        </div>

        <div class="streak-stat-bar">
          <div class="streak-count-text">
            <span>🔥 连续打卡 <b id="streak-count-${id}">${streakDays}</b> 天</span>
          </div>
          <div class="streak-rate-text">本周达成率 <b>100%</b></div>
        </div>

        <div class="calendar-week-grid" id="streak-grid-${id}">
          <div class="calendar-week-day">
            <span class="calendar-day-label">一</span>
            <div class="calendar-day-dot done">✓</div>
          </div>
          <div class="calendar-week-day">
            <span class="calendar-day-label">二</span>
            <div class="calendar-day-dot done">✓</div>
          </div>
          <div class="calendar-week-day">
            <span class="calendar-day-label">三</span>
            <div class="calendar-day-dot done">✓</div>
          </div>
          <div class="calendar-week-day">
            <span class="calendar-day-label">四</span>
            <div class="calendar-day-dot done">✓</div>
          </div>
          <div class="calendar-week-day">
            <span class="calendar-day-label">五</span>
            <div class="calendar-day-dot done">✓</div>
          </div>
          <div class="calendar-week-day">
            <span class="calendar-day-label">六</span>
            <div class="calendar-day-dot done">✓</div>
          </div>
          <div class="calendar-week-day">
            <span class="calendar-day-label">日</span>
            <div class="calendar-day-dot ${isChecked ? 'done' : 'today-pending'}" id="streak-today-dot-${id}">${isChecked ? '✓' : '今'}</div>
          </div>
        </div>

        <div class="streak-btn-actions">
          <button class="streak-main-btn ${isChecked ? 'checked' : ''}" id="streak-btn-${id}" onclick="toggleDailyCheckin(${id}, this)">
            <svg class="svg-icon" style="width:13px; height:13px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
            <span class="streak-btn-text">${isChecked ? `今日已打卡 · ${punchTime}` : `立即打卡 (${punchTime})`}</span>
          </button>
          <button class="streak-share-btn" onclick="openShareModal(${id})">
            <svg class="svg-icon" style="width:12px; height:12px;" viewBox="0 0 24 24"><circle cx="18" cy="5" r="3"></circle><circle cx="6" cy="12" r="3"></circle><circle cx="18" cy="19" r="3"></circle><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"></line><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"></line></svg>
            <span>分享打卡</span>
          </button>
        </div>
      </div>
    `;
  }
"""
    if "建议 97 及每日节律习惯连击打卡" not in html:
        html = html.replace(
            "  // 1-C. 建议 7: 量血压，高了就吃药降到达标",
            widget_render_logic + "\n  // 1-C. 建议 7: 量血压，高了就吃药降到达标",
            1
        )

    # 6. Add Share Modal in HTML
    share_modal_html = """
      <!-- Oura/Wieland 风格打卡成就卡片分享模态框 (Share Card Modal) -->
      <div id="share-card-modal" class="jump-deck-modal" style="display:none; justify-content:center; align-items:center; padding:20px;" onclick="handleShareBackdrop(event)">
        <div class="share-modal-sheet" onclick="event.stopPropagation()">
          <!-- 动态注入分享卡片内容 -->
        </div>
      </div>
"""
    if "id=\"share-card-modal\"" not in html:
        html = html.replace(
            "<!-- Windows Metro 专注筛选抽屉中枢 (Jump Deck) -->",
            share_modal_html + "\n      <!-- Windows Metro 专注筛选抽屉中枢 (Jump Deck) -->",
            1
        )

    # 7. Add Sidebar Simulation button
    sidebar_btn = """        <button class="k-btn k-btn-secondary" style="justify-content:flex-start;" onclick="simulateFixedWakeupRoutine()">
          <svg class="svg-icon" style="color:var(--accent-emerald);" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
          习惯 · 固定起床打卡 (每日连击与分享)
        </button>
"""
    if "simulateFixedWakeupRoutine()" not in html:
        html = html.replace(
            "<button class=\"k-btn k-btn-secondary\" style=\"justify-content:flex-start;\" onclick=\"toggleHolidayAllDayMode()\">",
            sidebar_btn + "        <button class=\"k-btn k-btn-secondary\" style=\"justify-content:flex-start;\" onclick=\"toggleHolidayAllDayMode()\">",
            1
        )

    # 8. Add JS helper functions before </script>
    js_functions = """
// ========================================================
// 每日习惯打卡与成就分享卡片控制器 (Daily Habit Streak & Share)
// ========================================================
function toggleDailyCheckin(id, btnEl) {
  const item = ALL_ENRICHED_ADVICE.find(x => x.id === id);
  if (!item) return;

  item._streakChecked = !item._streakChecked;
  const isChecked = item._streakChecked;
  const baseDays = item._streakDays || 14;
  const countEl = document.getElementById(`streak-count-${id}`);
  const dotEl = document.getElementById(`streak-today-dot-${id}`);
  const btnText = btnEl.querySelector('.streak-btn-text');
  const isWakeup = id === 97 || item.t.includes('起床');
  const punchText = isWakeup ? '07:15 起床' : '已达成';

  if (isChecked) {
    const newCount = baseDays + 1;
    if (countEl) countEl.textContent = newCount;
    if (dotEl) {
      dotEl.className = 'calendar-day-dot done';
      dotEl.textContent = '✓';
    }
    btnEl.classList.add('checked');
    if (btnText) btnText.textContent = `今日已打卡 · ${punchText}`;
    notifyIsland(`已完成早起打卡 · 连续第 ${newCount} 天保持恒定作息！`);
    // 自动弹框提示是否分享
    setTimeout(() => {
      openShareModal(id);
    }, 450);
  } else {
    if (countEl) countEl.textContent = baseDays;
    if (dotEl) {
      dotEl.className = 'calendar-day-dot today-pending';
      dotEl.textContent = '今';
    }
    btnEl.classList.remove('checked');
    if (btnText) btnText.textContent = `立即打卡 (${punchText})`;
    notifyIsland('已取消今日早起打卡');
  }
}

function openShareModal(id) {
  const item = ALL_ENRICHED_ADVICE.find(x => x.id === id) || { id: 97, t: '固定起床时间，周末也一样' };
  const modal = document.getElementById('share-card-modal');
  if (!modal) return;
  const isChecked = item._streakChecked;
  const days = isChecked ? 15 : 14;
  const title = (item.parts && item.parts[0]) || item.t;
  const subRule = (item.parts && item.parts[1]) ? item.parts[1] : '周末也一样';

  const sheet = modal.querySelector('.share-modal-sheet');
  if (sheet) {
    sheet.innerHTML = `
      <button class="share-modal-close-x" onclick="closeShareModal()">
        <svg class="svg-icon" style="width:13px; height:13px;" viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>
      <div class="share-card-brand-row">
        <span class="share-card-brand">KAIROS STEP · 人生指引</span>
        <span class="share-stamp-green">
          <svg class="svg-icon" style="width:10px; height:10px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
          晨起立行 · 固化
        </span>
      </div>
      <div class="share-card-days-number">DAY ${days}</div>
      <div class="share-card-days-label">已连续稳定节律 ${days} 天</div>
      <div class="share-card-action-title">${title} · ${subRule}</div>
      <div class="share-card-quote">生物钟不会在周六自动重置；守住同一刻起床，周一才没有时差之苦。</div>

      <div class="share-card-grid">
        <div class="share-card-dot active">一</div>
        <div class="share-card-dot active">二</div>
        <div class="share-card-dot active">三</div>
        <div class="share-card-dot active">四</div>
        <div class="share-card-dot active">五</div>
        <div class="share-card-dot active">六</div>
        <div class="share-card-dot active">日</div>
      </div>

      <div class="share-card-btn-row">
        <button class="share-card-btn share-card-btn-main" onclick="copyShareCardText(${days})">
          复制打卡文案
        </button>
        <button class="share-card-btn share-card-btn-sub" onclick="saveShareCardPoster(${days})">
          保存成就卡片
        </button>
      </div>
    `;
  }
  modal.style.display = 'flex';
}

function closeShareModal() {
  const modal = document.getElementById('share-card-modal');
  if (modal) modal.style.display = 'none';
}

function handleShareBackdrop(e) {
  if (e.target.id === 'share-card-modal') {
    closeShareModal();
  }
}

function copyShareCardText(days) {
  const text = `🌅【KairosStep 晨起打卡 · 连续第 ${days} 天】\\n坚持「固定起床时间，周末也一样」。守住每日节律，摆脱周一时差！`;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text);
  }
  notifyIsland('已复制打卡文案到剪贴板，可前往朋友圈或社群分享！');
  setTimeout(closeShareModal, 1200);
}

function saveShareCardPoster(days) {
  notifyIsland(`已生成「DAY ${days} 晨起打卡成就卡片」，已保存至相册！`);
  setTimeout(closeShareModal, 1200);
}

function simulateFixedWakeupRoutine() {
  switchMainTab('today', document.querySelectorAll('.tab-icon-btn')[1]);
  notifyIsland('晨起节律：已调取固定起床打卡器（连续14天·可打卡与分享）');
  const card = document.querySelector('#view-today #advice-card-97');
  if (card) {
    card.scrollIntoView({ behavior: 'smooth' });
    card.style.outline = '2px solid var(--accent-emerald)';
    setTimeout(() => { card.style.outline = ''; }, 2000);
  }
}
"""
    if "function toggleDailyCheckin" not in html:
        html = html.replace("</script>\n</body>", js_functions + "\n</script>\n</body>", 1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(html)

    print("Successfully enhanced docs/AdviceInteractiveDemo.html with daily-streak and share-card!")

if __name__ == '__main__':
    main()
