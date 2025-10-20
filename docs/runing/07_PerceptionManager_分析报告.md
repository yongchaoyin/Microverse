# PerceptionManager 系统分析报告

## 📋 文档信息
- **系统名称**: PerceptionManager (感知管理器)
- **分析日期**: 2025-10-20
- **分析师**: Claude (Sonnet 4.5)
- **当前状态**: ❌ 未实现 (0% 完成)

---

## 1. 需求分析

### 1.1 设计文档来源

根据以下文档分析:
1. **03_Phase_B_AI核心能力_进度报告.md** - 列出PerceptionManager为Phase B中优先级系统
2. **13_LLM集成架构详细规范.md** - 定义了"环境感知"作为AI思考类型之一
3. **15_Godot项目技术架构.md** - 未明确定义PerceptionManager作为Autoload

### 1.2 核心功能需求

根据进度报告,PerceptionManager需要实现以下功能:

#### 1. 空间感知 (Spatial Perception)
- **检测附近的AI**
  - 距离计算
  - 视野范围判断
  - 实时更新附近AI列表

#### 2. 社交感知 (Social Perception)
- **检测可互动对象**
  - 基于关系等级判断互动优先级
  - 判断社交机会 (谁在附近可以聊天)
  - 优先级排序 (基于关系、性格契合度)

#### 3. 环境感知 (Environmental Perception)
- **地点检测**
  - 当前所在地点
  - 附近可移动的地点
- **活动识别**
  - 检测当前地点的活动类型
  - 检测其他AI正在做什么
- **时间段感知**
  - 当前时间段 (早晨/下午/晚上/深夜)
  - 天气状态

#### 4. 感知过滤 (Perception Filtering)
- **基于性格过滤**
  - 外向AI感知更多社交机会
  - 内向AI忽略部分社交信号
- **基于关系过滤**
  - 优先感知好友和亲密关系
  - 过滤陌生人或敌人
- **减少计算负担**
  - 不是每帧都计算
  - 缓存感知结果

---

## 2. 现有实现分析

### 2.1 现状
- **文件状态**: ❌ 不存在
- **代码量**: 0行
- **实现度**: 0%

### 2.2 相关已有代码

虽然PerceptionManager本身不存在,但在**13_LLM集成架构详细规范.md**中发现了相关代码片段:

```gdscript
# 环境感知 (每5分钟)
func _on_environmental_perception():
    if ai_agent.is_sleeping:
        return

    print("[AI感知] %s 感知周围环境..." % ai_agent.character_name)
    AIThinkingSystem.perceive_environment(ai_agent)
```

以及附近AI检测的示例:

```gdscript
# 示例:检测附近AI
func _get_nearby_ais(ai: Node) -> Array:
    var nearby = []
    var all_ais = get_tree().get_nodes_in_group("ai_characters")

    for other_ai in all_ais:
        if other_ai == ai:
            continue

        var distance = ai.global_position.distance_to(other_ai.global_position)
        if distance < 200:  # 感知半径
            nearby.append(other_ai)

    return nearby
```

**分析**: 这些代码片段分散在不同的地方(AIAgent.gd, AIThinkingSystem.gd等),没有统一的感知管理器。

---

## 3. 设计决策

### 3.1 是否应该作为Autoload?

**分析**:

**反对Autoload的理由**:
1. PerceptionManager不需要全局单例
2. 每个AI的感知是独立的,不需要共享状态
3. 感知逻辑可以作为AI的组件存在

**支持Autoload的理由**:
1. 统一管理所有AI的感知缓存
2. 优化性能:避免重复计算 (如多个AI检测同一区域)
3. 集中管理感知配置 (感知半径、更新频率等)
4. 更容易调试和监控

**决策**: ⚖️ **不作为Autoload,而是作为AI组件**

**理由**:
- PerceptionManager的主要职责是**为单个AI提供感知服务**,而非全局管理
- 感知数据是AI特定的 (视野、性格过滤都是个体化的)
- 可以通过**PerceptionComponent**方式实现,挂载到每个AICharacter上
- 如果需要全局优化,可以在CharacterManager层面实现感知缓存

---

### 3.2 实现方式决策

