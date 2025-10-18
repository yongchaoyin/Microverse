# Godot项目技术架构详细规范

## 文档信息
- **版本**: v1.0
- **创建日期**: 2025-10-18
- **文档类型**: P0 - 技术架构
- **依赖文档**:
  - 01_项目愿景与核心设计.md
  - 13_LLM集成架构详细规范.md
  - 14_数据结构设计规范.md

---

## 1. 架构概述

### 1.1 技术栈
- **游戏引擎**: Godot 4.4 (GL Compatibility)
- **脚本语言**: GDScript
- **渲染模式**: 2D + 简单3D (透视模拟)
- **架构模式**:
  - **Autoload Singleton** - 全局管理器
  - **Scene Component** - 场景组件化
  - **Signal-Driven** - 信号驱动通信
  - **Observer Pattern** - 观察者模式(UI观察游戏状态)

### 1.2 设计哲学
```
核心原则:
1. AI优先 - AI系统是核心,其他系统围绕AI设计
2. 观察者模式 - 玩家不干预,只观察
3. 松耦合 - 通过Signal和Autoload解耦模块
4. 数据驱动 - 配置和数据分离,支持热加载
5. 性能优先 - 8个AI同时运行,大量LLM调用
```

---

## 2. Autoload全局管理器架构

### 2.1 Autoload配置清单

根据项目需求,需要配置以下Autoload单例(按依赖顺序):

```ini
# project.godot [autoload] section

# ========== 基础层 (无依赖) ==========
ConfigManager="*res://script/core/ConfigManager.gd"           # 配置管理器
EventBus="*res://script/core/EventBus.gd"                     # 全局事件总线
DebugConsole="*res://script/debug/DebugConsole.gd"            # 调试控制台

# ========== 核心系统层 ==========
TimeSystem="*res://script/time/TimeSystem.gd"                 # 时间系统
EconomyManager="*res://script/economy/EconomyManager.gd"      # 经济系统
SettingsManager="*res://script/ui/SettingsManager.gd"         # 设置管理器(已存在)

# ========== AI系统层 ==========
APIManager="*res://script/ai/APIManager.gd"                   # API管理器(已存在)
MemoryManager="*res://script/ai/memory/MemoryManager.gd"      # 记忆管理器(已存在)
RelationshipManager="*res://script/ai/RelationshipManager.gd" # 关系管理器
PersonalityEngine="*res://script/ai/PersonalityEngine.gd"     # 性格引擎
CareerSystem="*res://script/ai/CareerSystem.gd"               # 职业系统
ScheduleManager="*res://script/ai/ScheduleManager.gd"         # 日程管理器

# ========== 角色管理层 ==========
CharacterManager="*res://script/CharacterManager.gd"          # 角色管理器(已存在)
DialogManager="*res://script/ai/DialogManager.gd"             # 对话管理器(已存在)

# ========== 存档系统层 ==========
GameSaveManager="*res://script/GameSaveManager.gd"            # 存档管理器(已存在)
DatabaseManager="*res://script/data/DatabaseManager.gd"       # SQLite数据库管理器

# ========== UI层 (Scene形式) ==========
SaveLoadUIManager="*res://scene/ui/SaveLoadUIManager.tscn"    # 存档UI管理器(已存在)
ObservationUIManager="*res://script/ui/ObservationUIManager.gd" # 观察者UI管理器
```

### 2.2 Autoload依赖关系图

```
基础层:
  ConfigManager (配置管理)
  EventBus (事件总线)
  DebugConsole (调试)
        ↓
核心系统层:
  TimeSystem (时间) ← EventBus
  EconomyManager (经济) ← TimeSystem
  SettingsManager (设置) ← ConfigManager
        ↓
AI系统层:
  APIManager (API) ← SettingsManager
  MemoryManager (记忆) ← TimeSystem
  RelationshipManager (关系) ← TimeSystem, MemoryManager
  PersonalityEngine (性格) ← ConfigManager
  CareerSystem (职业) ← TimeSystem, EconomyManager
  ScheduleManager (日程) ← TimeSystem, CareerSystem
        ↓
角色管理层:
  CharacterManager (角色) ← TimeSystem, PersonalityEngine, MemoryManager, RelationshipManager, ScheduleManager
  DialogManager (对话) ← APIManager, CharacterManager
        ↓
存档系统层:
  GameSaveManager (存档) ← CharacterManager, TimeSystem, EconomyManager
  DatabaseManager (数据库) ← ConfigManager
        ↓
UI层:
  SaveLoadUIManager (存档UI) ← GameSaveManager
  ObservationUIManager (观察UI) ← CharacterManager, TimeSystem, EventBus
```

### 2.3 核心Autoload实现

#### 2.3.1 ConfigManager - 配置管理器

```gdscript
# script/core/ConfigManager.gd
extends Node

# 配置文件路径
const CONFIG_DIR = "res://config/"
const DATA_DIR = "res://data/"

# 缓存的配置数据
var _config_cache: Dictionary = {}

func _ready():
	print("[ConfigManager] 初始化配置管理器")
	_load_all_configs()

# 加载所有配置文件
func _load_all_configs():
	_load_json_config("careers.json")        # 职业配置
	_load_json_config("personalities.json")  # 性格模板配置
	_load_json_config("locations.json")      # 地点配置
	_load_json_config("schedules.json")      # 日程模板配置
	_load_json_config("prompts.json")        # Prompt模板配置
	print("[ConfigManager] 所有配置加载完成")

# 加载JSON配置
func _load_json_config(filename: String) -> Dictionary:
	var path = CONFIG_DIR + filename
	if not FileAccess.file_exists(path):
		push_warning("[ConfigManager] 配置文件不存在: " + path)
		return {}

	var file = FileAccess.open(path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("[ConfigManager] JSON解析错误: " + path)
		return {}

	_config_cache[filename] = json.data
	print("[ConfigManager] 加载配置: " + filename)
	return json.data

# 获取配置数据
func get_config(config_name: String) -> Dictionary:
	if _config_cache.has(config_name):
		return _config_cache[config_name]
	else:
		push_warning("[ConfigManager] 配置不存在: " + config_name)
		return {}

# 热重载配置
func reload_config(config_name: String):
	_load_json_config(config_name)
	EventBus.emit_signal("config_reloaded", config_name)

# 获取职业数据
func get_career_data(career_name: String) -> Dictionary:
	var careers = get_config("careers.json")
	return careers.get(career_name, {})

# 获取性格模板
func get_personality_template(template_name: String) -> Dictionary:
	var personalities = get_config("personalities.json")
	return personalities.get(template_name, {})

# 获取Prompt模板
func get_prompt_template(template_name: String) -> String:
	var prompts = get_config("prompts.json")
	return prompts.get(template_name, "")
```

