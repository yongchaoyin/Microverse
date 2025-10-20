# Phase D: Social Dynamics (社交动力学) - 开发计划

## 📋 计划概述

| 项目 | 内容 |
|------|------|
| **阶段名称** | Phase D: Social Dynamics |
| **中文名称** | 社交动力学 |
| **开发时间** | 预计 8-10 小时 |
| **创建日期** | 2025-10-20 |
| **负责人** | Claude (Sonnet 4.5) |
| **状态** | 🚧 **进行中** |

---

## 🎯 Phase D 目标

根据 P0 工程路线图,Phase D 的核心目标是:

1. **完善 RelationshipManager** - 多通道关系图,信任阈值,查询 API
2. **实现 ConflictSystem** - 处理纠纷,冷却期,事件日志
3. **增强 MemoryManager** - 支持新的关系事件类别
4. **创建 ObservationUI** - 关系图可视化,冲突日志面板
5. **系统集成** - 将对话/任务/经济系统与信任阈值和冲突解决挂钩

---

## ✅ 当前状态检查

### 已完成系统 (Phase A-C)

| 系统 | 状态 | 代码行数 | 版本 |
|------|------|---------|------|
| **ConfigManager** | ✅ 完成 | - | - |
| **EventBus** | ✅ 完成 | - | - |
| **DebugConsole** | ✅ 完成 | - | - |
| **TimeSystem** | ✅ 完成 | - | - |
| **CareerSystem** | ✅ 完成 | 563 行 | 1.0.0 |
| **ScheduleManager** | ✅ 完成 | - | - |
| **TaskSystem** | ✅ 完成 | - | - |
| **EconomyManager** | ✅ 完成 | 537 行 | 1.0.0 |
| **DatabaseManager** | ✅ 完成 | 900 行 | 2.0.0 (SQLite) |
| **SaveManager** | ✅ 完成 | 850 行 | 1.0.0 |
| **SaveLoadUIManager** | ✅ 集成完成 | - | - |

### Phase D 系统状态

| 系统 | 状态 | 代码行数 | 优先级 |
|------|------|---------|--------|
| **RelationshipManager** | ✅ **已存在** | 1195 行 | P0 - 检查并增强 |
| **ConflictSystem** | ❌ **未实现** | 0 行 | P0 - 需要实现 |
| **MemoryManager 增强** | ⏳ **部分完成** | - | P1 - 添加关系事件类别 |
| **ObservationUI** | ❌ **未实现** | 0 行 | P1 - 关系图可视化 |

---

## 📊 Phase D 实现步骤

### Step 1: 检查并增强 RelationshipManager (已完成 ✅)

**当前状态**: RelationshipManager 已有 1195 行代码,包含:
- ✅ 多通道关系 (好感度、信任度、尊重度、浪漫度、熟悉度)
- ✅ 关系阈值定义 (陌生人、熟人、朋友、好友、挚友)
- ✅ 信任阈值 (借钱、倾诉、分享秘密)
- ✅ 衰减机制 (72 小时无互动开始衰减)
- ✅ 事件权重配置 (对话、礼物、帮助、冲突、背叛等)
- ✅ 关系标签系统 (陌生人、朋友、敌人、恋人等)
- ✅ 关系里程碑 (初次相识、成为朋友、初次争吵等)

**需要增强的功能**:
- ⏳ 与 DatabaseManager 集成 (记录关系历史)
- ⏳ 与 EventBus 集成 (发送关系事件)
- ⏳ 信任阈值触发冲突 (`trust_below_threshold` 信号)

**优先级**: P1 (增强功能)

---

### Step 2: 实现 ConflictSystem (核心任务 🚧)

**目标**: 创建冲突管理系统,处理 AI 角色之间的纠纷

**功能需求**:

#### 2.1 冲突类型
- **INTEREST** - 利益冲突 (资源争夺、工作分配)
- **VALUES** - 价值观冲突 (理念分歧)
- **PERSONALITY** - 性格冲突 (互相看不惯)
- **MISUNDERSTANDING** - 误会 (沟通不畅)
- **TASK_DISPUTE** - 任务纠纷 (工作分歧)

#### 2.2 冲突严重程度
- **MINOR** (1-2) - 小摩擦,容易解决
- **MODERATE** (3-5) - 中等冲突,需要调解
- **MAJOR** (6-8) - 严重冲突,可能影响关系
- **CRITICAL** (9-10) - 极端冲突,可能导致敌对