**方案A: Autoload单例 + 集中管理**
```gdscript
# script/ai/PerceptionManager.gd (Autoload)
extends Node

var perception_cache: Dictionary = {}  # {ai_id: PerceptionData}

func update_perception(ai_id: String) -> Dictionary:
    # 计算感知
    pass
```

**方案B: 组件化 + 每个AI独立**
```gdscript
# script/ai/perception/PerceptionComponent.gd
extends Node

var ai_character: Node
var cached_perception: Dictionary = {}

func update_perception() -> Dictionary:
    # 计算当前AI的感知
    pass
```

**最终决策**: ✅ **方案B - 组件化实现**

**具体实现方案**:
```
AICharacter (CharacterBody2D)
└── Components (Node)
    ├── AIBrain (Node)
    ├── MovementController (Node)
    ├── PerceptionComponent (Node)  # ✅ 新增
    └── ...
```

**优势**:
1. **解耦**: 每个AI的感知逻辑独立
2. **性能**: 可以按需启用/禁用感知 (如AI睡觉时)
3. **灵活**: 每个AI可以有不同的感知配置
4. **可扩展**: 未来可以添加特殊感知能力 (如某些AI有"第六感")

---

## 4. 功能规格详细设计

### 4.1 PerceptionComponent核心结构

```gdscript
# script/ai/perception/PerceptionComponent.gd
class_name PerceptionComponent extends Node

# ========================================
# 配置
# ========================================
const PERCEPTION_RADIUS = 300.0       # 感知半径 (像素)
const VISION_CONE_ANGLE = 180.0       # 视野角度 (度)
const UPDATE_INTERVAL = 5.0           # 更新间隔 (秒,游戏内5分钟)
const MAX_PERCEIVED_CHARACTERS = 10   # 最多感知10个AI

# ========================================
# 感知数据
# ========================================
var ai_character: Node                # 所属AI角色
var cached_perception: Dictionary = {
    "nearby_characters": [],          # 附近的AI
    "current_location": null,         # 当前地点
    "nearby_locations": [],           # 附近地点
    "current_activities": {},         # 正在进行的活动
    "time_period": "",                # 时间段
    "weather": "",                    # 天气
    "last_update_time": 0.0           # 上次更新时间
}

# ========================================
# 信号
# ========================================
signal perception_updated(perception_data: Dictionary)
signal character_entered_range(character: Node)
signal character_left_range(character: Node)
signal arrived_at_new_location(location: Dictionary)

# ========================================
# 核心方法
# ========================================

func update_perception() -> Dictionary:
    """更新感知数据"""

    var perception = {}

    # 1. 空间感知
    perception.nearby_characters = _perceive_nearby_characters()
    perception.current_location = _perceive_current_location()
    perception.nearby_locations = _perceive_nearby_locations()

    # 2. 社交感知
    perception.social_opportunities = _perceive_social_opportunities()

    # 3. 环境感知
    perception.current_activities = _perceive_current_activities()
    perception.time_period = TimeSystem.get_time_period()
    perception.weather = WeatherSystem.get_current_weather()

    # 4. 感知过滤
    perception = _apply_perception_filters(perception)

    cached_perception = perception
    cached_perception.last_update_time = Time.get_ticks_msec() / 1000.0

    perception_updated.emit(perception)

    return perception

func get_perception() -> Dictionary:
    """获取当前感知数据 (可能是缓存的)"""
    return cached_perception

func get_perception_summary_for_llm() -> String:
    """为LLM生成感知摘要"""
    var summary = ""

    # 地点
    if cached_perception.current_location:
        summary += "我现在在%s。\n" % cached_perception.current_location.name_cn

    # 周围的人
    if cached_perception.nearby_characters.size() > 0:
        summary += "周围有:\n"
        for char_data in cached_perception.nearby_characters:
            var relationship = _get_relationship_description(char_data.character_id)
            var activity = char_data.get("current_activity", "")
            summary += "  - %s (%s)%s\n" % [
                char_data.character_name,
                relationship,
                (" 正在" + activity if activity else "")
            ]
    else:
        summary += "周围没有其他人。\n"

    # 时间和天气
    summary += "\n现在是%s,%s。\n" % [
        _get_time_period_cn(cached_perception.time_period),
        _get_weather_cn(cached_perception.weather)
    ]

    return summary
```

