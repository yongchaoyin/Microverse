# MemoryManager增强 - 完成报告

## 📋 任务概述

**任务**: 增强MemoryManager以支持ConflictSystem集成
**开始时间**: 2025-10-20
**完成时间**: 2025-10-20
**状态**: ✅ 已完成

## 🎯 实现目标

为MemoryManager添加ConflictSystem集成功能，使冲突和和解事件能够自动转化为AI角色的记忆。

## ✅ 已实现功能

### 1. ConflictSystem集成API (303行新增代码)

#### 1.1 冲突记忆创建
```gdscript
func create_conflict_memory(
    ai_id: String,
    other_ai_id: String,
    conflict_type: String,
    severity: int,
    reason: String,
    location: String = "",
    conflict_id: String = ""
) -> Memory
```

**功能**:
- 为冲突双方自动创建冲突记忆
- 根据严重程度(1-9)自动计算情感强度(0.3-1.0)
- 冲突记忆始终为负面情感(-0.5 ~ -1.0)
- 记录冲突ID以便后续关联

**示例**:
```gdscript
# 创建任务纠纷冲突记忆
MemoryManager.create_conflict_memory(
    "alice_001",
    "bob_002",
    "TASK_DISPUTE",
    5,
    "关于项目截止日期的争执",
    "办公室",
    "conflict_1729411200_1"
)
```

#### 1.2 和解记忆创建
```gdscript
func create_reconciliation_memory(
    ai_id: String,
    other_ai_id: String,
    resolution_type: String,
    reason: String,
    location: String = "",
    conflict_id: String = ""
) -> Memory
```

**功能**:
- 为和解双方创建和解记忆
- 固定情感参数: intensity=0.7, valence=0.8 (正面情感)
- 记录和解方式(MEDIATION/COMPROMISE/APOLOGY等)
- 关联原冲突ID

**示例**:
```gdscript
# 创建通过道歉和解的记忆
MemoryManager.create_reconciliation_memory(
    "alice_001",
    "bob_002",
    "APOLOGY",
    "Bob为误会向Alice道歉",
    "咖啡厅",
    "conflict_1729411200_1"
)
```

#### 1.3 关系里程碑记忆创建
```gdscript
func create_relationship_milestone_memory(
    ai_id: String,
    other_ai_id: String,
    milestone_type: String,
    description: String,
    location: String = ""
) -> Memory
```

**功能**:
- 创建关系里程碑记忆(初次见面/成为朋友/成为敌人等)
- 根据里程碑类型自动匹配情感参数
- 为双方创建对称记忆

**支持的里程碑类型**:
| 类型 | 情感强度 | 情感正负 |
|------|----------|----------|
| first_meeting | 0.5 | +0.3 |
| became_friends | 0.7 | +0.7 |
| became_close_friends | 0.8 | +0.8 |
| became_couple | 1.0 | +1.0 |
| marriage | 1.0 | +1.0 |
| became_enemies | 0.9 | -0.9 |
| relationship_milestone | 0.6 | +0.5 |

#### 1.4 冲突记忆查询
```gdscript
func get_conflict_memories(ai_id: String, other_ai_id: String = "", limit: int = 10) -> Array
```

**功能**:
- 获取AI的所有冲突记忆
- 可选: 只获取与特定AI的冲突
- 按时间倒序返回(最近的在前)
- 搜索范围: 短期记忆 + 长期记忆

**示例**:
```gdscript
# 获取Alice与Bob之间的最近5次冲突
var conflicts = MemoryManager.get_conflict_memories("alice_001", "bob_002", 5)
for conflict in conflicts:
    print("冲突: %s (严重度: %.2f)" % [conflict.description, conflict.emotional_intensity])
```

#### 1.5 和解记忆查询
```gdscript
func get_reconciliation_memories(ai_id: String, other_ai_id: String = "", limit: int = 10) -> Array
```

**功能**:
- 获取AI的所有和解记忆
- 可选: 只获取与特定AI的和解
- 按时间倒序返回

#### 1.6 完整关系历史查询
```gdscript
func get_relationship_history(ai_id: String, other_ai_id: String, limit: int = 20) -> Array
```

**功能**:
- 获取与特定AI的完整社交历史
- 包括: 对话/赠礼/冲突/和解/表白/分手/初次见面/成为朋友/成为敌人等
- 按时间正序返回(最早到最新, 呈现历史发展脉络)
- 搜索范围: 短期记忆 + 长期记忆 + 核心记忆

