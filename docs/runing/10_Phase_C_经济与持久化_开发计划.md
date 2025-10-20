# Phase C: 经济与持久化 - 开发计划

## 📋 概述

**任务**: 实现 Microverse 项目的 Phase C - Economy & Persistence (经济与持久化)
**开始时间**: 2025-10-20
**当前状态**: 🔄 **准备开始**

---

## ✅ Phase A & B 回顾

### Phase A: 核心骨架 (100% 完成)
- ✅ ConfigManager.gd (349行)
- ✅ EventBus.gd (414行)
- ✅ DebugConsole.gd (600行)
- ✅ TimeSystem.gd (514行)

### Phase B: AI核心能力 (100% 完成)
- ✅ RelationshipManager.gd (512行) - 已增强
- ✅ MemoryManager.gd (1458行) - 已重构
- ✅ PersonalityEngine.gd (~400行) - 已实现
- ✅ PerceptionComponent.gd (754行) - 已完成
- ✅ AICharacterData.gd (675行) - 已完成

**Phase A+B 总代码量**: ~5600行

---

## 🎯 Phase C 系统清单

根据工程计划 (engineering_plan_p0.md)，Phase C 包含以下系统：

### 1. EconomyManager - 经济系统管理器 ❌ (需新建)

**优先级**: 🔥 **最高**

**功能设计**:
- 工资系统 (每周一 06:00 发放)
- 交易记录 (购买、消费、转账)
- 通货膨胀 (每季度调整)
- 绩效奖金
- 债务管理

**关键API**:
```gdscript
func process_weekly_payroll()
func record_transaction(buyer_id, seller_id, item_id, amount, channel)
func get_character_balance(character_id) -> int
func award_bonus(character_id, amount, reason)
```

**集成系统**:
- TimeSystem (监听 `hour_changed`, `day_changed`)
- CareerSystem (获取薪资数据)
- TaskSystem (绩效奖金)
- DatabaseManager (交易日志)

**预计代码量**: 300-400行

---

### 2. CareerSystem - 职业系统 ❌ (需新建)

**优先级**: 🔥 **最高** (EconomyManager 依赖)

**功能设计**:
- 职业数据管理 (从 `data/careers.json` 加载)
- 薪资计算 (基础工资 + 职级系数)
- 晋升系统
- 绩效评估

**关键API**:
```gdscript
func get_career_data(career_id: String) -> Dictionary
func get_base_salary(career_id: String, level: int) -> int
func calculate_promotion_eligibility(character_id: String) -> float
func promote_character(character_id: String)
```

**集成系统**:
- ConfigManager (加载职业配置)
- PersonalityEngine (影响绩效)
- TaskSystem (工作任务完成度)

**预计代码量**: 250-350行

---

### 3. SaveManager - 增强版存档管理器 ❌ (需新建)

**优先级**: ⭐ **高**

**功能设计**:
- 替换现有的 GameSaveManager
- 版本化存档 (支持向后兼容)
- 快照系统 (time, world, agents, economy, config)
- 自动存档
- 备份管理

**关键API**:
```gdscript
func save_game(save_name: String, save_type: String) -> bool
func load_game(save_name: String) -> bool
func create_autosave()
func list_all_saves() -> Array
func upgrade_save_data(old_data: Dictionary) -> Dictionary
```

**集成系统**:
- TimeSystem (时间快照)
- WeatherSystem (天气状态)
- 所有 Manager (数据收集)
- DatabaseManager (大量日志数据)

**预计代码量**: 400-600行

---

### 4. DatabaseManager - 数据库管理器 ❌ (需新建)

**优先级**: ⭐ **高** (SaveManager 依赖)

**功能设计**:
- SQLite 集成
- 交易日志存储
- 记忆数据持久化
- 思考历史存储
- 查询优化

**关键API**:
```gdscript
func initialize_database()
func log_transaction(transaction_data: Dictionary)
func save_memory(memory_data: Dictionary)
func query_memories(ai_id: String, filters: Dictionary) -> Array
func cleanup_old_data(days_to_keep: int)
```

**集成系统**:
- EconomyManager (交易日志)
- MemoryManager (记忆持久化)
- SaveManager (大数据存储)

**预计代码量**: 350-500行