### 4.2 空间感知实现

```gdscript
func _perceive_nearby_characters() -> Array:
    """感知附近的AI角色"""
    var nearby = []
    var all_characters = CharacterManager.get_all_characters()

    for other_char in all_characters:
        if other_char == ai_character:
            continue

        var distance = ai_character.global_position.distance_to(other_char.global_position)

        # 距离过滤
        if distance > PERCEPTION_RADIUS:
            continue

        # 视野角度过滤 (可选)
        if not _is_in_vision_cone(other_char.global_position):
            continue

        # 构建角色数据
        var char_data = {
            "character_id": other_char.name,
            "character_name": other_char.character_data.character_name,
            "distance": distance,
            "position": other_char.global_position,
            "current_activity": _get_character_activity(other_char)
        }

        nearby.append(char_data)

    # 按距离排序
    nearby.sort_custom(func(a, b): return a.distance < b.distance)

    # 限制数量
    if nearby.size() > MAX_PERCEIVED_CHARACTERS:
        nearby = nearby.slice(0, MAX_PERCEIVED_CHARACTERS)

    return nearby

func _perceive_current_location() -> Dictionary:
    """感知当前所在地点"""
    # 查找距离最近且包含该AI的地点
    var current_pos = ai_character.global_position
    var nearest_location = LocationManager.get_nearest_location(current_pos)

    if nearest_location and current_pos.distance_to(nearest_location.position) < 100:
        return nearest_location.to_dict()

    return {}

func _perceive_nearby_locations() -> Array:
    """感知附近的地点"""
    var nearby_locs = []

    for location in LocationManager.locations.values():
        var distance = ai_character.global_position.distance_to(location.position)

        if distance < PERCEPTION_RADIUS and distance > 50:  # 不包括当前地点
            nearby_locs.append({
                "location_id": location.id,
                "name": location.name_cn,
                "distance": distance,
                "type": location.type
            })

    # 按距离排序,最多返回5个
    nearby_locs.sort_custom(func(a, b): return a.distance < b.distance)
    return nearby_locs.slice(0, 5)
```

### 4.3 社交感知实现

```gdscript
func _perceive_social_opportunities() -> Array:
    """感知社交机会"""
    var opportunities = []

    for char_data in cached_perception.get("nearby_characters", []):
        var char_id = char_data.character_id

        # 获取关系数据
        var relationship = RelationshipManager.get_relationship(ai_character.name, char_id)
        if relationship.is_empty():
            continue

        # 计算互动优先级
        var priority = _calculate_social_priority(char_id, char_data, relationship)

        # 判断是否可以互动
        if priority > 0:
            opportunities.append({
                "character_id": char_id,
                "character_name": char_data.character_name,
                "priority": priority,
                "relationship_level": relationship.relationship_level,
                "suggested_action": _suggest_social_action(relationship)
            })

    # 按优先级排序
    opportunities.sort_custom(func(a, b): return a.priority > b.priority)

    return opportunities

func _calculate_social_priority(char_id: String, char_data: Dictionary, relationship: Dictionary) -> float:
    """计算社交优先级 (0-100)"""
    var priority = 0.0

    # 1. 关系因素 (40%)
    var affection = relationship.get("affection", 50)
    var familiarity = relationship.get("familiarity", 0)
    priority += (affection * 0.3 + familiarity * 0.1)

    # 2. 性格因素 (30%)
    var my_personality = PersonalityEngine.get_personality(ai_character.name)
    var their_personality = PersonalityEngine.get_personality(char_id)

    # 外向性影响社交意愿
    priority += my_personality.extraversion * 0.3

    # 性格契合度
    var compatibility = PersonalityEngine.get_compatibility(ai_character.name, char_id)
    priority += compatibility * 0.1

    # 3. 距离因素 (20%)
    var distance = char_data.distance
    var distance_factor = max(0, 1.0 - distance / PERCEPTION_RADIUS)  # 越近优先级越高
    priority += distance_factor * 20.0

    # 4. 时间因素 (10%)
    # 上次互动时间越久,优先级越高
    var last_interaction = relationship.get("last_interaction_time", "")
    if last_interaction:
        var hours_since = _calculate_hours_since(last_interaction)
        priority += min(hours_since / 24.0 * 10.0, 10.0)  # 最多+10

    return clamp(priority, 0.0, 100.0)

func _suggest_social_action(relationship: Dictionary) -> String:
    """建议社交行为"""
    var level = relationship.relationship_level

    match level:
        "stranger":
            return "打招呼,自我介绍"
        "acquaintance":
            return "聊聊天,增进了解"
        "friend":
            return "一起做点什么(喝咖啡、聊工作)"
        "close_friend":
            return "深度交流,分享秘密"
        "best_friend":
            return "一起计划活动,互相支持"
        "romantic":
            return "约会,增进感情"
        "enemy":
            return "避免冲突,保持距离"
        _:
            return "观察对方"
```