#### 2.3.2 EventBus - 全局事件总线

```gdscript
# script/core/EventBus.gd
extends Node

# ==================== 时间系统事件 ====================
signal time_tick(game_minutes_passed: int)        # 每游戏分钟触发
signal hour_changed(hour: int)                     # 每小时触发
signal day_changed(year: int, season: int, day: int) # 每天触发
signal season_changed(season: int)                 # 每季节触发
signal year_changed(year: int)                     # 每年触发

# ==================== AI系统事件 ====================
signal ai_thought_generated(ai_id: String, thought: String)   # AI产生思考
signal ai_action_taken(ai_id: String, action: Dictionary)     # AI执行行动
signal ai_dialogue_started(ai_id: String, target_id: String)  # AI开始对话
signal ai_dialogue_ended(ai_id: String)                       # AI结束对话
signal ai_emotion_changed(ai_id: String, emotion: String)     # AI情绪变化
signal ai_relationship_changed(ai_id: String, target_id: String, relationship: Dictionary) # 关系变化

# ==================== 职业系统事件 ====================
signal work_started(ai_id: String)                # 开始工作
signal work_ended(ai_id: String)                  # 结束工作
signal salary_paid(ai_id: String, amount: int)    # 发放工资
signal career_promoted(ai_id: String, new_level: int) # 职业晋升
signal performance_evaluated(ai_id: String, performance: int) # 绩效评估

# ==================== 记忆系统事件 ====================
signal memory_created(ai_id: String, memory: Dictionary)      # 创建记忆
signal memory_forgotten(ai_id: String, memory_id: String)     # 遗忘记忆
signal memory_consolidated(ai_id: String, memory_ids: Array)  # 记忆整合
signal core_memory_updated(ai_id: String)                     # 核心记忆更新

# ==================== 存档系统事件 ====================
signal game_saved(slot_id: int)                   # 游戏保存
signal game_loaded(slot_id: int)                  # 游戏加载
signal autosave_triggered()                       # 自动存档触发

# ==================== UI系统事件 ====================
signal ui_focus_changed(ai_id: String)            # UI焦点切换
signal ui_panel_opened(panel_name: String)        # UI面板打开
signal ui_panel_closed(panel_name: String)        # UI面板关闭

# ==================== 配置系统事件 ====================
signal config_reloaded(config_name: String)       # 配置重载

func _ready():
	print("[EventBus] 全局事件总线初始化完成")

# 辅助函数:打印所有连接的信号(调试用)
func debug_print_connections(signal_name: String):
	var connections = get_signal_connection_list(signal_name)
	print("[EventBus] Signal '%s' 连接数: %d" % [signal_name, connections.size()])
	for connection in connections:
		print("  - Target: %s, Method: %s" % [connection["callable"].get_object(), connection["callable"].get_method()])
```

#### 2.3.3 TimeSystem - 时间系统