**示例**:
```gdscript
# 获取Alice与Bob的完整关系史
var history = MemoryManager.get_relationship_history("alice_001", "bob_002", 20)
print("=== Alice与Bob的关系发展史 ===")
for memory in history:
    var time_str = "%d年%s第%d天" % [
        memory.game_time.year,
        memory.game_time.season,
        memory.game_time.day
    ]
    print("[%s] %s" % [time_str, memory.llm_summary])
```

### 2. 自动信号监听

在`_ready()`函数中自动连接ConflictSystem的3个信号:

```gdscript
# 连接冲突系统信号
var conflict_system = get_node_or_null("/root/ConflictSystem")
if conflict_system:
    if conflict_system.has_signal("conflict_triggered"):
        conflict_system.conflict_triggered.connect(_on_conflict_triggered)
    if conflict_system.has_signal("conflict_resolved"):
        conflict_system.conflict_resolved.connect(_on_conflict_resolved)
    if conflict_system.has_signal("mediation_completed"):
        conflict_system.mediation_completed.connect(_on_mediation_completed)
```

### 3. 信号处理器

#### 3.1 冲突触发处理器
```gdscript
func _on_conflict_triggered(conflict_id: String, conflict_data: Dictionary)
```

**行为**:
- 监听`ConflictSystem.conflict_triggered`信号
- 自动调用`create_conflict_memory()`为冲突双方创建记忆
- 提取冲突类型、严重程度、原因、地点等信息
- 打印日志: `[MemoryManager] 自动创建冲突记忆: conflict_xxx (ID: conflict_xxx)`

#### 3.2 冲突解决处理器
```gdscript
func _on_conflict_resolved(conflict_id: String, conflict_data: Dictionary)
```

**行为**:
- 监听`ConflictSystem.conflict_resolved`信号
- 排除`NONE`和`FORCED`类型的解决(不创建记忆)
- 对成功和解(MEDIATION/COMPROMISE/APOLOGY/TIME_HEALED)创建和解记忆
- 打印日志: `[MemoryManager] 自动创建和解记忆: conflict_xxx (方式: COMPROMISE)`

#### 3.3 调解完成处理器
```gdscript
func _on_mediation_completed(conflict_id: String, mediator_id: String, success: bool)
```

**行为**:
- 监听`ConflictSystem.mediation_completed`信号
- 为调解者创建`work_achievement`类型记忆
- 成功调解: intensity=0.6, valence=0.7
- 失败调解: intensity=0.4, valence=-0.2
- 记忆参与者包括冲突双方
- 打印日志: `[MemoryManager] 创建调解记忆: conflict_xxx (调解者: charlie_003, 成功: true)`

## 📊 代码统计

| 项目 | 数量 |
|------|------|
| 新增函数 | 9个 |
| 新增代码行数 | 303行 |
| 信号连接 | 3个 |
| 信号处理器 | 3个 |
| 查询API | 3个 |
| 创建API | 3个 |
| 辅助函数 | 1个 (`_get_milestone_emotional_params`) |

**文件位置**: `script/ai/memory/MemoryManager.gd`
**修改前行数**: 1457行
**修改后行数**: 1873行 (+416行, 包含注释和空行)

## 🔄 工作流程

### 冲突发生时的完整流程

```
1. AIAgent检测到冲突条件
   ↓
2. AIAgent调用ConflictSystem.trigger_conflict()
   ↓
3. ConflictSystem创建冲突记录, 发出conflict_triggered信号
   ↓
4. MemoryManager._on_conflict_triggered()自动触发
   ↓
5. MemoryManager.create_conflict_memory()为双方创建记忆
   ↓
6. Memory对象添加到短期记忆池
   ↓
7. 发出EventBus.memory_created事件
   ↓
8. AIAgent在下次决策时可访问该冲突记忆
```

### 和解时的完整流程

```
1. AIAgent或调解者调用ConflictSystem.resolve_conflict()
   ↓
2. ConflictSystem更新冲突状态为RESOLVED, 发出conflict_resolved信号
   ↓
3. MemoryManager._on_conflict_resolved()自动触发
   ↓
4. 检查解决类型(排除NONE和FORCED)
   ↓
5. MemoryManager.create_reconciliation_memory()为双方创建和解记忆
   ↓
6. Memory对象添加到短期记忆池
   ↓
7. 发出EventBus.memory_created事件
```

### 调解时的完整流程

