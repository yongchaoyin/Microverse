# Phase E: Polish & QA - 开发计划

## 📋 阶段概述

**阶段名称**: Phase E - Polish & Quality Assurance
**目标**: 完善系统、提升用户体验、确保稳定性
**预计时间**: 12-15小时
**优先级**: P0 (关键)

## 🎯 核心目标

1. **WeatherSystem**: 实现季节性天气系统，增加游戏沉浸感
2. **性能监控**: 通过DebugConsole提供实时性能分析
3. **UI/UX优化**: 优化ObservationUI，提升交互体验
4. **自动化测试**: 编写核心功能测试，确保系统稳定性

## 📅 任务分解

### Task 1: WeatherSystem实现 ⭐⭐⭐

**优先级**: P0
**预计时间**: 3-4小时

#### 1.1 核心天气系统

**功能需求**:
- 天气状态枚举: SUNNY, RAINY, SNOWY, CLOUDY, FOGGY, STORMY
- 季节性天气概率分布
- 天气转换逻辑(平滑过渡)
- 天气持续时间系统

**数据结构**:
```gdscript
{
  "current_weather": "SUNNY",
  "temperature": 25.0,
  "humidity": 60.0,
  "wind_speed": 5.0,
  "weather_start_time": 1736932200.0,
  "weather_duration": 3600.0,  # 1小时
  "next_weather": "CLOUDY"
}
```

**季节天气概率表**:
```json
{
  "spring": {
    "SUNNY": 0.4,
    "RAINY": 0.3,
    "CLOUDY": 0.2,
    "FOGGY": 0.1
  },
  "summer": {
    "SUNNY": 0.6,
    "RAINY": 0.2,
    "CLOUDY": 0.15,
    "STORMY": 0.05
  },
  "autumn": {
    "CLOUDY": 0.4,
    "RAINY": 0.3,
    "SUNNY": 0.2,
    "FOGGY": 0.1
  },
  "winter": {
    "SNOWY": 0.4,
    "CLOUDY": 0.3,
    "SUNNY": 0.2,
    "FOGGY": 0.1
  }
}
```

**核心API**:
```gdscript
# 获取当前天气
func get_current_weather() -> Dictionary

# 触发天气变化
func change_weather(new_weather: WeatherType, duration: float)

# 获取天气描述
func get_weather_description() -> String

# 检查是否下雨/下雪
func is_raining() -> bool
func is_snowing() -> bool
```

**信号系统**:
```gdscript
signal weather_changed(old_weather: String, new_weather: String)
signal temperature_changed(new_temp: float)
signal extreme_weather_started(weather_type: String)
```

#### 1.2 天气影响系统

**AI心情影响**:
- SUNNY: +5 mood
- RAINY: -3 mood
- SNOWY: -2 mood (winter) / -5 mood (other seasons)
- CLOUDY: -1 mood
- STORMY: -10 mood

**行为影响**:
- 下雨天减少户外活动倾向
- 晴天提升工作效率 (+10%)
- 暴风雨天AI倾向待在室内

**实现方式**:
```gdscript
# 在ScheduleManager中
func _apply_weather_modifier(activity: Dictionary) -> Dictionary:
    var weather = WeatherSystem.get_current_weather()

    if activity.location_type == "outdoor":
        if weather.current_weather in ["RAINY", "STORMY"]:
            activity.preference_penalty = -30  # 降低户外活动意愿

    return activity

# 在AIAgent中
func _calculate_work_efficiency() -> float:
    var base_efficiency = 1.0
    var weather = WeatherSystem.get_current_weather()

    if weather.current_weather == "SUNNY":
        base_efficiency *= 1.1
    elif weather.current_weather == "STORMY":
        base_efficiency *= 0.8

    return base_efficiency
```

#### 1.3 天气可视化

**简单粒子效果**:
- 雨滴粒子系统(GPUParticles2D)
- 雪花粒子系统
- 云层移动效果(Sprite移动)

**天气UI显示**:
- 右上角天气图标
- 温度显示
- 天气描述文字

**天气音效** (可选):
- 雨声音效
- 雷声音效
- 风声音效

**代码量预估**: 400-500行