```gdscript
# script/time/TimeSystem.gd
extends Node

# 时间配置
const REAL_SECONDS_PER_GAME_MINUTE: float = 6.0  # 10倍速: 10游戏分钟 = 60现实秒
const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const DAYS_PER_SEASON: int = 28
const SEASONS_PER_YEAR: int = 4

# 季节枚举
enum Season {
	SPRING = 0,
	SUMMER = 1,
	AUTUMN = 2,
	WINTER = 3
}

# 当前时间状态
var current_year: int = 1
var current_season: int = Season.SPRING
var current_day: int = 1
var current_hour: int = 6        # 游戏从早上6点开始
var current_minute: int = 0

# 时间流逝控制
var time_paused: bool = false
var time_multiplier: float = 1.0  # 时间倍率(可调整)

# 内部计时器
var _accumulated_time: float = 0.0

func _ready():
	print("[TimeSystem] 时间系统初始化")
	set_process(true)

func _process(delta: float):
	if time_paused:
		return

	_accumulated_time += delta * time_multiplier

	# 每累积足够时间,游戏时间前进1分钟
	if _accumulated_time >= REAL_SECONDS_PER_GAME_MINUTE:
		_accumulated_time -= REAL_SECONDS_PER_GAME_MINUTE
		_advance_time(1)

# 时间前进
func _advance_time(minutes: int):
	var old_hour = current_hour
	var old_day = current_day
	var old_season = current_season
	var old_year = current_year

	current_minute += minutes

	# 处理进位
	if current_minute >= MINUTES_PER_HOUR:
		var hours_to_add = current_minute / MINUTES_PER_HOUR
		current_minute = current_minute % MINUTES_PER_HOUR
		current_hour += hours_to_add

	if current_hour >= HOURS_PER_DAY:
		var days_to_add = current_hour / HOURS_PER_DAY
		current_hour = current_hour % HOURS_PER_DAY
		current_day += days_to_add

	if current_day > DAYS_PER_SEASON:
		var seasons_to_add = (current_day - 1) / DAYS_PER_SEASON
		current_day = ((current_day - 1) % DAYS_PER_SEASON) + 1
		current_season += seasons_to_add

	if current_season >= SEASONS_PER_YEAR:
		var years_to_add = current_season / SEASONS_PER_YEAR
		current_season = current_season % SEASONS_PER_YEAR
		current_year += years_to_add

	# 发送事件
	EventBus.emit_signal("time_tick", minutes)

	if current_hour != old_hour:
		EventBus.emit_signal("hour_changed", current_hour)

	if current_day != old_day:
		EventBus.emit_signal("day_changed", current_year, current_season, current_day)

	if current_season != old_season:
		EventBus.emit_signal("season_changed", current_season)

	if current_year != old_year:
		EventBus.emit_signal("year_changed", current_year)

# 获取当前时间字符串
func get_time_string() -> String:
	return "%02d:%02d" % [current_hour, current_minute]

# 获取当前日期字符串
func get_date_string() -> String:
	var season_names = ["春", "夏", "秋", "冬"]
	return "第%d年 %s季 第%d天" % [current_year, season_names[current_season], current_day]

# 获取完整时间字符串
func get_full_time_string() -> String:
	return "%s %s" % [get_date_string(), get_time_string()]

# 暂停/恢复时间
func pause_time():
	time_paused = true
	print("[TimeSystem] 时间已暂停")

func resume_time():
	time_paused = false
	print("[TimeSystem] 时间已恢复")

func toggle_pause():
	time_paused = !time_paused

# 设置时间倍率
func set_time_multiplier(multiplier: float):
	time_multiplier = clamp(multiplier, 0.1, 10.0)
	print("[TimeSystem] 时间倍率设置为: %.1fx" % time_multiplier)

# 检查是否在某个时间段内
func is_time_between(start_hour: int, end_hour: int) -> bool:
	if end_hour > start_hour:
		return current_hour >= start_hour and current_hour < end_hour
	else:  # 跨越午夜
		return current_hour >= start_hour or current_hour < end_hour

# 获取时间段描述
func get_time_period() -> String:
	if current_hour >= 6 and current_hour < 12:
		return "morning"
	elif current_hour >= 12 and current_hour < 18:
		return "afternoon"
	elif current_hour >= 18 and current_hour < 22:
		return "evening"
	else:
		return "night"

# 保存/加载时间状态
func save_state() -> Dictionary:
	return {
		"year": current_year,
		"season": current_season,
		"day": current_day,
		"hour": current_hour,
		"minute": current_minute,
		"paused": time_paused,
		"multiplier": time_multiplier
	}

func load_state(state: Dictionary):
	current_year = state.get("year", 1)
	current_season = state.get("season", 0)
	current_day = state.get("day", 1)
	current_hour = state.get("hour", 6)
	current_minute = state.get("minute", 0)
	time_paused = state.get("paused", false)
	time_multiplier = state.get("multiplier", 1.0)
	_accumulated_time = 0.0
	print("[TimeSystem] 时间状态已加载: " + get_full_time_string())
```

#### 2.3.4 RelationshipManager - 关系管理器

