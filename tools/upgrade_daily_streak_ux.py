import re
import json

def main():
    path = "docs/AdviceInteractiveDemo.html"
    with open(path, "r", encoding="utf-8") as f:
        html = f.read()

    # 1. Add extra CSS for the new UX elements before </style>
    extra_css = """
/* ================= 每日习惯深度交互增强 (Tactile, Matrix, Drawers & Canvas) ================= */
@keyframes stampin {
  0% { transform: scale(1.3) rotate(-3deg); opacity: 0; }
  60% { transform: scale(0.96) rotate(1deg); opacity: 1; }
  100% { transform: scale(1) rotate(0deg); opacity: 1; }
}
@keyframes pop {
  0% { transform: scale(1); }
  45% { transform: scale(0.93); }
  75% { transform: scale(1.06); }
  100% { transform: scale(1); }
}
@keyframes goldPulse {
  0%, 100% { box-shadow: 0 0 0 0 rgba(188, 146, 76, 0.5); }
  50% { box-shadow: 0 0 0 6px rgba(188, 146, 76, 0); }
}

.calendar-day-dot {
  cursor: pointer;
}
.calendar-day-dot:hover {
  transform: translateY(-1px) scale(1.05);
  border-color: var(--border-active);
}
.calendar-day-dot:active {
  transform: scale(0.92);
}
.calendar-day-dot.done {
  animation: stampin 0.22s cubic-bezier(0.16, 1, 0.3, 1);
}
.streak-main-btn {
  transition: all 0.2s cubic-bezier(0.16, 1, 0.3, 1);
}
.streak-main-btn.checked {
  animation: pop 0.25s ease-out;
}
.streak-alarm-pill {
  cursor: pointer;
  transition: all 0.16s ease;
}
.streak-alarm-pill:hover {
  border-color: var(--accent-action);
  background: rgba(37, 99, 235, 0.04);
}
.streak-defense-rule {
  cursor: pointer;
  transition: all 0.16s ease;
}
.streak-defense-rule:hover {
  border-color: var(--accent-amber);
  background: rgba(245, 158, 11, 0.12);
}
.defense-rule-explanation {
  background: var(--bg-surface);
  border-left: 3px solid var(--accent-amber);
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 11px;
  color: var(--text-sub);
  line-height: 1.55;
  margin-top: -6px;
  margin-bottom: 10px;
  animation: deckFadeIn 0.2s ease;
}
.defense-rule-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
}
.defense-rule-chevron {
  transition: transform 0.2s ease;
  color: var(--accent-amber);
}
.defense-rule-chevron.open {
  transform: rotate(180deg);
}

/* 提醒时点微调浮层 (Alarm Drawer) */
.alarm-picker-sheet {
  background: var(--bg-card);
  border: 1px solid var(--border-subtle);
  border-radius: 14px;
  padding: 10px 12px;
  margin-top: -6px;
  margin-bottom: 10px;
  animation: deckFadeIn 0.2s ease;
}
.alarm-time-chips {
  display: flex;
  gap: 6px;
  margin: 6px 0;
  flex-wrap: wrap;
}
.alarm-chip {
  padding: 4px 10px;
  border-radius: 9999px;
  font-size: 11px;
  background: var(--bg-interactive);
  border: 1px solid var(--border-subtle);
  color: var(--text-pure);
  cursor: pointer;
  transition: all 0.15s ease;
}
.alarm-chip.selected {
  background: var(--accent-action);
  color: #fff;
  border-color: var(--accent-action);
}

/* 今日节律仪表盘 (Today Rhythm Progress Bar) */
.today-rhythm-strip {
  background: var(--bg-card);
  border: 1px solid var(--border-subtle);
  border-radius: 16px;
  padding: 10px 14px;
  margin-bottom: 14px;
}
.today-rhythm-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 11.5px;
  margin-bottom: 8px;
}
.today-rhythm-pills-row {
  display: flex;
  gap: 6px;
  overflow-x: auto;
  padding-bottom: 2px;
  scrollbar-width: none;
}
.today-rhythm-pills-row::-webkit-scrollbar { display: none; }
.today-rhythm-pill {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 9px;
  border-radius: 9999px;
  font-size: 10.5px;
  background: var(--bg-interactive);
  border: 1px solid var(--border-subtle);
  color: var(--text-main);
  cursor: pointer;
  transition: all 0.16s ease;
}
.today-rhythm-pill.done {
  background: #eef0e4;
  color: #224228;
  border-color: #224228;
  font-weight: 600;
}
.today-rhythm-pill.pending {
  border-color: #bc924c;
  color: #bc924c;
}

/* 分享海报图片容器 */
.share-poster-preview-box {
  margin: 12px 0 14px;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 4px 18px rgba(0,0,0,0.4);
  border: 1px solid rgba(255,255,255,0.12);
}
.share-poster-preview-img {
  width: 100%;
  height: auto;
  display: block;
}
"""
    if "/* ================= 每日习惯深度交互增强" not in html:
        html = html.replace("</style>", extra_css + "\n</style>", 1)

    # 2. Update widget_render_logic in createFullInteractiveAdviceCard
    # We will refine the daily-streak card HTML to include alarm drawer, interactive days, and science drawer
    new_widget_logic = """  // ================= 1-C-0. 建议 61 及每日节律习惯连击打卡 (daily-streak) =================
  else if (id === 61 || type === "daily-streak") {
    completeMsg = "今日习惯打卡完成，每日连击已记录";
    const streakDays = item._streakDays || 14;
    const isChecked = item._streakChecked || false;
    
    // 针对不同习惯类型自适应语义标签
    let alarmLabel = "每日提醒 <b>08:30</b>（每天推送）";
    let defenseRule = (parts && parts[1]) ? parts[1] : "守住每日恒定节律 · 持续积累健康资本";
    let punchTime = "已达成";
    let isWakeup = id === 61 || t.includes("起床");
    let scienceExp = "守住每日恒定节律，是帮助神经内分泌系统建立稳定生物节律钟的核心杠杆。";

    if (isWakeup) {
      alarmLabel = "晨间闹钟 <b>07:00</b>（工作日与周末同步）";
      defenseRule = "关键防线：周末也一样 · 守住生物钟不倒时差";
      punchTime = "07:15 起床";
      scienceExp = "生物学机制：下丘脑视交叉上核（SCN）无法区分工作日与周末。周末晚起2小时会使褪黑素分泌推迟约45分钟，引发持续至周三的“社交时差”与大脑晨雾。守住同一刻起床是稳定神经内分泌的最简杠杆。";
    } else if (t.includes("睡") || t.includes("睡眠")) {
      alarmLabel = "睡前提醒 <b>23:00</b>（提前放下手机）";
      defenseRule = (parts && parts[1]) ? parts[1] : "关键防线：保证 7-8 小时整段睡眠，别把 6 小时当够用";
      punchTime = "按时就寝";
      scienceExp = "生物学机制：深度慢波睡眠负责脑脊液冲洗清除 β-淀粉样蛋白。连续睡眠剥夺 <7 小时会导致胰岛素抵抗增加20%以上，6小时不足以完成4个完整神经修复周期。";
    } else if (t.includes("刷牙") || t.includes("牙缝")) {
      alarmLabel = "早晚洗漱 <b>07:30 / 22:30</b>";
      defenseRule = "关键防线：每天清一次牙缝 · 缺牙及时就诊";
      punchTime = "早晚清洁";
      scienceExp = "生物学机制：普通牙刷刷毛只能清洁牙齿表面约60%面积，邻面牙菌斑是牙周炎与骨质吸收的首要元凶。每日一次牙线可降低牙周致病菌负荷80%以上。";
    } else if (t.includes("步") || t.includes("用力") || t.includes("力量") || t.includes("运动") || t.includes("户外")) {
      alarmLabel = "日间活力 <b>10:00 / 16:00</b>";
      defenseRule = (parts && parts[1]) ? parts[1] : "关键防线：中高强度碎片化累计 · 告别连续久坐";
      punchTime = "身体活动";
      scienceExp = "生物学机制：连续久坐使脂蛋白脂肪酶（LPL）活性断崖式下跌90%。把快走或爬楼梯攒到每天4-5分钟的高强度用力，可使心血管全因死亡风险下降30%以上。";
    } else if (t.includes("坚果") || t.includes("蔬菜") || t.includes("咖啡") || t.includes("水") || t.includes("奶")) {
      alarmLabel = "健康膳食 <b>正餐与加餐时段</b>";
      defenseRule = (parts && parts[1]) ? parts[1] : "关键防线：足量天然抗氧化与膳食纤维 · 杜绝超加工食品";
      punchTime = "营养达标";
      scienceExp = "营养学机制：充足的膳食纤维与坚果不饱和脂肪酸能滋养肠道有益拟杆菌，每日摄入天然多酚可有效抑制慢性系统性低度炎症。";
    } else if (t.includes("血压") || t.includes("吃药")) {
      alarmLabel = "慢病健康 <b>每日晨起定点</b>";
      defenseRule = (parts && parts[1]) ? parts[1] : "关键防线：遵医嘱规律监测与服药 · 绝不随意停药";
      punchTime = "健康达标";
      scienceExp = "临床指引：晨起清晨高压峰值最易诱发脑卒中。每天固定晨起监测并按医嘱规律服药达标，能将远期心血管意外风险压降50%以上。";
    } else if (t.includes("戒烟")) {
      alarmLabel = "无烟生活 <b>全天守护</b>";
      defenseRule = (parts && parts[1]) ? parts[1] : "关键防线：决绝戒烟日一次停掉 · 戒烟门诊专业支持";
      punchTime = "今日无烟";
      scienceExp = "成瘾医学：尼古丁受体在完全停止接触后2-3周开始下调。定一个戒烟日一次性彻底断吸的成功率，显著高于减量法。";
    }

    interactiveWidgetHtml = `
      <div class="daily-streak-box">
        <!-- 1. 提醒时钟配置胶囊 (点击展开快速调节) -->
        <div class="streak-alarm-pill" onclick="toggleAlarmSettingModal(${id})" title="点击微调每日提醒时间与规则">
          <div class="streak-alarm-tag">
            <svg class="svg-icon" style="width:12px; height:12px; color:var(--accent-action);" viewBox="0 0 24 24"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg>
            <span id="streak-alarm-text-${id}">${alarmLabel}</span>
          </div>
          <div style="display:flex; align-items:center; gap:4px;">
            <span style="font-size:10.5px; color:var(--accent-action); font-weight:600;">调时点</span>
            <svg class="svg-icon" style="width:10px; height:10px; color:var(--text-mute);" viewBox="0 0 24 24"><polyline points="9 18 15 12 9 6"></polyline></svg>
          </div>
        </div>

        <!-- 1.1 提醒时钟调节抽屉 -->
        <div class="alarm-picker-sheet" id="alarm-picker-${id}" style="display:none;">
          <div style="display:flex; justify-content:space-between; align-items:center; font-size:11px; margin-bottom:4px;">
            <span style="font-weight:600; color:var(--text-pure);">快速切换每日提醒时刻：</span>
            <span style="color:var(--text-mute); cursor:pointer;" onclick="toggleAlarmSettingModal(${id})">收起</span>
          </div>
          <div class="alarm-time-chips">
            <span class="alarm-chip ${alarmLabel.includes('06:30') ? 'selected' : ''}" onclick="applyAlarmTime(${id}, '06:30')">06:30 晨光</span>
            <span class="alarm-chip ${alarmLabel.includes('07:00') ? 'selected' : ''}" onclick="applyAlarmTime(${id}, '07:00')">07:00 标准</span>
            <span class="alarm-chip ${alarmLabel.includes('07:30') ? 'selected' : ''}" onclick="applyAlarmTime(${id}, '07:30')">07:30 宽裕</span>
            <span class="alarm-chip ${alarmLabel.includes('23:00') ? 'selected' : ''}" onclick="applyAlarmTime(${id}, '23:00')">23:00 就寝</span>
          </div>
          <div style="font-size:10.5px; color:var(--text-mute); margin-top:4px;">已启用系统智能唤醒联动，周末同步守护不倒时差</div>
        </div>

        <!-- 2. 关键防线标牌 (点击折叠展开科学依据) -->
        <div class="streak-defense-rule" onclick="toggleDefenseRuleExplanation(${id})" title="点击查看此防线的科学原理">
          <div class="defense-rule-header">
            <div style="display:flex; align-items:center; gap:6px;">
              <svg class="svg-icon" style="width:12px; height:12px; flex-shrink:0;" viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
              <span><b>${defenseRule}</b></span>
            </div>
            <div class="defense-rule-chevron" id="defense-chevron-${id}">
              <svg class="svg-icon" style="width:10px; height:10px;" viewBox="0 0 24 24"><polyline points="6 9 12 15 18 9"></polyline></svg>
            </div>
          </div>
        </div>

        <!-- 2.1 科学原理展开抽屉 -->
        <div class="defense-rule-explanation" id="defense-exp-${id}" style="display:none;">
          ${scienceExp}
        </div>

        <!-- 3. 连击统计与 7 天微周历 (交互式方格，支持点击查看/补卡) -->
        <div class="streak-stat-bar">
          <div class="streak-count-text">
            <span>🔥 连续打卡 <b id="streak-count-${id}">${streakDays}</b> 天</span>
          </div>
          <div class="streak-rate-text">本周达成率 <b id="streak-rate-${id}">100%</b></div>
        </div>

        <div class="calendar-week-grid" id="streak-grid-${id}">
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 1, '一', '10月19日', '07:12')">
            <span class="calendar-day-label">一</span>
            <div class="calendar-day-dot done" title="周一：已打卡">✓</div>
          </div>
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 2, '二', '10月20日', '07:08')">
            <span class="calendar-day-label">二</span>
            <div class="calendar-day-dot done" title="周二：已打卡">✓</div>
          </div>
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 3, '三', '10月21日', '07:15')">
            <span class="calendar-day-label">三</span>
            <div class="calendar-day-dot done" title="周三：已打卡">✓</div>
          </div>
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 4, '四', '10月22日', '07:11')">
            <span class="calendar-day-label">四</span>
            <div class="calendar-day-dot done" title="周四：已打卡">✓</div>
          </div>
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 5, '五', '10月23日', '07:14')">
            <span class="calendar-day-label">五</span>
            <div class="calendar-day-dot done" title="周五：已打卡">✓</div>
          </div>
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 6, '六', '10月24日', '07:18')">
            <span class="calendar-day-label">六</span>
            <div class="calendar-day-dot done" title="周六：周末同样按时打卡">✓</div>
          </div>
          <div class="calendar-week-day" onclick="inspectStreakDay(${id}, 7, '日', '今日', '')">
            <span class="calendar-day-label">日</span>
            <div class="calendar-day-dot ${isChecked ? "done" : "today-pending"}" id="streak-today-dot-${id}" title="今日：点击打卡">${isChecked ? "✓" : "今"}</div>
          </div>
        </div>

        <!-- 4. 主打卡按钮与成就分享按钮 -->
        <div class="streak-btn-actions">
          <button class="streak-main-btn ${isChecked ? "checked" : ""}" id="streak-btn-${id}" onclick="toggleDailyCheckin(${id}, this, '${punchTime}')">
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
  }"""

    html = re.sub(
        r"  // ================= 1-C-0\. 建议 61 及每日节律习惯连击打卡 \(daily-streak\) =================\n.*?  // 1-C\. 建议 7: 量血压",
        new_widget_logic + "\n\n  // 1-C. 建议 7: 量血压",
        html,
        flags=re.DOTALL
    )

    # 3. Update renderTodayStream to include the Today Rhythm Strip & spotlight items
    today_stream_code = """function renderTodayStream() {
  const container = document.getElementById('today-advice-stream');
  // 精选丰富交互元型：固定起床打卡(ID 61)、全车安全带(ID 1)、血压监测(ID 7)、刷牙洁牙(ID 58)、燃气管窗口期(ID 4)
  const spotlightIds = [61, 1, 7, 58, 4];
  const items = spotlightIds.map(id => ALL_ENRICHED_ADVICE.find(it => it.id === id) || ALL_ENRICHED_ADVICE[id-1]);

  // 顶部沉浸式今日节律仪表盘
  const rhythmStripHtml = `
    <div class="today-rhythm-strip">
      <div class="today-rhythm-header">
        <span style="font-weight:700; color:var(--text-pure);">🌅 每日健康节律看板</span>
        <span style="color:var(--accent-emerald); font-weight:600;" id="today-rhythm-stat">已达成 2/3</span>
      </div>
      <div class="today-rhythm-pills-row">
        <div class="today-rhythm-pill done" onclick="jumpToSpotlightCard(61)">
          <svg class="svg-icon" style="width:11px; height:11px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
          <span>固定作息 07:00</span>
        </div>
        <div class="today-rhythm-pill done" onclick="jumpToSpotlightCard(7)">
          <svg class="svg-icon" style="width:11px; height:11px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
          <span>晨起血压 120/80</span>
        </div>
        <div class="today-rhythm-pill pending" onclick="jumpToSpotlightCard(58)">
          <svg class="svg-icon" style="width:11px; height:11px;" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle></svg>
          <span>早晚刷牙牙线</span>
        </div>
        <div class="today-rhythm-pill" onclick="jumpToSpotlightCard(1)">
          <svg class="svg-icon" style="width:11px; height:11px;" viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path></svg>
          <span>出行安全带</span>
        </div>
      </div>
    </div>
  `;

  container.innerHTML = rhythmStripHtml + items.map(createFullInteractiveAdviceCard).join('');
}

function jumpToSpotlightCard(id) {
  const card = document.querySelector('#view-today #advice-card-' + id);
  if (card) {
    card.scrollIntoView({ behavior: 'smooth', block: 'center' });
    card.style.animation = 'pop 0.3s ease';
    card.style.boxShadow = '0 0 0 3px var(--accent-action)';
    setTimeout(() => {
      card.style.animation = '';
      card.style.boxShadow = '';
    }, 1200);
  }
}
"""
    html = re.sub(
        r"function renderTodayStream\(\) \{.*?function renderWeeklyStream\(\)",
        today_stream_code + "\n\n// 渲染 Tab 3 Weekly 当月流\nfunction renderWeeklyStream()",
        html,
        flags=re.DOTALL
    )

    # 4. Enhance JS controller functions (Audio click, Haptic, Canvas Generator, Day inspect, Alarm sheet)
    enhanced_js = """
// ========================================================
// 拟物触觉与音效中枢 (Web Audio & Vibration)
// ========================================================
function playMicroClick(freq = 340) {
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = 'sine';
    osc.frequency.setValueAtTime(freq, ctx.currentTime);
    osc.frequency.exponentialRampToValueAtTime(100, ctx.currentTime + 0.035);
    gain.gain.setValueAtTime(0.09, ctx.currentTime);
    gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + 0.035);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + 0.035);
  } catch(e) {}
}

function playSuccessChord() {
  try {
    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    if (!AudioCtx) return;
    const ctx = new AudioCtx();
    [440, 660].forEach((freq, i) => {
      const osc = ctx.createOscillator();
      const gain = ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, ctx.currentTime + i * 0.06);
      gain.gain.setValueAtTime(0.08, ctx.currentTime + i * 0.06);
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + i * 0.06 + 0.12);
      osc.connect(gain);
      gain.connect(ctx.destination);
      osc.start(ctx.currentTime + i * 0.06);
      osc.stop(ctx.currentTime + i * 0.06 + 0.12);
    });
  } catch(e) {}
}

function triggerTactileVibration() {
  if (navigator.vibrate) {
    try { navigator.vibrate([15, 25, 20]); } catch(e) {}
  }
}

// 每日习惯打卡切换
function toggleDailyCheckin(id, btnEl, punchTimeDefault) {
  const item = ALL_ENRICHED_ADVICE.find(x => x.id === id);
  if (!item) return;

  item._streakChecked = !item._streakChecked;
  const isChecked = item._streakChecked;
  const baseDays = item._streakDays || 14;
  const countEl = document.getElementById(`streak-count-${id}`);
  const dotEl = document.getElementById(`streak-today-dot-${id}`);
  const btnText = btnEl.querySelector(".streak-btn-text");
  const punchText = punchTimeDefault || "已达成";

  if (isChecked) {
    playSuccessChord();
    triggerTactileVibration();
    const newCount = baseDays + 1;
    if (countEl) {
      countEl.textContent = newCount;
      countEl.style.color = 'var(--accent-emerald)';
    }
    if (dotEl) {
      dotEl.className = "calendar-day-dot done";
      dotEl.textContent = "✓";
    }
    btnEl.classList.add("checked");
    if (btnText) btnText.textContent = `今日已打卡 · ${punchText}`;
    notifyIsland(`已完成【${(item.parts && item.parts[0]) || item.t}】打卡 · 连续第 ${newCount} 天达成！`);
    setTimeout(() => {
      openShareModal(id);
    }, 450);
  } else {
    playMicroClick(220);
    if (countEl) {
      countEl.textContent = baseDays;
      countEl.style.color = '';
    }
    if (dotEl) {
      dotEl.className = "calendar-day-dot today-pending";
      dotEl.textContent = "今";
    }
    btnEl.classList.remove("checked");
    if (btnText) btnText.textContent = `立即打卡 (${punchText})`;
    notifyIsland("已取消今日打卡记录");
  }
}

// 点击周历任一天查看详情或触发今日打卡
function inspectStreakDay(id, dayIndex, dayName, dateStr, timeStr) {
  playMicroClick(380);
  if (dayIndex === 7) {
    // 今日
    const btn = document.getElementById(`streak-btn-${id}`);
    if (btn) btn.click();
  } else {
    notifyIsland(`📅 周${dayName}（${dateStr}）：在 ${timeStr || '07:12'} 打卡达成 · 状态：优秀 ✓`);
  }
}

// 闹钟时点微调展开/收起
function toggleAlarmSettingModal(id) {
  playMicroClick(400);
  const sheet = document.getElementById(`alarm-picker-${id}`);
  if (sheet) {
    sheet.style.display = sheet.style.display === 'none' ? 'block' : 'none';
  }
}

function applyAlarmTime(id, timeStr) {
  playMicroClick(480);
  const textEl = document.getElementById(`streak-alarm-text-${id}`);
  if (textEl) {
    textEl.innerHTML = `晨间闹钟 <b>${timeStr}</b>（工作日与周末恒定同步）`;
  }
  const sheet = document.getElementById(`alarm-picker-${id}`);
  if (sheet) sheet.style.display = 'none';
  notifyIsland(`已将每日提醒时间调整为 ${timeStr}，已同步系统唤醒联动`);
}

// 关键防线科学依据展开/收起
function toggleDefenseRuleExplanation(id) {
  playMicroClick(320);
  const exp = document.getElementById(`defense-exp-${id}`);
  const chevron = document.getElementById(`defense-chevron-${id}`);
  if (exp) {
    const isHidden = exp.style.display === 'none';
    exp.style.display = isHidden ? 'block' : 'none';
    if (chevron) chevron.classList.toggle('open', isHidden);
  }
}

// ========================================================
// HTML5 Canvas 离线高清成就海报绘制与导出 (640x960 Oura风格)
// ========================================================
function generatePosterCanvas(days, title, quote, stampName) {
  const canvas = document.createElement('canvas');
  canvas.width = 640;
  canvas.height = 960;
  const ctx = canvas.getContext('2d');

  // 1. 深色极质感背景 (#19191c)
  ctx.fillStyle = '#19191c';
  ctx.fillRect(0, 0, 640, 960);

  // 细微米色暖纸边框 (#e1dcd3 with opacity)
  ctx.strokeStyle = 'rgba(225, 220, 211, 0.15)';
  ctx.lineWidth = 2;
  ctx.strokeRect(28, 28, 584, 904);

  // 2. 品牌 Header
  ctx.fillStyle = '#a8a5a0';
  ctx.font = 'bold 18px -apple-system, "PingFang SC", sans-serif';
  ctx.letterSpacing = '3px';
  ctx.fillText('KAIROS STEP · 人生指引', 52, 80);

  // 3. 森林绿方章印记
  const stampText = stampName || '晨起立行 · 固化';
  ctx.font = 'bold 16px -apple-system, sans-serif';
  const stampWidth = ctx.measureText(stampText).width + 24;
  ctx.fillStyle = '#eef0e4';
  ctx.fillRect(640 - 52 - stampWidth, 58, stampWidth, 32);
  ctx.strokeStyle = '#224228';
  ctx.lineWidth = 2.5;
  ctx.strokeRect(640 - 52 - stampWidth, 58, stampWidth, 32);
  ctx.fillStyle = '#224228';
  ctx.fillText(stampText, 640 - 52 - stampWidth + 12, 80);

  // 分隔线
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(52, 115);
  ctx.lineTo(588, 115);
  ctx.stroke();

  // 4. Georgia 衬线巨大天数
  ctx.fillStyle = '#ffffff';
  ctx.font = '500 84px Georgia, "Songti SC", serif';
  ctx.fillText(`DAY ${days}`, 52, 220);

  ctx.fillStyle = '#838280';
  ctx.font = 'bold 20px -apple-system, sans-serif';
  ctx.fillText(`连续稳定节律达成第 ${days} 天`, 52, 260);

  // 5. 建议标题
  ctx.fillStyle = '#f7f1e8';
  ctx.font = '500 32px Georgia, "Songti SC", serif';
  ctx.fillText(title, 52, 335);

  // 6. 箴言引用 (自动换行)
  ctx.fillStyle = '#a8a5a0';
  ctx.font = '22px -apple-system, "PingFang SC", sans-serif';
  const words = quote;
  let line = '';
  let y = 390;
  for (let n = 0; n < words.length; n++) {
    const testLine = line + words[n];
    if (ctx.measureText(testLine).width > 530 && n > 0) {
      ctx.fillText(line, 52, y);
      line = words[n];
      y += 34;
    } else {
      line = testLine;
    }
  }
  ctx.fillText(line, 52, y);

  // 7. 七日连击矩阵 (7个纯色方格)
  const gridY = 560;
  ctx.fillStyle = '#838280';
  ctx.font = 'bold 15px -apple-system, sans-serif';
  ctx.fillText('近 7 日连续连击记录', 52, gridY);

  const dayLabels = ['一', '二', '三', '四', '五', '六', '日'];
  const startX = 52;
  const cellSize = 64;
  const cellGap = 15;

  dayLabels.forEach((label, idx) => {
    const cx = startX + idx * (cellSize + cellGap);
    const cy = gridY + 20;

    // 方格背景 (已完成森林绿)
    ctx.fillStyle = '#224228';
    ctx.beginPath();
    ctx.roundRect(cx, cy, cellSize, cellSize, 12);
    ctx.fill();
    ctx.strokeStyle = '#3d6f45';
    ctx.lineWidth = 2;
    ctx.stroke();

    // 内部文本
    ctx.fillStyle = '#ffffff';
    ctx.font = 'bold 20px -apple-system, sans-serif';
    ctx.fillText('✓', cx + 24, cy + 32);

    ctx.font = '14px -apple-system, sans-serif';
    ctx.fillStyle = '#a8a5a0';
    ctx.fillText(label, cx + 26, cy + 54);
  });

  // 8. 底部防伪与水印
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.08)';
  ctx.beginPath();
  ctx.moveTo(52, 850);
  ctx.lineTo(588, 850);
  ctx.stroke();

  ctx.fillStyle = '#64748b';
  ctx.font = '16px -apple-system, sans-serif';
  ctx.fillText('由 KairosStep · 科学人生行为系统生成', 52, 890);

  const dateNow = new Date();
  const dateStr = `${dateNow.getFullYear()}.${dateNow.getMonth() + 1}.${dateNow.getDate()} 晨间完成`;
  ctx.fillText(dateStr, 430, 890);

  return canvas;
}

// 打开分享成就弹窗
function openShareModal(id) {
  playMicroClick(440);
  const item = ALL_ENRICHED_ADVICE.find(x => x.id === id) || { id: 61, t: "保证充足的睡眠" };
  const modal = document.getElementById("share-card-modal");
  if (!modal) return;
  const isChecked = item._streakChecked;
  const days = isChecked ? 15 : 14;
  const title = (item.parts && item.parts[0]) || item.t;
  const t = item.t;

  // 自适应成就印章与箴言
  let stampName = "晨起立行 · 固化";
  let quote = "生物钟不会在周六自动重置；守住同一刻起床，周一才没有时差之苦。";

  if (t.includes("睡") || t.includes("睡眠")) {
    stampName = "节律安睡 · 达标";
    quote = "睡眠不是时间的消耗，而是身体细胞与大脑的系统性深度修复。";
  } else if (t.includes("刷牙") || t.includes("牙缝")) {
    stampName = "口腔健康 · 守护";
    quote = "认真的两分钟与牙线清洁，抵过年老后的十万种植牙费用。";
  } else if (t.includes("步") || t.includes("用力") || t.includes("力量") || t.includes("运动") || t.includes("户外")) {
    stampName = "体魄活力 · 积累";
    quote = "把运动融入日常每一步，持续积累心肺耐力与终身抗衰资本。";
  } else if (t.includes("坚果") || t.includes("蔬菜") || t.includes("咖啡") || t.includes("水") || t.includes("奶")) {
    stampName = "健康滋养 · 纯净";
    quote = "给身体细胞提供干净优质的抗氧化燃料，远离超加工食品的侵蚀。";
  } else if (t.includes("血压") || t.includes("吃药")) {
    stampName = "慢病防护 · 达标";
    quote = "平稳指标源于每日规律的自律守护，每一次监测都是对生命的负责。";
  } else if (t.includes("戒烟")) {
    stampName = "无烟新生 · 胜战";
    quote = "每一个没有吸烟的日子，都是呼吸系统与生命力重获新生的胜利。";
  }

  const safeTitle = title.replace(/'/g, "\\\\'");
  const safeQuote = quote.replace(/'/g, "\\\\'");
  const sheet = modal.querySelector(".share-modal-sheet");
  if (sheet) {
    sheet.innerHTML = `
      <button class="share-modal-close-x" onclick="closeShareModal()">
        <svg class="svg-icon" style="width:13px; height:13px;" viewBox="0 0 24 24"><line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line></svg>
      </button>
      <div class="share-card-brand-row">
        <span class="share-card-brand">KAIROS STEP · 人生指引</span>
        <span class="share-stamp-green">
          <svg class="svg-icon" style="width:10px; height:10px;" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>
          ${stampName}
        </span>
      </div>
      <div class="share-card-days-number">DAY ${days}</div>
      <div class="share-card-days-label">已连续稳定达成 ${days} 天</div>
      <div class="share-card-action-title">${title}</div>
      <div class="share-card-quote">${quote}</div>

      <div class="share-card-grid">
        <div class="share-card-dot active" title="周一完成">一</div>
        <div class="share-card-dot active" title="周二完成">二</div>
        <div class="share-card-dot active" title="周三完成">三</div>
        <div class="share-card-dot active" title="周四完成">四</div>
        <div class="share-card-dot active" title="周五完成">五</div>
        <div class="share-card-dot active" title="周六完成">六</div>
        <div class="share-card-dot active" title="今日达成">日</div>
      </div>

      <div id="share-card-img-container" style="display:none;" class="share-poster-preview-box">
        <!-- 动态注入生成的海报图片预览 -->
      </div>

      <div class="share-card-btn-row">
        <button class="share-card-btn share-card-btn-main" onclick="copyShareCardText(${days}, '${safeTitle}', '${safeQuote}')">
          复制打卡文案
        </button>
        <button class="share-card-btn share-card-btn-sub" onclick="saveShareCardPoster(${days}, '${safeTitle}', '${safeQuote}', '${stampName}')">
          保存成就卡片
        </button>
      </div>
    `;
  }
  modal.style.display = "flex";
}

function closeShareModal() {
  playMicroClick(240);
  const modal = document.getElementById('share-card-modal');
  if (modal) modal.style.display = 'none';
}

function copyShareCardText(days, title, quote) {
  playMicroClick(500);
  const text = `🌅【KairosStep 晨起打卡 · 连续第 ${days} 天】\\n行动：「${title}」\\n箴言：${quote || '守住每日恒定节律，持续积累健康资本。'}\\n——由 KairosStep 生成`;
  if (navigator.clipboard) {
    navigator.clipboard.writeText(text);
  }
  notifyIsland('已复制精美打卡文案到剪贴板，可前往朋友圈或社群分享！');
  setTimeout(closeShareModal, 1200);
}

// 真正导出高清海报图片并触发本地下载
function saveShareCardPoster(days, title, quote, stampName) {
  playSuccessChord();
  const canvas = generatePosterCanvas(days, title, quote, stampName);
  const dataUrl = canvas.toDataURL('image/png');

  // 1. 触发真实浏览器图片下载
  const a = document.createElement('a');
  a.href = dataUrl;
  a.download = `kairos-streak-day${days}.png`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);

  // 2. 在模态框内展示图片预览方便手机端长按存图
  const imgBox = document.getElementById('share-card-img-container');
  if (imgBox) {
    imgBox.style.display = 'block';
    imgBox.innerHTML = `<img src="${dataUrl}" class="share-poster-preview-img" alt="打卡成就卡片"><div style="font-size:10px; color:#838280; padding:4px 0 2px;">海报已生成并下载（手机端亦可长按图片存图）</div>`;
  }

  notifyIsland(`已绘制生成「DAY ${days} 高清成就海报」，已启动图片下载！`);
}
"""

    html = re.sub(
        r"function toggleDailyCheckin\(id, btnEl, punchTimeDefault\) \{.*?(?=function simulateFixedWakeupRoutine\(\))",
        enhanced_js + "\n\n",
        html,
        flags=re.DOTALL
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(html)

    print("Successfully enhanced AdviceInteractiveDemo.html with full tactile and visual interaction suite!")

if __name__ == '__main__':
    main()