```
1. 调解者调用ConflictSystem.start_mediation()
   ↓
2. ConflictSystem添加调解者, 发出mediation_started信号
   ↓
3. 调解者尝试调解(通过AIAgent的LLM决策)
   ↓
4. ConflictSystem发出mediation_completed信号
   ↓
5. MemoryManager._on_mediation_completed()自动触发
   ↓
6. 为调解者创建work_achievement记忆
   ↓
7. 记忆中包含冲突双方ID作为参与者
```

## 📖 使用示例

### 示例1: 手动创建冲突记忆
```gdscript
# 场景: Alice和Bob因为项目截止日期产生严重争执
MemoryManager.create_conflict_memory(
    "alice_001",         # 发起者
    "bob_002",           # 冲突对象
    "TASK_DISPUTE",      # 冲突类型
    7,                   # 严重程度(MAJOR级别)
    "Bob要求提前截止日期,Alice认为不可能完成",
    "会议室A",           # 地点
    "conflict_1729411200_5"  # 冲突ID
)

# 结果: Alice和Bob各自获得一条冲突记忆
# Alice的记忆: "与bob_002发生了TASK_DISPUTE冲突: Bob要求提前截止日期,Alice认为不可能完成 (ID: conflict_1729411200_5)"
# Bob的记忆: "与alice_001发生了TASK_DISPUTE冲突: Bob要求提前截止日期,Alice认为不可能完成 (ID: conflict_1729411200_5)"
# 情感强度: 0.78 (7/9)
# 情感正负: -0.78
```

### 示例2: 查询冲突历史
```gdscript
# 查询Alice与Bob之间的冲突历史
var conflicts = MemoryManager.get_conflict_memories("alice_001", "bob_002")

if conflicts.size() > 0:
    print("Alice与Bob之间有 %d 次冲突记录:" % conflicts.size())
    for conflict in conflicts:
        print("  - [%s] %s (情感强度: %.2f)" % [
            _format_time(conflict.game_time),
            conflict.description,
            conflict.emotional_intensity
        ])
else:
    print("Alice与Bob之间没有冲突记录")
```

### 示例3: 获取完整关系史
```gdscript
# 获取Alice与Bob的完整关系发展史
var history = MemoryManager.get_relationship_history("alice_001", "bob_002", 30)

print("=== Alice与Bob的关系时间线 ===")
for memory in history:
    var emoji = _get_memory_emoji(memory.memory_type)
    print("%s [%s] %s" % [
        emoji,
        _format_time(memory.game_time),
        memory.llm_summary
    ])

# 输出示例:
# 🤝 [第1年春季第3天] 在公司大厅初次遇见bob_002
# 💬 [第1年春季第5天] 与bob_002讨论了新项目的技术方案
# 🎁 [第1年春季第8天] 收到了bob_002赠送的技术书籍
# 😊 [第1年春季第10天] 与bob_002成为朋友
# ⚔️ [第1年夏季第2天] 与bob_002发生了TASK_DISPUTE冲突: 关于代码规范的分歧
# 🤝 [第1年夏季第3天] 与bob_002通过COMPROMISE方式和解: 双方各让一步
```

### 示例4: 在AIAgent中使用关系历史
```gdscript
# AIAgent.gd中构建提示词时使用关系历史
func _build_conversation_prompt(target_id: String) -> String:
    var prompt = ""

    # 添加基础人设
    prompt += _get_personality_prompt()

    # 添加与对方的关系历史(最近10条)
    var history = MemoryManager.get_relationship_history(ai_id, target_id, 10)
    if history.size() > 0:
        prompt += "\n\n## 你与%s的关系史:\n" % target_id
        for memory in history:
            prompt += "- %s: %s\n" % [
                _format_time(memory.game_time),
                memory.llm_summary
            ]

    # 检查是否有未解决的冲突
    var recent_conflicts = MemoryManager.get_conflict_memories(ai_id, target_id, 3)
    if recent_conflicts.size() > 0:
        prompt += "\n⚠️ 注意: 你与%s之间有%d个冲突记录,说话时要考虑这些矛盾。\n" % [
            target_id,
            recent_conflicts.size()
        ]

    return prompt
```