**技术难点**:
- Godot 4.x 的 SQLite 插件集成
- 可能需要使用第三方插件或自己实现接口

---

## 📊 开发优先级排序

根据依赖关系,推荐实施顺序:

```
1. CareerSystem (无依赖,被 EconomyManager 依赖)
   ↓
2. EconomyManager (依赖 CareerSystem)
   ↓
3. DatabaseManager (被 SaveManager 依赖)
   ↓
4. SaveManager (依赖所有上述系统)
```

---

## 🎯 Phase C 详细实施计划

### Step 1: CareerSystem (预计 2-3 小时)

**任务**:
1. ✅ 读取职业系统设计文档 (08_AI职业系统详细规范.md)
2. ✅ 创建 `script/ai/career/` 目录
3. ✅ 创建 `CareerSystem.gd` Autoload
4. ✅ 实现职业数据加载 (从 JSON)
5. ✅ 实现薪资计算方法
6. ✅ 实现晋升系统
7. ✅ 集成 TimeSystem 和 PersonalityEngine
8. ✅ 创建完成报告

**验收标准**:
- [ ] 可以加载 `data/careers.json`
- [ ] 可以根据职业和职级计算薪资
- [ ] 晋升逻辑正常工作
- [ ] 集成 EventBus,发送职业相关事件

---

### Step 2: EconomyManager (预计 2-3 小时)

**任务**:
1. ✅ 读取经济系统设计文档 (07_经济系统详细规范.md)
2. ✅ 创建 `script/economy/` 目录
3. ✅ 创建 `EconomyManager.gd` Autoload
4. ✅ 实现工资发放系统
5. ✅ 实现交易记录系统
6. ✅ 实现通货膨胀机制
7. ✅ 集成 TimeSystem, CareerSystem, EventBus
8. ✅ 创建完成报告

**验收标准**:
- [ ] 每周一自动发工资
- [ ] 可以记录所有交易
- [ ] 通货膨胀每季度调整
- [ ] 绩效奖金系统正常

---

### Step 3: DatabaseManager (预计 3-4 小时)

**任务**:
1. ✅ 调研 Godot 4.x SQLite 插件
2. ✅ 创建 `script/data/` 目录
3. ✅ 创建 `DatabaseManager.gd` Autoload
4. ✅ 实现数据库初始化
5. ✅ 实现交易日志表
6. ✅ 实现记忆数据表
7. ✅ 实现查询接口
8. ✅ 创建完成报告

**验收标准**:
- [ ] 数据库文件创建成功 (`user://database/game.db`)
- [ ] 可以存储和查询交易
- [ ] 可以存储和查询记忆
- [ ] 性能良好 (1000条记录 < 100ms)

**备选方案**:
如果 SQLite 插件有问题,可以:
- 使用 JSON 文件存储 (性能较差,但兼容性好)
- 延迟到 Phase E 再实现
- 使用内存数据库 + 定期序列化

---

### Step 4: SaveManager (预计 3-4 小时)

**任务**:
1. ✅ 读取存档系统设计文档 (22_游戏存档系统详细规范.md)
2. ✅ 创建 `script/save/` 目录
3. ✅ 创建 `SaveManager.gd` Autoload
4. ✅ 实现数据收集方法 (from all managers)
5. ✅ 实现保存/加载方法
6. ✅ 实现版本迁移
7. ✅ 实现自动存档
8. ✅ 更新 SaveLoadUIManager 集成
9. ✅ 创建完成报告

**验收标准**:
- [ ] 可以保存完整游戏状态
- [ ] 可以加载并恢复游戏状态
- [ ] 版本迁移正常工作
- [ ] 自动存档每天触发
- [ ] 备份系统正常

---

## 📝 所需配置文件

### 1. `data/careers.json`

```json
{
  "ceo": {
    "name_cn": "CEO",
    "name_en": "Chief Executive Officer",
    "base_salary": 50000,
    "salary_per_level": 10000,
    "max_level": 1,
    "work_hours": {"start": 9, "end": 18},
    "description": "公司老板"
  },
  "frontend_engineer": {
    "name_cn": "前端工程师",
    "name_en": "Frontend Engineer",
    "base_salary": 5000,
    "salary_per_level": 2000,
    "max_level": 5,
    "work_hours": {"start": 9, "end": 18},
    "promotion_requirements": {
      "performance_threshold": 80,
      "years_required": 2
    }
  },
  // ... 其他职业
}
```