---

### Task 2: 性能监控系统 ⭐⭐⭐

**优先级**: P0
**预计时间**: 3-4小时

#### 2.1 DebugConsole增强

**新增面板**:
1. **性能仪表盘** (PerformancePanel)
   - FPS显示
   - 内存使用量
   - 活跃节点数量
   - 活跃Timer数量

2. **LLM监控面板** (LLMMetricsPanel)
   - API调用总次数
   - 成功/失败率
   - 平均响应时间
   - Token消耗统计
   - 按角色分组统计

3. **系统状态面板** (SystemStatusPanel)
   - 活跃对话数量
   - 活跃任务数量
   - 活跃冲突数量
   - 经济交易量

**核心功能**:
```gdscript
# PerformanceMonitor.gd
class_name PerformanceMonitor

var _metrics: Dictionary = {
    "fps": [],
    "memory_mb": [],
    "node_count": [],
    "llm_calls": 0,
    "llm_success": 0,
    "llm_fail": 0,
    "llm_total_time": 0.0,
    "llm_token_count": 0
}

func record_fps(fps: float):
    _metrics.fps.append(fps)
    if _metrics.fps.size() > 60:
        _metrics.fps.pop_front()

func record_llm_call(success: bool, response_time: float, tokens: int):
    _metrics.llm_calls += 1
    if success:
        _metrics.llm_success += 1
    else:
        _metrics.llm_fail += 1
    _metrics.llm_total_time += response_time
    _metrics.llm_token_count += tokens

func get_average_fps() -> float:
    if _metrics.fps.is_empty():
        return 0.0
    return _metrics.fps.reduce(func(acc, val): return acc + val, 0.0) / _metrics.fps.size()

func get_llm_success_rate() -> float:
    if _metrics.llm_calls == 0:
        return 0.0
    return float(_metrics.llm_success) / float(_metrics.llm_calls)
```

#### 2.2 APIManager集成监控

**修改APIManager**:
```gdscript
# 在APIManager中添加监控钩子
func _on_request_completed(result, response_code, headers, body, character_name, http_node):
    var end_time = Time.get_ticks_msec()
    var response_time = (end_time - http_node.get_meta("start_time", end_time)) / 1000.0

    var success = response_code == 200
    var tokens = _estimate_tokens(body)

    # 记录到性能监控
    if PerformanceMonitor:
        PerformanceMonitor.record_llm_call(success, response_time, tokens)

    # ... 原有逻辑
```

#### 2.3 实时图表显示

**使用Godot内置绘图**:
```gdscript
# 绘制FPS曲线图
func _draw_fps_chart(canvas: Control, data: Array):
    var chart_size = Vector2(300, 100)
    var max_fps = 60.0

    for i in range(data.size() - 1):
        var x1 = float(i) / data.size() * chart_size.x
        var y1 = chart_size.y - (data[i] / max_fps * chart_size.y)
        var x2 = float(i + 1) / data.size() * chart_size.x
        var y2 = chart_size.y - (data[i + 1] / max_fps * chart_size.y)

        canvas.draw_line(Vector2(x1, y1), Vector2(x2, y2), Color.GREEN, 2.0)
```

**代码量预估**: 500-600行

---

### Task 3: UI/UX优化 ⭐⭐

**优先级**: P1
**预计时间**: 3-4小时

#### 3.1 ObservationUI性能优化

**优化点**:
1. **节点池(Object Pooling)**:
   - 复用冲突列表项节点
   - 复用关系图节点
   - 减少节点创建/销毁开销

2. **延迟加载**:
   - 只在面板可见时刷新数据
   - 使用虚拟滚动(Virtual Scrolling)

3. **批量更新**:
   - 合并多个关系变化为单次更新
   - 使用脏标记(Dirty Flag)模式