```gdscript
# script/ai/RelationshipManager.gd
extends Node

# 关系数据存储 {ai_id: {target_id: RelationshipData}}
var _relationships: Dictionary = {}

# 关系阈值配置
const RELATIONSHIP_THRESHOLDS = {
	"stranger": 0,      # 陌生人
	"acquaintance": 20, # 熟人
	"friend": 60,       # 朋友
	"close_friend": 80, # 好友
	"best_friend": 95,  # 挚友
	"romantic": 70      # 恋爱(需要romance维度)
}

func _ready():
	print("[RelationshipManager] 关系管理器初始化")
	EventBus.connect("ai_dialogue_ended", _on_dialogue_ended)
	EventBus.connect("day_changed", _on_day_changed)

# 初始化AI的关系网络
func initialize_character(ai_id: String, all_ai_ids: Array[String]):
	if not _relationships.has(ai_id):
		_relationships[ai_id] = {}

	for other_id in all_ai_ids:
		if other_id != ai_id and not _relationships[ai_id].has(other_id):
			_relationships[ai_id][other_id] = _create_initial_relationship()

	print("[RelationshipManager] 初始化 %s 的关系网络" % ai_id)

# 创建初始关系数据
func _create_initial_relationship() -> Dictionary:
	return {
		"familiarity": 0,    # 熟悉度 0-100
		"affection": 50,     # 好感度 0-100
		"trust": 50,         # 信任度 0-100
		"romance": 0,        # 浪漫度 0-100
		"interaction_count": 0,
		"last_interaction_time": "",
		"relationship_level": "stranger",
		"interaction_history": []  # 最近10次互动记录
	}

# 获取关系数据
func get_relationship(ai_id: String, target_id: String) -> Dictionary:
	if not _relationships.has(ai_id):
		return {}
	return _relationships[ai_id].get(target_id, {})

# 更新关系维度
func update_relationship(ai_id: String, target_id: String, dimension: String, change: int):
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		push_warning("[RelationshipManager] 关系不存在: %s -> %s" % [ai_id, target_id])
		return

	var relationship = _relationships[ai_id][target_id]

	# 更新维度值
	if dimension in ["familiarity", "affection", "trust", "romance"]:
		var old_value = relationship[dimension]
		relationship[dimension] = clamp(relationship[dimension] + change, 0, 100)

		print("[RelationshipManager] %s 对 %s 的%s: %d -> %d (变化:%+d)" %
			[ai_id, target_id, dimension, old_value, relationship[dimension], change])

	# 更新关系等级
	_update_relationship_level(ai_id, target_id)

	# 发送事件
	EventBus.emit_signal("ai_relationship_changed", ai_id, target_id, relationship)

# 记录互动
func record_interaction(ai_id: String, target_id: String, interaction_type: String, sentiment: int):
	if not _relationships.has(ai_id) or not _relationships[ai_id].has(target_id):
		return

	var relationship = _relationships[ai_id][target_id]
	relationship.interaction_count += 1
	relationship.last_interaction_time = TimeSystem.get_full_time_string()

	# 记录互动历史(保留最近10次)
	var history_entry = {
		"type": interaction_type,
		"sentiment": sentiment,
		"time": TimeSystem.get_full_time_string()
	}
	relationship.interaction_history.append(history_entry)
	if relationship.interaction_history.size() > 10:
		relationship.interaction_history.pop_front()

	# 根据互动类型和情感值更新关系维度
	_apply_interaction_effects(ai_id, target_id, interaction_type, sentiment)

# 应用互动影响
func _apply_interaction_effects(ai_id: String, target_id: String, interaction_type: String, sentiment: int):
	# 每次互动增加熟悉度
	update_relationship(ai_id, target_id, "familiarity", 1)

	# 根据情感值影响好感度
	var affection_change = sentiment / 10  # sentiment范围-100到100,转换为-10到10
	update_relationship(ai_id, target_id, "affection", affection_change)

	# 正面互动增加信任
	if sentiment > 50:
		update_relationship(ai_id, target_id, "trust", 1)
	elif sentiment < -50:
		update_relationship(ai_id, target_id, "trust", -2)

	# 特殊互动类型影响浪漫度
	if interaction_type in ["flirt", "date", "gift"]:
		update_relationship(ai_id, target_id, "romance", 2)

# 更新关系等级
func _update_relationship_level(ai_id: String, target_id: String):
	var relationship = _relationships[ai_id][target_id]
	var familiarity = relationship.familiarity
	var affection = relationship.affection

	# 判断关系等级
	var level = "stranger"
	if familiarity >= RELATIONSHIP_THRESHOLDS.best_friend and affection >= RELATIONSHIP_THRESHOLDS.best_friend:
		level = "best_friend"
	elif familiarity >= RELATIONSHIP_THRESHOLDS.close_friend and affection >= RELATIONSHIP_THRESHOLDS.close_friend:
		level = "close_friend"
	elif familiarity >= RELATIONSHIP_THRESHOLDS.friend and affection >= RELATIONSHIP_THRESHOLDS.friend:
		level = "friend"
	elif familiarity >= RELATIONSHIP_THRESHOLDS.acquaintance:
		level = "acquaintance"

	# 检查是否有浪漫关系
	if relationship.romance >= RELATIONSHIP_THRESHOLDS.romantic and affection >= RELATIONSHIP_THRESHOLDS.romantic:
		level = "romantic"

	if relationship.relationship_level != level:
		var old_level = relationship.relationship_level
		relationship.relationship_level = level
		print("[RelationshipManager] %s 和 %s 的关系升级: %s -> %s" % [ai_id, target_id, old_level, level])

# 获取所有好友列表
func get_friends(ai_id: String, min_level: String = "friend") -> Array[String]:
	if not _relationships.has(ai_id):
		return []

	var friends: Array[String] = []
	var level_priority = {
		"stranger": 0,
		"acquaintance": 1,
		"friend": 2,
		"close_friend": 3,
		"best_friend": 4,
		"romantic": 5
	}

	var min_priority = level_priority.get(min_level, 2)

	for target_id in _relationships[ai_id]:
		var relationship = _relationships[ai_id][target_id]
		var target_priority = level_priority.get(relationship.relationship_level, 0)
		if target_priority >= min_priority:
			friends.append(target_id)

	return friends

# 获取最亲密的N个人
func get_closest_people(ai_id: String, count: int = 5) -> Array[String]:
	if not _relationships.has(ai_id):
		return []

	# 按综合分数排序
	var scored_relationships = []
	for target_id in _relationships[ai_id]:
		var relationship = _relationships[ai_id][target_id]
		var score = relationship.familiarity * 0.3 + relationship.affection * 0.4 + relationship.trust * 0.2 + relationship.romance * 0.1
		scored_relationships.append({"id": target_id, "score": score})

	# 排序
	scored_relationships.sort_custom(func(a, b): return a.score > b.score)

	# 返回前N个
	var result: Array[String] = []
	for i in range(min(count, scored_relationships.size())):
		result.append(scored_relationships[i].id)

	return result

# 每日关系衰减
func _on_day_changed(year: int, season: int, day: int):
	for ai_id in _relationships:
		for target_id in _relationships[ai_id]:
			var relationship = _relationships[ai_id][target_id]

			# 如果长时间没有互动,熟悉度和浪漫度会衰减
			# (简化实现,实际应检查last_interaction_time)
			if relationship.familiarity > 0:
				relationship.familiarity = max(0, relationship.familiarity - 0.5)
			if relationship.romance > 0:
				relationship.romance = max(0, relationship.romance - 1)

# 对话结束后的关系处理
func _on_dialogue_ended(ai_id: String):
	# 在DialogManager中会调用record_interaction
	pass

# 保存/加载关系数据
func save_state() -> Dictionary:
	return {
		"relationships": _relationships
	}

func load_state(state: Dictionary):
	_relationships = state.get("relationships", {})
	print("[RelationshipManager] 关系数据已加载,共%d个AI的关系网络" % _relationships.size())
```

---

## 3. 场景树架构

### 3.1 主场景结构