### 示例5: 自动触发流程
```gdscript
# 在AIAgent.gd中检测冲突条件并触发
func _check_and_trigger_conflict(other_agent: Node):
    var other_id = other_agent.get_meta("ai_id", other_agent.name)

    # 获取关系数据
    var trust = RelationshipManager.get_trust(ai_id, other_id)

    # 如果信任度低于30,考虑触发冲突
    if trust < 30:
        # 获取最近的对话记忆,查看是否有矛盾点
        var recent_conversations = MemoryManager.get_recent_memories(ai_id, 5)
        var has_disagreement = false

        for memory in recent_conversations:
            if memory.memory_type == "conversation" and other_id in memory.participants:
                if memory.emotional_valence < -0.3:
                    has_disagreement = true
                    break

        if has_disagreement:
            # 触发冲突
            var conflict_id = ConflictSystem.trigger_conflict(
                ai_id,
                other_id,
                ConflictSystem.ConflictType.VALUES,  # 价值观冲突
                3,  # MODERATE严重程度
                "因为工作理念不同产生矛盾",
                _get_current_location()
            )

            # MemoryManager会自动创建冲突记忆(通过信号)
            print("[AIAgent] 触发冲突: %s (ID: %s)" % [ai_id, conflict_id])
```

## 🔧 集成要点

### 1. 无需手动调用记忆创建

由于已连接信号,大部分情况下ConflictSystem的事件会自动触发记忆创建:

```gdscript
# ❌ 不推荐: 手动创建
var conflict_id = ConflictSystem.trigger_conflict(...)
MemoryManager.create_conflict_memory(...)  # 多余!

# ✅ 推荐: 只调用ConflictSystem, MemoryManager会自动响应
var conflict_id = ConflictSystem.trigger_conflict(...)
# MemoryManager已通过信号自动创建记忆
```

### 2. 何时手动创建记忆

只在以下情况手动调用:

1. **初始化旧数据**: 从存档加载时补充历史冲突记忆
2. **离线事件**: 模拟AI不在场时发生的冲突
3. **测试**: 单元测试或调试时直接创建记忆

```gdscript
# 示例: 从存档加载历史冲突
func _restore_historical_conflicts(save_data: Dictionary):
    var conflicts = save_data.get("historical_conflicts", [])
    for conflict in conflicts:
        # 手动创建记忆(不通过ConflictSystem)
        MemoryManager.create_conflict_memory(
            conflict.source_id,
            conflict.target_id,
            conflict.conflict_type,
            conflict.severity,
            conflict.reason,
            conflict.location,
            conflict.conflict_id
        )
```

### 3. 查询API的典型用途

| 函数 | 典型用途 |
|------|---------|
| `get_conflict_memories()` | 对话提示词构建, 检查是否有未解决冲突 |
| `get_reconciliation_memories()` | 评估关系改善趋势 |
| `get_relationship_history()` | 构建完整上下文, 生成关系总结报告 |

### 4. 情感参数设计理念

| 记忆类型 | 情感强度 | 情感正负 | 设计理念 |
|---------|---------|---------|---------|
| conflict | 0.3-1.0 (基于severity) | -0.5~-1.0 | 严重冲突=高强度负面情感 |
| reconciliation | 0.7 (固定) | +0.8 | 和解总是高强度正面情感 |
| became_friends | 0.7 | +0.7 | 成为朋友是积极里程碑 |
| became_enemies | 0.9 | -0.9 | 成为敌人是严重负面事件 |

## 🧪 测试建议

### 测试场景1: 冲突-和解循环
```gdscript
# 1. 触发冲突
var conflict_id = ConflictSystem.trigger_conflict(
    "alice_001", "bob_002",
    ConflictSystem.ConflictType.PERSONALITY,
    5, "性格不合"
)

# 2. 验证冲突记忆
await get_tree().create_timer(0.1).timeout  # 等待信号处理
var conflicts = MemoryManager.get_conflict_memories("alice_001", "bob_002")
assert(conflicts.size() > 0, "应该有冲突记忆")
assert(conflicts[0].emotional_valence < 0, "冲突应是负面情感")

# 3. 解决冲突
ConflictSystem.resolve_conflict(
    conflict_id,
    ConflictSystem.ResolutionType.COMPROMISE,
    "双方各让一步"
)

# 4. 验证和解记忆
await get_tree().create_timer(0.1).timeout
var reconciliations = MemoryManager.get_reconciliation_memories("alice_001", "bob_002")
assert(reconciliations.size() > 0, "应该有和解记忆")
assert(reconciliations[0].emotional_valence > 0, "和解应是正面情感")
```