**实现示例**:
```gdscript
# 节点池实现
class NodePool:
    var _pool: Array = []
    var _scene: PackedScene

    func get_node() -> Control:
        if _pool.is_empty():
            return _scene.instantiate()
        return _pool.pop_back()

    func return_node(node: Control):
        node.visible = false
        _pool.append(node)

# 虚拟滚动实现
class VirtualScrollContainer:
    var _visible_items: int = 10
    var _item_height: float = 60.0
    var _scroll_position: float = 0.0

    func _update_visible_items(all_items: Array):
        var start_index = int(_scroll_position / _item_height)
        var end_index = start_index + _visible_items

        # 只更新可见项
        for i in range(start_index, min(end_index, all_items.size())):
            _render_item(all_items[i], i)
```

#### 3.2 关系图交互增强

**新增功能**:
1. **节点拖拽**:
   - 鼠标拖拽调整节点位置
   - 保存用户自定义布局

2. **缩放和平移**:
   - 鼠标滚轮缩放
   - 中键拖拽平移画布

3. **节点高亮**:
   - 鼠标悬停高亮节点
   - 显示关系提示框

4. **连线高亮**:
   - 点击节点高亮所有相关连线
   - 连线粗细动画

**实现示例**:
```gdscript
# 节点拖拽
var _dragging_node = null
var _drag_offset = Vector2.ZERO

func _on_node_gui_input(event: InputEvent, ai_id: String):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                _dragging_node = ai_id
                var node = _character_nodes[ai_id]["node"]
                _drag_offset = event.position - node.position
            else:
                _dragging_node = null

    elif event is InputEventMouseMotion:
        if _dragging_node == ai_id:
            var node = _character_nodes[ai_id]["node"]
            node.position = event.position - _drag_offset
            _character_nodes[ai_id]["position"] = node.position + NODE_SIZE / 2
            queue_redraw()  # 重绘连线
```

#### 3.3 统一UI主题

**创建主题资源**:
```gdscript
# res://resources/themes/main_theme.tres
[gd_resource type="Theme"]

[resource]
default_font = preload("res://assets/fonts/main_font.ttf")

# 按钮样式
Button/colors/font_color = Color(0.9, 0.9, 0.9)
Button/colors/font_hover_color = Color(1.0, 1.0, 1.0)
Button/styles/normal = StyleBoxFlat { bg_color = Color(0.2, 0.2, 0.25) }
Button/styles/hover = StyleBoxFlat { bg_color = Color(0.25, 0.25, 0.3) }

# 面板样式
Panel/styles/panel = StyleBoxFlat { bg_color = Color(0.15, 0.15, 0.2, 0.95) }

# 标签样式
Label/colors/font_color = Color(0.9, 0.9, 0.9)
Label/font_sizes/font_size = 14
```

**应用主题**:
```gdscript
# 在ObservationUI中
func _ready():
    var main_theme = load("res://resources/themes/main_theme.tres")
    theme = main_theme
```

**代码量预估**: 400-500行

---

### Task 4: 自动化测试 ⭐

**优先级**: P2 (可选)
**预计时间**: 3-4小时

#### 4.1 测试框架选择

**使用GUT (Godot Unit Test)**:
- 安装: https://github.com/bitwes/Gut
- 集成到项目

#### 4.2 核心功能测试

**测试1: SaveManager测试**:
```gdscript
# test_save_manager.gd
extends GutTest

func test_save_and_load_basic():
    var save_manager = get_node("/root/SaveManager")

    # 保存当前状态
    var save_name = "test_save_" + str(Time.get_ticks_msec())
    save_manager.save_game(save_name)

    # 修改一些状态
    var time_system = get_node("/root/TimeSystem")
    var original_day = time_system.current_day
    time_system.add_days(5)

    # 加载存档
    save_manager.load_game(save_name)

    # 验证状态恢复
    assert_eq(time_system.current_day, original_day, "时间应该恢复到保存时的状态")
```

**测试2: ConflictSystem测试**:
```gdscript
# test_conflict_system.gd
extends GutTest

func test_conflict_lifecycle():
    var conflict_system = get_node("/root/ConflictSystem")

    # 触发冲突
    var conflict_id = conflict_system.trigger_conflict(
        "test_ai_a", "test_ai_b",
        conflict_system.ConflictType.TASK_DISPUTE,
        5, "测试冲突"
    )

    assert_ne(conflict_id, "", "冲突应该成功创建")

    # 获取冲突
    var conflict = conflict_system.get_conflict(conflict_id)
    assert_eq(conflict.source_id, "test_ai_a", "源AI应该正确")
    assert_eq(conflict.severity, 5, "严重程度应该正确")

    # 解决冲突
    var resolved = conflict_system.resolve_conflict(
        conflict_id,
        conflict_system.ResolutionType.COMPROMISE,
        "测试解决"
    )

    assert_true(resolved, "冲突应该成功解决")
```