#### 2.3 冲突状态
- **TRIGGERED** - 刚触发
- **ESCALATING** - 升级中
- **PEAK** - 高峰期
- **COOLING_DOWN** - 冷却期
- **MEDIATED** - 调解中
- **RESOLVED** - 已解决
- **UNRESOLVED** - 未解决

#### 2.4 核心 API
```gdscript
# 触发冲突
func trigger_conflict(source_id: String, target_id: String, conflict_type: String, severity: int, reason: String) -> String

# 获取冲突
func get_conflict(conflict_id: String) -> Dictionary
func get_active_conflicts() -> Array
func get_character_conflicts(ai_id: String) -> Array

# 冲突升级
func escalate_conflict(conflict_id: String, additional_severity: int)

# 冲突调解
func start_mediation(conflict_id: String, mediator_id: String)
func resolve_conflict(conflict_id: String, resolution_type: String, outcome: Dictionary)

# 冲突查询
func can_interact(ai_a: String, ai_b: String) -> bool
func get_conflict_history(source_id: String, target_id: String) -> Array
```

#### 2.5 信号系统
```gdscript
signal conflict_triggered(conflict_id, conflict_data)
signal conflict_escalated(conflict_id, new_severity)
signal conflict_resolved(conflict_id, resolution_data)
signal mediation_started(conflict_id, mediator_id)
signal cooldown_started(conflict_id, duration)
```

#### 2.6 冷却期机制
- 冲突解决后进入冷却期
- 冷却期长度与严重程度相关:
  - MINOR: 1-2 游戏日
  - MODERATE: 3-5 游戏日
  - MAJOR: 7-14 游戏日
  - CRITICAL: 14-30 游戏日
- 冷却期内互动受限

#### 2.7 数据结构
```gdscript
{
  "conflict_id": "conflict_001",
  "conflict_type": "INTEREST",
  "source_id": "alice_001",
  "target_id": "bob_002",
  "severity": 3,
  "status": "ESCALATING",
  "trigger_event": {
    "type": "TASK_DISPUTE",
    "timestamp": 1729411200.0,
    "description": "项目优先级争议"
  },
  "escalation_history": [
    {"timestamp": 1729411200.0, "severity": 1, "event": "初次分歧"},
    {"timestamp": 1729411800.0, "severity": 3, "event": "争论升级"}
  ],
  "mediators": ["grace_003"],
  "resolution": {
    "resolution_type": "MEDIATION",
    "timestamp": 1729414800.0,
    "mediator": "grace_003",
    "outcome": "达成妥协",
    "relationship_impact": {
      "alice_bob": {"affection": -5, "trust": -3},
      "alice_grace": {"affection": +5, "trust": +3}
    }
  },
  "cooldown_until": 1729672000.0,
  "created_at": 1729411200.0,
  "resolved_at": 1729414800.0
}
```

**预计代码量**: 600-800 行
**预计时间**: 4-5 小时

---

### Step 3: 增强 MemoryManager (增强任务 ⏳)

**目标**: 添加新的记忆类别以支持关系和冲突事件

**新增记忆类型**:
```gdscript
enum MemoryType {
  # 现有类型
  PERSONAL,
  INTERACTION,
  TASK,
  EMOTION,
  EVENT,

  # 新增类型
  RELATIONSHIP_CHANGE,  # 关系变化 (成为朋友、关系恶化)
  CONFLICT,             # 冲突事件 (争吵、和解)
  MILESTONE,            # 关系里程碑 (初次相识、成为挚友)
}
```

**增强功能**:
- ✅ 关系事件记忆存储
- ✅ 冲突事件记忆存储
- ✅ 里程碑记忆存储
- ✅ 关系记忆查询 API

**预计代码量**: 100-150 行 (增强现有代码)
**预计时间**: 1-2 小时

---

### Step 4: 创建 ObservationUI (可视化任务 🎨)

**目标**: 为玩家提供关系图和冲突日志的可视化界面

#### 4.1 关系图面板 (RelationshipGraphPanel)
- 显示所有角色的关系网络
- 节点: 角色头像 + 名称
- 连线: 关系类型 (颜色编码)
  - 绿色: 朋友/好友
  - 红色: 敌人/竞争对手
  - 粉色: 恋爱关系
  - 灰色: 陌生人/熟人
