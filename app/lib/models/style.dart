// L2 交互样式 + L5 展示↔样式绑定（act_styles.json / display_bindings.json 的强类型视图）。
// 属模型层：UI 与 data/catalog 共同消费，不依赖 Flutter。
// ───────────────────────── styles（act_styles.json / display_bindings.json）─────────────────────────

/// L2 交互样式注册表。
class ActStylesConfig {
  const ActStylesConfig({required this.styles});

  final Map<String, ActStyleDef> styles;

  ActStyleDef? style(String key) => styles[key];

  factory ActStylesConfig.fromJson(Map<String, dynamic> json) =>
      ActStylesConfig(
        styles: {
          for (final e in (json['styles'] as List).cast<Map<String, dynamic>>())
            e['style'] as String: ActStyleDef.fromJson(e),
        },
      );
}

class ActStyleDef {
  const ActStyleDef({
    required this.style,
    required this.name,
    required this.iconKey,
    this.params = const {},
  });

  final String style;
  final String name;
  final String iconKey;
  final Map<String, dynamic> params;

  int intParam(String key, int fallback) =>
      (params[key] as num?)?.toInt() ?? fallback;

  factory ActStyleDef.fromJson(Map<String, dynamic> json) => ActStyleDef(
    style: json['style'] as String,
    name: json['name'] as String,
    iconKey: json['iconKey'] as String? ?? '',
    params: (json['params'] as Map<String, dynamic>?) ?? const {},
  );
}

/// L5 展示信息↔交互样式绑定（聚光专项覆盖）。
class DisplayBindingsConfig {
  const DisplayBindingsConfig({required this.byAdvice});

  final Map<int, DisplayBinding> byAdvice;

  DisplayBinding? bindingOf(int adviceId) => byAdvice[adviceId];

  factory DisplayBindingsConfig.fromJson(Map<String, dynamic> json) =>
      DisplayBindingsConfig(
        byAdvice: {
          for (final e in (json['list'] as List).cast<Map<String, dynamic>>())
            (e['id'] as num).toInt(): DisplayBinding.fromJson(e),
        },
      );
}

class DisplayBinding {
  const DisplayBinding({
    required this.adviceId,
    required this.style,
    required this.override,
    this.params = const {},
  });

  final int adviceId;
  final String style;
  final String? override; // 聚光专项交互器 key
  final Map<String, dynamic> params;

  int intParam(String key, int fallback) =>
      (params[key] as num?)?.toInt() ?? fallback;

  List<int> intListParam(String key) => ((params[key] as List?) ?? const [])
      .map((e) => (e as num).toInt())
      .toList();

  List<String> stringListParam(String key) =>
      ((params[key] as List?) ?? const []).cast<String>();

  factory DisplayBinding.fromJson(Map<String, dynamic> json) => DisplayBinding(
    adviceId: (json['id'] as num).toInt(),
    style: json['style'] as String,
    override: json['override'] as String?,
    params: (json['params'] as Map<String, dynamic>?) ?? const {},
  );
}

/// 闹钟预设（daily-streak 参数视图）。
class AlarmPreset {
  const AlarmPreset({
    required this.match,
    this.allOf = const [],
    required this.alarmName,
    required this.defaultTime,
    this.fallback = false,
  });

  final List<String> match; // 任一子串命中
  final List<List<String>> allOf; // 每组内全部命中（如 [屏幕,睡]）
  final String alarmName;
  final String defaultTime;
  final bool fallback;

  bool matches(String title) =>
      match.any(title.contains) || allOf.any((g) => g.every(title.contains));

  factory AlarmPreset.fromJson(Map<String, dynamic> json) => AlarmPreset(
    match: (json['match'] as List?)?.cast<String>() ?? const [],
    allOf: ((json['allOf'] as List?) ?? const [])
        .map((g) => (g as List).cast<String>())
        .toList(),
    alarmName: json['alarmName'] as String,
    defaultTime: json['defaultTime'] as String,
    fallback: json['fallback'] as bool? ?? false,
  );
}

/// 滑杆测算变体（slider-calc 参数视图；读数公式按 key 分派，保留在交互器）。
class SliderVariant {
  const SliderVariant({
    required this.key,
    required this.match,
    required this.label,
    required this.unit,
    required this.max,
  });

  final String key;
  final List<String> match;
  final String label;
  final String unit;
  final int max;

  bool matches(String title) => match.any(title.contains);

  factory SliderVariant.fromJson(Map<String, dynamic> json) => SliderVariant(
    key: json['key'] as String,
    match: (json['match'] as List?)?.cast<String>() ?? const [],
    label: json['label'] as String,
    unit: json['unit'] as String,
    max: (json['max'] as num).toInt(),
  );
}