### 测试场景2: 关系历史完整性
```gdscript
# 创建一系列关系事件
MemoryManager.create_relationship_milestone_memory(
    "alice_001", "bob_002",
    "first_meeting", "在公司大厅初次见面", "大厅"
)

MemoryManager.create_memory(
    "alice_001", "conversation",
    "与bob_002讨论了项目", ["bob_002"], "会议室"
)

MemoryManager.create_conflict_memory(
    "alice_001", "bob_002",
    "TASK_DISPUTE", 3, "关于截止日期的争执", "办公室"
)

# 验证历史顺序
var history = MemoryManager.get_relationship_history("alice_001", "bob_002")
assert(history.size() == 3, "应该有3条关系记忆")
assert(history[0].memory_type == "first_meeting", "第一条应是初次见面")
assert(history[1].memory_type == "conversation", "第二条应是对话")
assert(history[2].memory_type == "conflict", "第三条应是冲突")
```

### 测试场景3: 调解者记忆
```gdscript
# 1. 创建冲突
var conflict_id = ConflictSystem.trigger_conflict(
    "alice_001", "bob_002",
    ConflictSystem.ConflictType.INTEREST,
    6, "利益分配不均"
)

# 2. Charlie作为调解者介入
ConflictSystem.start_mediation(conflict_id, "charlie_003")

# 3. 完成调解
ConflictSystem.complete_mediation(conflict_id, "charlie_003", true)

# 4. 验证Charlie的记忆
await get_tree().create_timer(0.1).timeout
var charlie_memories = MemoryManager.get_recent_memories("charlie_003", 5)
var has_mediation_memory = false
for memory in charlie_memories:
    if memory.memory_type == "work_achievement" and "调解" in memory.description:
        has_mediation_memory = true
        assert("alice_001" in memory.participants, "记忆应包含Alice")
        assert("bob_002" in memory.participants, "记忆应包含Bob")
        break

assert(has_mediation_memory, "Charlie应该有调解记忆")
```

## 📝 注意事项

### 1. 性能考虑

- **查询优化**: `get_relationship_history()`会搜索3个记忆层(短期/长期/核心), 对于AI数量多的场景,建议限制limit参数(默认20)
- **双向创建**: `create_conflict_memory()`和`create_reconciliation_memory()`会为双方创建记忆, 每次调用实际创建2条记忆
- **记忆池管理**: 依赖现有的记忆衰减机制(短期7天, 长期根据importance保留)

### 2. 数据一致性

- **冲突ID关联**: 冲突记忆和和解记忆都记录了`conflict_id`, 可通过描述字符串搜索`(ID: conflict_xxx)`来关联
- **视角对称性**: 双方记忆的`description`基本对称, 但可能因字符串替换逻辑略有差异
- **情感对称性**: 双方记忆的情感参数完全一致(都是负面或都是正面)

### 3. 扩展性

如需添加新的关系里程碑类型, 需修改:
1. `_get_milestone_emotional_params()`的`params_map`字典
2. MemoryManager.gd顶部的`MEMORY_TYPES`常量(如果是全新类型)

## 🔗 相关文件

- **MemoryManager**: `script/ai/memory/MemoryManager.gd` (1873行)
- **ConflictSystem**: `script/conflict/ConflictSystem.gd` (720行)
- **RelationshipManager**: `script/ai/relationship/RelationshipManager.gd` (1195行)
- **设计文档**: `docs/design/11_AI记忆系统详细规范.md`

## 📈 Phase D进度更新

**Phase D: Social Dynamics (社交动力学)**

- ✅ **Task 1**: 检查RelationshipManager (已完成)
- ✅ **Task 2**: 实现ConflictSystem (已完成, 720行)
- ✅ **Task 3**: 增强MemoryManager (已完成, 303行新增)
- ⏳ **Task 4**: 创建ObservationUI (待开始)
- ⏳ **Task 5**: 系统集成 (待开始)

**当前进度**: 60% (3/5)

## 🎉 总结

MemoryManager现已完全集成ConflictSystem, 实现了:

1. ✅ 冲突事件自动转化为记忆
2. ✅ 和解事件自动转化为记忆
3. ✅ 调解者获得工作成就记忆
4. ✅ 提供3个查询API获取冲突/和解/完整关系历史
5. ✅ 提供3个创建API手动创建特殊场景记忆
6. ✅ 自动连接3个ConflictSystem信号
7. ✅ 为7种关系里程碑类型预设情感参数

**下一步**: 开始Task 4 - 创建ObservationUI (关系网络可视化)