**测试3: RelationshipManager测试**:
```gdscript
# test_relationship_manager.gd
extends GutTest

func test_relationship_modification():
    var rel_manager = get_node("/root/RelationshipManager")

    # 初始化关系
    rel_manager.initialize_relationship("test_ai_a", "test_ai_b")

    # 修改关系
    var changes = {"affection": 10.0, "trust": 5.0}
    rel_manager.modify_relationship("test_ai_a", "test_ai_b", changes, "测试修改")

    # 验证修改
    var relationship = rel_manager.get_relationship("test_ai_a", "test_ai_b")
    assert_almost_eq(relationship.affection, 10.0, 0.1, "好感度应该增加")
    assert_almost_eq(relationship.trust, 5.0, 0.1, "信任度应该增加")
```

**代码量预估**: 300-400行

---

## 📊 总体时间预估

| 任务 | 预计时间 | 优先级 |
|------|---------|--------|
| WeatherSystem实现 | 3-4小时 | P0 |
| 性能监控系统 | 3-4小时 | P0 |
| UI/UX优化 | 3-4小时 | P1 |
| 自动化测试 | 3-4小时 | P2 |
| **总计** | **12-16小时** | |

## 📁 文件结构

```
Microverse/
├── script/
│   ├── weather/
│   │   └── WeatherSystem.gd          # 天气系统核心
│   ├── debug/
│   │   ├── DebugConsole.gd           # 扩展性能监控
│   │   └── PerformanceMonitor.gd     # 性能监控单例
│   └── ui/
│       └── observation/
│           ├── ObservationUI.gd      # 优化后的主容器
│           ├── RelationshipGraphPanel.gd  # 增加拖拽功能
│           └── ...
├── resources/
│   └── themes/
│       └── main_theme.tres           # 统一UI主题
├── data/
│   └── weather/
│       └── weather_tables.json       # 天气概率表
├── tests/
│   ├── test_save_manager.gd
│   ├── test_conflict_system.gd
│   └── test_relationship_manager.gd
└── docs/
    └── runing/
        ├── 22_Phase_E_开发计划.md
        ├── 23_WeatherSystem_完成报告.md
        ├── 24_性能监控_完成报告.md
        └── 25_Phase_E_完成报告.md
```

## ✅ 验收标准

### WeatherSystem
- [ ] 天气状态正确切换
- [ ] 季节性天气概率符合配置
- [ ] 天气影响AI心情
- [ ] 天气可视化效果显示
- [ ] 天气描述文字正确

### 性能监控
- [ ] FPS实时显示
- [ ] 内存使用量准确
- [ ] LLM调用统计正确
- [ ] 图表实时更新
- [ ] 性能数据可导出

### UI/UX优化
- [ ] ObservationUI流畅无卡顿
- [ ] 关系图节点可拖拽
- [ ] 缩放和平移功能正常
- [ ] UI主题统一应用
- [ ] 交互反馈及时

### 自动化测试
- [ ] 存档/读档测试通过
- [ ] 冲突系统测试通过
- [ ] 关系系统测试通过
- [ ] 测试覆盖率>60%

## 🚀 实施顺序

**第1步**: WeatherSystem (高优先级,快速见效)
- 实现核心天气逻辑
- 添加基础可视化
- 集成到TimeSystem

**第2步**: 性能监控 (高优先级,长期价值)
- 扩展DebugConsole
- 添加PerformanceMonitor
- 集成到APIManager

**第3步**: UI/UX优化 (中优先级,提升体验)
- 优化ObservationUI性能
- 添加关系图交互
- 统一UI主题

**第4步**: 自动化测试 (可选,时间充裕时执行)
- 安装GUT框架
- 编写核心测试
- 配置CI流程

---

**准备开始实施!** 🎯