### 2. `data/economy_config.json`

```json
{
  "payroll_day": 1,  // 每周一
  "payroll_hour": 6,
  "inflation_rate": 0.02,  // 每季度2%
  "tax_rate": 0.15,
  "bonus_multipliers": {
    "excellent": 1.5,
    "good": 1.2,
    "average": 1.0,
    "poor": 0.8
  }
}
```

---

## 🔧 技术决策

### 1. 数据库选择

**选项A: SQLite**
- ✅ 适合大量数据
- ✅ 查询灵活
- ❌ 需要第三方插件
- ❌ 可能有兼容性问题

**选项B: JSON文件**
- ✅ Godot 原生支持
- ✅ 无需插件
- ❌ 大量数据性能差
- ❌ 查询不灵活

**决策**: 先尝试 SQLite,如有问题降级为 JSON

### 2. 存档格式

**决策**: JSON (人类可读,易于调试)
- 使用 `JSON.stringify(data, "\t")` 格式化
- 压缩选项留给后期优化
- 备份保留最近5个自动存档

### 3. 工资发放时机

**决策**: 每周一 06:00 (游戏时间)
- 监听 `TimeSystem.day_changed` 信号
- 检查是否为周一 (`current_day % 7 == 0`)
- 检查小时是否为 06:00

---

## 📈 预期成果

完成 Phase C 后:

1. **经济系统完整运作**:
   - AI 每周收到工资
   - 所有交易被记录
   - 通货膨胀影响价格

2. **存档系统完善**:
   - 可以随时保存游戏
   - 可以加载并继续游戏
   - 自动存档保护进度

3. **数据持久化**:
   - 大量数据存入数据库
   - 查询性能良好
   - 数据不丢失

4. **代码量增加**:
   - 预计新增 1300-1850 行代码
   - 总代码量达到 ~7000-7500 行

---

## ⚠️ 风险评估

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| SQLite 插件不可用 | 中 | 高 | 准备 JSON 降级方案 |
| 存档版本迁移复杂 | 低 | 中 | 从简单版本开始,逐步扩展 |
| 性能问题 (大量交易) | 中 | 中 | 使用数据库索引,定期清理 |
| 依赖系统未完成 | 低 | 高 | 按顺序实施,确保依赖就绪 |

---

## 🎯 验收标准

### 整体验收

- [ ] 所有4个系统实现完成
- [ ] 所有系统集成测试通过
- [ ] 存档/读档功能正常
- [ ] 经济系统运行稳定
- [ ] 性能符合预期
- [ ] 代码质量达标 (注释率 > 20%)
- [ ] 完成报告已创建

### 集成测试场景

1. **工资发放测试**:
   - 启动游戏,快进到下周一 06:00
   - 检查所有AI收到工资
   - 检查工资金额正确

2. **交易测试**:
   - AI之间进行交易
   - 检查交易记录正确
   - 检查余额更新

3. **存档测试**:
   - 保存游戏
   - 退出并重新加载
   - 检查所有状态恢复
   - 检查时间、金钱、关系、记忆都正确

4. **数据库测试**:
   - 插入1000条交易记录
   - 查询性能 < 100ms
   - 数据准确性100%

---

## 📚 参考文档

- `docs/engineering_plan_p0.md` - P0工程路线图
- `docs/design/07_经济系统详细规范.md` - 经济系统设计
- `docs/design/08_AI职业系统详细规范.md` - 职业系统设计
- `docs/design/22_游戏存档系统详细规范.md` - 存档系统设计
- `docs/design/15_Godot项目技术架构.md` - 技术架构
- `docs/design/15.5_Godot技术架构补充_新增系统集成.md` - 系统集成

---

## 🚀 下一步

**立即开始**: 实现 CareerSystem

**理由**:
1. 无依赖,可独立开发
2. EconomyManager 依赖它
3. 代码量适中 (250-350行)
4. 逻辑清晰,风险低

**预计时间**: 2-3小时

---

**创建日期**: 2025-10-20
**负责人**: Claude (Sonnet 4.5)
**项目**: Microverse In Box (盒中小世界)
**状态**: ✅ 计划完成,等待开始实施