### 4.4 环境感知实现

```gdscript
func _perceive_current_activities() -> Dictionary:
    """感知当前环境中的活动"""
    var activities = {}

    # 检测附近AI正在做什么
    for char_data in cached_perception.get("nearby_characters", []):
        var char_id = char_data.character_id
        var character = CharacterManager.get_character(char_id)

        if character:
            var ai_brain = character.get_node_or_null("Components/AIBrain")
            if ai_brain and ai_brain.has_method("get_current_state"):
                var state = ai_brain.get_current_state()
                activities[char_id] = state

    # 检测地点活动
    if cached_perception.current_location:
        var location_id = cached_perception.current_location.id
        var occupants = LocationManager.get_occupants(location_id)
        activities["location_occupants_count"] = occupants.size()

    return activities
```

### 4.5 感知过滤实现

```gdscript
func _apply_perception_filters(perception: Dictionary) -> Dictionary:
    """应用感知过滤器"""
    var personality = PersonalityEngine.get_personality(ai_character.name)

    # 1. 外向性过滤社交机会
    if personality.extraversion < 30:
        # 内向AI只关注最亲密的人
        perception.nearby_characters = _filter_by_relationship(
            perception.nearby_characters,
            ["close_friend", "best_friend", "romantic"]
        )

    # 2. 神经质过滤威胁
    if personality.neuroticism > 70:
        # 神经质高的AI会注意到敌人
        var enemies = _filter_by_relationship(perception.nearby_characters, ["enemy"])
        if enemies.size() > 0:
            perception.perceived_threats = enemies

    # 3. 开放性影响新地点感知
    if personality.openness < 30:
        # 开放性低的AI不太关注新地点
        perception.nearby_locations = []

    return perception

func _filter_by_relationship(characters: Array, allowed_levels: Array) -> Array:
    """按关系等级过滤角色"""
    var filtered = []

    for char_data in characters:
        var char_id = char_data.character_id
        var relationship = RelationshipManager.get_relationship(ai_character.name, char_id)

        if relationship and relationship.relationship_level in allowed_levels:
            filtered.append(char_data)

    return filtered
```

---

## 5. 系统集成设计

### 5.1 与LLM集成架构的对接

根据**13_LLM集成架构详细规范.md**,环境感知是AI思考类型之一:

```gdscript
# AIThinkingSystem.perceive_environment() 应该使用 PerceptionComponent

# 修改前 (分散的代码)
func perceive_environment(ai_agent: Node):
    var nearby = _get_nearby_ais(ai_agent)  # 每次都重新计算
    var location = _get_current_location(ai_agent)
    # ...

# 修改后 (使用PerceptionComponent)
func perceive_environment(ai_agent: Node):
    var perception_component = ai_agent.get_node("Components/PerceptionComponent")
    if not perception_component:
        return

    # 使用缓存的感知数据,无需重新计算
    var perception_summary = perception_component.get_perception_summary_for_llm()

    # 调用LLM
    var prompt = _build_perception_prompt(ai_agent, perception_summary)
    var response = await call_llm(prompt)
    # ...
```

### 5.2 与其他系统的集成