```
Main (Node2D)
├── WorldEnvironment (CanvasLayer)
│   ├── Background (ColorRect)
│   └── TimeOfDayOverlay (ColorRect) # 时间段光照效果
│
├── GameWorld (Node2D) # 游戏世界根节点
│   ├── Map (TileMap) # 地图
│   ├── Buildings (Node2D) # 建筑物容器
│   │   ├── Office (Building)
│   │   ├── Cafe (Building)
│   │   ├── Park (Building)
│   │   └── Apartments (Node2D)
│   │       ├── Apartment_1 (Building)
│   │       └── ... (其他公寓)
│   │
│   ├── Characters (Node2D) # 角色容器
│   │   ├── AICharacter_1 (AICharacter)
│   │   ├── AICharacter_2 (AICharacter)
│   │   └── ... (其他AI角色)
│   │
│   └── InteractionZones (Node2D) # 交互区域
│       ├── WorkZone (Area2D)
│       ├── SocialZone (Area2D)
│       └── ...
│
├── CameraController (Camera2D) # 观察者摄像机
│   └── CameraUI (CanvasLayer) # 摄像机UI提示
│
└── UILayer (CanvasLayer) # UI层
    ├── HUD (Control) # 主HUD
    │   ├── TimeDisplay (Label)
    │   ├── SpeedControl (HBoxContainer)
    │   └── QuickActions (HBoxContainer)
    │
    ├── ObservationPanel (Panel) # 观察面板(右侧)
    │   ├── CharacterInfo (VBoxContainer)
    │   ├── ThoughtDisplay (RichTextLabel)
    │   ├── StatsDisplay (GridContainer)
    │   └── RelationshipView (TabContainer)
    │
    ├── CharacterListPanel (Panel) # 角色列表(左侧)
    │   ├── CharacterList (ItemList)
    │   └── FilterButtons (HBoxContainer)
    │
    ├── SettingsMenu (Panel) # 设置菜单
    ├── SaveLoadMenu (Panel) # 存档菜单
    └── DebugOverlay (Panel) # 调试覆盖层
```

### 3.2 核心场景组件

#### 3.2.1 AICharacter场景

```
AICharacter (CharacterBody2D)
├── Sprite (Sprite2D) # 角色精灵
├── AnimationPlayer (AnimationPlayer) # 动画播放器
├── CollisionShape (CollisionShape2D) # 碰撞形状
├── InteractionArea (Area2D) # 交互区域
│   └── InteractionCollision (CollisionShape2D)
├── ThoughtBubble (Node2D) # 思考气泡
│   ├── BubbleSprite (Sprite2D)
│   └── ThoughtText (Label)
├── EmotionIcon (Sprite2D) # 情绪图标
├── NameLabel (Label) # 名字标签
│
└── Components (Node) # 组件容器
    ├── AIBrain (Node) # AI大脑组件
    │   ├── ThinkingSystem (AIMultiTimerThinking)
    │   ├── DecisionMaker (AIDecisionMaker)
    │   └── DialogueHandler (AIDialogueHandler)
    │
    ├── MovementController (Node) # 移动控制器
    ├── AnimationController (Node) # 动画控制器
    ├── StatsController (Node) # 状态控制器
    └── ScheduleExecutor (Node) # 日程执行器
```

**AICharacter核心脚本**:

```gdscript
# scene/character/AICharacter.gd
class_name AICharacter extends CharacterBody2D

# AI数据引用
var character_data: AICharacterData

# 组件引用
@onready var ai_brain = $Components/AIBrain
@onready var movement_controller = $Components/MovementController
@onready var animation_controller = $Components/AnimationController
@onready var stats_controller = $Components/StatsController
@onready var schedule_executor = $Components/ScheduleExecutor

# UI元素引用
@onready var sprite = $Sprite
@onready var thought_bubble = $ThoughtBubble
@onready var emotion_icon = $EmotionIcon
@onready var name_label = $NameLabel

func _ready():
	# 初始化角色
	if character_data:
		_initialize_character()

	# 连接事件
	EventBus.connect("time_tick", _on_time_tick)
	EventBus.connect("hour_changed", _on_hour_changed)

func _initialize_character():
	name_label.text = character_data.character_name

	# 初始化AI大脑
	ai_brain.initialize(character_data)

	# 初始化其他组件
	movement_controller.initialize(character_data)
	stats_controller.initialize(character_data)
	schedule_executor.initialize(character_data)

	print("[AICharacter] %s 初始化完成" % character_data.character_name)

func _physics_process(delta):
	# 更新移动
	movement_controller.update(delta)

	# 更新动画
	animation_controller.update(velocity, movement_controller.current_state)

	# 物理移动
	move_and_slide()

# 显示思考气泡
func show_thought(thought: String, duration: float = 3.0):
	thought_bubble.get_node("ThoughtText").text = thought
	thought_bubble.visible = true

	# duration秒后隐藏
	await get_tree().create_timer(duration).timeout
	thought_bubble.visible = false

# 更新情绪图标
func update_emotion_icon(emotion: String):
	# 根据情绪显示不同图标
	var icon_map = {
		"happy": preload("res://assets/icons/emotion_happy.png"),
		"sad": preload("res://assets/icons/emotion_sad.png"),
		"angry": preload("res://assets/icons/emotion_angry.png"),
		"neutral": preload("res://assets/icons/emotion_neutral.png")
	}

	if emotion in icon_map:
		emotion_icon.texture = icon_map[emotion]
		emotion_icon.visible = true
	else:
		emotion_icon.visible = false

# 时间tick处理
func _on_time_tick(minutes: int):
	# 更新状态(饥饿、能量等)
	stats_controller.on_time_tick(minutes)

# 小时变化处理
func _on_hour_changed(hour: int):
	# 检查日程
	schedule_executor.check_schedule(hour)

# 保存角色状态
func save_state() -> Dictionary:
	return {
		"character_data": character_data.to_dict(),
		"position": {"x": position.x, "y": position.y},
		"current_state": movement_controller.current_state
	}

# 加载角色状态
func load_state(state: Dictionary):
	if state.has("character_data"):
		character_data.from_dict(state.character_data)
	if state.has("position"):
		position = Vector2(state.position.x, state.position.y)
	if state.has("current_state"):
		movement_controller.current_state = state.current_state
```

---

## 4. 信号系统架构

### 4.1 信号流向图

```
EventBus (全局事件总线)
    ↓ 时间事件
TimeSystem → hour_changed → ScheduleManager (检查日程)
                          → CareerSystem (检查上下班)
                          → AICharacter (更新状态)
    ↓ AI事件
AIBrain → ai_thought_generated → ObservationUIManager (显示思考)
                               → MemoryManager (记录思考)
        → ai_action_taken → CharacterManager (执行动作)
                          → ObservationUIManager (更新UI)
    ↓ 对话事件
DialogManager → ai_dialogue_started → ObservationUIManager (显示对话)
                                    → RelationshipManager (准备关系更新)
              → ai_dialogue_ended → RelationshipManager (更新关系)
                                  → MemoryManager (记录对话记忆)
    ↓ 关系事件
RelationshipManager → ai_relationship_changed → ObservationUIManager (更新关系显示)
                                              → MemoryManager (记录关系变化)
    ↓ 存档事件
GameSaveManager → game_saved → SaveLoadUIManager (更新UI)
                → game_loaded → 所有Manager (重新加载状态)
```

