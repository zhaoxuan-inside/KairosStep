# DESIGN.md —— KairosStep / HowToLiveBetter

```yaml
version: 1.0
name: HowToLiveBetter-design
source: 改编自 VoltAgent/awesome-design-md 之 oura（暖纸质感健康生活设计），状态色映射本项目语义
description: 温暖纸感的人生指南界面 —— 奶油纸底、衬线标题、极简细线、药丸控件；状态以纯色块表达（森林绿=完成、淘金=打折进行、银灰=未做、朱红=紧急），不用渐变与文字描述状态。

colors:
  # 基础
  canvas: "#f7f1e8"
  surface: "#ffffff"
  surface-grey: "#ececec"
  hairline: "#e1dcd3"
  ink: "#1c1b1a"
  ink-band: "#19191c"
  stone: "#4a4741"
  ash: "#838280"
  mute: "#a8a5a0"
  silver: "#cccac7"
  # 品牌与功能色
  primary: "#2a72de"        # 行动蓝（挂号、办事、主按钮）
  on-primary: "#ffffff"
  # 状态色（ Wieland=Oura 风）
  done: "#224228"           # 森林绿 —— 完成
  done-bg: "#eef0e4"
  part: "#bc924c"           # 淘金 —— 打折/进行中
  part-bg: "#f4ebdd"
  miss: "#cccac7"           # 银灰 —— 未做
  miss-bg: "#f1efec"
  error: "#e33a22"          # 朱红 —— 紧急/越线
  error-bg: "#fbdfd9"
  # 辅助
  forest: "#224228"
  olive: "#5c6f5d"
  sage: "#849671"
  sage-pale: "#ced4b8"
  gold: "#bc924c"
  gold-sub: "#af751b"
  clay: "#6b443d"

typography:
  serif-display:            # 节标题 / 数字大字
    fontFamily: 'Georgia, "Songti SC", "Noto Serif SC", serif'
    fontSize: 26px
    fontWeight: 500
    lineHeight: 1.2
  title:
    fontFamily: 'Georgia, "Songti SC", serif'
    fontSize: 16px
    fontWeight: 500
  ui:
    fontFamily: '"AkkuratLL", -apple-system, "PingFang SC", "Noto Sans SC", sans-serif'
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.5
  eyebrow:
    fontFamily: '"-apple-system", "PingFang SC", sans-serif'
    fontSize: 9px
    fontWeight: 700
    letterSpacing: 1px
    textTransform: uppercase

rounded:
  xs: 4px
  md: 12px
  lg: 20px      # 卡片
  full: 9999px  # 按钮/胶囊/圆点

spacing: {xxs: 4, xs: 8, sm: 13, md: 16, lg: 24}

components:
  card:          {background: surface, borderColor: hairline, rounded: lg(20), 无阴影}
  card-status:   {状态=整卡底色+描边二位标记；运行态金环脉冲；紧急态红底+红外环脉冲}
  button-primary:    {backgroundColor: "{colors.blue}",  textColor: "{colors.on-primary}", rounded: full}
  button-secondary:  {backgroundColor: "{colors.t-miss}+细框", textColor: "{colors.ink}", rounded: full}
  button-icon-round: {rounded: full, 固定 34-64px, 状态色直填}
  tag:             {eyebrow, background: surface-grey, rounded: full}
  input:           {background: surface, borderColor: hairline, rounded: full, focus borderColor: primary}
  toast:           {background: ink-band, rounded: full}
  banner-urgent:   {background: error, textColor: "#fff", rounded: lg, 图标+最大 6 字}
  verdict-urgent:  {error 底 + Georgia 大号 "120" + 圆形拨号钮}
  share-card:      {background: ink-band, textColor: "#fff", stamp(森林绿方章) + 三枚胶囊钮(复制/系统分享/存图)，分享主钮白底，Web Share 优先带海报图，降级为复制文案+长按存图}
  calendar5:       {每小时 1-2 行，行内 6 个 24px 圆角方格；类型=纯色(蓝/绿/棕)，运行=金颌环脉冲，评价直接变色}
  nano-anim:       {stampin / pop / spin / waveform —— 仅状态切换瞬间出现，不加装饰}

# —— 内容态语义 ——
# 完成信息：只给 效果（状态色+图标），文本只作最小标签（≤6 字 / 图标 title）
# 卡片聚焦原则：交互卡片主体严格聚焦于「原子行动 + 专属微交互器」，不呈现所属分组/章节类型名（如「不要早死」等），避免冗余文字干扰注意力
# 禁用：渐变、毛玻璃、emoji、恐吓性大段文字、卡片露出分组类型名
```