```gdscript
# 1. 与CharacterManager集成
# CharacterManager需要提供get_all_characters()方法

# 2. 与RelationshipManager集成
# PerceptionComponent直接调用RelationshipManager.get_relationship()

# 3. 与PersonalityEngine集成
# 用于感知过滤和社交优先级计算

# 4. 与LocationManager集成
# 用于地点感知

# 5. 与TimeSystem集成
# 用于时间段感知

# 6. 与WeatherSystem集成
# 用于天气感知
```

---

## 6. 性能优化策略

### 6.1 缓存策略

```gdscript
# 1. 时间缓存:每5秒更新一次,而非每帧
var _last_update_time: float = 0.0
const UPDATE_INTERVAL: float = 5.0

func _process(delta):
    _last_update_time += delta
    if _last_update_time >= UPDATE_INTERVAL:
        update_perception()
        _last_update_time = 0.0

# 2. 结果缓存:LLM prompt可以使用缓存的get_perception_summary_for_llm()
# 避免每次都重新格式化

# 3. 距离计算优化:先计算平方距离,再开方
func _is_within_range(pos1: Vector2, pos2: Vector2, radius: float) -> bool:
    var dx = pos2.x - pos1.x
    var dy = pos2.y - pos1.y
    var dist_squared = dx * dx + dy * dy
    return dist_squared <= radius * radius
```

### 6.2 按需启用/禁用

```gdscript
# AI睡觉时禁用感知
func set_perception_enabled(enabled: bool):
    set_process(enabled)

# AIBrain可以调用:
func on_sleep_state_changed(is_sleeping: bool):
    var perception = get_node("../PerceptionComponent")
    if perception:
        perception.set_perception_enabled(not is_sleeping)
```

---

## 7. 代码量估算

### 7.1 核心文件

| 文件路径 | 预计代码量 | 说明 |
|---------|----------|------|
| `script/ai/perception/PerceptionComponent.gd` | 400-500行 | 核心组件 |
| `script/ai/perception/PerceptionData.gd` | 50-80行 | 数据结构定义 |
| `script/ai/perception/PerceptionFilters.gd` | 100-150行 | 过滤器逻辑 (可选拆分) |

**总计**: 约550-730行

### 7.2 集成代码修改

| 文件路径 | 修改量 | 说明 |
|---------|-------|------|
| `script/ai/AIAgent.gd` | +30行 | 初始化PerceptionComponent |
| `script/ai/thinking/AIThinkingSystem.gd` | 修改20行 | 使用PerceptionComponent代替旧逻辑 |
| `scene/character/AICharacter.tscn` | +1节点 | 添加PerceptionComponent节点 |

---

## 8. 开发优先级

### 8.1 实现顺序

```
Phase 1: 核心空间感知 (1-2小时)
  ✅ PerceptionComponent基础结构
  ✅ _perceive_nearby_characters()
  ✅ _perceive_current_location()
  ✅ 基础缓存机制

Phase 2: 社交感知 (1-2小时)
  ✅ _perceive_social_opportunities()
  ✅ _calculate_social_priority()
  ✅ _suggest_social_action()

Phase 3: 环境感知 (30分钟)
  ✅ _perceive_current_activities()
  ✅ 天气和时间段集成

Phase 4: 感知过滤 (1小时)
  ✅ _apply_perception_filters()
  ✅ 性格驱动的过滤逻辑

Phase 5: LLM集成 (30分钟)
  ✅ get_perception_summary_for_llm()
  ✅ 修改AIThinkingSystem

Phase 6: 测试和优化 (1小时)
  ✅ 性能测试
  ✅ 调试输出
  ✅ 边界情况处理
```

**预计总时间**: 5-7小时

---

## 9. 验收标准

### 9.1 功能验收

- [ ] 每个AI都有PerceptionComponent组件
- [ ] 能正确检测附近的AI (距离300像素内)
- [ ] 能识别当前所在地点
- [ ] 能识别附近可移动的地点
- [ ] 社交优先级计算正确 (考虑关系、性格、距离)
- [ ] 性格过滤正常工作 (内向AI过滤陌生人)
- [ ] 为LLM生成的感知摘要格式正确,包含必要信息
- [ ] 感知更新频率为每5秒一次,不影响帧率

### 9.2 性能验收