### 4.2 信号使用示例

```gdscript
# 示例1: AI思考系统发送思考事件
# script/ai/thinking/AIMultiTimerThinking.gd
func _on_continuous_thought():
	var thought = await _call_llm_for_thought("continuous")
	EventBus.emit_signal("ai_thought_generated", character_data.id, thought)
	# MemoryManager和ObservationUIManager会自动接收并处理

# 示例2: ObservationUIManager监听多个事件
# script/ui/ObservationUIManager.gd
func _ready():
	EventBus.connect("ai_thought_generated", _on_ai_thought_generated)
	EventBus.connect("ai_action_taken", _on_ai_action_taken)
	EventBus.connect("ai_emotion_changed", _on_ai_emotion_changed)
	EventBus.connect("ui_focus_changed", _on_ui_focus_changed)

func _on_ai_thought_generated(ai_id: String, thought: String):
	if ai_id == currently_focused_ai_id:
		thought_display.text = thought
		_add_thought_to_history(thought)

# 示例3: 时间系统驱动日程检查
# script/ai/ScheduleManager.gd
func _ready():
	EventBus.connect("hour_changed", _on_hour_changed)

func _on_hour_changed(hour: int):
	for ai_id in _schedules:
		_check_and_execute_schedule(ai_id, hour)
```

---

## 5. 项目目录结构

```
Microverse/
├── project.godot
├── icon.svg
│
├── assets/ # 资源文件
│   ├── fonts/
│   ├── icons/
│   ├── sprites/
│   │   ├── characters/
│   │   ├── buildings/
│   │   └── ui/
│   ├── audio/
│   │   ├── music/
│   │   └── sfx/
│   └── shaders/
│
├── config/ # 配置文件(JSON)
│   ├── careers.json
│   ├── personalities.json
│   ├── locations.json
│   ├── schedules.json
│   └── prompts.json
│
├── data/ # 数据文件(运行时生成)
│   ├── saves/ # 存档文件
│   └── database/ # SQLite数据库
│       └── memories.db
│
├── scene/ # 场景文件
│   ├── main.tscn # 主场景
│   ├── character/
│   │   ├── AICharacter.tscn
│   │   └── AICharacter.gd
│   ├── buildings/
│   │   ├── Building.tscn
│   │   └── Building.gd
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── ObservationPanel.tscn
│   │   ├── CharacterListPanel.tscn
│   │   ├── SettingsMenu.tscn
│   │   ├── SaveLoadUIManager.tscn (已存在)
│   │   └── DebugOverlay.tscn
│   └── world/
│       ├── Map.tscn
│       └── InteractionZone.tscn
│
├── script/ # 脚本文件
│   ├── core/ # 核心系统
│   │   ├── ConfigManager.gd (新)
│   │   └── EventBus.gd (新)
│   │
│   ├── time/ # 时间系统
│   │   └── TimeSystem.gd (新)
│   │
│   ├── economy/ # 经济系统
│   │   └── EconomyManager.gd (新)
│   │
│   ├── ai/ # AI系统
│   │   ├── APIManager.gd (已存在)
│   │   ├── APIConfig.gd (已存在)
│   │   ├── DialogManager.gd (已存在)
│   │   ├── AIAgent.gd (已存在)
│   │   │
│   │   ├── memory/ # 记忆系统
│   │   │   ├── MemoryManager.gd (已存在)
│   │   │   ├── MemoryData.gd (新)
│   │   │   └── ThoughtData.gd (新)
│   │   │
│   │   ├── thinking/ # 思考系统
│   │   │   ├── AIMultiTimerThinking.gd (新)
│   │   │   ├── AIDecisionMaker.gd (新)
│   │   │   └── AIDialogueHandler.gd (新)
│   │   │
│   │   ├── data/ # AI数据
│   │   │   └── AICharacterData.gd (新)
│   │   │
│   │   ├── RelationshipManager.gd (新)
│   │   ├── PersonalityEngine.gd (新)
│   │   ├── CareerSystem.gd (新)
│   │   └── ScheduleManager.gd (新)
│   │
│   ├── ui/ # UI系统
│   │   ├── SettingsManager.gd (已存在)
│   │   ├── ObservationUIManager.gd (新)
│   │   └── CameraController.gd (新)
│   │
│   ├── data/ # 数据管理
│   │   └── DatabaseManager.gd (新)
│   │
│   ├── debug/ # 调试工具
│   │   └── DebugConsole.gd (新)
│   │
│   ├── CharacterManager.gd (已存在)
│   └── GameSaveManager.gd (已存在)
│
├── docs/ # 文档
│   ├── 01_项目愿景与核心设计.md
│   ├── 02_观察者哲学与设计原则.md
│   ├── ... (其他文档)
│   └── design/
│       ├── 06-12_*.md (P1系统规范)
│       ├── 13_LLM集成架构详细规范.md
│       ├── 14_数据结构设计规范.md
│       └── 15_Godot项目技术架构.md (本文档)
│
└── addons/ # Godot插件
    └── (未来可能添加SQLite插件等)
```

---

## 6. 性能优化策略

### 6.1 AI系统性能优化

