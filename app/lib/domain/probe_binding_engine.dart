// 建议与主动探查方式绑定引擎（原 models/probe_binding.dart，规则数据化于 probes.json）。
// 解析顺序与原实现逐字对齐：显式 ID 表 → urgent 判定 → 关键词规则链（声明序）→ lifestyle 兜底。
import '../data/engine_config.dart';
import '../models/advice.dart';
import '../models/probe_model.dart';

class AdviceProbeBindingEngine {
  const AdviceProbeBindingEngine(this._bindings);

  final ProbeBindingsConfig _bindings;

  /// 获取指定建议的主动探查方式规范
  AdviceProbeSpec specFor(Advice advice) {
    // 1. 优先查核心重点建议显式表
    final explicit = _bindings.explicit[advice.id];
    if (explicit != null) return explicit;

    // 2. 检查是否为突发急救或生命底线 -> urgent (mandatory)
    if (advice.isEmergencyOrIncident) {
      return _bindings.urgentFallback;
    }

    // 3. 全库自动化语义归并与推断规则（声明序即优先级）
    for (final rule in _bindings.keywordRules) {
      if (rule.matches(advice)) return rule.spec;
    }

    // 默认为常规生活习惯
    return _bindings.lifestyleFallback;
  }
}