- [ ] 8个AI同时运行,感知系统开销 < 5% CPU
- [ ] 感知缓存正常工作,避免重复计算
- [ ] AI睡觉时禁用感知,减少计算

### 9.3 集成验收

- [ ] AIThinkingSystem.perceive_environment()使用PerceptionComponent
- [ ] LLM Prompt包含感知摘要信息
- [ ] 感知结果影响AI的决策 (如选择与谁对话)

---

## 10. 风险评估

### 10.1 技术风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 性能开销过大 | 中 | 高 | 使用缓存、降低更新频率 |
| 感知数据过时 | 低 | 中 | 5秒更新间隔足够 |
| 与现有代码冲突 | 低 | 低 | 渐进式重构,保留旧代码兼容 |

### 10.2 依赖风险

PerceptionComponent依赖以下系统:
- ✅ CharacterManager - 已存在
- ✅ RelationshipManager - 已存在且增强完成
- ✅ PersonalityEngine - 已存在
- ✅ LocationManager - 未实现 (需先实现)
- ✅ TimeSystem - 已存在
- ✅ WeatherSystem - 未实现 (可暂时跳过)

**结论**: LocationManager是前置依赖,需要先实现或使用临时替代方案。

---

## 11. 决策总结

### 11.1 核心决策

1. **不作为Autoload** ✅
   - 理由:感知是AI个体行为,不需要全局单例
   - 实现方式:作为AICharacter的组件

2. **组件化设计** ✅
   - 路径:`scene/character/AICharacter.tscn -> Components/PerceptionComponent`
   - 类名:`PerceptionComponent`

3. **缓存优先** ✅
   - 更新频率:5秒一次
   - 缓存感知结果,供LLM使用

4. **性格驱动过滤** ✅
   - 外向性影响社交感知范围
   - 神经质影响威胁感知
   - 开放性影响新地点探索

### 11.2 下一步行动

**立即实施**:
1. 创建`script/ai/perception/`目录
2. 实现`PerceptionComponent.gd`核心文件
3. 添加到AICharacter场景
4. 修改AIThinkingSystem集成

**暂缓实施**:
- WeatherSystem集成 (可在WeatherSystem实现后再添加)
- 高级视野角度过滤 (当前使用简单距离判断即可)

---

## 12. 补充设计: 临时LocationManager方案

由于LocationManager尚未实现,提供临时方案:

```gdscript
# PerceptionComponent.gd临时实现

func _perceive_current_location() -> Dictionary:
    # 临时方案:通过场景节点元数据获取地点
    var location_nodes = get_tree().get_nodes_in_group("location")
    var min_distance = INF
    var nearest_location = null

    for node in location_nodes:
        var distance = ai_character.global_position.distance_to(node.global_position)
        if distance < min_distance and distance < 100:
            min_distance = distance
            nearest_location = node

    if nearest_location:
        return {
            "id": nearest_location.name,
            "name_cn": nearest_location.get_meta("location_name_cn", nearest_location.name),
            "type": nearest_location.get_meta("location_type", "OTHER")
        }

    return {}
```

**注意**: 一旦LocationManager实现,立即替换为正式API。

---

## 13. 总结

### 13.1 现状与目标

| 项目 | 现状 | 目标 |
|------|------|------|
| 实现度 | 0% | 100% |
| 代码量 | 0行 | ~600行 |
| 集成度 | 0% (代码分散) | 100% (统一组件) |

### 13.2 核心价值

实现PerceptionComponent后:
1. **统一感知逻辑**: 不再分散在多个文件
2. **性能优化**: 缓存避免重复计算
3. **LLM质量提升**: 提供结构化感知数据
4. **AI行为更真实**: 基于性格的感知过滤

### 13.3 预期效果

AI将能够:
- ✅ "看到"附近的人和地点
- ✅ "理解"社交机会和优先级
- ✅ "感受"环境氛围 (时间、天气)
- ✅ 基于性格"选择性感知"

这将显著提升AI的智能表现和沉浸感! 🎯

---

**分析完成日期**: 2025-10-20
**分析师**: Claude (Sonnet 4.5)
**状态**: ✅ 分析完成,可立即开发
