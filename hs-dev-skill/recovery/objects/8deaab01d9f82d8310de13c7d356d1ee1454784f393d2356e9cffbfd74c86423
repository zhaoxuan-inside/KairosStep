# KairosStep 应用图标

生成日期：2026-10-28。使用内置 `image_gen` 工具生成，未调用 CLI/API 备用路径。

## 品牌含义

深海军蓝背景、翠绿盾形与一条向上的路径，表达防护、行动和持续改善。完整图形没有字母、文字、医疗十字或计步符号，用同一枚标志承载风险预防、事件应对、减少坏习惯与建立好习惯。

主文件：`kairosstep-icon.png`，保留生成结果的原始方形分辨率和不透明背景。导出时仅进行尺寸缩放、RGB 转换与平台编码，不重画图形。主图不是图标包中的示意图。

## 导出与核验

从仓库根运行（Python 3，依赖 Pillow）：

```bash
python3 tools/export_app_icons.py
python3 tools/export_app_icons.py --check
```

Android 使用现有 5 个 mipmap 密度；iOS/macOS 依据各自 `Contents.json`；Web 覆盖现有 192/512 与 maskable 资源以及 favicon；Windows ICO 包含 16/24/32/48/64/128/256 像素帧。平台资源使用原有文件名，沿用现有资源引用。Linux 当前没有独立的应用图标资源槽位，未虚构 Linux 集成完成。

核验包含主图方形、最小分辨率、不透明度，所有 PNG 尺寸与像素、Windows ICO 全部帧的像素。手机系统的图标掩模、实际安装与桌面观感需要设备验收。本次未生成新的 APK/IPA 或桌面安装包，已有历史安装包不包含此次图标。

## 原始生成提示词

```text
Use case: logo-brand. Asset type: final production mobile application icon, square 1024x1024 or higher, for KairosStep 人生阶跃, an offline personal safety and behavior guidance app. Primary request: a distinctive calm, trustworthy app icon expressing protection from everyday risks and steady improvement in life. Create one bold unified geometric emblem: a protective shield whose internal negative space forms a clear upward two-step path, with a softly rounded small terminal point suggesting the next achievable action. The shield and pathway must read as one coherent simple brand mark, not separate pictograms. Style: highly polished flat vector-like graphic, precise geometry, generous negative space, softly rounded corners in the emblem, no 3D. Backdrop: full bleed solid very dark navy matching #0C0F17, completely opaque; no pre-rounded tile outline because operating systems mask the icon. Emblem in rich emerald/teal close to #10B981 with a restrained lighter mint path; use no more than three colors. Composition: emblem centered, occupies approximately 58 percent of canvas width and height; keep all significant content within the central 60 percent for Android adaptive icon safe area. Must remain immediately recognizable at 48px. No text, no letters, no numbers, no Flutter logo, no medical cross, no heart pulse, no running person, no finance chart, no checkmark, no padlock, no tiny details, no gradients, no drop shadow, no borders, no mockup, no multiple options, no watermark. Return just the single square icon artwork.
```

提示词属于设计意图，实际视觉交付以主图为准；工具结果有轻微明暗变化，未把提示词中的精确颜色与几何比例当作实测值。