```gdscript
# 1. LLM调用异步化+队列管理
class_name LLMRequestQueue extends Node

var _request_queue: Array = []
var _active_requests: int = 0
const MAX_CONCURRENT_REQUESTS = 3  # 最多同时3个LLM请求

func add_request(request_data: Dictionary):
	_request_queue.append(request_data)
	_process_queue()

func _process_queue():
	while _active_requests < MAX_CONCURRENT_REQUESTS and _request_queue.size() > 0:
		var request = _request_queue.pop_front()
		_active_requests += 1
		_execute_request(request)

func _execute_request(request: Dictionary):
	# 执行异步LLM请求
	var response = await APIManager.call_ai_async(request)
	_active_requests -= 1
	request.callback.call(response)
	_process_queue()

# 2. 内存系统分层加载
# MemoryManager只在内存中保存工作记忆+短期记忆
# 长期记忆和核心记忆按需从SQLite加载

# 3. 关系数据延迟加载
# RelationshipManager只加载活跃AI的关系数据
# 其他AI关系数据按需加载
```

### 6.2 渲染性能优化

```gdscript
# 1. 角色可见性剔除
# AICharacter只在摄像机视野内才更新动画和思考气泡

func _on_visibility_changed():
	if not visible:
		# 不在视野内,停止高频更新
		ai_brain.reduce_update_frequency()
		animation_controller.pause()

# 2. UI更新节流
# ObservationPanel只在选中AI时更新,且限制更新频率
var _last_ui_update_time: float = 0.0
const UI_UPDATE_INTERVAL: float = 0.5  # 每0.5秒更新一次

func _process(delta):
	_last_ui_update_time += delta
	if _last_ui_update_time >= UI_UPDATE_INTERVAL:
		_update_ui()
		_last_ui_update_time = 0.0

# 3. 地图分块加载(未来扩展)
# 如果地图很大,使用TileMap分块加载
```

### 6.3 内存管理

```gdscript
# 1. 对象池模式(思考气泡、UI元素)
class_name ObjectPool extends Node

var _pool: Array = []
var _scene_template: PackedScene

func get_instance() -> Node:
	if _pool.size() > 0:
		return _pool.pop_back()
	else:
		return _scene_template.instantiate()

func return_instance(instance: Node):
	instance.visible = false
	_pool.append(instance)

# 2. 记忆数据定期清理
# MemoryManager每天自动清理importance < 10的短期记忆

# 3. 存档压缩
# GameSaveManager保存时压缩JSON数据
```

---

## 7. 开发工作流与调试

### 7.1 开发模式

```gdscript
# script/debug/DebugConsole.gd
extends CanvasLayer

var console_visible: bool = false
var debug_mode: bool = false

@onready var console_panel = $ConsolePanel
@onready var command_input = $ConsolePanel/CommandInput
@onready var output_log = $ConsolePanel/OutputLog

func _ready():
	console_panel.visible = false

	# 注册调试命令
	_register_commands()

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_QUOTELEFT:  # ` key
		toggle_console()

func toggle_console():
	console_visible = !console_visible
	console_panel.visible = console_visible
	if console_visible:
		command_input.grab_focus()

func _register_commands():
	# 时间控制
	add_command("time_set", _cmd_time_set, "设置游戏时间: time_set <hour> <minute>")
	add_command("time_speed", _cmd_time_speed, "设置时间倍率: time_speed <multiplier>")
	add_command("time_pause", _cmd_time_pause, "暂停/恢复时间")

	# AI控制
	add_command("ai_think", _cmd_ai_think, "强制AI思考: ai_think <ai_id>")
	add_command("ai_teleport", _cmd_ai_teleport, "传送AI: ai_teleport <ai_id> <x> <y>")
	add_command("ai_stats", _cmd_ai_stats, "显示AI状态: ai_stats <ai_id>")

	# 关系控制
	add_command("rel_set", _cmd_rel_set, "设置关系: rel_set <ai_id> <target_id> <dimension> <value>")
	add_command("rel_show", _cmd_rel_show, "显示关系: rel_show <ai_id> <target_id>")

	# 记忆控制
	add_command("mem_add", _cmd_mem_add, "添加记忆: mem_add <ai_id> <memory_text>")
	add_command("mem_list", _cmd_mem_list, "列出记忆: mem_list <ai_id>")

	# 存档控制
	add_command("save", _cmd_save, "快速保存: save <slot_id>")
	add_command("load", _cmd_load, "快速加载: load <slot_id>")

	# 系统控制
	add_command("reload_config", _cmd_reload_config, "重载配置: reload_config <config_name>")
	add_command("debug_mode", _cmd_debug_mode, "切换调试模式")

func _cmd_time_set(args: Array):
	if args.size() < 2:
		return "用法: time_set <hour> <minute>"
	TimeSystem.current_hour = int(args[0])
	TimeSystem.current_minute = int(args[1])
	return "时间已设置为: %s" % TimeSystem.get_time_string()

func _cmd_ai_think(args: Array):
	if args.size() < 1:
		return "用法: ai_think <ai_id>"
	var ai_id = args[0]
	var character = CharacterManager.get_character(ai_id)
	if character:
		character.ai_brain.force_think("continuous")
		return "已强制 %s 进行思考" % ai_id
	return "找不到AI: %s" % ai_id

# ... 更多命令实现
```

### 7.2 调试UI

```gdscript
# scene/ui/DebugOverlay.gd
extends Panel

# 显示实时统计信息
@onready var fps_label = $VBoxContainer/FPSLabel
@onready var time_label = $VBoxContainer/TimeLabel
@onready var ai_count_label = $VBoxContainer/AICountLabel
@onready var llm_calls_label = $VBoxContainer/LLMCallsLabel
@onready var memory_usage_label = $VBoxContainer/MemoryUsageLabel

func _process(delta):
	if visible:
		_update_stats()

func _update_stats():
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	time_label.text = "游戏时间: %s" % TimeSystem.get_full_time_string()
	ai_count_label.text = "AI数量: %d" % CharacterManager.get_character_count()
	llm_calls_label.text = "LLM调用/分钟: %d" % APIManager.get_calls_per_minute()

	var memory_mb = OS.get_static_memory_usage() / 1024.0 / 1024.0
	memory_usage_label.text = "内存使用: %.1f MB" % memory_mb
