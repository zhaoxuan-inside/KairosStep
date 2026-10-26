import re
import json

def main():
    path = "docs/AdviceInteractiveDemo.html"
    with open(path, "r", encoding="utf-8") as f:
        html = f.read()

    # Match ALL_ENRICHED_ADVICE
    m = re.search(r"const ALL_ENRICHED_ADVICE = (\[.*?\]);", html, re.DOTALL)
    if not m:
        print("Error: Could not match ALL_ENRICHED_ADVICE")
        return

    data = json.loads(m.group(1))
    print(f"Loaded {len(data)} items.")

    # 1. Rules for daily habits that should be daily-streak
    habit_upgrades = {
      98: {"badge": "每日睡前 · 23:00 节律", "desc": "睡前放下手机与节律感知，睡眠达标打卡与连续连击", "type": "daily-streak"},
      61: {"badge": "每日睡前 · 23:00 节律", "desc": "作息恒定感知，睡足7小时打卡与连续连击", "type": "daily-streak"},
      106: {"badge": "每日午间 · 13:00 小憩", "desc": "午后疲劳节律提醒，10分钟高效小憩打卡", "type": "daily-streak"},
      59: {"badge": "每日日间 · 步数达成", "desc": "计步传感器联动，每日7000步/快走打卡与连击", "type": "daily-streak"},
      63: {"badge": "每日日间 · 碎片用力", "desc": "久坐与爬楼梯情境感知，每日4-5分钟高强度活动打卡", "type": "daily-streak"},
      64: {"badge": "每周周期 · 力量训练", "desc": "每周健身日程提醒，30-60分钟抗阻训练打卡", "type": "daily-streak"},
      58: {"badge": "每日早晚 · 洗漱护理", "desc": "洗漱时段定时提醒，每日刷牙与牙线清洁打卡", "type": "daily-streak"},
      70: {"badge": "每日午间 · 优质脂肪", "desc": "午餐/加餐时段提醒，每日一小把坚果打卡", "type": "daily-streak"},
      74: {"badge": "每日日间 · 咖啡因管理", "desc": "日间提神感知，适量黑咖啡摄入打卡与无糖记录", "type": "daily-streak"},
      75: {"badge": "每日三餐 · 膳食纤维", "desc": "正餐时段提醒，每日5份果蔬达标打卡与连击", "type": "daily-streak"},
      82: {"badge": "每日早间 · 优质乳钙", "desc": "早餐时段提醒，每日奶制品摄入打卡", "type": "daily-streak"},
      482: {"badge": "每日多次 · 充足饮水", "desc": "全天饮水间隔提醒，每日2.5L控盐打卡", "type": "daily-streak"},
      7: {"badge": "每日晨起 · 血压监测", "desc": "晨起固定测量提醒，血压读数记录与服药达标打卡", "type": "daily-streak"},
      475: {"badge": "每日定点 · 规范服药", "desc": "医嘱服药周期提醒，按时规律服药打卡，绝不擅自停药", "type": "daily-streak"},
      49: {"badge": "每日全天 · 戒烟连击", "desc": "设定戒烟日，记录连续无烟天数，生成成就卡片分享激励", "type": "daily-streak"},
      52: {"badge": "每日全天 · 戒烟连击", "desc": "设定戒烟日，记录连续无烟天数，生成成就卡片分享激励", "type": "daily-streak"},
      100: {"badge": "每日固定 · 批量消息", "desc": "工作日固定时段提醒，每日集中批量处理邮件与消息打卡", "type": "daily-streak"},
      687: {"badge": "每日白天 · 户外光照", "desc": "自然光暴露感知，每日2小时户外防近视打卡与成就分享", "type": "daily-streak"}
    }

    # 2. Situational / Acute items misclassified as leisure
    situational_upgrades = {
      10: {"badge": "情境感知 · 上车即查", "desc": "车载蓝牙或出行感应，检查4岁以下儿童安全座椅"},
      12: {"badge": "情境感知 · 涉水防险", "desc": "亲水地理围栏或户外提醒，儿童近水不离视线并穿救生衣"},
      15: {"badge": "突发外伤 · 当天即办", "desc": "铁钉木刺外伤直达，当天清创并排查破伤风针"},
      30: {"badge": "情境感知 · 亲密防护", "desc": "亲密生活决策时点，全程使用安全套与器具专有"},
      414: {"badge": "P0 紧急 · 触电施救", "desc": "触电现场秒级直达，先断电再用干燥木棍挑开，严禁直接手拉", "type": "emergency-action"},
      422: {"badge": "P0 紧急 · 海姆立克", "desc": "气道异物梗阻秒级直达，5次拍背+5次腹部冲击", "type": "emergency-action"},
      425: {"badge": "P0 紧急 · 毒蛇咬伤", "desc": "毒蛇咬伤秒级直达，坐下制动、摘除饰品速送医，不切不吸", "type": "emergency-action"},
      437: {"badge": "P0 紧急 · 骨折制动", "desc": "疑似骨折秒级直达，托住制动冷敷20分钟，严禁自行掰正", "type": "emergency-action"}
    }

    updated_habits = 0
    updated_situational = 0

    for item in data:
        iid = item.get("id")
        if iid in habit_upgrades:
            u = habit_upgrades[iid]
            item["timing_badge"] = u["badge"]
            item["timing_desc"] = u["desc"]
            item["act_type"] = u["type"]
            updated_habits += 1
        elif iid in situational_upgrades:
            u = situational_upgrades[iid]
            item["timing_badge"] = u["badge"]
            item["timing_desc"] = u["desc"]
            if "type" in u:
                item["act_type"] = u["type"]
            updated_situational += 1

    print(f"Updated {updated_habits} habit items to daily-streak.")
    print(f"Updated {updated_situational} situational items out of leisure.")

    new_json = json.dumps(data, ensure_ascii=False)
    new_html = html[:m.start(1)] + new_json + html[m.end(1):]

    with open(path, "w", encoding="utf-8") as f:
        f.write(new_html)

    print("Successfully written updated data back to docs/AdviceInteractiveDemo.html")

if __name__ == '__main__':
    main()