- 交互: 点击节点查看详情,点击连线查看关系历史

#### 4.2 冲突日志面板 (ConflictLogPanel)
- 显示所有活跃和历史冲突
- 列表项包含:
  - 冲突双方
  - 冲突类型
  - 严重程度 (颜色编码)
  - 状态 (进行中/已解决)
  - 时间
- 过滤器: 按状态、严重程度、角色过滤
- 详情视图: 点击查看冲突详情和历史

#### 4.3 关系详情面板 (RelationshipDetailPanel)
- 显示两个角色之间的详细关系
- 包含:
  - 关系维度数值 (好感、信任、尊重等)
  - 关系标签
  - 关系里程碑
  - 互动历史
  - 冲突历史
  - 记忆片段

**预计代码量**: 400-600 行 (UI + 逻辑)
**预计时间**: 3-4 小时

---

### Step 5: 系统集成 (集成任务 🔗)

**目标**: 将关系和冲突系统与现有系统集成

#### 5.1 DialogManager 集成
- 对话时检查关系状态
- 对话内容影响关系变化
- 低信任度时限制某些对话选项

#### 5.2 TaskSystem 集成
- 任务分配考虑关系状态
- 任务合作影响关系
- 任务冲突可能触发纠纷

#### 5.3 EconomyManager 集成
- 借贷检查信任阈值
- 借贷行为影响关系
- 债务纠纷触发冲突

#### 5.4 EventBus 集成
- 所有关系事件通过 EventBus 广播
- 所有冲突事件通过 EventBus 广播
- UI 监听事件并更新显示

**预计时间**: 2-3 小时

---

## 📅 实施时间表

| 任务 | 优先级 | 预计时间 | 依赖 |
|------|--------|---------|------|
| 检查 RelationshipManager | P1 | 0.5小时 | - |
| 增强 RelationshipManager | P1 | 1小时 | 检查完成 |
| 实现 ConflictSystem | P0 | 4-5小时 | RelationshipManager |
| 增强 MemoryManager | P1 | 1-2小时 | ConflictSystem |
| 创建 ObservationUI | P1 | 3-4小时 | ConflictSystem |
| 系统集成 | P0 | 2-3小时 | 所有上述任务 |

**总预计时间**: 11.5-15.5 小时
**核心路径**: RelationshipManager → ConflictSystem → 系统集成

---

## ✅ 验收标准

### ConflictSystem 验收标准
- [ ] 可以触发冲突
- [ ] 可以升级冲突
- [ ] 可以调解冲突
- [ ] 可以解决冲突
- [ ] 冷却期机制正常工作
- [ ] 冲突历史正确记录
- [ ] 所有信号正确发送
- [ ] 与 DatabaseManager 正确集成

### MemoryManager 增强验收标准
- [ ] 可以存储关系事件记忆
- [ ] 可以存储冲突事件记忆
- [ ] 可以存储里程碑记忆
- [ ] 可以查询关系相关记忆

### ObservationUI 验收标准
- [ ] 关系图正确显示
- [ ] 冲突日志正确显示
- [ ] 交互功能正常
- [ ] 实时更新

### 系统集成验收标准
- [ ] DialogManager 考虑关系状态
- [ ] TaskSystem 考虑关系状态
- [ ] EconomyManager 借贷检查信任
- [ ] EventBus 事件正确广播

---

## 📚 相关文档

- [engineering_plan_p0.md](../engineering_plan_p0.md) - P0 工程路线图
- [15_SaveManager_完成报告.md](15_SaveManager_完成报告.md) - SaveManager 完成报告
- [16_SaveLoadUIManager_集成报告.md](16_SaveLoadUIManager_集成报告.md) - UI 集成报告

---

## 🚀 开始开发

现在开始实施 Phase D,首要任务是:

1. **检查 RelationshipManager 功能** (30分钟)
2. **实现 ConflictSystem** (4-5小时) ⬅️ **当前任务**
3. **增强 MemoryManager** (1-2小时)
4. **创建 ObservationUI** (3-4小时)
5. **系统集成** (2-3小时)

---

**计划创建时间**: 2025-10-20
**负责人**: Claude (Sonnet 4.5)
**项目**: Microverse In Box (盒中小世界)
**状态**: 🚧 **进行中** - 准备实现 ConflictSystem
