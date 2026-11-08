// 数据层兼容出口:Catalog 门面已按分层原则上移至视图层
// (lib/view/catalog.dart —— 加工流程与关联逻辑属视图层);
// 数据层仅保留拆分纯数据的加载器(assets.dart 与各表 loader)。
// 存量 22 处 import 'data/catalog.dart' 经此 shim 零改动续用。
export '../view/action_types.dart' show actionTypes, actionTypeName, actionTypeIcon;
export '../view/catalog.dart';
