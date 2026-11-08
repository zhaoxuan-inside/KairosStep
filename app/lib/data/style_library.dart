import '../models/style.dart';

/// 数据层：交互库（styles/ 两表）——13 形态注册表 + 按建议覆盖绑定。
/// 类型定义复用 models/style.dart 的 ActStylesConfig / DisplayBindingsConfig。

ActStylesConfig loadActStyles(Map<String, dynamic> json) =>
    ActStylesConfig.fromJson(json);

DisplayBindingsConfig loadDisplayBindings(Map<String, dynamic> json) =>
    DisplayBindingsConfig.fromJson(json);
