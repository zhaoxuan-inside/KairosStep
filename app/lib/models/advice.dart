// 建议领域模型桶文件（Phase 2 分域重组：全部类名与导入路径保持兼容，行为零变化）。
// 分域结构（见 docs/refactor/ARCHITECTURE.md §3）：
//   advice_core   原始事实元 RawAdvice / 证据包 AdviceDetail / 聚合根 Advice
//   facets        多维属性标签 AdviceFacets
//   presentation  样式表现元 AdvicePresentation / 交互形态 ActionTypeDef / 时机模型 TimingModel / 六大人生领域 LifeDomain
//   trigger       触发模式 TriggerMode / 自定义触发 CustomTriggerConfig / 时段规范 PeriodDefinition
//   user          自建待办 UserTodoItem / 节点包 NodePackage / 90 天周期 / 卡内基复盘 / 紧急联系人
// 新代码请直接引用分域文件；本桶文件仅为存量 22 处 import 的兼容层。
export 'advice_core.dart';
export 'facets.dart';
export 'presentation.dart';
export 'trigger.dart';
export 'user.dart';
