import re

def main():
    path = "docs/AdviceInteractiveDemo.html"
    with open(path, "r", encoding="utf-8") as f:
        text = f.read()

    new_js = """function toggleDailyCheckin(id, btnEl, punchTimeDefault) {
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
    const newCount = baseDays + 1;
    if (countEl) countEl.textContent = newCount;
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
    if (countEl) countEl.textContent = baseDays;
    if (dotEl) {
      dotEl.className = "calendar-day-dot today-pending";
      dotEl.textContent = "今";
    }
    btnEl.classList.remove("checked");
    if (btnText) btnText.textContent = `立即打卡 (${punchText})`;
    notifyIsland("已取消今日打卡记录");
  }
}

function openShareModal(id) {
  const item = ALL_ENRICHED_ADVICE.find(x => x.id === id) || { id: 97, t: "固定起床时间，周末也一样" };
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
        <div class="share-card-dot active">一</div>
        <div class="share-card-dot active">二</div>
        <div class="share-card-dot active">三</div>
        <div class="share-card-dot active">四</div>
        <div class="share-card-dot active">五</div>
        <div class="share-card-dot active">六</div>
        <div class="share-card-dot active">日</div>
      </div>

      <div class="share-card-btn-row">
        <button class="share-card-btn share-card-btn-main" onclick="copyShareCardText(${days}, '${safeTitle}')">
          复制打卡文案
        </button>
        <button class="share-card-btn share-card-btn-sub" onclick="saveShareCardPoster(${days}, '${safeTitle}')">
          保存成就卡片
        </button>
      </div>
    `;
  }
  modal.style.display = "flex";
}"""

    text = re.sub(
        r"function toggleDailyCheckin\(id, btnEl\) \{.*?function openShareModal\(id\) \{.*?(?=function closeShareModal\(\))",
        new_js + "\n\n",
        text,
        flags=re.DOTALL
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)

    print("Successfully updated JS share functions!")

if __name__ == '__main__':
    main()