```

### 7.3 单元测试结构(未来扩展)

```
tests/
├── unit/
│   ├── test_time_system.gd
│   ├── test_relationship_manager.gd
│   ├── test_memory_manager.gd
│   └── test_personality_engine.gd
├── integration/
│   ├── test_ai_thinking_flow.gd
│   └── test_save_load_system.gd
└── test_runner.gd
```

---

## 8. 部署与打包配置

### 8.1 导出预设

```ini
# project.godot [export] section

# Windows导出
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
custom_features=""
export_filter="all_resources"
include_filter="*.json,*.db"
exclude_filter=""

# 自定义配置
[preset.0.options]
binary_format/64_bits=true
texture_format/bptc=true
binary_format/embed_pck=true

# macOS导出
[preset.1]
name="macOS"
platform="macOS"
runnable=true
# ... 类似配置

# Linux导出
[preset.2]
name="Linux/X11"
platform="Linux/X11"
runnable=true
# ... 类似配置
```

### 8.2 资源优化

```
# 1. 纹理压缩
- 角色精灵: VRAM Compressed (S3TC/BPTC)
- UI图标: Lossless (PNG)

# 2. 音频压缩
- 背景音乐: OGG Vorbis (质量7)
- 音效: WAV/OGG (质量5)

# 3. 字体子集化
- 只包含需要的字符(中文常用3500字)

# 4. 场景实例化
- 使用场景继承减少重复
```

---

## 9. 技术债务与未来扩展

### 9.1 当前已知技术债务

1. **SQLite插件依赖**: 目前依赖第三方SQLite插件,未来可能需要自己维护或迁移
2. **LLM调用错误处理**: 需要更完善的重试机制和降级策略
3. **关系系统复杂度**: 随着AI数量增加,关系网络会呈指数增长
4. **内存泄漏风险**: 大量异步LLM调用可能导致内存泄漏,需要严格测试

### 9.2 未来扩展方向

```
# 1. 多人观察模式(网络同步)
- 多个玩家同时观察同一个世界
- 使用Godot High-Level Multiplayer API

# 2. MOD支持
- 允许玩家自定义AI性格、职业、Prompt模板
- 使用GDScript脚本热加载

# 3. AI训练模式
- 记录玩家评价,优化AI行为
- 使用强化学习调整personality权重

# 4. 更多AI模型支持
- 本地模型(Llama 3, Qwen等)
- 更多云API(Azure OpenAI, Cohere等)

# 5. 3D渲染升级
- 迁移到3D渲染器
- 更逼真的环境和光照
```

---

## 10. 总结与检查清单

### 10.1 架构完成度检查

- [x] Autoload管理器架构设计完成
- [x] 场景树结构设计完成
- [x] 信号系统架构设计完成
- [x] 核心Autoload实现示例(ConfigManager, EventBus, TimeSystem, RelationshipManager)
- [x] 核心场景组件实现示例(AICharacter)
- [x] 项目目录结构规划完成
- [x] 性能优化策略规划完成
- [x] 调试工具设计完成
- [x] 部署配置规划完成

### 10.2 开发准备度评估

**P0文档完成度**:
- ✅ 13_LLM集成架构详细规范.md (已完成)
- ✅ 14_数据结构设计规范.md (已完成)
- ✅ 15_Godot项目技术架构.md (本文档)
- ⏳ 16_观察者UI/UX详细设计.md (待创建)

**可以开始的开发任务**:
1. ✅ 创建核心Autoload单例(ConfigManager, EventBus, TimeSystem等)
2. ✅ 实现AICharacterData资源类
3. ✅ 创建AICharacter场景和脚本
4. ✅ 实现RelationshipManager
5. ✅ 实现DatabaseManager(SQLite集成)

**需要UI文档后才能开始的任务**:
1. ⏳ 创建ObservationPanel UI
2. ⏳ 创建CharacterListPanel UI
3. ⏳ 实现CameraController交互

---

## 附录A: project.godot完整配置

```ini
; Engine configuration file.
config_version=5

[application]

config/name="Microverse"
run/main_scene="res://scene/main.tscn"
config/features=PackedStringArray("4.4", "GL Compatibility")
config/icon="res://icon.svg"

[autoload]

# ========== 基础层 ==========
ConfigManager="*res://script/core/ConfigManager.gd"
EventBus="*res://script/core/EventBus.gd"
DebugConsole="*res://script/debug/DebugConsole.gd"

# ========== 核心系统层 ==========
TimeSystem="*res://script/time/TimeSystem.gd"
EconomyManager="*res://script/economy/EconomyManager.gd"
SettingsManager="*res://script/ui/SettingsManager.gd"

# ========== AI系统层 ==========
APIManager="*res://script/ai/APIManager.gd"
MemoryManager="*res://script/ai/memory/MemoryManager.gd"
RelationshipManager="*res://script/ai/RelationshipManager.gd"
PersonalityEngine="*res://script/ai/PersonalityEngine.gd"
CareerSystem="*res://script/ai/CareerSystem.gd"
ScheduleManager="*res://script/ai/ScheduleManager.gd"

# ========== 角色管理层 ==========
CharacterManager="*res://script/CharacterManager.gd"
DialogManager="*res://script/ai/DialogManager.gd"

# ========== 存档系统层 ==========
GameSaveManager="*res://script/GameSaveManager.gd"
DatabaseManager="*res://script/data/DatabaseManager.gd"

# ========== UI层 ==========
SaveLoadUIManager="*res://scene/ui/SaveLoadUIManager.tscn"
ObservationUIManager="*res://script/ui/ObservationUIManager.gd"

[display]

window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"
display/window/dpi/allow_hidpi=true

[input]

# ... (现有输入配置保持不变)

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
environment/defaults/default_clear_color=Color(0, 0, 0, 1)
```

---

**文档结束**

**下一步**: 创建 16_观察者UI/UX详细设计.md,完成所有P0文档,然后正式开始开发。
