# Microverse P0 Engineering Roadmap

> Authored: 2025-10-19  
> Scope: Bring the current Godot prototype to the P0 design baseline.  
> Audience: Engineering team taking over implementation.

## 0. 开发环境配置

### Godot 引擎要求
- **版本**: Godot 4.5.1 (stable.official.f62fdbde1)
- **安装路径**: `C:\Godot\godot.exe`
- **重要**: 本项目使用 Godot 4.x 语法，请确保使用正确版本避免语法错误

### 环境验证
```bash
# 验证 Godot 版本
godot --version
# 应输出: 4.5.1.stable.official.f62fdbde1

# 验证安装路径
where godot
# 应输出: C:\Godot\godot.exe
```

### 项目兼容性
- ✅ 项目配置文件兼容 Godot 4.5.1
- ✅ GDScript 语法使用 Godot 4.x 标准
- ✅ 场景文件和节点类型完全兼容
- ✅ 自动加载脚本配置正确

## 1. Target Autoload Topology

| Order | Node Alias          | Script Path                               | Status | Notes |
|-------|---------------------|-------------------------------------------|--------|-------|
| 01    | `ConfigManager`     | `res://script/core/ConfigManager.gd`      | ✳️ New | Runtime settings, feature toggles, exposed via JSON + inspector. |
| 02    | `EventBus`          | `res://script/core/EventBus.gd`           | ✳️ New | Central signal relay; minimizes hard references. |
| 03    | `DebugConsole`      | `res://script/debug/DebugConsole.gd`      | ✳️ New | Overlay for commands, log filtering, performance probes. |
| 04    | `TimeSystem`        | `res://script/time/TimeSystem.gd`         | ✳️ New | Global clock, seasonal cycle, cadence signals. |
| 05    | `WeatherSystem`     | `res://script/weather/WeatherSystem.gd`   | ✳️ New | Season-aware forecast + environmental hooks. |
| 06    | `EconomyManager`    | `res://script/economy/EconomyManager.gd`  | ✳️ New | Payroll, purchases, inflation, transaction history. |
| 07    | `SettingsManager`   | `res://script/ui/SettingsManager.gd`      | ✅     | Already shipping; extend to read ConfigManager defaults. |
| 08    | `APIManager`        | `res://script/ai/APIManager.gd`           | ✅     | Integrate with EventBus for tracing. |
| 09    | `MemoryManager`     | `res://script/ai/memory/MemoryManager.gd` | ✅     | Needs retention policies + TimeSystem hooks. |
| 10    | `RelationshipManager`| `res://script/ai/RelationshipManager.gd` | ✳️ New | Multi-channel relations, trust thresholds, lookup APIs. |
| 11    | `PersonalityEngine` | `res://script/ai/PersonalityEngine.gd`    | ✳️ New | Normalizes trait data, exposes bias modifiers. |
| 12    | `CareerSystem`      | `res://script/ai/CareerSystem.gd`         | ✳️ New | Career ladders, seniority, salary bands. |
| 13    | `ScheduleManager`   | `res://script/ai/ScheduleManager.gd`      | ✳️ New | Generates daily agendas per AI, reacts to TimeSystem. |
| 14    | `TaskSystem`        | `res://script/task/TaskSystem.gd`         | ✳️ New | Full task lifecycle + LLM scoring integration. |
| 15    | `ConflictSystem`    | `res://script/conflict/ConflictSystem.gd` | ✳️ New | Handles disputes, cooldowns, logs events. |
| 16    | `CharacterManager`  | `res://script/CharacterManager.gd`        | ✅     | Subscribe to EventBus/TimeSystem for selection refresh. |
| 17    | `DialogManager`     | `res://script/ai/DialogManager.gd`        | ✅     | Modules updates: incorporate Task/Relation context. |
| 18    | `LocationManager`   | `res://script/navigation/LocationManager.gd` | ✅ | Requires occupancy + hotspot metadata. |
| 19    | `SaveManager`       | `res://script/save/SaveManager.gd`        | ✳️ New | Versioned persistence; replaces `GameSaveManager`. |
| 20    | `DatabaseManager`   | `res://script/data/DatabaseManager.gd`    | ✳️ New | SQLite bridge for high-volume logs. |
| 21    | `ObservationUIManager` | `res://script/ui/ObservationUIManager.gd` | ✳️ New | Observer dashboards, draws from Time/Economy/Relations. |
| 22    | `SaveLoadUIManager` | `res://scene/ui/SaveLoadUIManager.tscn`   | ✅     | Wire to SaveManager once replaced. |

✳️ New = to be implemented in this roadmap.

## 2. Module Responsibilities & Key APIs

### TimeSystem
- `set_time_scale(float)`, `pause()`, `resume()`.
- Getter utilities: `get_current_timestamp()`, `is_weekend()`, `add_hours()`, `add_days()`.
- Emits cadence signals consumed by ScheduleManager, WeatherSystem, EconomyManager, MemoryManager.

### ScheduleManager
- `register_agent(ai_id: String, profile: Dictionary)` – called by CharacterManager on spawn.  
- `get_current_activity(ai_id)` – returns `{type, location_id, task_ref, mood_bias}`.  
- Listens to `TimeSystem.hour_changed` to push activity transitions; falls back to default schedule templates per career.

### TaskSystem
- `request_daily_plan(ai_id, context)` – merges scheduled blocks with outstanding tasks.  
- `assign_task(ai_id, task_dict)`, `complete_task(ai_id, task_id, result_dict)`, `fail_task(...)`.  
- `get_weekly_performance(ai_id)` – returns KPIs for EconomyManager.  
- Internally manages LLMAssist queue (`DialogManager` backed) for task creation/evaluation.

### EconomyManager
- Payroll pipeline: `process_weekly_payroll()` invoked by `TimeSystem` every Monday 06:00.  
- `record_transaction(buyer_id, seller_id, item_id, amount, channel)` – logs to DatabaseManager + EventBus.  
- Inflation tick executed at `season_changed`.

### RelationshipManager
- Relation graph keyed by tuple `(source_id, target_id)`.  
- APIs: `get_relationship(ai_a, ai_b)`, `apply_delta(ai_a, ai_b, channel, amount, reason)`, `can_request_loan(...)`.  
- Emits `relationship_changed` to UI/ConflictSystem.

### SaveManager
- Snapshot groups: `time`, `world` (weather, locations), `agents` (stats, relations, tasks, memories), `economy`, `config`.  
- Uses DatabaseManager for heavy logs and JSON for quick saves.  
- Backward-compatible migration pipeline: `upgrade(save_data)` returning normalized structure.

## 3. Integration Flow (Event Perspective)

1. **Time Tick**  
   `TimeSystem.hour_changed` → ScheduleManager updates activities → TaskSystem checks deadlines  
   → WeatherSystem maybe transitions → EconomyManager accrues salaries → MemoryManager rotates buffers.

2. **Task Completion**  
   TaskSystem marks completion → emits `task_completed(ai_id, task_data)` via EventBus  
   → RelationshipManager adjusts affinity if relevant → EconomyManager awards bonus  
   → MemoryManager stores highlight → ObservationUIManager refreshes panels.

3. **Conflict Trigger**  
   RelationshipManager emits `trust_below_threshold` → ConflictSystem opens case  
   → pushes notification to ObservationUI and potential tasks (mediation) → on resolve, SaveManager logs outcome.

## 4. Implementation Phasing

### Phase A – Core Simulation Spine
1. Create `core/` (ConfigManager, EventBus, DebugConsole).  
2. Implement `time/TimeSystem.gd` with signals/utilities.  
3. Update scenes/autoload list; retrofit modules (MemoryManager, CharacterManager) to consume new signals.

### Phase B – AI Daily Flow
4. Implement `ai/CareerSystem`, `ai/ScheduleManager`, `task/TaskSystem`.  
5. Extend AIAgent to subscribe to schedule/task updates, request LLM assistance through DialogManager.  
6. Extend GodUI to display time controls and per-character schedule/task state.

### Phase C – Economy & Persistence
7. Implement `economy/EconomyManager` + payroll workflow (`get_weekly_performance` dependency).  
8. Replace `GameSaveManager` with `save/SaveManager` and integrate DatabaseManager.  
9. Update SaveLoad UI and GodUI dashboards.

### Phase D – Social Dynamics
10. Build `ai/RelationshipManager`, `conflict/ConflictSystem`, enhance MemoryManager for new categories.  
11. Add ObservationUI overlays (relationship graph, conflict log).  
12. Hook dialog/task/economy systems to trust thresholds and conflict resolutions.

### Phase E – Polish & QA
13. WeatherSystem visuals + audio, integrate mood modifiers.  
14. Performance instrumentation via DebugConsole (LLM call counters, task queue metrics).  
15. Automated smoke scripts (GUT or lightweight) to ensure save/load, time progression, task loops.

## 5. Data & Configuration Artifacts
- `res://data/tasks/*.json` – template definitions per domain.  
- `res://data/careers.json` – work hours, salary bands, role metadata.  
- `res://data/locations.json` – canonical location registry (id → attributes).  
- `res://data/weather_tables.json` – seasonal weather probability curves.  
- `res://config/default_settings.json` – feed ConfigManager initial state.

## 6. Tech Debt Management
- Deprecate direct singletons lookups in AIAgent; prefer EventBus subscriptions.  
- Refactor `GodUI.gd` monolith by extracting panels (TaskPanel, CharacterDetailPanel).  
- Ensure all new systems emit explicit signals for UI/analytics instead of direct node references.

## 7. 开发环境详细配置指南

### Godot 安装与配置
1. **下载 Godot 4.5.1**
   - 官方下载地址: https://godotengine.org/download/
   - 选择 "Godot Engine 4.5.1 - Standard version"
   - 推荐安装到: `C:\Godot\`

2. **环境变量配置**
   ```bash
   # 将 Godot 添加到系统 PATH
   # 在系统环境变量中添加: C:\Godot\
   ```

3. **项目导入**
   ```bash
   # 克隆项目
   git clone <repository-url>
   cd Microverse
   
   # 使用 Godot 打开项目
   godot project.godot
   ```

### 常见问题排查
- **语法错误**: 确保使用 Godot 4.x 语法，避免 Godot 3.x 遗留代码
- **节点路径**: 使用 `get_node()` 而非 `$` 操作符进行动态节点访问
- **信号连接**: 使用 `signal.connect()` 新语法
- **类型提示**: 充分利用 Godot 4.x 的静态类型系统

### 开发工具推荐
- **IDE**: Godot 内置编辑器 + VSCode (GDScript 插件)
- **版本控制**: Git (已配置 .gitignore)
- **调试**: 使用 DebugConsole 系统进行运行时调试

This roadmap should remain living; update after each phase with delivered status and adjustments.

